#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOTFS="${1:-/var/tmp/liteoffice-build/rootfs_x86_64}"

echo "[1] Syncing openrc init binary..."
ln -sf /sbin/openrc-init "$ROOTFS/sbin/init"

echo "[2] Syncing installer binary and launcher..."
cp "$PROJECT_ROOT/installer/liteoffice-installer.py" "$ROOTFS/usr/local/bin/liteoffice-installer"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-installer"
cp "$PROJECT_ROOT/installer/liteoffice-installer-launcher" "$ROOTFS/usr/local/bin/liteoffice-installer-launcher"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-installer-launcher"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-installer.desktop"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-installer.desktop"
mkdir -p "$ROOTFS/usr/share/applications"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/usr/share/applications/liteoffice-installer.desktop"

echo "[2b] Syncing Windows 10/11 Task Manager (liteoffice-monitor)..."
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.py" "$ROOTFS/usr/local/bin/liteoffice-monitor"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-monitor"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-monitor.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-monitor.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/usr/share/applications/liteoffice-monitor.desktop"

echo "[2b] Syncing sudoers env_keep for X11 root installer..."
mkdir -p "$ROOTFS/etc/sudoers.d"
cat <<'EOF' > "$ROOTFS/etc/sudoers.d/99-liteuser"
liteuser ALL=(ALL) NOPASSWD:ALL
Defaults:liteuser env_keep += "DISPLAY XAUTHORITY XDG_RUNTIME_DIR"
EOF
chmod 0440 "$ROOTFS/etc/sudoers.d/99-liteuser"

echo "[3] Syncing libfm and pcmanfm configs (quick_exec=1)..."
mkdir -p "$ROOTFS/etc/xdg/libfm" "$ROOTFS/home/liteuser/.config/libfm" "$ROOTFS/etc/skel/.config/libfm"
cp "$PROJECT_ROOT/desktop/pcmanfm/libfm.conf" "$ROOTFS/etc/xdg/libfm/libfm.conf"
cp "$PROJECT_ROOT/desktop/pcmanfm/libfm.conf" "$ROOTFS/home/liteuser/.config/libfm/libfm.conf"
cp "$PROJECT_ROOT/desktop/pcmanfm/libfm.conf" "$ROOTFS/etc/skel/.config/libfm/libfm.conf"

mkdir -p "$ROOTFS/etc/xdg/pcmanfm/default" "$ROOTFS/home/liteuser/.config/pcmanfm/default" "$ROOTFS/etc/skel/.config/pcmanfm/default"
cp "$PROJECT_ROOT/desktop/pcmanfm/pcmanfm.conf" "$ROOTFS/etc/xdg/pcmanfm/default/pcmanfm.conf"
cp "$PROJECT_ROOT/desktop/pcmanfm/pcmanfm.conf" "$ROOTFS/home/liteuser/.config/pcmanfm/default/pcmanfm.conf"
cp "$PROJECT_ROOT/desktop/pcmanfm/pcmanfm.conf" "$ROOTFS/etc/skel/.config/pcmanfm/default/pcmanfm.conf"

echo "[4] Syncing openbox rc.xml (smooth close, no maximize on close)..."
mkdir -p "$ROOTFS/etc/xdg/openbox" "$ROOTFS/home/liteuser/.config/openbox" "$ROOTFS/etc/skel/.config/openbox"
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$ROOTFS/etc/xdg/openbox/rc.xml"
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$ROOTFS/home/liteuser/.config/openbox/rc.xml"
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$ROOTFS/etc/skel/.config/openbox/rc.xml"

echo "[5] Syncing openbox autostart (nm-applet)..."
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$ROOTFS/etc/xdg/openbox/autostart"
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$ROOTFS/home/liteuser/.config/openbox/autostart"
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$ROOTFS/etc/skel/.config/openbox/autostart"

echo "[6] Syncing openbox theme..."
mkdir -p "$ROOTFS/usr/share/themes/LiteOffice-Dark/openbox-3" "$ROOTFS/home/liteuser/.themes/LiteOffice-Dark/openbox-3" "$ROOTFS/etc/skel/.themes/LiteOffice-Dark/openbox-3"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/usr/share/themes/LiteOffice-Dark/openbox-3/themerc"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/home/liteuser/.themes/LiteOffice-Dark/openbox-3/themerc"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/etc/skel/.themes/LiteOffice-Dark/openbox-3/themerc"

echo "[7] Cleaning duplicate About shortcuts..."
rm -f "$ROOTFS/home/liteuser/Desktop/liteoffice-about.desktop"
rm -f "$ROOTFS/etc/skel/Desktop/liteoffice-about.desktop"
cp "$PROJECT_ROOT/desktop/assets/About-LiteOffice.desktop" "$ROOTFS/home/liteuser/Desktop/About-LiteOffice.desktop"
cp "$PROJECT_ROOT/desktop/assets/About-LiteOffice.desktop" "$ROOTFS/etc/skel/Desktop/About-LiteOffice.desktop"

echo "[8] Fixing ownership of liteuser home..."
chown -R 1000:1000 "$ROOTFS/home/liteuser"

echo "[8b] Syncing kernel modules if present..."
if [ -d "/var/tmp/liteoffice-build/modules_staging_x86_64/lib/modules" ]; then
    mkdir -p "$ROOTFS/lib/modules"
    cp -r /var/tmp/liteoffice-build/modules_staging_x86_64/lib/modules/* "$ROOTFS/lib/modules/"
    chroot "$ROOTFS" depmod -a 6.6.78-lite 2>/dev/null || true
fi

echo "[9] Running OpenRC patch script..."
bash "$PROJECT_ROOT/scripts/patch_openrc_services.sh" "$ROOTFS"

echo "ALL ROOTFS SYNC COMPLETED SUCCESSFULLY"
