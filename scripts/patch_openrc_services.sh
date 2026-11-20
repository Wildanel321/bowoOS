#!/usr/bin/env bash
# ==============================================================================
# LiteOffice OS — OpenRC Service Cleanup and Native udev Integrator
# ==============================================================================
set -euo pipefail

ROOTFS_DIR="${1:-/var/tmp/liteoffice-build/rootfs_x86_64}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[*] Integrating native OpenRC udev service into rootfs..."
cp "$PROJECT_ROOT/init/init.d/udev" "$ROOTFS_DIR/etc/init.d/udev"
chmod 755 "$ROOTFS_DIR/etc/init.d/udev"

echo "[*] Updating zram-swap service in rootfs..."
cp "$PROJECT_ROOT/init/init.d/zram-swap" "$ROOTFS_DIR/etc/init.d/zram-swap"
chmod 755 "$ROOTFS_DIR/etc/init.d/zram-swap"

echo "[*] Integrating NetworkManager OpenRC service into rootfs..."
cp "$PROJECT_ROOT/init/init.d/networkmanager" "$ROOTFS_DIR/etc/init.d/networkmanager"
chmod 755 "$ROOTFS_DIR/etc/init.d/networkmanager"

echo "[*] Ensuring OpenRC init binary symlink..."
ln -sf /sbin/openrc-init "$ROOTFS_DIR/sbin/init"

echo "[*] Fixing LSB headers on legacy SysVinit scripts..."
# Fix procps
sed -i 's/mountkernfs //g' "$ROOTFS_DIR/etc/init.d/procps"

# Fix alsa-utils: check if /proc/asound/cards has numbers before calling amixer
if ! grep -q "proc/asound/cards" "$ROOTFS_DIR/etc/init.d/alsa-utils"; then
    chroot "$ROOTFS_DIR" python3 -c "
path = '/etc/init.d/alsa-utils'
with open(path, 'r') as f:
    content = f.read()
target = '[ -x /usr/sbin/alsactl ] || exit 0'
replacement = '''[ -x /usr/sbin/alsactl ] || exit 0

# Exit cleanly if no physical or virtual sound cards exist
if [ ! -f /proc/asound/cards ] || ! grep -q '[0-9]' /proc/asound/cards 2>/dev/null; then
    exit 0
fi'''
if target in content:
    with open(path, 'w') as f:
        f.write(content.replace(target, replacement, 1))
"
fi

echo "[*] Adjusting OpenRC runlevel registrations..."
chroot "$ROOTFS_DIR" rc-update add devpts sysinit 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add udev sysinit 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add liteoffice-firewall boot 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add networkmanager default 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add liteoffice-health default 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update add lite-oom default 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update del hwclock.sh sysinit 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update del pulseaudio-enable-autospawn default 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update del plymouth default 2>/dev/null || true
chroot "$ROOTFS_DIR" rc-update del plymouth-log sysinit 2>/dev/null || true

echo "[*] Checking dependency graph in OpenRC:"
chroot "$ROOTFS_DIR" rc-status -a
