# Void Linux Automated Installation Script

Automated installer for Void Linux with LUKS2 encryption, BTRFS filesystem, and UEFI support.

**Inspired by**: [easy-arch](https://github.com/classy-giraffe/easy-arch) and [VoidLinuxInstaller](https://github.com/Le0xFF/VoidLinuxInstaller)

## Features

- **Full Disk Encryption** (LUKS2)
- **BTRFS with Subvolumes** (snapshots, compression)
- **UEFI Boot** (GRUB with encryption support)
- **Security** (AppArmor enabled)
- **Performance** (zram swap, optimized mount options)
- **Snapshot Management** (snapper for root and home, grub-btrfs for bootable snapshots)


## Prerequisites

- Boot from Void Linux live image
- UEFI-capable system
- Internet connection configured (the easiest way is via `void-installer`)

## Installation Steps

1. **Initial Setup**:
```bash
# Download and run
curl -O https://raw.githubusercontent.com/debelio/linux-install/main/void/void-install.sh
chmod +x void-install.sh
sudo ./void-install.sh
```

## What the Script Does

1. **Preparation**: Checks permissions, updates packages
2. **User Input**: Passwords, hostname, user account
3. **Partitioning**: Creates ESP (1GB) + encrypted root
4. **Encryption**: LUKS2 with keyfile for boot
5. **Filesystem**: BTRFS with subvolumes (@, @home, @snapshots, etc.)
6. **Installation**: Base system + essential packages + AppArmor + zram + snapper + grub-btrfs + the XBPS source packages collection
7. **Configuration**: Timezone, locales, users, services
8. **Boot Setup**: GRUB with LUKS2 support

## Post-Installation

Use `nmcli` or `nm-tui` after installation to set up networking.

## BTRFS Layout

The installation creates separate BTRFS subvolumes for different parts of the filesystem:

```
/                  (@)
/home              (@home)
/home/.snapshots   (@home/.snapshots)   - snapper snapshots for home
/opt               (@opt)
/.snapshots        (@.snapshots)        - snapper snapshots for root
/var/cache         (@var/cache)
/var/lib/docker    (@var/lib/docker)
/var/lib/libvirt   (@var/lib/libvirt)
/var/log           (@var/log)
/var/spool         (@var/spool)
/tmp               (@tmp)
```

This layout allows:
- Separate snapshots for root and home directories via snapper
- Selective exclusion of cache, logs, and temporary data from snapshots
- Optimized mount options (compression, noatime, SSD support)
- Boot into any snapshot via GRUB menu (grub-btrfs integration)

## License

This project is licensed under the Apache License - see the [LICENSE](LICENSE) file for details.
