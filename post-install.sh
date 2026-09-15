#!/usr/bin/bash

set -euo pipefail


have_cmd() { command -v "$1" &>/dev/null; }

enable_epel() {
  echo "Enable CodeReady Builder repository..."
  dnf config-manager --set-enabled crb

  echo "Checking for EPEL repository..."
  if ! dnf repolist enabled | grep -qE '^epel'; then
    echo "EPEL repository not found — enabling it now."
    dnf -y install epel-release || {
      echo "Failed to install epel-release. Attempting manual enable..."
      dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
    }
  else
    echo "EPEL is already enabled."
  fi
}

install_storage_deps() {
  dnf -y install mdadm cryptsetup lvm2
}

write_network_file() {
  mkdir -p /etc/systemd/network
  local f="/etc/systemd/network/20-wired.network"
  cat > "$f" <<'EOF'
[Match]
Type=ether

[Network]
DHCP=yes
EOF
  chmod 0644 "$f"
  echo "Wrote $f"
}

disable_networkmanager() {
  systemctl disable NetworkManager.service || true
  systemctl disable NetworkManager-wait-online.service || true
  systemctl mask NetworkManager.service || true
  echo "NetworkManager disabled and masked."
}

enable_networkd_and_resolved() {
  dnf -y install systemd-networkd systemd-resolved
  systemctl enable systemd-networkd.service
  systemctl enable systemd-resolved.service
  echo "Enabled systemd-networkd and systemd-resolved."
}


configure_dracut() {
  local f="/etc/dracut.conf.d/10-raid1-luks.conf"
  cat > "$f" <<'EOF'
add_drivers+=" raid1 dm_crypt "
add_dracutmodules+=" mdraid crypt lvm "
EOF
  chmod 0644 "$f"
  echo "Wrote $f"

  local f="/etc/dracut.conf.d/90-networkd.conf"
  cat > "$f" <<'EOF'
install_items+=" /etc/systemd/network/20-wired.network "
add_dracutmodules+=" systemd-networkd "
omit_dracutmodules+=" network-manager "
EOF
  chmod 0644 "$f"
  echo "Wrote $f"

  echo "Configured initrd for lvm on luks on raid1, systemd-networkd."
}

enable_dracut_sshd() {
  dnf -y install dracut-sshd
  echo "Enabled dracut-sshd."
}

regenerate_initrd() {
  dracut --regenerate-all --force
}

check_initrd() {
  local red=$(tput setaf 1)
  local green=$(tput setaf 2)
  local reset=$(tput sgr0)
  local ret=0

  for initrd in /boot/initramfs*; do
    # Skip over kdump and rescue image
    if [[ $initrd == *_64kdump.img ]] || [[ $initrd == /boot/initramfs-0-rescue* ]]; then
      continue
    fi

    echo "== $initrd"

    local tmpo=`mktemp`
    lsinitrd $initrd &>$tmpo

    for should_be in root/.ssh/authorized_keys bin/sshd usr/lib/systemd/systemd-networkd\$ etc/systemd/network/20-wired.network raid1.ko.xz dm-crypt.ko.xz usr/lib/systemd/system/cryptsetup.target bin/lvm\$ bin/mdadm\$ etc/ssh/ssh_host_ed25519_key; do
      if grep -q "$should_be" $tmpo; then
        echo "${green}OK: $should_be${reset}"
      else
        echo "${red}MISSING: $should_be${reset}"
        ret=1
      fi
    done
  done
  return $ret
}

setup_resolv_conf() {
  local target="/run/systemd/resolve/stub-resolv.conf"
  [[ -e "$target" ]] || target="/run/systemd/resolve/resolv.conf"

  if [[ -e /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
    cp -a /etc/resolv.conf /etc/resolv.conf.backup.$(date +%s)
  fi
  ln -snf "$target" /etc/resolv.conf
  echo "Linked /etc/resolv.conf -> $target"
}

main() {
  enable_epel

  install_storage_deps

  write_network_file
  enable_networkd_and_resolved
  disable_networkmanager

  configure_dracut

  enable_dracut_sshd

  regenerate_initrd
  check_initrd

  # Must be last to not break DNS before installs are finished:
  setup_resolv_conf
}

main "$@"
