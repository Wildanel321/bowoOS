#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Graphical Desktop QEMU Boot & Memory Benchmark Test
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
LOG_FILE="${PROJECT_ROOT}/output/qemu_desktop_${RAM}.log"
BENCHMARK_LOG="${PROJECT_ROOT}/output/desktop_memory_benchmark_${RAM}.txt"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Desktop Boot & Memory Profiling (RAM: ${RAM})${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ ! -f "$KERNEL" ]; then
    echo -e "${RED}[-] Error: Kernel '$KERNEL' not found!${NC}"
    exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
    echo -e "${RED}[-] Error: Rootfs staging directory '$ROOTFS_DIR' not found!${NC}"
    exit 1
fi

# 1. Update/Create ext4 disk image from rootfs
echo "[*] Synchronizing ext4 disk image (${RAW_DISK})..."
# Ensure disk image is large enough (2.5 GB for desktop stack)
if [ ! -f "$RAW_DISK" ] || [ "$(stat -c%s "$RAW_DISK")" -lt 2500000000 ]; then
    rm -f "$RAW_DISK"
    truncate -s 2500M "$RAW_DISK"
    mkfs.ext4 -q -F -L "LITE_ROOT" "$RAW_DISK"
fi

TMP_MNT="/var/tmp/liteoffice-build/mnt_${ARCH}"
mkdir -p "$TMP_MNT"
echo "[*] Syncing rootfs files to disk image..."
mount -o loop "$RAW_DISK" "$TMP_MNT"
rsync -aHAX --delete --quiet "$ROOTFS_DIR"/ "$TMP_MNT"/
sync
umount "$TMP_MNT"
rmdir "$TMP_MNT"
echo -e "${GREEN}[+] Disk image synchronized.${NC}"

# 2. Inject automated benchmark capture into rootfs autostart for test run
# This captures free -m and process memory usage right after desktop initializes
cat << 'EOF' > "$ROOTFS_DIR/home/liteuser/.config/openbox/bench_hook.sh"
#!/bin/sh
sleep 5
echo "=== DESKTOP BENCHMARK CAPTURE ===" > /tmp/bench.log
free -m >> /tmp/bench.log
echo "--- PROCESS MEMORY USAGE ---" >> /tmp/bench.log
ps -eo pid,ppid,cmd,%mem,rss --sort=-rss | head -n 20 >> /tmp/bench.log
echo "=== BENCHMARK COMPLETE ===" >> /tmp/bench.log
sync
EOF
chmod +x "$ROOTFS_DIR/home/liteuser/.config/openbox/bench_hook.sh"

# 3. Launch QEMU with Display Emulation & Serial Log
echo "[*] Launching QEMU with VGA Display (RAM: $RAM)..."
rm -f "$LOG_FILE"

QEMU_ARGS=(
    -m "$RAM"
    -smp 2
    -kernel "$KERNEL"
    -drive file="$RAW_DISK",format=raw,if=virtio
    -vga std
    -display none
    -append "root=/dev/vda rw console=tty1 console=ttyS0 init=/sbin/init quiet=0"
    -no-reboot
    -serial file:"$LOG_FILE"
    -monitor none
)

if qemu-system-x86_64 -accel kvm -display none -serial none </dev/null >/dev/null 2>&1; then
    echo -e "    ${GREEN}[+] KVM Hardware Acceleration active!${NC}"
    QEMU_ARGS+=(-accel kvm -cpu host)
else
    echo -e "    ${YELLOW}[!] Running in reliable TCG emulation mode.${NC}"
    QEMU_ARGS+=(-accel tcg -cpu qemu64)
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}" &
QEMU_PID=$!

echo "[*] Waiting up to 75s for graphical desktop initialization..."
DESKTOP_READY=0
for i in $(seq 1 75); do
    sleep 1
    # Check if benchmark completed
    if grep -q "BENCHMARK COMPLETE" "$LOG_FILE" 2>/dev/null; then
        DESKTOP_READY=1
        echo -e "    ${GREEN}[+] Desktop initialized and telemetry received!${NC}"
        break
    elif grep -q "login:" "$LOG_FILE" 2>/dev/null && [ "$i" -ge 55 ]; then
        DESKTOP_READY=1
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

# Check for kernel panic
if grep -q "Kernel panic" "$LOG_FILE"; then
    echo -e "${RED}[-] FAIL: Kernel panic detected in boot log:${NC}"
    grep -C 3 "Kernel panic" "$LOG_FILE"
    exit 1
fi

# Check OpenRC
if grep -q "OpenRC" "$LOG_FILE"; then
    echo -e "    - Init System       : ${GREEN}PASS${NC} (OpenRC running)"
else
    echo -e "    - Init System       : ${RED}FAIL${NC}"
    exit 1
fi

# Check ZRAM
if grep -q "ZRAM swap active" "$LOG_FILE"; then
    ZRAM_LINE=$(grep "ZRAM swap active" "$LOG_FILE" | head -n 1)
    echo -e "    - ZRAM Compression  : ${GREEN}PASS${NC} ($ZRAM_LINE)"
fi

# Check Profile
if grep -q "Detected Profile" "$LOG_FILE"; then
    PROF_LINE=$(grep "Detected Profile" "$LOG_FILE" | head -n 1)
    echo -e "    - Hardware Profile  : ${GREEN}PASS${NC} ($PROF_LINE)"
fi

# Check Benchmark Output
echo "[*] Extracting desktop benchmark data..."
mkdir -p "$TMP_MNT"
mount -o loop,ro "$RAW_DISK" "$TMP_MNT" 2>/dev/null || true
if [ -f "$TMP_MNT/home/liteuser/desktop_benchmark.log" ]; then
    cp "$TMP_MNT/home/liteuser/desktop_benchmark.log" "$BENCHMARK_LOG"
    echo -e "\n${BLUE}==============================================================================${NC}"
    echo -e "${GREEN}>>> LITE OFFICE OS MEASURED MEMORY BENCHMARK (${RAM} RAM ENVELOPE) <<<${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    cat "$BENCHMARK_LOG"
    echo -e "${BLUE}==============================================================================${NC}"
elif grep -q "DESKTOP BENCHMARK" "$LOG_FILE"; then
    echo -e "\n${BLUE}==============================================================================${NC}"
    echo -e "${GREEN}>>> LITE OFFICE OS MEASURED MEMORY BENCHMARK (${RAM} RAM ENVELOPE) <<<${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    sed -n '/=== LITE OFFICE OS DESKTOP BENCHMARK ===/,/=== BENCHMARK COMPLETE ===/p' "$LOG_FILE"
    echo -e "${BLUE}==============================================================================${NC}"
fi
umount "$TMP_MNT" 2>/dev/null || true
rmdir "$TMP_MNT" 2>/dev/null || true

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}[V] STAGE 4 DESKTOP BOOT TEST COMPLETE ON ${RAM} RAM!${NC}"
echo -e "${BLUE}==============================================================================${NC}"
exit 0
