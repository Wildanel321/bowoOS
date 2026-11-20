#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOTFS="${1:-/var/tmp/liteoffice-build/rootfs_x86_64}"

echo "[1] Syncing openrc init binary..."
ln -sf /sbin/openrc-init "$ROOTFS/sbin/init"

echo "[2] Syncing installer binary, wrapper, and launcher..."
cp "$PROJECT_ROOT/installer/liteoffice-installer.py" "$ROOTFS/usr/local/bin/liteoffice-installer"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-installer"
cp "$PROJECT_ROOT/installer/liteoffice-installer-launcher" "$ROOTFS/usr/local/bin/liteoffice-installer-launcher"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-installer-launcher"
cp "$PROJECT_ROOT/installer/lite-installer.sh" "$ROOTFS/usr/local/bin/lite-installer"
chmod 755 "$ROOTFS/usr/local/bin/lite-installer"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-installer.desktop"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-installer.desktop"
mkdir -p "$ROOTFS/usr/share/applications"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$ROOTFS/usr/share/applications/liteoffice-installer.desktop"

cp "$PROJECT_ROOT/installer/liteoffice-installer-cli.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-installer-cli.desktop"
cp "$PROJECT_ROOT/installer/liteoffice-installer-cli.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-installer-cli.desktop"
cp "$PROJECT_ROOT/installer/liteoffice-installer-cli.desktop" "$ROOTFS/usr/share/applications/liteoffice-installer-cli.desktop"
chmod 755 "$ROOTFS/home/liteuser/Desktop/"*.desktop "$ROOTFS/etc/skel/Desktop/"*.desktop 2>/dev/null || true

echo "[2a] Configuring official APT update repositories (Debian 12 Bookworm)..."
mkdir -p "$ROOTFS/etc/apt"
cat << 'EOF' > "$ROOTFS/etc/apt/sources.list"
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
if [ ! -s "$ROOTFS/etc/resolv.conf" ]; then
    cat << 'EOF' > "$ROOTFS/etc/resolv.conf"
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
fi

# Create helper 1-click upgrade utility
cat << 'EOF' > "$ROOTFS/usr/local/bin/liteoffice-upgrade"
#!/bin/bash
echo "=================================================================="
echo "  LiteOffice OS — System Package Updater & Upgrader"
echo "=================================================================="
sudo apt-get update && sudo apt-get upgrade -y
echo ""
echo "[✓] System packages successfully upgraded to latest versions!"
read -p "Press Enter to exit..."
EOF
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-upgrade"

echo "[2b] Syncing Windows 10/11 Task Manager (liteoffice-monitor)..."
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.py" "$ROOTFS/usr/local/bin/liteoffice-monitor"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-monitor"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-monitor.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-monitor.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$ROOTFS/usr/share/applications/liteoffice-monitor.desktop"

echo "[2c] Syncing Windows 11 Fluent Start Menu (liteoffice-menu)..."
cp "$PROJECT_ROOT/branding/apps/liteoffice-menu.py" "$ROOTFS/usr/local/bin/liteoffice-menu"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-menu"
cp "$PROJECT_ROOT/desktop/assets/lite-start-menu.desktop" "$ROOTFS/usr/share/applications/lite-start-menu.desktop"
chmod 755 "$ROOTFS/usr/share/applications/lite-start-menu.desktop"

echo "[2d] Syncing Auto Hardware Driver & Application Provisioner..."
cp "$PROJECT_ROOT/installer/liteoffice-auto-provision" "$ROOTFS/usr/local/bin/liteoffice-auto-provision"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-auto-provision"
cp "$PROJECT_ROOT/init/init.d/liteoffice-auto-provision" "$ROOTFS/etc/init.d/liteoffice-auto-provision"
chmod 755 "$ROOTFS/etc/init.d/liteoffice-auto-provision"

echo "[2e] Syncing sudoers env_keep for X11 root installer..."
mkdir -p "$ROOTFS/etc/sudoers.d"
cat <<'EOF' > "$ROOTFS/etc/sudoers.d/99-liteuser"
liteuser ALL=(ALL) NOPASSWD:ALL
Defaults:liteuser env_keep += "DISPLAY XAUTHORITY XDG_RUNTIME_DIR"
EOF
chmod 0440 "$ROOTFS/etc/sudoers.d/99-liteuser"

echo "[2f] Syncing Session & Power Control dialog, controller, and desktop entries..."
cp "$PROJECT_ROOT/branding/apps/liteoffice-session.py" "$ROOTFS/usr/local/bin/liteoffice-session"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-session"
cp "$PROJECT_ROOT/desktop/bin/lite-logout" "$ROOTFS/usr/local/bin/lite-logout"
chmod 755 "$ROOTFS/usr/local/bin/lite-logout"
cp "$PROJECT_ROOT/branding/apps/liteoffice-control-center.py" "$ROOTFS/usr/local/bin/liteoffice-control-center"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-control-center"
cp "$PROJECT_ROOT/branding/apps/liteoffice-session.desktop" "$ROOTFS/usr/share/applications/liteoffice-session.desktop"
chmod 755 "$ROOTFS/usr/share/applications/liteoffice-session.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-session.desktop" "$ROOTFS/home/liteuser/Desktop/liteoffice-session.desktop"
cp "$PROJECT_ROOT/branding/apps/liteoffice-session.desktop" "$ROOTFS/etc/skel/Desktop/liteoffice-session.desktop"

echo "[2g] Syncing Hardened Security (sysctl, firewall, limits, and health watchdog)..."
mkdir -p "$ROOTFS/etc/sysctl.d" "$ROOTFS/etc/security/limits.d"
cp "$PROJECT_ROOT/rootfs/etc/sysctl.d/99-security.conf" "$ROOTFS/etc/sysctl.d/99-security.conf"
cp "$PROJECT_ROOT/rootfs/etc/security/limits.d/99-limits.conf" "$ROOTFS/etc/security/limits.d/99-limits.conf"

cp "$PROJECT_ROOT/init/init.d/liteoffice-firewall" "$ROOTFS/etc/init.d/liteoffice-firewall"
chmod 755 "$ROOTFS/etc/init.d/liteoffice-firewall"
cp "$PROJECT_ROOT/init/init.d/liteoffice-health" "$ROOTFS/etc/init.d/liteoffice-health"
chmod 755 "$ROOTFS/etc/init.d/liteoffice-health"
cp "$PROJECT_ROOT/init/init.d/lite-oom" "$ROOTFS/etc/init.d/lite-oom"
chmod 755 "$ROOTFS/etc/init.d/lite-oom"

cp "$PROJECT_ROOT/installer/liteoffice-firewall" "$ROOTFS/usr/local/bin/liteoffice-firewall"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-firewall"

rm -f "$ROOTFS/usr/local/bin/liteoffice-health" "$ROOTFS/usr/local/bin/liteoffice-healthd"
cp "$PROJECT_ROOT/installer/liteoffice-health" "$ROOTFS/usr/local/bin/liteoffice-health"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-health"
ln -sf liteoffice-health "$ROOTFS/usr/local/bin/liteoffice-healthd"

chmod 1777 "$ROOTFS/tmp" "$ROOTFS/var/tmp" 2>/dev/null || true
chmod 0600 "$ROOTFS/etc/shadow" "$ROOTFS/etc/gshadow" 2>/dev/null || true

mkdir -p "$ROOTFS/etc/xdg/openbox" "$ROOTFS/home/liteuser/.config/openbox" "$ROOTFS/etc/skel/.config/openbox"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$ROOTFS/etc/xdg/openbox/menu.xml"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$ROOTFS/home/liteuser/.config/openbox/menu.xml"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$ROOTFS/etc/skel/.config/openbox/menu.xml"

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

echo "[5b] Syncing tint2 taskbar panel configuration..."
mkdir -p "$ROOTFS/etc/xdg/tint2" "$ROOTFS/home/liteuser/.config/tint2" "$ROOTFS/etc/skel/.config/tint2"
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$ROOTFS/etc/xdg/tint2/tint2rc"
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$ROOTFS/home/liteuser/.config/tint2/tint2rc"
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$ROOTFS/etc/skel/.config/tint2/tint2rc"

echo "[6] Syncing openbox theme..."
mkdir -p "$ROOTFS/usr/share/themes/LiteOffice-Dark/openbox-3" "$ROOTFS/home/liteuser/.themes/LiteOffice-Dark/openbox-3" "$ROOTFS/etc/skel/.themes/LiteOffice-Dark/openbox-3"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/usr/share/themes/LiteOffice-Dark/openbox-3/themerc"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/home/liteuser/.themes/LiteOffice-Dark/openbox-3/themerc"
cp "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/openbox-3/themerc" "$ROOTFS/etc/skel/.themes/LiteOffice-Dark/openbox-3/themerc"

echo "[6b] Syncing modern LXTerminal configuration, bashrc prompt, and devpts service..."
mkdir -p "$ROOTFS/etc/xdg/lxterminal" "$ROOTFS/home/liteuser/.config/lxterminal" "$ROOTFS/etc/skel/.config/lxterminal"
cp "$PROJECT_ROOT/desktop/lxterminal/lxterminal.conf" "$ROOTFS/etc/xdg/lxterminal/lxterminal.conf"
cp "$PROJECT_ROOT/desktop/lxterminal/lxterminal.conf" "$ROOTFS/home/liteuser/.config/lxterminal/lxterminal.conf"
cp "$PROJECT_ROOT/desktop/lxterminal/lxterminal.conf" "$ROOTFS/etc/skel/.config/lxterminal/lxterminal.conf"

cp "$PROJECT_ROOT/rootfs/etc/skel/.bashrc" "$ROOTFS/etc/skel/.bashrc"
cp "$PROJECT_ROOT/rootfs/etc/skel/.bashrc" "$ROOTFS/home/liteuser/.bashrc"
cp "$PROJECT_ROOT/rootfs/etc/skel/.bashrc" "$ROOTFS/root/.bashrc"

mkdir -p "$ROOTFS/home/liteuser/.config/gtk-3.0" "$ROOTFS/etc/skel/.config/gtk-3.0"
cp "$PROJECT_ROOT/desktop/assets/gtk-3.0-gtk.css" "$ROOTFS/home/liteuser/.config/gtk-3.0/gtk.css"
cp "$PROJECT_ROOT/desktop/assets/gtk-3.0-gtk.css" "$ROOTFS/etc/skel/.config/gtk-3.0/gtk.css"

cp "$PROJECT_ROOT/init/init.d/devpts" "$ROOTFS/etc/init.d/devpts"
chmod 755 "$ROOTFS/etc/init.d/devpts"
cp "$PROJECT_ROOT/init/init.d/udev" "$ROOTFS/etc/init.d/udev"
chmod 755 "$ROOTFS/etc/init.d/udev"

echo "[7] Cleaning duplicate About shortcuts and syncing liteoffice-about..."
cp "$PROJECT_ROOT/branding/apps/liteoffice-about.py" "$ROOTFS/usr/local/bin/liteoffice-about"
chmod 755 "$ROOTFS/usr/local/bin/liteoffice-about"
rm -f "$ROOTFS/home/liteuser/Desktop/liteoffice-about.desktop"
rm -f "$ROOTFS/etc/skel/Desktop/liteoffice-about.desktop"
cp "$PROJECT_ROOT/desktop/assets/About-LiteOffice.desktop" "$ROOTFS/home/liteuser/Desktop/About-LiteOffice.desktop"
cp "$PROJECT_ROOT/desktop/assets/About-LiteOffice.desktop" "$ROOTFS/etc/skel/Desktop/About-LiteOffice.desktop"

echo "[7b] Setting executable permissions on all desktop shortcuts..."
chmod 755 "$ROOTFS/home/liteuser/Desktop/"*.desktop 2>/dev/null || true
chmod 755 "$ROOTFS/etc/skel/Desktop/"*.desktop 2>/dev/null || true

echo "[8] Fixing ownership of liteuser home..."
chown -R 1000:1000 "$ROOTFS/home/liteuser"

echo "[8b] Syncing kernel modules if present..."
if [ -d "/var/tmp/liteoffice-build/modules_staging_x86_64/lib/modules" ]; then
    mkdir -p "$ROOTFS/lib/modules"
    cp -r /var/tmp/liteoffice-build/modules_staging_x86_64/lib/modules/* "$ROOTFS/lib/modules/"
    chroot "$ROOTFS" depmod -a 6.6.78-lite 2>/dev/null || true
fi

echo "[8c] Syncing kernel and initramfs to rootfs /boot..."
mkdir -p "$ROOTFS/boot"
if [ -f "$PROJECT_ROOT/output/vmlinuz-6.6-lite-x86_64" ]; then
    cp "$PROJECT_ROOT/output/vmlinuz-6.6-lite-x86_64" "$ROOTFS/boot/vmlinuz-6.6.78-lite-x86_64"
    ln -sf "vmlinuz-6.6.78-lite-x86_64" "$ROOTFS/boot/vmlinuz"
fi
if [ -f "$PROJECT_ROOT/output/initramfs-x86_64.img" ]; then
    cp "$PROJECT_ROOT/output/initramfs-x86_64.img" "$ROOTFS/boot/initrd.img-6.6.78-lite-x86_64"
    ln -sf "initrd.img-6.6.78-lite-x86_64" "$ROOTFS/boot/initrd.img"
fi

echo "[8d] Syncing branded palm tree wallpaper..."
mkdir -p "$ROOTFS/usr/share/wallpapers/liteoffice"
if [ -f "$PROJECT_ROOT/branding/wallpapers/liteoffice-default.png" ]; then
    cp "$PROJECT_ROOT/branding/wallpapers/liteoffice-default.png" "$ROOTFS/usr/share/wallpapers/liteoffice/liteoffice-default.png"
fi
if [ -f "$PROJECT_ROOT/branding/wallpapers/liteoffice-1024x768.png" ]; then
    cp "$PROJECT_ROOT/branding/wallpapers/liteoffice-1024x768.png" "$ROOTFS/usr/share/wallpapers/liteoffice/liteoffice-1024x768.png"
fi

echo "[9] Running OpenRC patch script..."
bash "$PROJECT_ROOT/scripts/patch_openrc_services.sh" "$ROOTFS"

echo "ALL ROOTFS SYNC COMPLETED SUCCESSFULLY"
