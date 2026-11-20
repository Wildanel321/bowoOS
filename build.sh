#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Master Build Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ARCH="x86_64"
STAGE="all"

usage() {
    local exit_code="${1:-0}"
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --arch <x86_64|i686>     Target system architecture (default: x86_64)
  --stage <1..8|all|test>  Execute specific build stage:
                             1: Host Environment Validation
                             2: Kernel & Initramfs Build
                             3: Base Rootfs Assembly
                             4: Desktop Integration (Xorg + Openbox + Tint2)
                             5: LiteOffice Branding, Apps & Services
                             6: Office Suite & Printing Stack
                             7: RAM Optimization & Memory Daemons
                             8: Bootable Hybrid Live ISO Generation
                             all: Execute complete build pipeline (Stages 1-8)
                             test: Run comprehensive automated test suites
  --help                   Display this help message
EOF
    exit "$exit_code"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --stage)
            STAGE="$2"
            shift 2
            ;;
        --help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1"
            usage 1
            ;;
    esac
done

echo "=============================================================================="
echo "Lite Office OS — Build Pipeline [ARCH: $ARCH, STAGE: $STAGE]"
echo "=============================================================================="

case "$STAGE" in
    1)
        bash scripts/01_host_check.sh
        ;;
    2)
        bash scripts/02_build_kernel.sh --arch "$ARCH"
        ;;
    3)
        bash scripts/03_assemble_rootfs.sh --arch "$ARCH"
        ;;
    4)
        bash scripts/04_install_desktop.sh --arch "$ARCH"
        ;;
    5)
        bash scripts/05_install_liteoffice_suite.sh --arch "$ARCH"
        ;;
    6)
        bash scripts/06_install_office_suite.sh --arch "$ARCH"
        ;;
    7)
        bash scripts/07_optimize_memory.sh --arch "$ARCH"
        ;;
    8)
        bash scripts/08_generate_iso.sh --arch "$ARCH"
        ;;
    all)
        bash scripts/01_host_check.sh
        bash scripts/02_build_kernel.sh --arch "$ARCH"
        bash scripts/03_assemble_rootfs.sh --arch "$ARCH"
        bash scripts/04_install_desktop.sh --arch "$ARCH"
        bash scripts/05_install_liteoffice_suite.sh --arch "$ARCH"
        bash scripts/06_install_office_suite.sh --arch "$ARCH"
        bash scripts/07_optimize_memory.sh --arch "$ARCH"
        bash scripts/08_generate_iso.sh --arch "$ARCH"
        ;;
    test)
        bash tests/test_liteoffice_suite.sh "$ARCH"
        bash tests/test_office_suite.sh "$ARCH"
        bash tests/test_memory_optimization.sh "$ARCH"
        bash tests/test_live_iso.sh "$ARCH"
        ;;
    *)
        echo "Error: Invalid stage '$STAGE'"
        usage
        ;;
esac

echo "[V] Pipeline execution completed successfully."
