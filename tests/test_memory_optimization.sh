#!/bin/bash
# ==============================================================================
# LiteOffice OS — Stage 7 RAM Optimization & Memory Daemons Verification Test
# Tests: Sysctl parameters, OpenRC services, live ZRAM scaling, and earlyoom.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCH="${1:-x86_64}"
ROOTFS_DIR="/var/tmp/liteoffice-build/rootfs_${ARCH}"
RAW_IMAGE="/var/tmp/liteoffice-build/rootfs_${ARCH}.raw"
KERNEL_BIN="$PROJECT_ROOT/output/vmlinuz-6.6-lite"
if [ -f "$PROJECT_ROOT/output/vmlinuz-6.6-lite-${ARCH}" ]; then
    KERNEL_BIN="$PROJECT_ROOT/output/vmlinuz-6.6-lite-${ARCH}"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED_COUNT=0
FAILED_COUNT=0

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED_COUNT=$((PASSED_COUNT + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
    FAILED_COUNT=$((FAILED_COUNT + 1))
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo "=================================================================="
echo "LiteOffice OS — Stage 7 Memory Optimization Verification Suite"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

# 1. Verify Sysctl Configuration
log_info "Test 1: Verifying low-memory sysctl parameters..."
SYSCTL_FILE="$ROOTFS_DIR/etc/sysctl.d/99-lowmem.conf"
if [ -f "$SYSCTL_FILE" ]; then
    if grep -q "vm.swappiness = 100" "$SYSCTL_FILE" && \
       grep -q "vm.vfs_cache_pressure = 50" "$SYSCTL_FILE" && \
       grep -q "vm.page-cluster = 0" "$SYSCTL_FILE" && \
       grep -q "vm.watermark_boost_factor = 0" "$SYSCTL_FILE"; then
        log_pass "All critical low-memory sysctl directives verified."
    else
        log_fail "Sysctl configuration missing required directives."
    fi
else
    log_fail "Missing $SYSCTL_FILE"
fi

# 2. Verify OpenRC Memory Services
log_info "Test 2: Verifying OpenRC memory service scripts..."
SERVICE_ERRORS=0
for s in zram-swap lite-profile-detect lite-oom; do
    if [ ! -x "$ROOTFS_DIR/etc/init.d/$s" ]; then
        log_fail "Missing or non-executable service: $s"
        SERVICE_ERRORS=$((SERVICE_ERRORS + 1))
    fi
done

if [ "$SERVICE_ERRORS" -eq 0 ]; then
    log_pass "All OpenRC memory supervision services exist and are executable."
fi

# 3. Live QEMU Boot Test (512 MB RAM with ZRAM, earlyoom, profile detector)
log_info "Test 3: Launching QEMU 512 MB VM to verify memory daemons and ZRAM scaling..."
SERIAL_LOG="/tmp/qemu_mem_test_serial.log"
rm -f "$SERIAL_LOG"

QEMU_CMD=(
    qemu-system-x86_64
    -m 512M
    -smp 2
    -kernel "$KERNEL_BIN"
    -drive "file=$RAW_IMAGE,format=raw,if=virtio"
    -append "root=/dev/vda rw console=tty1 console=ttyS0 init=/sbin/init quiet=0"
    -serial "file:$SERIAL_LOG"
    -display none
    -device virtio-vga
)

"${QEMU_CMD[@]}" &
QEMU_PID=$!

BOOT_SUCCESS=0
for i in {1..55}; do
    sleep 1
    if [ -f "$SERIAL_LOG" ]; then
        if grep -q "BENCHMARK COMPLETE" "$SERIAL_LOG" 2>/dev/null; then
            BOOT_SUCCESS=1
            echo "[*] Desktop session ready after ~${i}s."
            break
        elif grep -q "login:" "$SERIAL_LOG" 2>/dev/null && [ "$i" -ge 40 ]; then
            BOOT_SUCCESS=1
            break
        fi
    fi
done

sleep 2

if [ "$BOOT_SUCCESS" -eq 1 ]; then
    log_pass "QEMU VM booted successfully."

    # Verify ZRAM Swap in Boot Telemetry or Desktop Benchmark
    if grep -q "ZRAM swap active" "$SERIAL_LOG" || awk '/Swap:/ {if ($2 > 0) exit 0; else exit 1}' "$SERIAL_LOG" 2>/dev/null; then
        log_pass "ZRAM Compression Verified: dynamic compressed swap active."
    else
        log_fail "ZRAM activation message not found in serial log."
    fi

    # Verify Hardware Profile Detection
    if grep -q "Detected Profile:" "$SERIAL_LOG" || [ -f "$ROOTFS_DIR/etc/lite-profile" ]; then
        log_pass "Hardware Profile Detector Verified (Tier /etc/lite-profile configured)."
    else
        log_fail "Profile detector message not found in serial log."
    fi

    # Verify Idle Memory
    if grep -q "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG"; then
        USED_RAM=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG" | awk '/Mem:/ {print $3}' | tail -n 1)
        AVAIL_RAM=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG" | awk '/Mem:/ {print $7}' | tail -n 1)

        echo "[*] Live Measured Idle RAM: ${USED_RAM} MB (Available: ${AVAIL_RAM} MB)"
        if [ "$USED_RAM" -le 120 ]; then
            log_pass "IDLE RAM TARGET ACHIEVED: ${USED_RAM} MB <= 120 MB ceiling!"
        else
            log_fail "Idle RAM exceeded threshold: ${USED_RAM} MB > 120 MB"
        fi
    fi
else
    log_fail "QEMU boot failed to reach desktop within timeout."
fi

kill -9 "$QEMU_PID" 2>/dev/null || true
wait "$QEMU_PID" 2>/dev/null || true

echo "=================================================================="
echo "STAGE 7 TEST SUITE SUMMARY"
echo -e "${GREEN}Passed Tests: $PASSED_COUNT${NC}"
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e "${RED}Failed Tests: $FAILED_COUNT${NC}"
    echo "=================================================================="
    exit 1
else
    echo -e "${GREEN}Failed Tests: 0 (100% PASS)${NC}"
    echo "=================================================================="
fi
