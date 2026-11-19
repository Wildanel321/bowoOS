#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Early Userspace Initramfs Generator
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCH="${1:-x86_64}"
OUTPUT_DIR="${2:-$PROJECT_ROOT/output}"
OUTPUT_IMG="$OUTPUT_DIR/initramfs-${ARCH}.img"

WORK_DIR="/var/tmp/liteoffice-build/initramfs-${ARCH}"
mkdir -p "$OUTPUT_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{bin,sbin,usr/bin,usr/sbin,dev,proc,sys,run,mnt,newroot,etc}

echo "[*] Constructing BusyBox initramfs for $ARCH..."

# 1. Install Static BusyBox
if ! command -v busybox >/dev/null 2>&1; then
    echo "[-] Error: 'busybox' binary not found. Please install busybox-static."
    exit 1
fi

BUSYBOX_BIN=$(which busybox)
cp "$BUSYBOX_BIN" "$WORK_DIR/bin/busybox"
chmod +x "$WORK_DIR/bin/busybox"

# 2. Populate clean relative symlinks via busybox
(
    cd "$WORK_DIR/bin"
    for applet in $(./busybox --list); do
        if [ "$applet" != "busybox" ]; then
            ln -sf busybox "$applet"
        fi
    done
)

# Symlink core sbin tools to busybox
(
    cd "$WORK_DIR/sbin"
    for applet in init reboot poweroff halt switch_root mdev; do
        ln -sf ../bin/busybox "$applet"
    done
)

# 3. Create device nodes fallback
mknod -m 600 "$WORK_DIR/dev/console" c 5 1 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/null" c 1 3 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/zero" c 1 5 2>/dev/null || true
mknod -m 666 "$WORK_DIR/dev/tty" c 5 0 2>/dev/null || true
mknod -m 620 "$WORK_DIR/dev/tty1" c 4 1 2>/dev/null || true

# 4. Create robust /init script
cat << 'EOF' > "$WORK_DIR/init"
#!/bin/sh
# ==============================================================================
# Lite Office OS — Early Stage /init
# ==============================================================================
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
export HOME=/root

# Mount fundamental virtual filesystems
mount -t devtmpfs devtmpfs /dev 2>/dev/null || {
    mount -t tmpfs dev /dev
    mdev -s
}
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t tmpfs -o mode=0755,nodev,nosuid tmpfs /run

# Clear screen if not in quiet mode
clear 2>/dev/null || true

echo "=================================================================="
echo "         _     _ _         ____   __  __ _            ____   ____ "
echo "        | |   (_) |_ ___  / ___| / _|/ _(_) ___ ___  / __ \ / ___|"
echo "        | |   | | __/ _ \ \___ \| |_| |_| |/ __/ _ \| |  | |\___ \ "
echo "        | |___| | ||  __/  ___) |  _|  _| | (_|  __/| |__| | ___) |"
echo "        |_____|_|\__\___| |____/|_| |_| |_|\___\___(_)____(_)____/ "
echo "=================================================================="
echo " Lite Office OS — Early Userspace Bootloader"
echo " Kernel Release : $(uname -r)"
echo " Detected Memory: $(awk '/MemTotal/ {printf "%.1f MB", $2/1024}' /proc/meminfo)"
echo " Detected Cores : $(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)"
echo " Boot Time (sec): $(awk '{print $1}' /proc/uptime)"
echo "=================================================================="

# Parse kernel command line parameters
ROOT_DEV=""
INIT_BIN="/sbin/init"
BREAK_FLAG=0
LIVE_BOOT=0

for param in $(cat /proc/cmdline); do
    case "$param" in
        boot=live|root=live|live)
            LIVE_BOOT=1
            ;;
        root=*)
            ROOT_DEV="${param#root=}"
            ;;
        init=*)
            INIT_BIN="${param#init=}"
            ;;
        break|break=*)
            BREAK_FLAG=1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Live ISO Boot Mode (SquashFS + Tmpfs Overlay)
# ------------------------------------------------------------------------------
if [ "$LIVE_BOOT" -eq 1 ] || [ "$ROOT_DEV" = "live" ]; then
    echo "[*] Searching for LiteOffice OS live boot media..."
    mkdir -p /cdrom /rofs /cow /newroot
    LIVE_DEV=""

    # Try finding device by volume label first
    LIVE_DEV=$(findfs LABEL="LITEOFFICE_LIVE" 2>/dev/null || blkid -L "LITEOFFICE_LIVE" 2>/dev/null || echo "")

    # Fallback: scan all block devices for /live/filesystem.squashfs
    if [ -z "$LIVE_DEV" ]; then
        for i in 1 2 3 4 5; do
            for dev in /dev/sr* /dev/vd* /dev/sd*; do
                if [ -b "$dev" ]; then
                    mount -o ro "$dev" /cdrom 2>/dev/null || true
                    if [ -f "/cdrom/live/filesystem.squashfs" ]; then
                        LIVE_DEV="$dev"
                        break 2
                    fi
                    umount /cdrom 2>/dev/null || true
                fi
            done
            sleep 1
        done
    else
        mount -o ro "$LIVE_DEV" /cdrom 2>/dev/null || true
    fi

    if [ -f "/cdrom/live/filesystem.squashfs" ]; then
        echo "[+] Found Live media at $LIVE_DEV. Mounting compressed rootfs..."
        mount -t squashfs -o loop /cdrom/live/filesystem.squashfs /rofs
        
        # Setup tmpfs overlay for read-write live session in memory
        mount -t tmpfs -o mode=0755 tmpfs /cow
        mkdir -p /cow/upper /cow/work
        mount -t overlay overlay -o lowerdir=/rofs,upperdir=/cow/upper,workdir=/cow/work /newroot
        
        # Make rootfs available for installer rsync
        mkdir -p /newroot/run/live/rootfs
        mount --bind /rofs /newroot/run/live/rootfs 2>/dev/null || true
        
        echo "[+] Transitioning to Live LiteOffice OS session..."
        umount /run /sys /proc 2>/dev/null || true
        exec switch_root /newroot "$INIT_BIN"
    else
        echo "[-] ERROR: /live/filesystem.squashfs not found on live boot media!"
        exec /bin/sh </dev/console >/dev/console 2>&1
    fi
fi

# ------------------------------------------------------------------------------
# Direct Block Device Root Boot Mode
# ------------------------------------------------------------------------------

# If break is requested or no root specified, drop to recovery/test shell
if [ "$BREAK_FLAG" -eq 1 ] || [ -z "$ROOT_DEV" ]; then
    echo "[!] No root device specified or break requested."
    echo "[*] Early kernel and userspace initramfs verification PASSED."
    echo "[*] Starting interactive maintenance shell (type 'poweroff' to exit):"
    echo ""
    # Start shell on controlling tty
    exec /bin/sh </dev/console >/dev/console 2>&1
fi

echo "[*] Locating root filesystem: $ROOT_DEV ..."
# Resolve LABEL= or UUID=
case "$ROOT_DEV" in
    LABEL=*)
        TARGET_LABEL="${ROOT_DEV#LABEL=}"
        RESOLVED_DEV=$(findfs LABEL="$TARGET_LABEL" 2>/dev/null || blkid -L "$TARGET_LABEL" 2>/dev/null || true)
        ;;
    UUID=*)
        TARGET_UUID="${ROOT_DEV#UUID=}"
        RESOLVED_DEV=$(findfs UUID="$TARGET_UUID" 2>/dev/null || blkid -U "$TARGET_UUID" 2>/dev/null || true)
        ;;
    *)
        RESOLVED_DEV="$ROOT_DEV"
        ;;
esac

# Wait up to 10 seconds for root device to appear (USB settling)
WAIT_SEC=10
while [ -z "$RESOLVED_DEV" ] || [ ! -b "$RESOLVED_DEV" ]; do
    if [ "$WAIT_SEC" -le 0 ]; then
        echo "[-] ERROR: Root filesystem '$ROOT_DEV' not found after 10s!"
        echo "[*] Dropping to emergency shell:"
        exec /bin/sh </dev/console >/dev/console 2>&1
    fi
    echo "[-] Waiting for storage device $ROOT_DEV ($WAIT_SEC s)..."
    sleep 1
    WAIT_SEC=$((WAIT_SEC - 1))
    case "$ROOT_DEV" in
        LABEL=*) RESOLVED_DEV=$(findfs LABEL="$TARGET_LABEL" 2>/dev/null || blkid -L "$TARGET_LABEL" 2>/dev/null || true) ;;
        UUID=*)  RESOLVED_DEV=$(findfs UUID="$TARGET_UUID" 2>/dev/null || blkid -U "$TARGET_UUID" 2>/dev/null || true) ;;
    esac
done

echo "[+] Found root device at $RESOLVED_DEV. Mounting to /newroot..."
mkdir -p /newroot
mount -o ro "$RESOLVED_DEV" /newroot

if [ ! -x "/newroot$INIT_BIN" ]; then
    echo "[-] ERROR: Init binary /newroot$INIT_BIN not found or not executable!"
    exec /bin/sh </dev/console >/dev/console 2>&1
fi

echo "[+] Transitioning to root filesystem via switch_root..."
umount /run /sys /proc 2>/dev/null || true
exec switch_root /newroot "$INIT_BIN"
EOF

chmod +x "$WORK_DIR/init"

# 5. Pack cpio.gz archive
echo "[*] Packing initramfs cpio.gz into $OUTPUT_IMG..."
(
    cd "$WORK_DIR"
    find . -print0 | cpio --null -ov --format=newc | gzip -9 > "$OUTPUT_IMG"
)

IMG_SIZE=$(du -h "$OUTPUT_IMG" | cut -f1)
echo "[V] Initramfs generated successfully: $OUTPUT_IMG (Size: $IMG_SIZE)"
