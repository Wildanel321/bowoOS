#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Stage 3: Base Root Filesystem Construction Engine
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
DEBIAN_ARCH="amd64"
SUITE="bookworm"
MIRROR="http://deb.debian.org/debian"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            if [ "$ARCH" = "i686" ]; then
                DEBIAN_ARCH="i386"
            else
                DEBIAN_ARCH="amd64"
            fi
            shift 2
            ;;
        --suite)
            SUITE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Assembling Base Root Filesystem (${ARCH} / ${SUITE})${NC}"
echo -e "${BLUE}==============================================================================${NC}"

BUILD_DIR="/var/tmp/liteoffice-build"
ROOTFS_DIR="$BUILD_DIR/rootfs_${ARCH}"
OUTPUT_DIR="$PROJECT_ROOT/output"
mkdir -p "$OUTPUT_DIR"

# Ensure script is running with superuser privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}[!] Escalating to root privileges using sudo...${NC}"
    exec sudo bash "$0" --arch "$ARCH" --suite "$SUITE"
fi

# 1. Debootstrap Minimal Base System
if [ ! -f "$ROOTFS_DIR/bin/sh" ]; then
    echo -e "[*] Bootstrapping clean minimal system (${SUITE} ${DEBIAN_ARCH}) via debootstrap..."
    rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    debootstrap --arch="$DEBIAN_ARCH" --variant=minbase "$SUITE" "$ROOTFS_DIR" "$MIRROR"
else
    echo -e "[*] Existing rootfs base detected at ${GREEN}${ROOTFS_DIR}${NC}"
fi

# 2. Configure Apt Sources inside Rootfs
cat << EOF > "$ROOTFS_DIR/etc/apt/sources.list"
deb ${MIRROR} ${SUITE} main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free non-free-firmware
deb ${MIRROR} ${SUITE}-updates main contrib non-free non-free-firmware
EOF

# 3. Mount virtual filesystems for chroot operations
echo "[*] Mounting virtual filesystems into rootfs staging..."
mount -t proc none "$ROOTFS_DIR/proc" 2>/dev/null || true
mount -t sysfs none "$ROOTFS_DIR/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS_DIR/dev" 2>/dev/null || true
mount -t devpts none "$ROOTFS_DIR/dev/pts" 2>/dev/null || true

cleanup() {
    echo "[*] Unmounting virtual filesystems..."
    umount "$ROOTFS_DIR/dev/pts" 2>/dev/null || true
    umount "$ROOTFS_DIR/dev" 2>/dev/null || true
    umount "$ROOTFS_DIR/sys" 2>/dev/null || true
    umount "$ROOTFS_DIR/proc" 2>/dev/null || true
}
trap cleanup EXIT

# 4. Install Core Packages & OpenRC
echo -e "[*] Installing OpenRC, device management, and lightweight core utilities..."

# Prevent daemons from starting inside chroot
cat << 'EOF' > "$ROOTFS_DIR/usr/sbin/policy-rc.d"
#!/bin/sh
exit 101
EOF
chmod +x "$ROOTFS_DIR/usr/sbin/policy-rc.d"

cat << 'EOF' > "$ROOTFS_DIR/tmp/setup_base.sh"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update

# Install OpenRC, SysVInit tools, udev, networking, sudo, earlyoom, and system tools
apt-get install -y --no-install-recommends \
    openrc \
    sysvinit-utils \
    udev \
    kmod \
    iproute2 \
    isc-dhcp-client \
    sudo \
    earlyoom \
    procps \
    psmisc \
    pciutils \
    usbutils \
    nano \
    less \
    parted \
    dosfstools \
    rsync \
    htop

# Ensure essential groups exist
for grp in sudo video audio plugdev input netdev dialout render tty lp lpadmin; do
    groupadd -f "$grp"
done

# Create default unprivileged desktop user 'liteuser'
if ! id liteuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash -G sudo,video,audio,plugdev,input,netdev,dialout,render,tty,lp,lpadmin liteuser
    echo "liteuser:liteuser" | chpasswd
    echo "root:liteoffice" | chpasswd
    echo "liteuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-liteuser
    chmod 0440 /etc/sudoers.d/99-liteuser
fi

# Clean up apt caches to save space
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/*
EOF

chmod +x "$ROOTFS_DIR/tmp/setup_base.sh"
chroot "$ROOTFS_DIR" /tmp/setup_base.sh
rm -f "$ROOTFS_DIR/tmp/setup_base.sh" "$ROOTFS_DIR/usr/sbin/policy-rc.d"

# 5. Apply Base Skeleton Configuration
echo "[*] Injecting Lite Office OS base skeleton configurations..."
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/inittab" "$ROOTFS_DIR/etc/inittab"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/rc.conf" "$ROOTFS_DIR/etc/rc.conf"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/fstab" "$ROOTFS_DIR/etc/fstab"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/hostname" "$ROOTFS_DIR/etc/hostname"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/hosts" "$ROOTFS_DIR/etc/hosts"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/issue" "$ROOTFS_DIR/etc/issue"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/issue" "$ROOTFS_DIR/etc/issue.net"

mkdir -p "$ROOTFS_DIR/etc/sysctl.d"
cp "$PROJECT_ROOT/rootfs/base_skeleton/etc/sysctl.d/99-lowmem.conf" "$ROOTFS_DIR/etc/sysctl.d/99-lowmem.conf"

# 6. Install Custom OpenRC Services
echo "[*] Installing custom OpenRC low-memory services..."
mkdir -p "$ROOTFS_DIR/etc/init.d"
cp "$PROJECT_ROOT/init/init.d/udev" "$ROOTFS_DIR/etc/init.d/udev"
cp "$PROJECT_ROOT/init/init.d/zram-swap" "$ROOTFS_DIR/etc/init.d/zram-swap"
cp "$PROJECT_ROOT/init/init.d/lite-profile-detect" "$ROOTFS_DIR/etc/init.d/lite-profile-detect"
cp "$PROJECT_ROOT/init/init.d/lite-oom" "$ROOTFS_DIR/etc/init.d/lite-oom"
chmod +x "$ROOTFS_DIR/etc/init.d"/{udev,zram-swap,lite-profile-detect,lite-oom}

# 7. Configure OpenRC Runlevels inside Chroot
echo "[*] Registering services into OpenRC runlevels..."
chroot "$ROOTFS_DIR" bash -c "
    ln -sf agetty /etc/init.d/agetty.tty1
    ln -sf agetty /etc/init.d/agetty.ttyS0
    rc-update add agetty.tty1 default 2>/dev/null || true
    rc-update add agetty.ttyS0 default 2>/dev/null || true
    rc-update add udev sysinit 2>/dev/null || true
    rc-update add udev-trigger sysinit 2>/dev/null || true
    rc-update add zram-swap boot 2>/dev/null || true
    rc-update add lite-profile-detect default 2>/dev/null || true
    rc-update add lite-oom default 2>/dev/null || true

    # Clean up broken Debian SysVinit services with non-existent dependencies
    rc-update del pulseaudio-enable-autospawn default 2>/dev/null || true
    rc-update del plymouth default 2>/dev/null || true
    rc-update del plymouth-log default 2>/dev/null || true
    rc-update del hwclock.sh default 2>/dev/null || true
    [ -f /etc/init.d/procps ] && sed -i 's/Required-Start: mountkernfs/Required-Start:/g' /etc/init.d/procps
    [ -f /etc/init.d/alsa-utils ] && sed -i '/case \"\$1\" in/a \    [ ! -f /proc/asound/cards ] || ! grep -q \"[0-9]\" /proc/asound/cards && exit 0' /etc/init.d/alsa-utils || true
"

# 8. Copy Custom Kernel Modules
MODULES_DIR="$BUILD_DIR/modules_staging_${ARCH}/lib/modules"
if [ -d "$MODULES_DIR" ]; then
    echo -e "[*] Injecting custom compiled kernel modules from ${MODULES_DIR}..."
    mkdir -p "$ROOTFS_DIR/lib/modules"
    cp -r "$MODULES_DIR"/* "$ROOTFS_DIR/lib/modules/"
    # Run depmod
    KERNEL_RELEASE=$(ls "$ROOTFS_DIR/lib/modules" | head -n 1 || echo "")
    if [ -n "$KERNEL_RELEASE" ]; then
        chroot "$ROOTFS_DIR" depmod -a "$KERNEL_RELEASE" 2>/dev/null || true
        echo -e "    ${GREEN}[+] depmod generated for kernel release: ${KERNEL_RELEASE}${NC}"
    fi
fi

# 9. Cleanly unmount virtual filesystems before finishing
cleanup
trap - EXIT

# Ensure /bin/init symlink exists pointing to /sbin/init
if [ ! -e "$ROOTFS_DIR/sbin/init" ]; then
    ln -sf openrc-init "$ROOTFS_DIR/sbin/init" 2>/dev/null || ln -sf /sbin/openrc-init "$ROOTFS_DIR/sbin/init"
fi

echo -e "${BLUE}==============================================================================${NC}"
ROOTFS_SIZE=$(du -sh "$ROOTFS_DIR" | cut -f1)
echo -e "${GREEN}[V] BASE ROOT FILESYSTEM ASSEMBLED SUCCESSFULLY!${NC}"
echo -e "Location: ${ROOTFS_DIR} (Total Size: ${ROOTFS_SIZE})"
echo -e "${BLUE}==============================================================================${NC}"
