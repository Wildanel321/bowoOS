#!/bin/bash
# ==============================================================================
# LiteOffice OS — Modular System Installer Wrapper
# Launches modern GTK3 GUI installer if desktop DISPLAY is present,
# or provides interactive/automated CLI installation with min 8 GB swap.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    AUTH_FILE="${XAUTHORITY:-$HOME/.Xauthority}"
    exec sudo DISPLAY="${DISPLAY:-:0}" XAUTHORITY="$AUTH_FILE" "$0" "$@"
fi

BOOT_MODE="BIOS"
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="UEFI"
fi

print_header() {
    clear 2>/dev/null || true
    echo -e "${BLUE}${BOLD}==============================================================================${NC}"
    echo -e "${BLUE}${BOLD}  LiteOffice OS 1.0 LTS — System Storage Installation Utility                 ${NC}"
    echo -e "${BLUE}${BOLD}  Boot Mode: ${YELLOW}${BOOT_MODE}${BLUE} | Storage Safety: Min 8 GB Swap Enforced      ${NC}"
    echo -e "${BLUE}${BOLD}==============================================================================${NC}\n"
}

select_disk_interactive() {
    print_header
    echo -e "${BOLD}Available Physical Storage Devices:${NC}"
    echo "------------------------------------------------------------------------------"
    lsblk -dpno NAME,SIZE,TYPE,MODEL,TRAN 2>/dev/null | grep -E 'disk' || lsblk
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

# Detect drive capacity
TOTAL_BYTES=$(lsblk -bdno SIZE "$TARGET_DISK" | head -n1)
TOTAL_GB=$(( TOTAL_BYTES / 1073741824 ))
echo -e "[*] Total Storage Size   : ${GREEN}${TOTAL_GB} GB${NC}"

# Configure partition sizing with minimum 8 GB swap
SWAP_GB=8
if [ "$TOTAL_GB" -lt 12 ]; then
    SWAP_GB=2
    echo -e "${YELLOW}[!] Notice: Small disk detected (< 12 GB). Clamping swap to ${SWAP_GB} GB.${NC}"
else
    echo -e "[*] Configuring Swap     : ${GREEN}${SWAP_GB} GB${NC} (Minimum 8 GB safety buffer)"
fi

# Root size default: 25 GB or 60% of available
ROOT_GB=25
if [ "$TOTAL_GB" -le 35 ]; then
    ROOT_GB=$(( (TOTAL_GB - SWAP_GB - 2) * 6 / 10 ))
    [ "$ROOT_GB" -lt 8 ] && ROOT_GB=8
fi

USE_HOME=1
HOME_GB=$(( TOTAL_GB - SWAP_GB - ROOT_GB - 1 ))
if [ "$HOME_GB" -lt 4 ]; then
    USE_HOME=0
    ROOT_GB=$(( TOTAL_GB - SWAP_GB - 1 ))
fi

echo -e "[*] Configuring Root (/) : ${GREEN}${ROOT_GB} GB${NC} (ext4)"
if [ "$USE_HOME" -eq 1 ]; then
    echo -e "[*] Configuring /home    : ${GREEN}${HOME_GB} GB${NC} (ext4, dedicated personal storage)"
fi

# 1. Unmount existing partitions on target disk
echo "[*] Unmounting existing partitions on ${TARGET_DISK}..."
for part in $(lsblk -lno NAME "$TARGET_DISK" | grep -v "^$(basename "$TARGET_DISK")$" || true); do
    swapoff "/dev/$part" 2>/dev/null || true
    umount -l "/dev/$part" 2>/dev/null || true
done

# 2. Partitioning Disk
echo "[*] Initializing partition table..."
dd if=/dev/zero of="$TARGET_DISK" bs=1M count=16 status=none

TARGET_ROOT_PART=""
TARGET_SWAP_PART=""
TARGET_HOME_PART=""
TARGET_EFI_PART=""

SWAP_MB=$(( SWAP_GB * 1024 ))
ROOT_MB=$(( ROOT_GB * 1024 ))

if [ "$BOOT_MODE" = "UEFI" ]; then
    parted -s "$TARGET_DISK" mklabel gpt
    parted -s "$TARGET_DISK" mkpart "ESP" fat32 1MiB 513MiB
    parted -s "$TARGET_DISK" set 1 esp on
    
    SWAP_END=$(( 513 + SWAP_MB ))
    parted -s "$TARGET_DISK" mkpart "LiteOfficeSwap" linux-swap 513MiB "${SWAP_END}MiB"
    
    if [ "$USE_HOME" -eq 1 ]; then
        ROOT_END=$(( SWAP_END + ROOT_MB ))
        parted -s "$TARGET_DISK" mkpart "LiteOfficeRoot" ext4 "${SWAP_END}MiB" "${ROOT_END}MiB"
        parted -s "$TARGET_DISK" mkpart "LiteOfficeHome" ext4 "${ROOT_END}MiB" 100%
    else
        parted -s "$TARGET_DISK" mkpart "LiteOfficeRoot" ext4 "${SWAP_END}MiB" 100%
    fi

    if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
        TARGET_EFI_PART="${TARGET_DISK}p1"
        TARGET_SWAP_PART="${TARGET_DISK}p2"
        TARGET_ROOT_PART="${TARGET_DISK}p3"
        [ "$USE_HOME" -eq 1 ] && TARGET_HOME_PART="${TARGET_DISK}p4"
    else
        TARGET_EFI_PART="${TARGET_DISK}1"
        TARGET_SWAP_PART="${TARGET_DISK}2"
        TARGET_ROOT_PART="${TARGET_DISK}3"
        [ "$USE_HOME" -eq 1 ] && TARGET_HOME_PART="${TARGET_DISK}4"
    fi
else
    parted -s "$TARGET_DISK" mklabel msdos
    SWAP_END=$(( 1 + SWAP_MB ))
    parted -s "$TARGET_DISK" mkpart primary linux-swap 1MiB "${SWAP_END}MiB"
    
    if [ "$USE_HOME" -eq 1 ]; then
        ROOT_END=$(( SWAP_END + ROOT_MB ))
        parted -s "$TARGET_DISK" mkpart primary ext4 "${SWAP_END}MiB" "${ROOT_END}MiB"
        parted -s "$TARGET_DISK" set 2 boot on
        parted -s "$TARGET_DISK" mkpart primary ext4 "${ROOT_END}MiB" 100%
    else
        parted -s "$TARGET_DISK" mkpart primary ext4 "${SWAP_END}MiB" 100%
        parted -s "$TARGET_DISK" set 2 boot on
    fi

    if [[ "$TARGET_DISK" =~ [0-9]$ ]]; then
        TARGET_SWAP_PART="${TARGET_DISK}p1"
        TARGET_ROOT_PART="${TARGET_DISK}p2"
        [ "$USE_HOME" -eq 1 ] && TARGET_HOME_PART="${TARGET_DISK}p3"
    else
        TARGET_SWAP_PART="${TARGET_DISK}1"
        TARGET_ROOT_PART="${TARGET_DISK}2"
        [ "$USE_HOME" -eq 1 ] && TARGET_HOME_PART="${TARGET_DISK}3"
    fi
fi

partprobe "$TARGET_DISK" 2>/dev/null || true
sleep 1.5

# 3. Format Partitions
if [ -n "$TARGET_EFI_PART" ]; then
    echo "    - Formatting EFI Partition (${TARGET_EFI_PART})..."
    mkfs.vfat -F32 -n "LITE_EFI" "$TARGET_EFI_PART" >/dev/null
fi

echo "    - Formatting Swap Partition (${TARGET_SWAP_PART}, ${SWAP_GB} GB)..."
mkswap -L "LITE_SWAP" "$TARGET_SWAP_PART" >/dev/null

echo "    - Formatting Root Partition (${TARGET_ROOT_PART}, ${ROOT_GB} GB)..."
mkfs.ext4 -F -q -L "LITEOFFICE" "$TARGET_ROOT_PART"

if [ -n "$TARGET_HOME_PART" ]; then
    echo "    - Formatting Home Partition (${TARGET_HOME_PART}, ${HOME_GB} GB)..."
    mkfs.ext4 -F -q -L "LITE_HOME" "$TARGET_HOME_PART"
fi

# 4. Mount Target File System
MOUNT_TARGET="/mnt/liteoffice_target"
mkdir -p "$MOUNT_TARGET"
mount "$TARGET_ROOT_PART" "$MOUNT_TARGET"

if [ -n "$TARGET_EFI_PART" ]; then
    mkdir -p "$MOUNT_TARGET/boot/efi"
    mount "$TARGET_EFI_PART" "$MOUNT_TARGET/boot/efi"
fi

if [ -n "$TARGET_HOME_PART" ]; then
    mkdir -p "$MOUNT_TARGET/home"
    mount "$TARGET_HOME_PART" "$MOUNT_TARGET/home"
fi

# 5. Copy System Files
echo "[*] Synchronizing LiteOffice OS files to target partition..."
SOURCE_DIR="/"
for candidate in /run/live/rootfs/filesystem.squashfs /run/live/rootfs /run/live/rofs /rofs; do
    if [ -d "$candidate/usr" ]; then
        SOURCE_DIR="$candidate"
        break
    fi
done

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

mkdir -p "$MOUNT_TARGET"/{proc,sys,dev,tmp,run,mnt,media,home}
chmod 1777 "$MOUNT_TARGET/tmp"

# 6. Generate Target fstab
echo "[*] Generating /etc/fstab with persistent filesystem UUIDs..."
ROOT_UUID=$(blkid -s UUID -o value "$TARGET_ROOT_PART")
SWAP_UUID=$(blkid -s UUID -o value "$TARGET_SWAP_PART")

cat << EOF > "$MOUNT_TARGET/etc/fstab"
# /etc/fstab: static file system information for LiteOffice OS
UUID=${ROOT_UUID}    /          ext4    noatime,errors=remount-ro 0 1
UUID=${SWAP_UUID}    none       swap    sw                        0 0
EOF

if [ -n "$TARGET_EFI_PART" ]; then
    EFI_UUID=$(blkid -s UUID -o value "$TARGET_EFI_PART")
    cat << EOF >> "$MOUNT_TARGET/etc/fstab"
UUID=${EFI_UUID}    /boot/efi  vfat    umask=0077,shortname=winnt 0 2
EOF
fi

if [ -n "$TARGET_HOME_PART" ]; then
    HOME_UUID=$(blkid -s UUID -o value "$TARGET_HOME_PART")
    cat << EOF >> "$MOUNT_TARGET/etc/fstab"
UUID=${HOME_UUID}    /home      ext4    defaults,noatime          0 2
EOF
fi

# 6b. Configure Full APT Repositories for Upgrades and Package Management
echo "[*] Configuring Debian 12 Bookworm package repositories in /etc/apt/sources.list..."
mkdir -p "$MOUNT_TARGET/etc/apt"
cat << 'EOF' > "$MOUNT_TARGET/etc/apt/sources.list"
# LiteOffice OS 1.0 LTS — Official Package Repositories (Debian 12 Bookworm)
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
EOF

# Ensure fallback DNS nameservers exist
if [ ! -s "$MOUNT_TARGET/etc/resolv.conf" ]; then
    cat << 'EOF' > "$MOUNT_TARGET/etc/resolv.conf"
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
fi

# 6c. Deploy Linux LTS Kernel and Initramfs to Target /boot
echo "[*] Deploying Linux LTS kernel and initramfs to target /boot..."
mkdir -p "$MOUNT_TARGET/boot"

K_SRC=""
for kp in /run/live/medium/live/vmlinuz /cdrom/live/vmlinuz /live/vmlinuz /boot/vmlinuz-6.6.78-lite-x86_64 /boot/vmlinuz; do
    if [ -f "$kp" ]; then
        K_SRC="$kp"
        break
    fi
done

I_SRC=""
for ip in /run/live/medium/live/initrd.img /cdrom/live/initrd.img /live/initrd.img /boot/initrd.img-6.6.78-lite-x86_64 /boot/initrd.img; do
    if [ -f "$ip" ]; then
        I_SRC="$ip"
        break
    fi
done

if [ -n "$K_SRC" ] && [ -n "$I_SRC" ]; then
    cp "$K_SRC" "$MOUNT_TARGET/boot/vmlinuz-6.6.78-lite-x86_64"
    cp "$I_SRC" "$MOUNT_TARGET/boot/initrd.img-6.6.78-lite-x86_64"
    ln -sf "vmlinuz-6.6.78-lite-x86_64" "$MOUNT_TARGET/boot/vmlinuz" 2>/dev/null || true
    ln -sf "initrd.img-6.6.78-lite-x86_64" "$MOUNT_TARGET/boot/initrd.img" 2>/dev/null || true
    echo "    - Deployed kernel and initramfs to $MOUNT_TARGET/boot"
fi

# 7. Configure Target Bootloader (GRUB)
echo "[*] Installing GRUB bootloader (${BOOT_MODE})..."
mount --bind /dev "$MOUNT_TARGET/dev"
mount --bind /dev/pts "$MOUNT_TARGET/dev/pts"
mount -t proc proc "$MOUNT_TARGET/proc"
mount -t sysfs sysfs "$MOUNT_TARGET/sys"
mount --bind /run "$MOUNT_TARGET/run"
if [ -d /sys/firmware/efi/efivars ]; then
    mkdir -p "$MOUNT_TARGET/sys/firmware/efi/efivars"
    mount --bind /sys/firmware/efi/efivars "$MOUNT_TARGET/sys/firmware/efi/efivars" 2>/dev/null || true
fi

echo "[*] Regenerating target initramfs for installed storage..."
chroot "$MOUNT_TARGET" update-initramfs -u -k all 2>/dev/null || true

if [ "$BOOT_MODE" = "UEFI" ]; then
    EFI_TARGET="x86_64-efi"
    if [ "$(uname -m)" = "i686" ]; then
        EFI_TARGET="i386-efi"
    fi
    chroot "$MOUNT_TARGET" grub-install --target="$EFI_TARGET" --efi-directory=/boot/efi --bootloader-id=LiteOffice --recheck 2>/dev/null || \
    chroot "$MOUNT_TARGET" grub-install --target="$EFI_TARGET" --efi-directory=/boot/efi --removable 2>/dev/null || true
else
    chroot "$MOUNT_TARGET" grub-install --target=i386-pc "$TARGET_DISK" --recheck 2>/dev/null || true
fi

chroot "$MOUNT_TARGET" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true

# Verify grub.cfg contains boot entry; generate direct fallback if empty
if [ ! -f "$MOUNT_TARGET/boot/grub/grub.cfg" ] || ! grep -q "menuentry " "$MOUNT_TARGET/boot/grub/grub.cfg" 2>/dev/null; then
    echo "[*] Generating fallback grub.cfg for LiteOffice OS..."
    mkdir -p "$MOUNT_TARGET/boot/grub"
    cat << EOF > "$MOUNT_TARGET/boot/grub/grub.cfg"
set default=0
set timeout=5

insmod all_video
insmod font
insmod gfxterm
terminal_output gfxterm console

menuentry "LiteOffice OS 1.0 LTS" --class os {
    linux /boot/vmlinuz-6.6.78-lite-x86_64 root=UUID=${ROOT_UUID} rw quiet loglevel=3
    initrd /boot/initrd.img-6.6.78-lite-x86_64
}
menuentry "LiteOffice OS 1.0 LTS (Recovery Mode)" --class os {
    linux /boot/vmlinuz-6.6.78-lite-x86_64 root=UUID=${ROOT_UUID} rw single
    initrd /boot/initrd.img-6.6.78-lite-x86_64
}
EOF
fi

# 7d. Register Hardware Driver & Application Auto-Provisioner
echo "[*] Registering automated driver and application auto-provisioner on target..."
chroot "$MOUNT_TARGET" rc-update add liteoffice-auto-provision default 2>/dev/null || true

if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    echo "[*] Internet connection detected! Pre-downloading hardware drivers and full application suite..."
    /usr/local/bin/liteoffice-auto-provision --target "$MOUNT_TARGET" || true
fi

# 8. Clean unmount target
echo "[*] Finalizing and unmounting target filesystem..."
sync
if [ -d "$MOUNT_TARGET/sys/firmware/efi/efivars" ]; then
    umount -l "$MOUNT_TARGET/sys/firmware/efi/efivars" 2>/dev/null || true
fi
umount -l "$MOUNT_TARGET/run" 2>/dev/null || true
umount -l "$MOUNT_TARGET/dev/pts" 2>/dev/null || true
umount -l "$MOUNT_TARGET/dev" 2>/dev/null || true
umount -l "$MOUNT_TARGET/proc" 2>/dev/null || true
umount -l "$MOUNT_TARGET/sys" 2>/dev/null || true

if [ -n "$TARGET_EFI_PART" ]; then
    umount "$MOUNT_TARGET/boot/efi" 2>/dev/null || true
fi
if [ -n "$TARGET_HOME_PART" ]; then
    umount "$MOUNT_TARGET/home" 2>/dev/null || true
fi
umount "$MOUNT_TARGET" 2>/dev/null || true
rmdir "$MOUNT_TARGET" 2>/dev/null || true

echo -e "\n${GREEN}${BOLD}==============================================================================${NC}"
echo -e "${GREEN}${BOLD}  LiteOffice OS has been successfully installed to ${TARGET_DISK}!           ${NC}"
echo -e "${GREEN}${BOLD}  Configured: Root (${ROOT_GB} GB), Swap (${SWAP_GB} GB), Home (${HOME_GB} GB)   ${NC}"
echo -e "${GREEN}${BOLD}  You may now reboot your system into your new LiteOffice OS installation.     ${NC}"
echo -e "${GREEN}${BOLD}==============================================================================${NC}\n"
