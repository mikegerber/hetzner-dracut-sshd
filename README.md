# hetzner-dracut-sshd

🚧 **Work in progress** 🚧

Post-install script for Hetzner's `installimage` that installs `dracut-sshd` to enable remote LUKS unlocking via SSH. Tested with Rocky Linux 10. It should also work with AlmaLinux 10 and possibly earlier releases, but these have not been tested.

## Notes

- The script assumes a setup with LVM on RAID1, but this is not a strict requirement. Other setups may require small changes to the script.
- Replaces NetworkManager with `systemd-networkd` and installs `systemd-resolved`
  - `systemd-networkd` is configured to use DHCP on all Ethernet interfaces
  - Although NetworkManager would probably also work with the implicitly installed `dracut-network`, we use `systemd-networkd` here because it’s our preferred option.
- Enables EPEL (required for `dracut-sshd` and `systemd-networkd`)
- Installs `dracut-sshd`
  - Uses the SSH keys in `/root/.ssh/authorized_keys`, as previously installed by `installimage`
