#!/bin/bash
# ==============================================================================
# LiteOffice OS — Hybrid Bootable Live ISO Generator (Stage 8)
# Creates bootable ISO image supporting both Legacy BIOS (MBR) and Modern UEFI (GPT).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCH="x86_64"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            if [[ "$1" != --* ]]; then
                ARCH="$1"
            fi
            shift
            ;;
    esac
done

ROOTFS_DIR="/var/tmp/liteoffice-build/rootfs_${ARCH}"
OUTPUT_DIR="$PROJECT_ROOT/output"
KERNEL_BIN="$OUTPUT_DIR/vmlinuz-6.6-lite"
if [ -f "$OUTPUT_DIR/vmlinuz-6.6-lite-${ARCH}" ]; then
    KERNEL_BIN="$OUTPUT_DIR/vmlinuz-6.6-lite-${ARCH}"
fi
INITRAMFS_IMG="$OUTPUT_DIR/initramfs-${ARCH}.img"
OUTPUT_ISO="$OUTPUT_DIR/liteoffice-1.0-${ARCH}.iso"

ISO_TREE="/var/tmp/liteoffice-build/iso_tree_${ARCH}"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Must run as root (use sudo)." >&2
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo "[-] Error: Rootfs staging directory '$ROOTFS_DIR' not found." >&2
    exit 1
fi

if [ ! -f "$KERNEL_BIN" ]; then
    echo "[-] Error: Kernel binary '$KERNEL_BIN' not found." >&2
    exit 1
fi

if [ ! -f "$INITRAMFS_IMG" ]; then
    echo "[-] Error: Initramfs archive '$INITRAMFS_IMG' not found." >&2
    exit 1
fi

echo "=================================================================="
echo "LiteOffice OS — Hybrid Live ISO Construction Engine"
echo "Target Architecture: $ARCH"
echo "Output Target      : $OUTPUT_ISO"
echo "=================================================================="

# 1. Clean and prepare staging workspace
echo "[*] Preparing ISO staging tree ($ISO_TREE)..."
rm -rf "$ISO_TREE"
mkdir -p "$ISO_TREE"/{live,boot/grub/themes/liteoffice}
mkdir -p "$OUTPUT_DIR"

# 1b. Stage Kernel and Initramfs into rootfs /boot so installed target has bootloader binaries
echo "[*] Ensuring Linux 6.6 LTS kernel and initramfs exist in rootfs /boot..."
mkdir -p "$ROOTFS_DIR/boot"
cp "$KERNEL_BIN" "$ROOTFS_DIR/boot/vmlinuz-6.6.78-lite-${ARCH}"
cp "$INITRAMFS_IMG" "$ROOTFS_DIR/boot/initrd.img-6.6.78-lite-${ARCH}"
ln -sf "vmlinuz-6.6.78-lite-${ARCH}" "$ROOTFS_DIR/boot/vmlinuz"
ln -sf "initrd.img-6.6.78-lite-${ARCH}" "$ROOTFS_DIR/boot/initrd.img"

# 2. Package Root Filesystem into Compressed SquashFS
echo "[*] Compressing rootfs into SquashFS (/live/filesystem.squashfs)..."
mksquashfs "$ROOTFS_DIR" "$ISO_TREE/live/filesystem.squashfs" \
    -comp zstd \
    -noappend \
    -wildcards \
    -e "proc/*" "sys/*" "dev/*" "tmp/*" "run/*" "mnt/*" "media/*" \
    -b 1048576

SQUASH_SIZE=$(du -h "$ISO_TREE/live/filesystem.squashfs" | cut -f1)
echo "[+] SquashFS archive generated: $SQUASH_SIZE"

# 3. Copy Kernel and Early Userspace Initramfs
echo "[*] Copying Linux 6.6 LTS kernel and live initramfs..."
cp "$KERNEL_BIN" "$ISO_TREE/live/vmlinuz"
cp "$INITRAMFS_IMG" "$ISO_TREE/live/initrd.img"
chmod 644 "$ISO_TREE/live/vmlinuz" "$ISO_TREE/live/initrd.img"

# 4. Deploy LiteOffice OS GRUB Theme and Live Menu Configuration
echo "[*] Deploying branded GRUB theme and multi-boot configuration..."
if [ -d "$PROJECT_ROOT/branding/grub/liteoffice" ]; then
    cp -r "$PROJECT_ROOT/branding/grub/liteoffice/"* "$ISO_TREE/boot/grub/themes/liteoffice/"
fi

cat << 'EOF' > "$ISO_TREE/boot/grub/grub.cfg"
# ==============================================================================
# LiteOffice OS 1.0 LTS — Hybrid Bootloader Configuration
# ==============================================================================
set timeout=5
set default=0

# Video and Console Terminal Initialization
insmod all_video
insmod font
insmod png
insmod gfxterm

terminal_input console
terminal_output gfxterm console

set gfxmode=1024x768,800x600,auto
set gfxpayload=text

if [ -f /boot/grub/themes/liteoffice/theme.txt ]; then
    set theme=/boot/grub/themes/liteoffice/theme.txt
fi

menuentry "LiteOffice OS 1.0 LTS (Live Desktop Session)" --class os {
    echo "Loading LiteOffice OS 6.6 LTS Kernel..."
    linux /live/vmlinuz boot=live console=tty1 quiet loglevel=3
    echo "Loading Userspace Initramfs..."
    initrd /live/initrd.img
}

menuentry "LiteOffice OS 1.0 LTS (Safe Graphics / VESA Mode)" --class os {
    echo "Loading LiteOffice OS in Safe Graphics Mode..."
    linux /live/vmlinuz boot=live nomodeset xforcevesa console=tty1 quiet loglevel=3
    echo "Loading Userspace Initramfs..."
    initrd /live/initrd.img
}

menuentry "LiteOffice OS 1.0 LTS (Direct System Installer)" --class os {
    echo "Loading LiteOffice OS Direct Hardware Installer..."
    linux /live/vmlinuz boot=live lite_install=1 console=tty1 quiet loglevel=3
    echo "Loading Userspace Initramfs..."
    initrd /live/initrd.img
}

menuentry "LiteOffice OS Early Maintenance Shell" --class recovery {
    echo "Dropping to early userspace maintenance shell..."
    linux /live/vmlinuz break console=tty1 quiet=0
    initrd /live/initrd.img
}

menuentry "LiteOffice OS Headless / QEMU Serial Console" --class os {
    echo "Loading LiteOffice OS in Headless Serial Mode..."
    linux /live/vmlinuz boot=live console=ttyS0 console=tty1 quiet loglevel=3
    initrd /live/initrd.img
}

menuentry "Reboot System" --class reboot {
    reboot
}

menuentry "Power Off Hardware" --class halt {
    halt
}
EOF

# 5. Build Hybrid Bootable ISO Image using grub-mkrescue & xorriso
echo "[*] Generating hybrid BIOS/UEFI bootable ISO with xorriso & grub-mkrescue..."
grub-mkrescue \
    -o "$OUTPUT_ISO" \
    "$ISO_TREE" \
    -- \
    -volid "LITEOFFICE_LIVE"

ISO_SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
echo "=================================================================="
echo -e "\033[0;32m[V] SUCCESS: LiteOffice OS Live Hybrid ISO Created Successfully!\033[0m"
echo "    Location : $OUTPUT_ISO"
echo "    Size     : $ISO_SIZE"
echo "    Target   : BIOS (MBR) + UEFI (GPT) Compatible"
echo "=================================================================="
