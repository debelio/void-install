# Void Linux Automated Installation Script

Automated installer for Void Linux with LUKS2 encryption, BTRFS filesystem, and UEFI support.

**Inspired by**: [easy-arch](https://github.com/classy-giraffe/easy-arch)

## Features

- **Full Disk Encryption** (LUKS2)
- **BTRFS with Subvolumes** (snapshots, compression)
- **UEFI Boot** (GRUB with encryption support)
- **Security** (AppArmor enabled)
- **Performance** (zram swap, optimized mount options)

## Prerequisites

- Boot from Void Linux live image
- UEFI-capable system
- Internet connection configured (the easiest way is via `void-installer`)

## Installation Steps

1. **Initial Setup**:
```bash
# Download and run
curl -O https://raw.githubusercontent.com/debelio/repo/void-install.sh
chmod +x void-install.sh
sudo ./void-install.sh
```

## What the Script Does

1. **Preparation**: Checks permissions, updates packages
2. **User Input**: Passwords, hostname, user account
3. **Partitioning**: Creates ESP (300MB) + encrypted root
4. **Encryption**: LUKS2 with keyfile for boot
5. **Filesystem**: BTRFS with subvolumes (@, @home, @snapshots, etc.)
6. **Installation**: Base system + essential packages + AppArmor + zram + snapper + the XBPS source packages collection
7. **Configuration**: Timezone, locales, users, services
8. **Boot Setup**: GRUB with LUKS2 support

## Post-Installation

Use `nmcli` or `nm-tui` after installation to set up networking.

## BTRFS Layout

```
/              (@)
/home          (@home)
/root          (@root)
/.snapshots    (@snapshots)
/var/cache     (@var/cache)
/var/log       (@var/log)
/boot/efi      (FAT32)
```

## License

This project is licensed under the Apache License - see the [LICENSE](LICENSE) file for details.
