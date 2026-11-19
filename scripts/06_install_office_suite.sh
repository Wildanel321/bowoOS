#!/bin/bash
# ==============================================================================
# LiteOffice OS — Office Productivity & Printing Suite Installer (Stage 6)
# Installs AbiWord, Gnumeric, qpdfview, CUPS print daemon, and adaptive launchers.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOTFS_DIR="/var/tmp/liteoffice-build/rootfs_x86_64"
RAW_IMAGE="/var/tmp/liteoffice-build/rootfs_x86_64.raw"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Must run as root (use sudo)." >&2
    exit 1
fi

if [ ! -d "$ROOTFS_DIR/etc" ]; then
    echo "[!] Target rootfs not found at $ROOTFS_DIR" >&2
    exit 1
fi

echo "[*] ======================================================"
echo "[*] Installing Stage 6: Office Suite & Printing Stack"
echo "[*] Target Rootfs: $ROOTFS_DIR"
echo "[*] ======================================================"

cleanup_chroot() {
    echo "[*] Cleaning chroot mounts..."
    umount -l "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/dev" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/proc" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/sys" 2>/dev/null || true
}
trap cleanup_chroot EXIT INT TERM

# 1. Mount virtual filesystems
echo "[*] Mounting virtual filesystems for chroot package configuration..."
mount --bind /dev "$ROOTFS_DIR/dev"
mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
mount -t proc proc "$ROOTFS_DIR/proc"
mount -t sysfs sysfs "$ROOTFS_DIR/sys"

cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

# 2. Install Office Suite & Printing Stack packages
echo "[*] Installing AbiWord, Gnumeric, qpdfview, CUPS daemon and filters..."
chroot "$ROOTFS_DIR" apt-get update -y
DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS_DIR" apt-get install -y --no-install-recommends \
    abiword \
    gnumeric \
    qpdfview \
    qpdfview-pdf-poppler-plugin \
    cups \
    cups-client \
    cups-filters \
    ghostscript

# Ensure systemd-sysv does not hijack OpenRC init
chroot "$ROOTFS_DIR" dpkg --purge --force-depends systemd-sysv libpam-systemd 2>/dev/null || true
chroot "$ROOTFS_DIR" ln -sf openrc-init /sbin/init

# Clean package caches to conserve disk footprint
chroot "$ROOTFS_DIR" apt-get clean
rm -rf "$ROOTFS_DIR/var/lib/apt/lists/"*

# 3. Deploy Adaptive Office Launchers
echo "[*] Deploying adaptive office launchers (/usr/local/bin/)..."
cp "$PROJECT_ROOT/office/bin/lite-launch-office" "$ROOTFS_DIR/usr/local/bin/lite-launch-office"
cp "$PROJECT_ROOT/office/bin/lite-launch-spreadsheet" "$ROOTFS_DIR/usr/local/bin/lite-launch-spreadsheet"
cp "$PROJECT_ROOT/office/bin/lite-launch-pdf" "$ROOTFS_DIR/usr/local/bin/lite-launch-pdf"
chmod 755 "$ROOTFS_DIR/usr/local/bin/lite-launch-"*

# 4. Deploy Low-Memory CUPS Configuration
echo "[*] Deploying optimized CUPS daemon configuration..."
mkdir -p "$ROOTFS_DIR/etc/cups"
cp "$PROJECT_ROOT/office/configs/cupsd.conf" "$ROOTFS_DIR/etc/cups/cupsd.conf"
chmod 640 "$ROOTFS_DIR/etc/cups/cupsd.conf"

# Register CUPS in OpenRC default runlevel
chroot "$ROOTFS_DIR" rc-update add cups default 2>/dev/null || true

# Add user 'liteuser' to printer operator groups
chroot "$ROOTFS_DIR" usermod -a -G lp,lpadmin liteuser 2>/dev/null || true

# 5. Deploy MIME Associations and Desktop Shortcuts
echo "[*] Deploying system MIME associations and office desktop entries..."
mkdir -p "$ROOTFS_DIR/etc/xdg" "$ROOTFS_DIR/usr/share/applications"
cp "$PROJECT_ROOT/office/mime_associations/mimeapps.list" "$ROOTFS_DIR/etc/xdg/mimeapps.list"
cp "$PROJECT_ROOT/office/mime_associations/mimeapps.list" "$ROOTFS_DIR/usr/share/applications/defaults.list"

cp "$PROJECT_ROOT/desktop/assets/Word-Processor.desktop" "$ROOTFS_DIR/usr/share/applications/Word-Processor.desktop"
cp "$PROJECT_ROOT/desktop/assets/Spreadsheet.desktop" "$ROOTFS_DIR/usr/share/applications/Spreadsheet.desktop"
cp "$PROJECT_ROOT/desktop/assets/PDF-Viewer.desktop" "$ROOTFS_DIR/usr/share/applications/PDF-Viewer.desktop"

# Deploy to live user Desktop and /etc/skel/Desktop
for dest in "$ROOTFS_DIR/home/liteuser/Desktop" "$ROOTFS_DIR/etc/skel/Desktop"; do
    mkdir -p "$dest"
    cp "$PROJECT_ROOT/desktop/assets/Word-Processor.desktop" "$dest/"
    cp "$PROJECT_ROOT/desktop/assets/Spreadsheet.desktop" "$dest/"
    cp "$PROJECT_ROOT/desktop/assets/PDF-Viewer.desktop" "$dest/"
    chmod 755 "$dest/"*.desktop
done
chown -R 1000:1000 "$ROOTFS_DIR/home/liteuser/Desktop" 2>/dev/null || true

# 6. Regenerate System Manifest
echo "[*] Updating system manifest with office and printing suite binaries..."
chroot "$ROOTFS_DIR" /usr/local/bin/liteoffice-manifest generate

# 7. Sync updated rootfs into raw ext4 image
cleanup_chroot

if [ -f "$RAW_IMAGE" ]; then
    echo "[*] Synchronizing updated rootfs into raw ext4 image ($RAW_IMAGE)..."
    LOOP_DEV=$(losetup -fP --show "$RAW_IMAGE")
    MNT_DIR="/var/tmp/liteoffice-build/mnt_img"
    mkdir -p "$MNT_DIR"
    mount "$LOOP_DEV" "$MNT_DIR"
    rsync -aHAX --delete --exclude="/dev/*" --exclude="/proc/*" --exclude="/sys/*" --exclude="/tmp/*" --exclude="/run/*" "$ROOTFS_DIR/" "$MNT_DIR/"
    sync
    umount "$MNT_DIR"
    losetup -d "$LOOP_DEV"
    rmdir "$MNT_DIR" 2>/dev/null || true
    echo "[+] Raw ext4 image synchronized successfully."
fi

echo "[+] ======================================================"
echo "[+] Stage 6 Office & Printing Suite Installed Successfully!"
echo "[+] ======================================================"
