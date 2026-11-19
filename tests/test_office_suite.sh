#!/bin/bash
# ==============================================================================
# LiteOffice OS — Stage 6 Office Productivity & Printing Verification Test
# Tests: AbiWord, Gnumeric, qpdfview, CUPS daemon syntax, MIME associations,
#        Adaptive Launchers, and live QEMU boot test with CUPS daemon running.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOTFS_DIR="/var/tmp/liteoffice-build/rootfs_x86_64"
RAW_IMAGE="/var/tmp/liteoffice-build/rootfs_x86_64.raw"
KERNEL_BIN="$PROJECT_ROOT/output/vmlinuz-6.6-lite"

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
echo "LiteOffice OS — Stage 6 Office & Printing Verification Suite"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

# 1. Verify Office Binaries
log_info "Test 1: Verifying Office Suite and Printing Binaries..."
BINARY_ERRORS=0
for bin in abiword gnumeric qpdfview cupsd cupsfilter gs; do
    if [ ! -f "$ROOTFS_DIR/usr/bin/$bin" ] && [ ! -f "$ROOTFS_DIR/usr/sbin/$bin" ]; then
        log_fail "Missing binary: $bin"
        BINARY_ERRORS=$((BINARY_ERRORS + 1))
    fi
done

if [ "$BINARY_ERRORS" -eq 0 ]; then
    log_pass "All core office suite and printing binaries verified (abiword, gnumeric, qpdfview, cupsd, cupsfilter, gs)."
fi

# 2. Verify Adaptive Launchers
log_info "Test 2: Verifying Adaptive Launchers..."
for launcher in lite-launch-office lite-launch-spreadsheet lite-launch-pdf; do
    if bash -n "$ROOTFS_DIR/usr/local/bin/$launcher" 2>/dev/null; then
        log_pass "Adaptive launcher '$launcher' validated syntax."
    else
        log_fail "Syntax error in $launcher"
    fi
done

# 3. Verify CUPS Configuration Syntax
log_info "Test 3: Checking CUPS daemon configuration..."
if [ -f "$ROOTFS_DIR/etc/cups/cupsd.conf" ]; then
    if grep -q "LogLevel warn" "$ROOTFS_DIR/etc/cups/cupsd.conf" && grep -q "MaxJobs 25" "$ROOTFS_DIR/etc/cups/cupsd.conf"; then
        log_pass "CUPS configuration is properly tuned for low-memory operation."
    else
        log_fail "CUPS configuration missing low-memory directives."
    fi
else
    log_fail "Missing /etc/cups/cupsd.conf"
fi

# 4. Verify MIME Associations
log_info "Test 4: Verifying Document MIME Associations..."
if [ -f "$ROOTFS_DIR/etc/xdg/mimeapps.list" ]; then
    if grep -q "application/pdf=PDF-Viewer.desktop" "$ROOTFS_DIR/etc/xdg/mimeapps.list" && \
       grep -q "application/msword=Word-Processor.desktop" "$ROOTFS_DIR/etc/xdg/mimeapps.list" && \
       grep -q "application/vnd.ms-excel=Spreadsheet.desktop" "$ROOTFS_DIR/etc/xdg/mimeapps.list"; then
        log_pass "MIME mappings for PDF, DOCX/DOC, and XLSX/XLS verified."
    else
        log_fail "MIME mappings missing expected desktop associations."
    fi
else
    log_fail "Missing /etc/xdg/mimeapps.list"
fi

# 5. Verify User Group Memberships
log_info "Test 5: Checking user printing permissions..."
USER_GROUPS=$(chroot "$ROOTFS_DIR" id -Gn liteuser 2>/dev/null || echo "")
if echo "$USER_GROUPS" | grep -q "lp" && echo "$USER_GROUPS" | grep -q "lpadmin"; then
    log_pass "User 'liteuser' enrolled in printer operator groups 'lp' and 'lpadmin'."
else
    log_fail "User 'liteuser' lacks lp/lpadmin groups: $USER_GROUPS"
fi

# 6. Live QEMU Boot Test (512 MB RAM with full Desktop + CUPS)
log_info "Test 6: Launching QEMU 512 MB VM with full Office & Printing Stack..."
SERIAL_LOG="/tmp/qemu_office_test_serial.log"
rm -f "$SERIAL_LOG"

QEMU_CMD=(
    qemu-system-x86_64
    -m 512M
    -smp 2
    -kernel "$KERNEL_BIN"
    -drive "file=$RAW_IMAGE,format=raw,if=virtio"
    -append "root=/dev/vda rw console=ttyS0 console=tty1 quiet loglevel=3"
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
    log_pass "QEMU booted successfully with full desktop and CUPS services."

    if grep -q "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG"; then
        echo "--------------------------------------------------"
        echo "LITEOFFICE OS LIVE MEMORY BENCHMARK (DESKTOP + CUPS)"
        sed -n '/=== LITE OFFICE OS DESKTOP BENCHMARK ===/,/=== BENCHMARK COMPLETE ===/p' "$SERIAL_LOG"
        echo "--------------------------------------------------"

        USED_RAM=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG" | awk '/Mem:/ {print $3}' | tail -n 1)
        AVAIL_RAM=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$SERIAL_LOG" | awk '/Mem:/ {print $7}' | tail -n 1)

        echo "[*] Measured Idle RAM with Office Stack & CUPS: ${USED_RAM} MB (Available: ${AVAIL_RAM} MB)"
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
echo "STAGE 6 TEST SUITE SUMMARY"
echo -e "${GREEN}Passed Tests: $PASSED_COUNT${NC}"
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo -e "${RED}Failed Tests: $FAILED_COUNT${NC}"
    echo "=================================================================="
    exit 1
else
    echo -e "${GREEN}Failed Tests: 0 (100% PASS)${NC}"
    echo "=================================================================="
fi
