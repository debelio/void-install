#!/usr/bin/env bash

#############################################
#                                           #
# VOID LINUX INSTALL                        #
#                                           #
#############################################

## Variables
#
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Track timing
START_TIME=$(date +%s)

# Lock file path
SCRIPT_NAME=$(basename "$0")
LOCK_FILE="/tmp/${SCRIPT_NAME%.*}.lock"

# Repository URL
REPO='https://repo-de.voidlinux.org/current'

## Functions
#
# Print colorized messages
print_msg() {
    local color=$1
    local message=$2
    printf "\n${color}==> %s${NC}\n" "$message"
}

# Convenience functions for different message types
print_info() { print_msg "$BLUE" "$1"; }
print_success() { print_msg "$GREEN" "$1"; }
print_error() { print_msg "$RED" "$1"; }
print_warning() { print_msg "$YELLOW" "$1"; }

# Print centered text
print_centered() {
    local text="$1"
    local color="${2:-$NC}"
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    local text_length=${#text}
    local padding=$(( (term_width - text_length) / 2 ))
    printf "%${padding}s" ""
    echo -e "${color}${text}${NC}"
}

# Format time in seconds to a readable format
format_time() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [ "$hours" -gt 0 ]; then
        echo "${hours}h:${minutes}m:${secs}s"
    elif [ "$minutes" -gt 0 ]; then
        echo "${minutes}m:${secs}s"
    else
        echo "${secs}s"
    fi
}

# Calculate and display total execution time
calculate_and_display_total_time() {
    local end_time
    end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))
    local total_formatted
    total_formatted=$(format_time $total_time)

    print_info "Done. Total execution time: $total_formatted."
}

# Check if script is run with root permissions
check_root_permissions() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run with root permissions!"
        print_info "Please run with sudo."
        exit 1
    fi
}

# Password for the LUKS Container
luks_password_selector() {
    print_info "Please enter a password for the LUKS container (you're not going to see the password): "
    stty -echo
    read -r LUKS_PASSWORD
    stty echo
    if [ -z "$LUKS_PASSWORD" ]; then
        echo
        print_error "You need to enter a password for the LUKS Container, please try again."
        LUKS_PASSWORD=""
        return 1
    fi
    echo
    print_info "Please enter the password for the LUKS container again (you're not going to see the password): "
    stty -echo
    read -r luks_password_2
    stty echo
    echo
    if [ "$LUKS_PASSWORD" != "$luks_password_2" ]; then
        print_error "Passwords don't match, please try again."
        LUKS_PASSWORD=""
        return 1
    fi
    return 0
}

# Setting up a password for the root account
root_password_selector() {
    print_info "Please enter a password for the root user (you're not going to see it): "
    read -r -s ROOT_PASSWORD
    if [[ -z "$ROOT_PASSWORD" ]]; then
        echo
        print_error "You need to enter a password for the root user, please try again."
        ROOT_PASSWORD=""
        return 1
    fi
    echo

    print_info "Please enter the password again (you're not going to see it): "
    read -r -s root_password_2
    echo
    if [[ "$ROOT_PASSWORD" != "$root_password_2" ]]; then
        print_error "Passwords don't match, please try again."
        ROOT_PASSWORD=""
        return 1
    fi
    return 0
}

# Setting up a username for the user account
username_selector() {
    print_info "Please enter name for a user account: "
    read -r USERNAME
    if [[ -z "$USERNAME" ]]; then
        print_error "You need to enter a username, please try again."
        USERNAME=""
        return 1
    fi
    return 0
}

# Setting up a password for the user account
user_password_selector() {
    print_info "Please enter a password for $USERNAME (you're not going to see the password): "
    read -r -s USER_PASSWORD
    if [[ -z "$USER_PASSWORD" ]]; then
        echo
        print_error "You need to enter a password for $USERNAME, please try again."
        USER_PASSWORD=""
        return 1
    fi
    echo

    print_info "Please enter the password again (you're not going to see it): "
    read -r -s user_password_2
    echo
    if [[ "$USER_PASSWORD" != "$user_password_2" ]]; then
        echo
        print_error "Passwords don't match, please try again."
        USER_PASSWORD=""
        return 1
    fi
    return 0
}

# Microcode detector
microcode_detector() {
    cpu=$(grep vendor_id /proc/cpuinfo)
    if [[ "$cpu" == *"AuthenticAMD"* ]]; then
        print_info "An AMD CPU has been detected, the AMD microcode will be installed."
        MICROCODE="linux-firmware-amd"
    else
        print_info "An Intel CPU has been detected, the Intel microcode will be installed."
        MICROCODE="linux-firmware-intel"
    fi
}

# User enters a hostname (function).
hostname_selector() {
    print_info "Please enter the hostname: "
    read -r HOSTNAME
    if [[ -z "$HOSTNAME" ]]; then
        print_error "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# Ask user for confirmation
void_packages_question() {
    while true; do
        print_info "Do you want to add the Void packages repository? [y/n]: "
        read -r response
        case "$response" in
        [yY]|[yY][eE][sS])
            REPOSITORY_VOID_PACKAGES=true
            break
            ;;
        [nN]|[nN][oO])
            REPOSITORY_VOID_PACKAGES=false
            break
            ;;
        *)
            print_error "Please answer yes or no (y/n)."
            ;;
        esac
    done
}

### Main script execution
#

# Clear the screen
clear

# Display banner
term_width=$(tput cols 2>/dev/null || echo 80)
banner_line=$(printf '=%.0s' $(seq 1 "$term_width"))
print_centered "$banner_line" "$MAGENTA"
print_centered "INSTALLING VOID LINUX" "$MAGENTA"
print_centered "$banner_line" "$MAGENTA"

print_info "Starting the Void Linux installation."

# Check for root permissions before proceeding
check_root_permissions

# Check if lock file exists, if not create it and set trap on exit
if { set -C; 2>/dev/null true >"${LOCK_FILE}"; }; then
    trap 'rm -f ${LOCK_FILE}' EXIT
else
    print_error "The lock file ${LOCK_FILE} exists. The script will exit now!"
    exit
fi

# Checking the internet connection
print_info "Checking the internet connection."
ping -c 2 kernel.org &>/dev/null || {
    print_error "No internet connection detected, please connect to the internet and try again."
    exit 1
}

# Update and install necessary packages
print_info "Updating xbps."
xbps-install -Syv xbps &>/dev/null
print_info "Installing necessary packages."
xbps-install -Syv gptfdisk &>/dev/null

# Setting up LUKS password
until luks_password_selector; do :; done

# Setting up username
until username_selector; do :; done

# Setting up the user's and root's passwords.
until user_password_selector; do :; done
until root_password_selector; do :; done

# Setting up the hostname
until hostname_selector; do :; done

# Ask user if they want to add the Void packages repository
void_packages_question

# Choosing the target for the installation
print_info "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
IFS=$'\n'
select CHOICE in $(lsblk -dpnoNAME,SIZE | grep -P "/dev/sd|nvme|vd" | awk '$2 != "0B" {gsub("/dev/", "", $1); print $1 " (" $2 ")"}');
do
    if [[ -n "$CHOICE" ]]; then
        DISK="/dev/${CHOICE%% *}"
        print_info "Void Linux will be installed on the following disk: $CHOICE"
        break
    else
        print_error "Invalid selection! Please try again or press CTRL+C to exit."
    fi
done

## Disk Partitioning and Encryption
#
# Wiping disk
print_info "Wiping disk and creating new GPT partition table on $DISK."
wipefs -a "$DISK" &>/dev/null
sgdisk --zap-all "$DISK" &>/dev/null

# Creating partitions
print_info "Creating partitions."
# Create 1024MB EFI partition
sgdisk -n 1:0:+1024M -t 1:ef00 -c 1:"ESP" "$DISK" &>/dev/null
# Create Linux partition with the remaining space
sgdisk -n 2:0:0 -t 2:8300 -c 2:"CRYPTROOT" "$DISK" &>/dev/null

# Refresh partition table
print_info "Refreshing partition table."
blockdev --rereadpt "$DISK" &>/dev/null
sleep 2

# Determine partition names based on device type
if echo "$DISK" | grep -q "nvme"; then
    disk_efi="${DISK}p1"
    disk_root="${DISK}p2"
else
    disk_efi="${DISK}1"
    disk_root="${DISK}2"
fi
print_info "Using $disk_efi as EFI partition and $disk_root as root partition."

# Final check if devices exist
if [ ! -e "$disk_efi" ] || [ ! -e "$disk_root" ]; then
    print_error "Failed to detect partitions. Manual intervention required."
    print_error "Expected partitions: $disk_efi and $disk_root not found."
    fdisk -l "$DISK"
    exit 1
fi

# Formatting the ESP as FAT32
print_info "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 -n EFI "$disk_efi" &>/dev/null

# Creating a LUKS Container for the root partition
print_info "Creating LUKS Container for the root partition."
printf "%s" "$LUKS_PASSWORD" | cryptsetup luksFormat "$disk_root" \
    --type luks2 \
    --label VOID_LUKS \
    --pbkdf pbkdf2 \
    --pbkdf-force-iterations 400000 \
    -d - &>/dev/null

# Open the LUKS container
print_info "Opening LUKS container."
printf "%s" "$LUKS_PASSWORD" | cryptsetup open "$disk_root" cryptroot -d - &>/dev/null

# Creating the BTRFS filesystem
print_info "Formatting the LUKS container as BTRFS."
btrfs_device="/dev/mapper/cryptroot"
mkfs.btrfs -L VOIDROOT "$btrfs_device" &>/dev/null

## Btrfs Subvolume Creation and Mounting
#
# Mount the BTRFS filesystem
print_info "Mounting BTRFS filesystem."
mount "$btrfs_device" /mnt

# Define subvolumes and their mount points
# Using separate subvolumes allows selective snapshots and excludes certain directories
declare -A btrfs_subvolumes=(
    [@]="/mnt"                          # Root subvolume
    [@cache]="/mnt/var/cache"           # Package cache
    [@docker]="/mnt/var/lib/docker"     # Docker data
    [@home]="/mnt/home"                 # User home directories
    [@libvirt]="/mnt/var/lib/libvirt"   # VM images
    [@log]="/mnt/var/log"               # System logs
    [@opt]="/mnt/opt"                   # Optional software
    [@snapshots]="/mnt/.snapshots"      # Snapper snapshots directory
    [@spool]="/mnt/var/spool"           # Print and mail queues
    # TODO: Add @swap subvolume for hibernation support
    # [@swap]="/mnt/swap"                 # Swap file location for hibernation
    [@tmp]="/mnt/tmp"                   # Temporary files
)

# Create all subvolumes
print_info "Creating Btrfs subvolumes."
for subvol in "${!btrfs_subvolumes[@]}"; do
    btrfs subvolume create "/mnt/${subvol}" &>/dev/null
done

# Mounting the newly created subvolumes
umount /mnt
mount_opts="ssd,noatime,compress-force=zstd:3,discard=async"

# Mount root subvolume first
print_info "Mounting the newly created subvolumes."
mount -o "$mount_opts",subvol=@ "$btrfs_device" /mnt

# Create all necessary mount points and mount subvolumes
print_info "Creating mount point directories and mounting subvolumes."
for subvol in "${!btrfs_subvolumes[@]}"; do
    [[ "$subvol" == "@" ]] && continue
    mount_point="${btrfs_subvolumes[$subvol]}"
    mkdir -p "$mount_point"
    mount -o "${mount_opts},subvol=${subvol}" "$btrfs_device" "$mount_point" &>/dev/null
done

# Mount the EFI partition
print_info "Mounting the EFI partition."
mkdir -p /mnt/boot/efi
mount -t vfat "$disk_efi" /mnt/boot/efi

# Set CoW attribute for directories that benefit from it
chattr +C /mnt/var/log &>/dev/null
# TODO: Uncomment when @swap subvolume is enabled for hibernation
# chattr +C /mnt/swap &>/dev/null

## Package Installation and System Configuration
#
# Detecting CPU microcode and setting variable
microcode_detector

# Copying RSA keys
print_info "Copying RSA keys."
mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# First install just the base packages
print_info "Installing base system."
xbps-install -Syvr /mnt -R "$REPO" base-system &>/dev/null

# Then proceed with the rest of the packages
print_info "Installing additional packages."
xbps-install -Syvr /mnt -R "$REPO" btrfs-progs cryptsetup grub-x86_64-efi \
    efibootmgr lvm2 grub-btrfs grub-btrfs-runit NetworkManager polkit apparmor \
    git curl util-linux tar coreutils binutils xtools xmirror void-repo-nonfree \
    void-repo-multilib void-repo-multilib-nonfree gcc snapper "$MICROCODE" &>/dev/null

# Setting up chroot environment
print_info "Setting up chroot environment."
mount -t proc none /mnt/proc
mount -t sysfs none /mnt/sys
mount --rbind /dev /mnt/dev
mount --rbind /run /mnt/run
mount --rbind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars/

# Copy DNS info
print_info "Copying DNS info."
cp -L /etc/resolv.conf /mnt/etc/

# Setting up the hostname.
print_info "Setting up the hostname."
rm -f /mnt/etc/hostname
echo "$HOSTNAME" >/mnt/etc/hostname

# Generating /etc/fstab
print_info "Creating a new fstab."
rm -f /mnt/etc/fstab
xgenfstab /mnt > /mnt/etc/fstab

# Setting hosts file.
print_info "Setting hosts file."
rm -f /mnt/etc/hosts
cat >/mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME
EOF

# Setting up LUKS2 encryption in grub.
print_info "Setting up grub config."
# Use the actual device path to ensure we get the correct UUID
UUID=$(blkid -s UUID -o value "$disk_root")
sed -i "\,^GRUB_CMDLINE_LINUX=\"\",s,\",&rd.luks.name=$UUID=cryptroot root=$btrfs_device," /mnt/etc/default/grub

## User Account Configuration
#
# Setting the root password.
print_info "Setting the root password."
xchroot /mnt usermod -p "$(openssl passwd -6 "${ROOT_PASSWORD}")" root &>/dev/null

# Creating the user and setting the password.
if [[ -n "$USERNAME" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/10-wheel
    print_info "Adding the user $USERNAME to the system with root privilege."
    xchroot /mnt useradd -m -G wheel,users,network -s /bin/bash "$USERNAME" &>/dev/null
    print_info "Setting user password for $USERNAME."
    xchroot /mnt usermod -p "$(openssl passwd -6 "${USER_PASSWORD}")" "$USERNAME" &>/dev/null
fi

# Configure snapper
print_info "Configuring snapper for root and home."
cp /mnt/usr/share/snapper/config-templates/default /mnt/etc/snapper/configs/root
sed -i -e "s|ALLOW_USERS=\"\"|ALLOW_USERS=\"$USERNAME\"|" \
    -e 's|SYNC_ACL="no"|SYNC_ACL="yes"|' \
    /mnt/etc/snapper/configs/root
cp /mnt/usr/share/snapper/config-templates/default /mnt/etc/snapper/configs/home
sed -i \
    -e 's|SUBVOLUME="/"|SUBVOLUME="/home"|' \
    -e "s|ALLOW_USERS=\"\"|ALLOW_USERS=\"$USERNAME\"|" \
    -e 's|SYNC_ACL="no"|SYNC_ACL="yes"|' \
    /mnt/etc/snapper/configs/home
sed -i \
     's|SNAPPER_CONFIGS=""|SNAPPER_CONFIGS="root home"|' \
    /mnt/etc/conf.d/snapper

# Create the first snapshot of the root subvolume
print_info "Creating the first snapshot of the root subvolume."
mkdir /mnt/.snapshots/1
cat >/mnt/.snapshots/1/info.xml <<EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>$(date -u +"%F %T")</date>
  <description>first root subvolume</description>
</snapshot>
EOF
btrfs subvolume snapshot /mnt /mnt/.snapshots/1/snapshot &>/dev/null
SNAP_ID="$(btrfs inspect-internal rootid /mnt/.snapshots/1/snapshot)"
btrfs subvolume set-default "${SNAP_ID}" /mnt

## Chroot Operations
#
# Export variables before chroot
export UUID LUKS_PASSWORD disk_root disk_efi USERNAME REPOSITORY_VOID_PACKAGES

# Chroot and finalize the installation
print_info "Finalizing the installation in chroot environment."
xchroot /mnt /bin/bash -e <<'EOF'
    ## Main chroot script execution
    #
    # Define print_info inside chroot
    print_info() { printf "\n\033[0;36m==> %s\033[0m\n" "$1"; }

    # Setting root ownership of /
    print_info "Setting root ownership and permissions of /."
    chown root:root /
    chmod 755 /

    # Enable dbus, polkit, and NetworkManager
    print_info "Enable the NetworkManager service."
    ln -s /etc/sv/dbus /etc/runit/runsvdir/default/
    ln -s /etc/sv/polkitd /etc/runit/runsvdir/default/
    ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/default/

    # Configure dracut
    print_info "Adding needed dracut configuration files."
    echo -e "hostonly=yes\nhostonly_cmdline=yes" >>/etc/dracut.conf.d/00-hostonly.conf
    echo -e "add_dracutmodules+=\" crypt btrfs resume \"" >>/etc/dracut.conf.d/20-addmodules.conf
    echo -e "tmpdir=/tmp" >>/etc/dracut.conf.d/30-tmpfs.conf

    # Set the timezone
    print_info "Setting the timezone in /etc/rc.conf."
    TIMEZONE=$(curl -s http://ip-api.com/line?fields=timezone)
    sed -i "/#TIMEZONE=/s|.*|TIMEZONE=$TIMEZONE|" /etc/rc.conf

    # Set the locale
    print_info "Setting the locale."
    sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/default/libc-locales
    xbps-reconfigure -f glibc-locales &>/dev/null

    # Install and configure GRUB
    print_info "Generating random key file to avoid typing password twice at boot."
    dd bs=512 count=4 if=/dev/random of=/boot/volume.key &>/dev/null

    print_info "Adding the key to the encrypted partition."
    printf "%s" "$LUKS_PASSWORD" | cryptsetup luksAddKey "$disk_root" /boot/volume.key -d - &>/dev/null

    print_info "Configuring the permissions of the key file."
    chmod 000 /boot/volume.key
    chmod -R g-rwx,o-rwx /boot

    print_info "Adding random key to /etc/crypttab."
    echo -e "\ncryptroot UUID=$UUID /boot/volume.key luks\n" >>/etc/crypttab

    print_info "Adding random key to dracut configuration files."
    echo -e "install_items+=\" /boot/volume.key /etc/crypttab \"" >>/etc/dracut.conf.d/10-crypt.conf

    print_info "Generating new dracut initramfs."
    dracut --regenerate-all --force --hostonly &>/dev/null

    print_info "Enabling GRUB cryptodisk support."
    echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

    print_info "Installing GRUB on EFI partition."
    grub-install --target=x86_64-efi --efi-directory=/boot/efi \
        --bootloader-id=Void --recheck &>/dev/null

    print_info "Enabling GRUB BTRFS integration."
    ln -s /etc/sv/grub-btrfs /etc/runit/runsvdir/default/

    # Add the EFI mount to fstab
    print_info "Adding EFI mount to fstab."
    ESP_UUID=$(blkid -s UUID -o value "$disk_efi")
    echo "UUID=$ESP_UUID  /boot/efi  vfat  defaults,noatime  0 2" >> /etc/fstab

    # Configure AppArmor
    print_info "Configuring AppArmor and setting it to enforce."
    sed -i "/APPARMOR=/s/.*/APPARMOR=enforce/" /etc/default/apparmor
    sed -i "/#write-cache/s/^#//" /etc/apparmor/parser.conf
    sed -i "/#show_notifications/s/^#//" /etc/apparmor/notify.conf
    sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ apparmor=1 security=apparmor&/" /etc/default/grub

    print_info "Updating grub."
    update-grub &>/dev/null

    # Installing zram
    print_info "Installing and configuring zram."
    xbps-install -Syv zramen &>/dev/null
    ln -s /etc/sv/zramen /etc/runit/runsvdir/default/

    # Clone the Void packages repository if the user opted for it
    if [ "$REPOSITORY_VOID_PACKAGES" = "true" ]; then
        print_info "Adding the Void packages repository."
        mkdir -p /home/"$USERNAME"/void-packages
        chown -R "$USERNAME":users /home/"$USERNAME"/void-packages
        sudo -u "$USERNAME" git clone https://github.com/void-linux/void-packages.git \
            /home/"$USERNAME"/void-packages &>/dev/null
        print_info "Enabling restricted packages."
        echo "XBPS_ALLOW_RESTRICTED=yes" >> /home/"$USERNAME"/void-packages/etc/conf
    fi

    # Reconfigure all installed packages
    print_info "Reconfiguring all installed packages."
    xbps-reconfigure -fa &>/dev/null
EOF

# Total execution time
calculate_and_display_total_time

print_success "The installation is done. If needed, use xchroot /mnt to enter your new Void Linux system and do more changes. umount -R /mnt before rebooting."
echo ""
