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
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --arch <x86_64|i686>     Target system architecture (default: x86_64)
  --stage <1..8|all>       Execute specific build stage:
                             1: Host Validation
                             2: Kernel & Initramfs Build
                             3: Rootfs Assembly
                             4: Desktop Integration
                             5: Office Suite Setup
                             6: RAM Optimization Services
                             7: Live ISO Generation
                             8: QEMU Automated Verification
                             all: Execute entire pipeline
  --help                   Display this help message
EOF
    exit 1
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
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
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
    4|5|6)
        echo "[*] Running sub-stages 4-6 within rootfs assembly..."
        bash scripts/03_assemble_rootfs.sh --arch "$ARCH"
        ;;
    7)
        bash scripts/04_generate_iso.sh --arch "$ARCH"
        ;;
    8)
        bash scripts/05_qemu_test.sh --ram 512M --iso "output/LiteOffice-${ARCH}.iso"
        ;;
    all)
        bash scripts/01_host_check.sh
        bash scripts/02_build_kernel.sh --arch "$ARCH"
        bash scripts/03_assemble_rootfs.sh --arch "$ARCH"
        bash scripts/04_generate_iso.sh --arch "$ARCH"
        bash scripts/05_qemu_test.sh --ram 512M --iso "output/LiteOffice-${ARCH}.iso"
        ;;
    *)
        echo "Error: Invalid stage '$STAGE'"
        usage
        ;;
esac

echo "[V] Pipeline execution completed successfully."
