#!/bin/bash
# ==============================================================================
# LiteOffice OS — Stage 7 RAM Optimization & Memory Daemons Installer
# Deploys low-RAM kernel parameters, ZRAM auto-scaler, and OOM supervisor.
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
echo "[*] Applying Stage 7: RAM Optimization & Memory Daemons"
echo "[*] Target Rootfs: $ROOTFS_DIR"
echo "[*] ======================================================"

# 1. Deploy low-memory sysctl configuration
echo "[*] Deploying /etc/sysctl.d/99-lowmem.conf..."
mkdir -p "$ROOTFS_DIR/etc/sysctl.d"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/sysctl.d/99-lowmem.conf" "$ROOTFS_DIR/etc/sysctl.d/99-lowmem.conf"
chmod 644 "$ROOTFS_DIR/etc/sysctl.d/99-lowmem.conf"

# 2. Deploy OpenRC memory supervision services
echo "[*] Ensuring OpenRC memory daemons are registered..."
cp "$PROJECT_ROOT/init/init.d/zram-swap" "$ROOTFS_DIR/etc/init.d/zram-swap"
cp "$PROJECT_ROOT/init/init.d/lite-profile-detect" "$ROOTFS_DIR/etc/init.d/lite-profile-detect"
cp "$PROJECT_ROOT/init/init.d/lite-oom" "$ROOTFS_DIR/etc/init.d/lite-oom"
chmod 755 "$ROOTFS_DIR/etc/init.d/zram-swap" \
          "$ROOTFS_DIR/etc/init.d/lite-profile-detect" \
          "$ROOTFS_DIR/etc/init.d/lite-oom"

chroot "$ROOTFS_DIR" rc-update add zram-swap boot 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add lite-profile-detect boot 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add lite-oom default 2>/dev/null || true

# 3. Regenerate System Manifest
echo "[*] Regenerating system manifest..."
chroot "$ROOTFS_DIR" /usr/local/bin/liteoffice-manifest generate

# 4. Synchronize raw disk image
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
echo "[+] Stage 7 RAM Optimization Applied Successfully!"
echo "[+] ======================================================"
