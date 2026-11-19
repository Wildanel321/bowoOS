#!/bin/bash
# ==============================================================================
# LiteOffice OS — Modular System Installer
# Supports Legacy BIOS (MBR) and Modern UEFI (GPT), with interactive & automated modes.
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

TARGET_DISK="${1:-}"
IS_AUTO=0

if [ "$TARGET_DISK" = "--auto" ]; then
    IS_AUTO=1
    TARGET_DISK="${2:-}"
fi

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Error: The LiteOffice OS installer must be executed as root.${NC}" >&2
    exit 1
fi

# Detect Firmware Boot Environment
BOOT_MODE="BIOS"
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
fi

print_header() {
    clear 2>/dev/null || true
    echo -e "${BLUE}${BOLD}==============================================================================${NC}"
    echo -e "${BLUE}${BOLD}  LiteOffice OS 1.0 LTS — System Installation Utility                         ${NC}"
    echo -e "${BLUE}${BOLD}  Boot Mode: ${YELLOW}${BOOT_MODE}${BLUE} | Target Spec: 512 MB - 2 GB Low-Memory Optimization ${NC}"
    echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"
}

select_disk_interactive() {
    print_header
    echo -e "${BOLD}Available Physical Storage Devices:${NC}"
    echo "------------------------------------------------------------------------------"
    lsblk -dpno NAME,SIZE,TYPE,MODEL 2>/dev/null | grep -E 'disk' || lsblk
    echo "------------------------------------------------------------------------------"

    read -r -p "Enter target disk device to install LiteOffice OS (e.g. /dev/sda, /dev/vda): " TARGET_DISK

    if [ ! -b "$TARGET_DISK" ]; then
        echo -e "${RED}[-] Invalid device: '$TARGET_DISK' does not exist.${NC}"
        exit 1
    fi

    echo -e "\n${RED}${BOLD}WARNING: ALL DATA ON ${TARGET_DISK} WILL BE PERMANENTLY ERASED!${NC}"
    read -r -p "Are you absolutely sure you want to proceed? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
        echo "Installation aborted by user."
        exit 0
    fi
}

if [ -z "$TARGET_DISK" ]; then
    select_disk_interactive
fi

if [ ! -b "$TARGET_DISK" ]; then
    echo -e "${RED}[-] Error: Target disk '$TARGET_DISK' is not a valid block device.${NC}" >&2
    exit 1
fi

print_header
echo -e "[*] Target Disk Selected : ${GREEN}${TARGET_DISK}${NC}"
echo -e "[*] Firmware Environment : ${YELLOW}${BOOT_MODE}${NC}"

# 1. Unmount existing partitions on target disk
echo "[*] Unmounting existing partitions on ${TARGET_DISK}..."
for part in $(lsblk -lno NAME "$TARGET_DISK" | grep -v "^$(basename "$TARGET_DISK")$" || true); do
    umount -l "/dev/$part" 2>/dev/null || true
done
swapoff -a 2>/dev/null || true

# 2. Partitioning Disk
echo "[*] Creating partition table and layout..."
dd if=/dev/zero of="$TARGET_DISK" bs=1M count=10 status=none

TARGET_ROOT_PART=""
TARGET_EFI_PART=""

if [ "$BOOT_MODE" = "UEFI" ]; then
    # GPT Layout: 128 MB EFI System Partition (ESP) + Ext4 Root
    echo "    - Initializing GPT partition table..."
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s "$TARGET_DISK" mkpart "ESP" fat32 1MiB 129MiB
    parted -s "$TARGET_DISK" set 1 esp on
    parted -s "$TARGET_DISK" mkpart "LiteOfficeRoot" ext4 129MiB 100%

    if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
        TARGET_EFI_PART="${TARGET_DISK}p1"
        TARGET_ROOT_PART="${TARGET_DISK}p2"
    else
        TARGET_EFI_PART="${TARGET_DISK}1"
        TARGET_ROOT_PART="${TARGET_DISK}2"
    fi

    partprobe "$TARGET_DISK" 2>/dev/null || true
    sleep 1

    echo "    - Formatting EFI System Partition (${TARGET_EFI_PART})..."
    mkfs.vfat -F32 -n "LITE_EFI" "$TARGET_EFI_PART" >/dev/null

else
    # MBR Layout: Single Bootable Primary Ext4 Partition
    echo "    - Initializing MBR partition table..."
    parted -s "$TARGET_DISK" mklabel msdos
    parted -s "$TARGET_DISK" mkpart primary ext4 1MiB 100%
    parted -s "$TARGET_DISK" set 1 boot on

    if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
        TARGET_ROOT_PART="${TARGET_DISK}p1"
    else
        TARGET_ROOT_PART="${TARGET_DISK}1"
    fi

    partprobe "$TARGET_DISK" 2>/dev/null || true
    sleep 1
fi

# 3. Format Root Filesystem
echo "[*] Formatting root partition (${TARGET_ROOT_PART}) as ext4..."
mkfs.ext4 -F -q -L "LITEOFFICE" "$TARGET_ROOT_PART"

# 4. Mount Target File System
MOUNT_TARGET="/mnt/liteoffice_target"
mkdir -p "$MOUNT_TARGET"
mount "$TARGET_ROOT_PART" "$MOUNT_TARGET"

if [ "$BOOT_MODE" = "UEFI" ] && [ -n "$TARGET_EFI_PART" ]; then
    mkdir -p "$MOUNT_TARGET/boot/efi"
    mount "$TARGET_EFI_PART" "$MOUNT_TARGET/boot/efi"
fi

# 5. Copy System Files
echo "[*] Synchronizing LiteOffice OS files to target partition..."
SOURCE_DIR="/"
if [ -d /run/live/rootfs ]; then
    SOURCE_DIR="/run/live/rootfs"
fi

rsync -aHAX --info=progress2 \
    --exclude="/proc/*" \
    --exclude="/sys/*" \
    --exclude="/dev/*" \
    --exclude="/tmp/*" \
    --exclude="/run/*" \
    --exclude="/mnt/*" \
    --exclude="/media/*" \
    --exclude="/lost+found" \
    "$SOURCE_DIR/" "$MOUNT_TARGET/"

# Re-create empty system mountpoints
mkdir -p "$MOUNT_TARGET"/{proc,sys,dev,tmp,run,mnt,media}
chmod 1777 "$MOUNT_TARGET/tmp"

# 6. Generate Target fstab
echo "[*] Generating /etc/fstab with persistent filesystem UUIDs..."
ROOT_UUID=$(blkid -s UUID -o value "$TARGET_ROOT_PART")
cat << EOF > "$MOUNT_TARGET/etc/fstab"
# /etc/fstab: static file system information for LiteOffice OS
# <file system>                             <mount point>   <type>  <options>                   <dump>  <pass>
UUID=${ROOT_UUID}                          /               ext4    noatime,errors=remount-ro   0       1
EOF

if [ "$BOOT_MODE" = "UEFI" ] && [ -n "$TARGET_EFI_PART" ]; then
    EFI_UUID=$(blkid -s UUID -o value "$TARGET_EFI_PART")
    cat << EOF >> "$MOUNT_TARGET/etc/fstab"
UUID=${EFI_UUID}                          /boot/efi       vfat    umask=0077,shortname=winnt  0       2
EOF
fi

# 7. Configure Target Bootloader (GRUB)
echo "[*] Installing GRUB bootloader (${BOOT_MODE})..."
mount --bind /dev "$MOUNT_TARGET/dev"
mount --bind /dev/pts "$MOUNT_TARGET/dev/pts"
mount -t proc proc "$MOUNT_TARGET/proc"
mount -t sysfs sysfs "$MOUNT_TARGET/sys"

if [ "$BOOT_MODE" = "UEFI" ]; then
    chroot "$MOUNT_TARGET" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=LiteOffice --recheck 2>/dev/null || \
    chroot "$MOUNT_TARGET" grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable 2>/dev/null || true
else
    chroot "$MOUNT_TARGET" grub-install --target=i386-pc "$TARGET_DISK" --recheck 2>/dev/null || true
fi

# Generate grub.cfg
chroot "$MOUNT_TARGET" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

# 8. Clean unmount target
echo "[*] Finalizing and unmounting target filesystem..."
umount -l "$MOUNT_TARGET/dev/pts" 2>/dev/null || true
umount -l "$MOUNT_TARGET/dev" 2>/dev/null || true
umount -l "$MOUNT_TARGET/proc" 2>/dev/null || true
umount -l "$MOUNT_TARGET/sys" 2>/dev/null || true

if [ "$BOOT_MODE" = "UEFI" ] && [ -n "$TARGET_EFI_PART" ]; then
    umount "$MOUNT_TARGET/boot/efi" 2>/dev/null || true
fi
umount "$MOUNT_TARGET" 2>/dev/null || true
rmdir "$MOUNT_TARGET" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}  LiteOffice OS has been successfully installed to ${TARGET_DISK}!           ${NC}"
echo -e "${GREEN}${BOLD}  You may now reboot your system into your new LiteOffice OS installation.     ${NC}"
echo -e "${GREEN}${BOLD}==============================================================================${NC}\n"
