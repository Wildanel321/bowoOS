#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Stage 4: X11 Display Server & Openbox Desktop Installer
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARCH="x86_64"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Installing Graphical Desktop Stack (${ARCH})${NC}"
echo -e "${BLUE}==============================================================================${NC}"

BUILD_DIR="/var/tmp/liteoffice-build"
ROOTFS_DIR="$BUILD_DIR/rootfs_${ARCH}"

if [ ! -d "$ROOTFS_DIR" ]; then
    echo -e "${RED}[-] Error: Rootfs staging directory '$ROOTFS_DIR' not found! Run Stage 3 first.${NC}"
    exit 1
fi

# Ensure superuser privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}[!] Escalating to root privileges using sudo...${NC}"
    exec sudo bash "$0" --arch "$ARCH"
fi

# 1. Mount virtual filesystems for chroot operations
echo "[*] Mounting virtual filesystems into rootfs..."
mount -t proc none "$ROOTFS_DIR/proc" 2>/dev/null || true
mount -t sysfs none "$ROOTFS_DIR/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
mount -t devpts none "$ROOTFS_DIR/dev/pts" 2>/dev/null || true

cleanup() {
    echo "[*] Cleaning up mounts..."
    umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    umount "$ROOTFS_DIR/dev" 2>/dev/null || true
    umount "$ROOTFS_DIR/sys" 2>/dev/null || true
    umount "$ROOTFS_DIR/proc" 2>/dev/null || true
}
trap cleanup EXIT

# 2. Prevent daemons from starting in chroot
cat << 'EOF' > "$ROOTFS_DIR/usr/sbin/policy-rc.d"
#!/bin/sh
exit 101
EOF
chmod +x "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# 3. Install Graphical Stack via Apt inside Chroot
echo -e "[*] Installing minimal Xorg, Openbox, Tint2, and Desktop Utilities..."
cat << 'EOF' > "$ROOTFS_DIR/tmp/install_desktop.sh"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update

# Core X11, video drivers, window manager, and lightweight applications
apt-get install -y --no-install-recommends \
    xserver-xorg-core \
    xserver-xorg-video-all \
    xserver-xorg-input-all \
    xserver-xorg-legacy \
    xinit \
    x11-xserver-utils \
    x11-utils \
    openbox \
    obconf \
    tint2 \
    pcmanfm \
    lxterminal \
    lxappearance \
    zenity \
    mousepad \
    galculator \
    xarchiver \
    scrot \
    papirus-icon-theme \
    fonts-dejavu-core \
    volumeicon-alsa \
    libnotify-bin \
    xdotool

# Allow non-console users to run Xorg
mkdir -p /etc/X11
cat << 'XW' > /etc/X11/Xwrapper.config
allowed_users=anybody
needs_root_rights=yes
XW

# Add user to hardware video and render acceleration groups
groupadd -f render
usermod -a -G render,video,audio,input,tty,dialout liteuser

# Ensure OpenRC remains the exclusive PID 1 init system (purge hijacked systemd-sysv)
dpkg --purge --force-depends systemd-sysv 2>/dev/null || true
ln -sf openrc-init /sbin/init

# Clean apt caches
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

chmod +x "$ROOTFS_DIR/tmp/install_desktop.sh"
chroot "$ROOTFS_DIR" /tmp/install_desktop.sh
rm -f "$ROOTFS_DIR/tmp/install_desktop.sh" "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# 4. Deploy Custom Binaries to /usr/local/bin
echo "[*] Deploying Lite Office desktop helper tools..."
mkdir -p "$ROOTFS_DIR/usr/local/bin"
cp "$PROJECT_ROOT/desktop/bin/lite-logout" "$ROOTFS_DIR/usr/local/bin/lite-logout"
cp "$PROJECT_ROOT/desktop/bin/lite-launch-office" "$ROOTFS_DIR/usr/local/bin/lite-launch-office"
cp "$PROJECT_ROOT/desktop/bin/lite-launch-spreadsheet" "$ROOTFS_DIR/usr/local/bin/lite-launch-spreadsheet"
cp "$PROJECT_ROOT/desktop/bin/lite-info" "$ROOTFS_DIR/usr/local/bin/lite-info"
chmod +x "$ROOTFS_DIR/usr/local/bin"/{lite-logout,lite-launch-office,lite-launch-spreadsheet,lite-info}

# 5. Deploy Openbox Configuration
echo "[*] Configuring Openbox window manager..."
mkdir -p "$ROOTFS_DIR/etc/xdg/openbox"
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$ROOTFS_DIR/etc/xdg/openbox/rc.xml"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$ROOTFS_DIR/etc/xdg/openbox/menu.xml"
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$ROOTFS_DIR/etc/xdg/openbox/autostart"
chmod +x "$ROOTFS_DIR/etc/xdg/openbox/autostart"

# 6. Deploy Tint2 Configuration
echo "[*] Configuring Tint2 modern panel..."
mkdir -p "$ROOTFS_DIR/etc/xdg/tint2"
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$ROOTFS_DIR/etc/xdg/tint2/tint2rc"

# Deploy Start Menu desktop file
mkdir -p "$ROOTFS_DIR/usr/share/applications"
cp "$PROJECT_ROOT/desktop/assets/lite-start-menu.desktop" "$ROOTFS_DIR/usr/share/applications/lite-start-menu.desktop"

# 7. Configure User Environment for 'liteuser'
echo "[*] Configuring user profile and desktop environment for 'liteuser'..."
USER_HOME="$ROOTFS_DIR/home/liteuser"
mkdir -p "$USER_HOME"/{Desktop,Documents,Downloads,Pictures,.config/openbox,.config/tint2,.config/pcmanfm/default}

# Openbox user configs
cp "$PROJECT_ROOT/desktop/openbox/rc.xml" "$USER_HOME/.config/openbox/rc.xml"
cp "$PROJECT_ROOT/desktop/openbox/menu.xml" "$USER_HOME/.config/openbox/menu.xml"
cp "$PROJECT_ROOT/desktop/openbox/autostart" "$USER_HOME/.config/openbox/autostart"
chmod +x "$USER_HOME/.config/openbox/autostart"

# Tint2 user configs
cp "$PROJECT_ROOT/desktop/tint2/tint2rc" "$USER_HOME/.config/tint2/tint2rc"

# PCManFM user configs
cp "$PROJECT_ROOT/desktop/pcmanfm/pcmanfm.conf" "$USER_HOME/.config/pcmanfm/default/pcmanfm.conf"
cp "$PROJECT_ROOT/desktop/pcmanfm/desktop-items-0.conf" "$USER_HOME/.config/pcmanfm/default/desktop-items-0.conf"

# Desktop Shortcuts
cp "$PROJECT_ROOT/desktop/assets/Word-Processor.desktop" "$USER_HOME/Desktop/"
cp "$PROJECT_ROOT/desktop/assets/Spreadsheet.desktop" "$USER_HOME/Desktop/"
cp "$PROJECT_ROOT/desktop/assets/File-Manager.desktop" "$USER_HOME/Desktop/"
cp "$PROJECT_ROOT/desktop/assets/Terminal.desktop" "$USER_HOME/Desktop/"
chmod +x "$USER_HOME"/Desktop/*.desktop

# User .xinitrc
cat << 'EOF' > "$USER_HOME/.xinitrc"
#!/bin/sh
# Lite Office OS X11 Client Startup
if [ -f "$HOME/.Xresources" ]; then
    xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fi

# Ensure user session bus is active
if which dbus-launch >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session openbox-session
elif which dbus-daemon >/dev/null 2>&1 && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval $(dbus-daemon --session --fork --print-address --print-pid 2>/dev/null) || true
    exec openbox-session
else
    exec openbox-session
fi
EOF
chmod +x "$USER_HOME/.xinitrc"

# User .profile (autostart X on tty1)
cat << 'EOF' > "$USER_HOME/.profile"
# Lite Office OS User Profile
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

# Automatic graphical login on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx > "$HOME/startx.log" 2>&1
fi
EOF

# 8. Configure OpenRC agetty.tty1 for Autologin
echo "[*] Configuring OpenRC automatic console login on tty1..."
mkdir -p "$ROOTFS_DIR/etc/conf.d"
cat << 'EOF' > "$ROOTFS_DIR/etc/conf.d/agetty.tty1"
# Lite Office OS tty1 Console Configuration
agetty_options="--autologin liteuser --noclear"
term_type="linux"
EOF

# Fix permissions
chroot "$ROOTFS_DIR" chown -R liteuser:liteuser /home/liteuser

# Clean up mounts
cleanup
trap - EXIT

echo -e "${BLUE}==============================================================================${NC}"
ROOTFS_SIZE=$(du -sh "$ROOTFS_DIR" | cut -f1)
echo -e "${GREEN}[V] STAGE 4 GRAPHICAL DESKTOP STACK INSTALLED SUCCESSFULLY!${NC}"
echo -e "Rootfs Size: ${ROOTFS_SIZE}"
echo -e "${BLUE}==============================================================================${NC}"
