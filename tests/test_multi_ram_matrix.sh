#!/bin/bash
# ==============================================================================
# LiteOffice OS — Stage 9 Multi-RAM Tier Benchmarking Harness
# Executes live QEMU benchmarks across 512 MB, 1 GB, and 2 GB RAM envelopes.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RAW_IMAGE="/var/tmp/liteoffice-build/rootfs_x86_64.raw"
KERNEL_BIN="$PROJECT_ROOT/output/vmlinuz-6.6-lite"
REPORT_FILE="$PROJECT_ROOT/output/multi_ram_benchmark_matrix.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo "=================================================================="
echo "LiteOffice OS — Multi-RAM Benchmark & Profiling Suite"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

mkdir -p "$PROJECT_ROOT/output"
cat << 'EOF' > "$REPORT_FILE"
# LiteOffice OS — Multi-RAM Performance & Resource Benchmark Matrix

| Target RAM Tier | Configured RAM | Idle RAM Measured | Available RAM | ZRAM Compressed Swap | Status (< Limit) |
| :--- | :--- | :--- | :--- | :--- | :--- |
EOF

run_tier_benchmark() {
    local tier_name="$1"
    local ram_size="$2"
    local max_idle_mb="$3"

    echo -e "\n${BLUE}[*] Benchmarking Tier: ${BOLD}${tier_name}${NC} (${ram_size} RAM)..."
    local serial_log="/tmp/qemu_bench_${ram_size}.log"
    rm -f "$serial_log"

    local qemu_cmd=(
        qemu-system-x86_64
        -m "$ram_size"
        -smp 2
        -kernel "$KERNEL_BIN"
        -drive "file=$RAW_IMAGE,format=raw,if=virtio"
        -append "root=/dev/vda rw console=tty1 console=ttyS0 init=/sbin/init quiet=0"
        -serial "file:$serial_log"
        -display none
        -device virtio-vga
    )

    "${qemu_cmd[@]}" &
    local qemu_pid=$!

    local ready=0
    for i in {1..55}; do
        sleep 1
        if [ -f "$serial_log" ]; then
            if grep -q "BENCHMARK COMPLETE" "$serial_log" 2>/dev/null; then
                ready=1
                echo "    - Desktop initialized and telemetry received after ~${i}s."
                break
            elif grep -q "login:" "$serial_log" 2>/dev/null && [ "$i" -ge 40 ]; then
                ready=1
                break
            fi
        fi
    done

    sleep 2
    kill -9 "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true

    if [ "$ready" -eq 1 ] && grep -q "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$serial_log"; then
        local used_mb=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$serial_log" | awk '/Mem:/ {print $3}' | tail -n 1)
        local total_mb=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$serial_log" | awk '/Mem:/ {print $2}' | tail -n 1)
        local avail_mb=$(grep -A 2 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$serial_log" | awk '/Mem:/ {print $7}' | tail -n 1)
        local swap_mb=$(grep -A 3 "=== LITE OFFICE OS DESKTOP BENCHMARK ===" "$serial_log" | awk '/Swap:/ {print $2}' | tail -n 1)

        echo -e "    - Total RAM     : ${total_mb} MB"
        echo -e "    - Used Idle RAM : ${BOLD}${used_mb} MB${NC} (Ceiling: ${max_idle_mb} MB)"
        echo -e "    - Available RAM : ${avail_mb} MB"
        echo -e "    - ZRAM Active   : ${swap_mb} MB"

        local status_str="PASS (<= ${max_idle_mb} MB)"
        if [ "$used_mb" -le "$max_idle_mb" ]; then
            echo -e "    - Evaluation    : ${GREEN}${BOLD}[PASS] Met Idle RAM Ceiling${NC}"
        else
            echo -e "    - Evaluation    : ${RED}${BOLD}[FAIL] Exceeded Ceiling${NC}"
            status_str="FAIL (> ${max_idle_mb} MB)"
        fi

        echo "| **${tier_name}** | ${total_mb} MB | **${used_mb} MB** | ${avail_mb} MB | ${swap_mb} MB (Active) | **${status_str}** |" >> "$REPORT_FILE"
    else
        echo -e "${RED}[-] Benchmark failed to capture telemetry for ${tier_name}.${NC}"
        echo "| **${tier_name}** | ${ram_size} | Failed | - | - | **FAIL** |" >> "$REPORT_FILE"
    fi
}

# Run 512M, 1G, 2G tiers
run_tier_benchmark "512 MB Low-Spec Tier" "512M" 120
run_tier_benchmark "1 GB Office Tier" "1024M" 180
run_tier_benchmark "2 GB Standard Tier" "2048M" 250

echo -e "\n=================================================================="
echo -e "${GREEN}${BOLD}MULTI-RAM BENCHMARK MATRIX COMPLETE!${NC}"
echo "Summary Report written to: $REPORT_FILE"
echo "=================================================================="
cat "$REPORT_FILE"
