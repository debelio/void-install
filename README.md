# Void Linux Automated Installation Script

Automated installer for Void Linux with LUKS2 encryption, BTRFS filesystem, and UEFI support.

**Inspired by**: [easy-arch](https://github.com/classy-giraffe/easy-arch), [VoidLinuxInstaller](https://github.com/Le0xFF/VoidLinuxInstaller) and [SysGuides](https://sysguides.com/install-fedora-42-with-full-disk-encryption-snapshot-and-rollback-support)

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
5. **Filesystem**: BTRFS with subvolumes
6. **Installation**: Base system + essential packages + AppArmor + zram + snapper + grub-btrfs + the XBPS source packages collection
7. **Configuration**: Timezone, locales, users, services
8. **Boot Setup**: GRUB with LUKS2 support

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

## Post-Installation

### Network Configuration

Use `nmcli` or `nmtui` after installation to set up networking.

### XBPS Snapshot Wrappers

**Important**: As far as I know, unlike some package managers (like APT with apt-btrfs-snapshot or DNF with dnf-plugin-snapper), XBPS does not have built-in hooks for automatic snapshot creation.

To work around this limitation, [01-base-system.sh](01-base-system.sh) creates wrapper scripts that automatically create btrfs snapshots before and after package operations:

- **`/usr/local/bin/vpm-snap`** - Wrapper for `vpm` (Void Package Manager helper)
- **`/usr/local/bin/xbps-install-snap`** - Wrapper for `xbps-install`
- **`/usr/local/bin/xbps-remove-snap`** - Wrapper for `xbps-remove`

#### How the Wrappers Work

1. **Pre-snapshot**: Creates a numbered snapshot before the package operation
2. **Package operation**: Runs the actual xbps command
3. **Post-snapshot**: Creates a matching post-snapshot
4. **GRUB update**: Automatically updates GRUB menu (if grub-btrfsd isn't running)

#### Create the Wrappers

**`/usr/local/bin/vpm-snap`**:
```bash
#!/bin/sh
# vpm wrapper with snapper snapshots

# Skip snapshots if requested
if [ -n "$SNAP_XBPS_SKIP" ]; then
    exec /usr/bin/vpm "$@"
fi

# Check if this is an operation that modifies packages
case "$1" in
    install|i|update|up|upgrade|u|remove|rm|r)
        # Check if snapper is available
        if command -v snapper >/dev/null 2>&1; then
            # Create pre-snapshot
            PRE_NUM=$(snapper --config root create --type pre --cleanup-algorithm number --print-number --description "vpm $*" 2>/dev/null)
            [ -n "$PRE_NUM" ] && echo ":: Created pre-snapshot #$PRE_NUM"

            # Run vpm
            /usr/bin/vpm "$@"
            RESULT=$?

            # Create post-snapshot
            if [ -n "$PRE_NUM" ]; then
                POST_NUM=$(snapper --config root create --type post --pre-number "$PRE_NUM" --cleanup-algorithm number --print-number --description "vpm $*" 2>/dev/null)
                [ -n "$POST_NUM" ] && echo ":: Created post-snapshot #$POST_NUM"

                # Update GRUB if grub-btrfsd isn't running
                if ! pgrep -x grub-btrfsd >/dev/null 2>&1; then
                    grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 &
                fi
            fi

            exit $RESULT
        fi
        ;;
esac

# For all other operations, just pass through
exec /usr/bin/vpm "$@"
```

**`/usr/local/bin/xbps-install-snap`**:
```bash
#!/bin/sh
# xbps-install wrapper with snapper snapshots

# Skip snapshots if requested
if [ -n "$SNAP_XBPS_SKIP" ]; then
    exec /usr/bin/xbps-install "$@"
fi

# Check if snapper is available
if command -v snapper >/dev/null 2>&1 && [ -d /.snapshots ]; then
    # Create pre-snapshot
    PRE_NUM=$(snapper --config root create --type pre --cleanup-algorithm number --print-number --description "xbps-install $*" 2>/dev/null)
    [ -n "$PRE_NUM" ] && echo ":: Created pre-snapshot #$PRE_NUM"

    # Run xbps-install
    /usr/bin/xbps-install "$@"
    RESULT=$?

    # Create post-snapshot
    if [ -n "$PRE_NUM" ]; then
        POST_NUM=$(snapper --config root create --type post --pre-number "$PRE_NUM" --cleanup-algorithm number --print-number --description "xbps-install $*" 2>/dev/null)
        [ -n "$POST_NUM" ] && echo ":: Created post-snapshot #$POST_NUM"

        # Update GRUB if grub-btrfsd isn't running
        if ! pgrep -x grub-btrfsd >/dev/null 2>&1; then
            grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 &
        fi
    fi

    exit $RESULT
fi

exec /usr/bin/xbps-install "$@"
```

**`/usr/local/bin/xbps-remove-snap`**:
```bash
#!/bin/sh
# xbps-remove wrapper with snapper snapshots

# Skip snapshots if requested
if [ -n "$SNAP_XBPS_SKIP" ]; then
    exec /usr/bin/xbps-remove "$@"
fi

# Check if snapper is available
if command -v snapper >/dev/null 2>&1 && [ -d /.snapshots ]; then
    # Create pre-snapshot
    PRE_NUM=$(snapper --config root create --type pre --cleanup-algorithm number --print-number --description "xbps-remove $*" 2>/dev/null)
    [ -n "$PRE_NUM" ] && echo ":: Created pre-snapshot #$PRE_NUM"

    # Run xbps-remove
    /usr/bin/xbps-remove "$@"
    RESULT=$?

    # Create post-snapshot
    if [ -n "$PRE_NUM" ]; then
        POST_NUM=$(snapper --config root create --type post --pre-number "$PRE_NUM" --cleanup-algorithm number --print-number --description "xbps-remove $*" 2>/dev/null)
        [ -n "$POST_NUM" ] && echo ":: Created post-snapshot #$POST_NUM"

        # Update GRUB if grub-btrfsd isn't running
        if ! pgrep -x grub-btrfsd >/dev/null 2>&1; then
            grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 &
        fi
    fi

    exit $RESULT
fi

exec /usr/bin/xbps-remove "$@"
```

#### Make the wrappers executable
```bash
sudo chmod +x /usr/local/bin/{vpm,xbps-install,xbps-remove}-snap
```

#### Using the Wrappers

To use the wrappers automatically with `sudo`, add this to your `~/.bashrc` or `~/.zshrc`:

```bash
# Override sudo to use snapper wrapper scripts for vpm, xbps-install and xbps-remove
sudo() {
    case "$1" in
        vpm)
            shift
            command sudo /usr/local/bin/vpm-snap "$@"
            ;;
        xbps-install)
            shift
            command sudo /usr/local/bin/xbps-install-snap "$@"
            ;;
        xbps-remove)
            shift
            command sudo /usr/local/bin/xbps-remove-snap "$@"
            ;;
        *)
            command sudo "$@"
            ;;
    esac
}
```

#### Skipping Snapshots

To skip snapshot creation for a specific operation, set the environment variable:

```bash
SNAP_XBPS_SKIP=1 sudo vpm install package-name
```

#### Example Usage

```bash
# With snapshots (using the wrapper)
sudo vpm install neovim
# Output:
# :: Created pre-snapshot #42
# [package installation output]
# :: Created post-snapshot #43

# Without snapshots (skipping wrapper)
SNAP_XBPS_SKIP=1 sudo vpm install neovim
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
