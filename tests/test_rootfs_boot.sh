#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Root Filesystem QEMU Boot Verification Test
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARCH="${1:-x86_64}"
RAM="${2:-512M}"
KERNEL="${PROJECT_ROOT}/output/vmlinuz-6.6-lite"
ROOTFS_DIR="/var/tmp/liteoffice-build/rootfs_${ARCH}"
RAW_DISK="/var/tmp/liteoffice-build/rootfs_${ARCH}.raw"
LOG_FILE="${PROJECT_ROOT}/output/qemu_rootfs_${RAM}.log"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Rootfs Boot Verification (RAM: ${RAM})${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ ! -f "$KERNEL" ]; then
    echo -e "${RED}[-] Error: Kernel '$KERNEL' not found!${NC}"
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo -e "${RED}[-] Error: Rootfs staging directory '$ROOTFS_DIR' not found!${NC}"
    exit 1
fi

# 1. Create ext4 disk image from rootfs
echo "[*] Creating ext4 disk image (${RAW_DISK})..."
rm -f "$RAW_DISK"
# 1.5 GB raw image
truncate -s 1500M "$RAW_DISK"
mkfs.ext4 -q -F -L "LITE_ROOT" "$RAW_DISK"

TMP_MNT="/var/tmp/liteoffice-build/mnt_${ARCH}"
mkdir -p "$TMP_MNT"
echo "[*] Populating disk image with rootfs files..."
mount -o loop "$RAW_DISK" "$TMP_MNT"
rsync -aHAX --quiet "$ROOTFS_DIR"/ "$TMP_MNT"/
sync
umount "$TMP_MNT"
rmdir "$TMP_MNT"

echo -e "${GREEN}[+] Disk image prepared: ${RAW_DISK} (1.5 GB)${NC}"

# 2. Boot QEMU with 512 MB RAM
echo "[*] Launching QEMU headless (RAM: $RAM, VirtIO Storage)..."
rm -f "$LOG_FILE"

QEMU_ARGS=(
    -m "$RAM"
    -smp 2
    -kernel "$KERNEL"
    -drive file="$RAW_DISK",format=raw,if=virtio
    -append "root=/dev/vda rw console=ttyS0 init=/sbin/init quiet=0"
    -nographic
    -no-reboot
    -serial file:"$LOG_FILE"
    -monitor none
)

# Test if KVM actually works (not just character device presence)
if qemu-system-x86_64 -accel kvm -display none -serial none </dev/null >/dev/null 2>&1; then
    echo -e "    ${GREEN}[+] KVM Hardware Acceleration active!${NC}"
    QEMU_ARGS+=(-accel kvm -cpu host)
else
    echo -e "    ${YELLOW}[!] Running in reliable TCG emulation mode.${NC}"
    QEMU_ARGS+=(-accel tcg -cpu qemu64)
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}" &
QEMU_PID=$!

# Wait up to 40 seconds for login prompt in serial log
BOOTED=0
for i in $(seq 1 40); do
    sleep 1
    if grep -q "login:" "$LOG_FILE" 2>/dev/null; then
        BOOTED=1
        break
    fi
done

kill -9 "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

echo "[*] Analyzing system boot log..."
if [ ! -f "$LOG_FILE" ]; then
    echo -e "${RED}[-] FAIL: No log file generated.${NC}"
    exit 1
fi

# 1. Check for kernel panics
if grep -q "Kernel panic" "$LOG_FILE"; then
    echo -e "${RED}[-] FAIL: Kernel panic detected in boot log:${NC}"
    grep -C 3 "Kernel panic" "$LOG_FILE"
    exit 1
fi

# 2. Check for OpenRC startup
if grep -q "OpenRC" "$LOG_FILE"; then
    OPENRC_LINE=$(grep "OpenRC" "$LOG_FILE" | head -n 1)
    echo -e "    - Init System   : ${GREEN}PASS${NC} ($OPENRC_LINE)"
else
    echo -e "    - Init System   : ${RED}FAIL (OpenRC not detected)${NC}"
    cat "$LOG_FILE" | tail -n 25
    exit 1
fi

# 3. Check for ZRAM swap activation
if grep -q "ZRAM swap active" "$LOG_FILE" || grep -q "zram" "$LOG_FILE"; then
    ZRAM_LINE=$(grep -E "ZRAM swap active|zram: Added" "$LOG_FILE" | tail -n 1)
    echo -e "    - ZRAM Service  : ${GREEN}PASS${NC} ($ZRAM_LINE)"
fi

# 4. Check for login prompt
if grep -q "login:" "$LOG_FILE"; then
    LOGIN_LINE=$(grep "login:" "$LOG_FILE" | tail -n 1)
    echo -e "    - Login Prompt  : ${GREEN}PASS${NC} ($LOGIN_LINE)"
else
    echo -e "    - Login Prompt  : ${RED}FAIL (No login prompt observed)${NC}"
    echo "Last 30 lines of log:"
    tail -n 30 "$LOG_FILE"
    exit 1
fi

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}[V] STAGE 3 ROOT FILESYSTEM & OPENRC BOOT TEST PASSED ON ${RAM} RAM!${NC}"
echo -e "${BLUE}==============================================================================${NC}"
exit 0
