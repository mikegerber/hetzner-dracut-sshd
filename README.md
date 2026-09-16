# hetzner-dracut-sshd

🚧 **Work in progress** 🚧

Post-install script for Hetzner's `installimage` that installs `dracut-sshd` to enable remote LUKS
unlocking via SSH.

This is tested with Rocky Linux 10. It should also work with AlmaLinux 10 and possibly earlier
releases, but these have not been tested.

Not written by Hetzner, it's written *for* (installing Rocky Linux servers at) Hetzner.


## Notes

- The script assumes a setup with LVM on LUKS on RAID1, but this is not a strict requirement. Other
  setups may require small changes to the script.
- Configures the initramfs to enable networking (e.g. NetworkManager) in early boot
  - `dracut-network`, NetworkManager in the initramfs and `rd.neednet=1` in the kernel cmdline
  - Reuses the static IP configuration that `installimage` configures (via `dracut-network`)
- Enables EPEL (required for `dracut-sshd`)
- Installs `dracut-sshd`
  - Uses the SSH keys in `/root/.ssh/authorized_keys`, as previously installed by `installimage`
- Always check `/root/postinstall_debug.txt` after `installimage` ran.

### After rebooting out of the rescue system

- The system reboots again after first boot due to SELinux autorelabeling. That means that you will
  need to ssh into the initrd to unlock *twice* if it's the first time.

### Troubleshooting

- Always check `/root/postinstall_debug.txt` after `postinstall` ran.
- It's not specific to this postinstall script, but make sure you know how to mount an encrypted
  system from the rescue disk using `mdadm`, `cryptsetup`, `lvscan` etc. Also remember to `touch
  /path-to/mounted-system/.autorelabel` after tinkering, to not break booting due to SELinux
  choking on unlabeled files.
- Be sure to regenerate your initramfs if you changed anything substantial, e.g. NetworkManager
  configuration.
