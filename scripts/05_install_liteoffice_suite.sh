#!/bin/bash
# ==============================================================================
# LiteOffice OS — Complete System & Branding Suite Installer
# Deploys branding, desktop themes, native apps, daemons, tools, and profiles.
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
RAW_IMAGE="/var/tmp/liteoffice-build/rootfs_${ARCH}.raw"

if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Must run as root (use sudo)." >&2
    exit 1
fi

if [ ! -d "$ROOTFS_DIR/etc" ]; then
    echo "[!] Target rootfs not found at $ROOTFS_DIR" >&2
    exit 1
fi

echo "[*] ======================================================"
echo "[*] Installing LiteOffice OS Complete System & Branding Suite"
echo "[*] Target Rootfs: $ROOTFS_DIR"
echo "[*] ======================================================"

# Clean unmount trap
cleanup_chroot() {
    echo "[*] Cleaning chroot mounts..."
    umount -l "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/dev" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/proc" 2>/dev/null || true
    umount -l "$ROOTFS_DIR/sys" 2>/dev/null || true
}
trap cleanup_chroot EXIT INT TERM

# ------------------------------------------------------------------------------
# 1. Mount virtual filesystems and install required runtime packages
# ------------------------------------------------------------------------------
echo "[*] Mounting virtual filesystems for chroot package configuration..."
mount --bind /dev "$ROOTFS_DIR/dev"
mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
mount -t proc proc "$ROOTFS_DIR/proc"
mount -t sysfs sysfs "$ROOTFS_DIR/sys"

# Configure DNS for chroot package retrieval
cp /etc/resolv.conf "$ROOTFS_DIR/etc/resolv.conf"

echo "[*] Installing native GUI runtimes, plymouth splash, and hardware utilities..."
chroot "$ROOTFS_DIR" apt-get update -y

EXTRA_PKGS=()
if [ "$ARCH" = "i686" ]; then
    EXTRA_PKGS+=("grub-efi-ia32-bin")
else
    EXTRA_PKGS+=("grub-efi-amd64-bin")
fi

DEBIAN_FRONTEND=noninteractive chroot "$ROOTFS_DIR" apt-get install -y \
    dbus-x11 \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-3.0 \
    plymouth \
    plymouth-themes \
    pciutils \
    usbutils \
    iproute2 \
    procps \
    psmisc \
    parted \
    dosfstools \
    rsync \
    htop \
    arandr \
    grub-common \
    grub-pc-bin \
    grub2-common \
    "${EXTRA_PKGS[@]}"

# Ensure systemd-sysv does not hijack OpenRC init
chroot "$ROOTFS_DIR" dpkg --purge --force-depends systemd-sysv libpam-systemd dbus-user-session 2>/dev/null || true
chroot "$ROOTFS_DIR" ln -sf openrc-init /sbin/init

# Clean package caches to preserve disk footprint
chroot "$ROOTFS_DIR" apt-get clean
rm -rf "$ROOTFS_DIR/var/lib/apt/lists/"*

# ------------------------------------------------------------------------------
# 2. Deploy Branding Assets (Logos, Icons, Wallpapers, Themes, OS Release)
# ------------------------------------------------------------------------------
echo "[*] Deploying brand identity, icon themes, and wallpapers..."

# Official OS release metadata
cat << 'EOF' > "$ROOTFS_DIR/etc/os-release"
NAME="LiteOffice OS"
VERSION="1.0 LTS"
ID=liteoffice
ID_LIKE=debian
PRETTY_NAME="LiteOffice OS 1.0 LTS"
VERSION_ID="1.0"
HOME_URL="https://github.com/Willcuy/bowoOS"
SUPPORT_URL="https://github.com/Willcuy/bowoOS/issues"
BUG_REPORT_URL="https://github.com/Willcuy/bowoOS/issues"
LOGO=liteoffice
EOF

# Issue and MOTD login banners
cat << 'EOF' > "$ROOTFS_DIR/etc/issue"
LiteOffice OS 1.0 LTS (\m) - \l

EOF

cat << 'EOF' > "$ROOTFS_DIR/etc/motd"
================================================================================
 LiteOffice OS 1.0 LTS — Ultra-Lightweight Modular Office Desktop
 Default desktop user: liteuser | Docs: /usr/share/doc/liteoffice
================================================================================
EOF

# Icon themes and pixmaps
ICON_BASE="$ROOTFS_DIR/usr/share/icons/LiteOffice"
for size in 16 24 32 48 64 128 256 512; do
    mkdir -p "$ICON_BASE/${size}x${size}/apps"
    if [ -f "$PROJECT_ROOT/branding/logo/liteoffice-icon-${size}.png" ]; then
        cp "$PROJECT_ROOT/branding/logo/liteoffice-icon-${size}.png" "$ICON_BASE/${size}x${size}/apps/liteoffice.png"
    fi
done

# Scalable SVG icon
mkdir -p "$ICON_BASE/scalable/apps"
cp "$PROJECT_ROOT/branding/logo/liteoffice-logo.svg" "$ICON_BASE/scalable/apps/liteoffice.svg"

# Standard pixmaps and hicolor fallback for menus and file managers
mkdir -p "$ROOTFS_DIR/usr/share/pixmaps"
mkdir -p "$ROOTFS_DIR/usr/share/icons/hicolor/48x48/apps"
if [ -f "$PROJECT_ROOT/branding/logo/liteoffice-icon-48.png" ]; then
    cp "$PROJECT_ROOT/branding/logo/liteoffice-icon-48.png" "$ROOTFS_DIR/usr/share/pixmaps/liteoffice.png"
    cp "$PROJECT_ROOT/branding/logo/liteoffice-icon-48.png" "$ROOTFS_DIR/usr/share/icons/hicolor/48x48/apps/liteoffice.png"
fi
if [ -f "$PROJECT_ROOT/branding/logo/liteoffice-logo.png" ]; then
    cp "$PROJECT_ROOT/branding/logo/liteoffice-logo.png" "$ROOTFS_DIR/usr/share/pixmaps/liteoffice-logo.png"
    cp "$PROJECT_ROOT/branding/logo/liteoffice-logo.png" "$ICON_BASE/liteoffice-logo.png"
fi
for size in 16 24 32 48 64 128 256 512; do
    if [ -f "$PROJECT_ROOT/branding/logo/liteoffice-icon-${size}.png" ]; then
        cp "$PROJECT_ROOT/branding/logo/liteoffice-icon-${size}.png" "$ICON_BASE/liteoffice-icon-${size}.png"
    fi
done

# Icon theme descriptor
cat << 'EOF' > "$ICON_BASE/index.theme"
[Icon Theme]
Name=LiteOffice
Comment=Official LiteOffice OS Vector and Hi-DPI Icon Theme
Inherits=Papirus-Dark,Adwaita,hicolor
Directories=16x16/apps,24x24/apps,32x32/apps,48x48/apps,64x64/apps,128x128/apps,256x256/apps,512x512/apps,scalable/apps

[16x16/apps]
Size=16
Type=Fixed

[24x24/apps]
Size=24
Type=Fixed

[32x32/apps]
Size=32
Type=Fixed

[48x48/apps]
Size=48
Type=Fixed

[64x64/apps]
Size=64
Type=Fixed

[128x128/apps]
Size=128
Type=Fixed

[256x256/apps]
Size=256
Type=Fixed

[512x512/apps]
Size=512
Type=Fixed

[scalable/apps]
Size=128
MinSize=16
MaxSize=512
Type=Scalable
EOF

# Wallpapers
WALLPAPER_DIR="$ROOTFS_DIR/usr/share/wallpapers/liteoffice"
mkdir -p "$WALLPAPER_DIR"
cp "$PROJECT_ROOT/branding/wallpapers/"*.png "$WALLPAPER_DIR/"
chmod 644 "$WALLPAPER_DIR/"*.png

# GRUB Theme
GRUB_THEME_DIR="$ROOTFS_DIR/boot/grub/themes/liteoffice"
mkdir -p "$GRUB_THEME_DIR"
cp -r "$PROJECT_ROOT/branding/grub/liteoffice/"* "$GRUB_THEME_DIR/"
sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/liteoffice/theme.txt"|' "$ROOTFS_DIR/etc/default/grub" 2>/dev/null || true

# Plymouth Boot and Shutdown Splash Theme
PLYMOUTH_THEME_DIR="$ROOTFS_DIR/usr/share/plymouth/themes/liteoffice"
mkdir -p "$PLYMOUTH_THEME_DIR"
cp -r "$PROJECT_ROOT/branding/plymouth/liteoffice/"* "$PLYMOUTH_THEME_DIR/"
chmod 644 "$PLYMOUTH_THEME_DIR/"*
mkdir -p "$ROOTFS_DIR/etc/plymouth"
cat << 'EOF' > "$ROOTFS_DIR/etc/plymouth/plymouthd.conf"
[Daemon]
Theme=liteoffice
ShowDelay=0
DeviceTimeout=8
EOF

# Desktop Themes (GTK 2.0, GTK 3.0, Openbox)
THEME_DEST="$ROOTFS_DIR/usr/share/themes/LiteOffice-Dark"
mkdir -p "$THEME_DEST"
cp -r "$PROJECT_ROOT/branding/themes/LiteOffice-Dark/"* "$THEME_DEST/"

# ------------------------------------------------------------------------------
# 3. Deploy Native Applications & System Tools
# ------------------------------------------------------------------------------
echo "[*] Deploying native GTK applications, administration tools, and health services..."

# Native Applications
cp "$PROJECT_ROOT/branding/apps/liteoffice-about.py" "$ROOTFS_DIR/usr/local/bin/liteoffice-about"
cp "$PROJECT_ROOT/branding/apps/liteoffice-welcome.py" "$ROOTFS_DIR/usr/local/bin/liteoffice-welcome"
cp "$PROJECT_ROOT/branding/apps/liteoffice-control-center.py" "$ROOTFS_DIR/usr/local/bin/liteoffice-control-center"
cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.py" "$ROOTFS_DIR/usr/local/bin/liteoffice-monitor"
chmod 755 "$ROOTFS_DIR/usr/local/bin/liteoffice-"*

# System Utilities & CLI Tools
cp "$PROJECT_ROOT/branding/tools/liteoffice-pkg" "$ROOTFS_DIR/usr/local/bin/liteoffice-pkg"
cp "$PROJECT_ROOT/branding/tools/liteoffice-automate" "$ROOTFS_DIR/usr/local/bin/liteoffice-automate"
cp "$PROJECT_ROOT/branding/tools/liteoffice-manifest" "$ROOTFS_DIR/usr/local/bin/liteoffice-manifest"
cp "$PROJECT_ROOT/branding/tools/liteoffice-security" "$ROOTFS_DIR/usr/local/bin/liteoffice-security"
cp "$PROJECT_ROOT/installer/lite-installer.sh" "$ROOTFS_DIR/usr/local/bin/lite-installer"
cp "$PROJECT_ROOT/installer/liteoffice-installer.py" "$ROOTFS_DIR/usr/local/bin/liteoffice-installer"
cp "$PROJECT_ROOT/desktop/bin/lite-youtube" "$ROOTFS_DIR/usr/local/bin/lite-youtube"
chmod 755 "$ROOTFS_DIR/usr/local/bin/liteoffice-pkg" \
          "$ROOTFS_DIR/usr/local/bin/liteoffice-automate" \
          "$ROOTFS_DIR/usr/local/bin/liteoffice-manifest" \
          "$ROOTFS_DIR/usr/local/bin/liteoffice-security" \
          "$ROOTFS_DIR/usr/local/bin/lite-installer" \
          "$ROOTFS_DIR/usr/local/bin/liteoffice-installer" \
          "$ROOTFS_DIR/usr/local/bin/lite-youtube"

# Desktop Entries
DESKTOP_APPS="$ROOTFS_DIR/usr/share/applications"
mkdir -p "$DESKTOP_APPS"
cp "$PROJECT_ROOT/branding/apps/"*.desktop "$DESKTOP_APPS/"
cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$DESKTOP_APPS/liteoffice-installer.desktop"
cp "$PROJECT_ROOT/desktop/assets/Web-Browser.desktop" "$DESKTOP_APPS/Web-Browser.desktop"
cp "$PROJECT_ROOT/desktop/assets/YouTube.desktop" "$DESKTOP_APPS/YouTube.desktop"
chmod 644 "$DESKTOP_APPS/"*.desktop

# System Health Daemon and OpenRC Init Service
cp "$PROJECT_ROOT/branding/services/liteoffice-healthd" "$ROOTFS_DIR/usr/local/bin/liteoffice-healthd"
chmod 755 "$ROOTFS_DIR/usr/local/bin/liteoffice-healthd"
ln -sf liteoffice-healthd "$ROOTFS_DIR/usr/local/bin/liteoffice-health"

cp "$PROJECT_ROOT/branding/services/init.d/liteoffice-health" "$ROOTFS_DIR/etc/init.d/liteoffice-health"
chmod 755 "$ROOTFS_DIR/etc/init.d/liteoffice-health"

# Register health check service in OpenRC default runlevel
chroot "$ROOTFS_DIR" rc-update add liteoffice-health default 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Configure User Skeleton (/etc/skel) & Active User Profile (/home/liteuser)
# ------------------------------------------------------------------------------
echo "[*] Populating user skeleton (/etc/skel) and live user configurations..."

populate_profile() {
    local target_dir="$1"
    local is_user="${2:-false}"

    mkdir -p "$target_dir"/{Desktop,Documents,Downloads,Pictures}
    mkdir -p "$target_dir"/.config/{openbox,tint2,gtk-3.0,pcmanfm/default}

    # Shell profile
    cp "$PROJECT_ROOT/branding/skel/.bashrc" "$target_dir/.bashrc"
    cp "$PROJECT_ROOT/desktop/assets/.profile" "$target_dir/.profile"
    cp "$PROJECT_ROOT/desktop/assets/.xinitrc" "$target_dir/.xinitrc"
    chmod 755 "$target_dir/.xinitrc"

    # Openbox
    cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$target_dir/.config/openbox/rc.xml"
    cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$target_dir/.config/openbox/menu.xml"
    cp "$PROJECT_ROOT/desktop/openbox/autostart" "$target_dir/.config/openbox/autostart"
    chmod 755 "$target_dir/.config/openbox/autostart"

    # Tint2 panel
    cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$target_dir/.config/tint2/tint2rc"

    # PCManFM file manager and desktop
    cp "$PROJECT_ROOT/desktop/pcmanfm/pcmanfm.conf" "$target_dir/.config/pcmanfm/default/pcmanfm.conf"
    cp "$PROJECT_ROOT/desktop/pcmanfm/desktop-items-0.conf" "$target_dir/.config/pcmanfm/default/desktop-items-0.conf"

    # GTK appearance config
    cat << 'EOF' > "$target_dir/.gtkrc-2.0"
gtk-theme-name="LiteOffice-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Sans 9"
gtk-cursor-theme-name="Adwaita"
gtk-cursor-theme-size=16
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-button-images=1
gtk-menu-images=1
EOF

    cat << 'EOF' > "$target_dir/.config/gtk-3.0/settings.ini"
[Settings]
gtk-theme-name=LiteOffice-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 9
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=16
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-button-images=1
gtk-menu-images=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

    # Desktop shortcuts
    cp "$PROJECT_ROOT/branding/apps/liteoffice-welcome.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/branding/apps/liteoffice-control-center.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/branding/apps/liteoffice-monitor.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/branding/apps/liteoffice-about.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/installer/liteoffice-installer.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/Word-Processor.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/Spreadsheet.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/Web-Browser.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/YouTube.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/File-Manager.desktop" "$target_dir/Desktop/"
    cp "$PROJECT_ROOT/desktop/assets/Terminal.desktop" "$target_dir/Desktop/"
    chmod 755 "$target_dir/Desktop/"*.desktop
}

populate_profile "$ROOTFS_DIR/etc/skel"
populate_profile "$ROOTFS_DIR/home/liteuser" true
chown -R 1000:1000 "$ROOTFS_DIR/home/liteuser"

# Firefox ESR low-memory and hardware video acceleration profile
mkdir -p "$ROOTFS_DIR/etc/firefox-esr"
cat << 'EOF' > "$ROOTFS_DIR/etc/firefox-esr/syspref.js"
// LiteOffice OS — Firefox ESR Low-Memory & Hardware Video Acceleration Profile
// Tuned for 2-Core / 2 GB RAM Mini PCs
pref("dom.ipc.processCount", 2);
pref("media.ffmpeg.vaapi.enabled", true);
pref("media.hardware-video-decoding.enabled", true);
pref("widget.dmabuf.vaapi.enabled", true);
pref("media.av1.enabled", false);
pref("browser.cache.memory.capacity", 65536);
pref("browser.tabs.unloadOnLowMemory", true);
pref("accessibility.force_disabled", 1);
EOF

# Update system-wide XDG defaults
mkdir -p "$ROOTFS_DIR/etc/xdg/tint2"
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$ROOTFS_DIR/etc/xdg/tint2/tint2rc"

mkdir -p "$ROOTFS_DIR/etc/xdg/openbox"
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$ROOTFS_DIR/etc/xdg/openbox/rc.xml"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$ROOTFS_DIR/etc/xdg/openbox/menu.xml"
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$ROOTFS_DIR/etc/xdg/openbox/autostart"

# ------------------------------------------------------------------------------
# 5. Generate System File & Security Manifest
# ------------------------------------------------------------------------------
echo "[*] Generating cryptographically verifiable system manifest (/etc/liteoffice/manifest.json)..."
chroot "$ROOTFS_DIR" /usr/local/bin/liteoffice-manifest generate

# ------------------------------------------------------------------------------
# 6. Synchronize changes to raw disk image
# ------------------------------------------------------------------------------
cleanup_chroot

if [ -f "$RAW_IMAGE" ]; then
    echo "[*] Synchronizing updated rootfs into raw ext4 image ($RAW_IMAGE)..."
    LOOP_DEV=$(losetup -fP --show "$RAW_IMAGE")
    MNT_DIR="/var/tmp/liteoffice-build/mnt_img"
    mkdir -p "$MNT_DIR"
    mount "$LOOP_DEV" "$MNT_DIR"
    rsync -aHAX --delete --exclude="/dev/*" --exclude="/proc/*" --exclude="/sys/*" --exclude="/tmp/*" --exclude="/run/*" "$ROOTFS_DIR/" "$MNT_DIR/"
    umount "$MNT_DIR"
    losetup -d "$LOOP_DEV"
    rmdir "$MNT_DIR" 2>/dev/null || true
    echo "[+] Raw ext4 image synchronized successfully."
fi

echo "[+] ======================================================"
echo "[+] LiteOffice OS Suite Installation Completed Successfully!"
echo "[+] ======================================================"
