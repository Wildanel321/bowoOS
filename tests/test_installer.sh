#!/usr/bin/env bash
# ==============================================================================
# LiteOffice OS — Stage 8 System Installer Verification Test
# Tests GUI installer syntax, min 8 GB swap enforcement, and desktop entry.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
    FAILED=$((FAILED + 1))
}

echo "=================================================================="
echo "LiteOffice OS — System Installer Verification Suite"
echo "=================================================================="

# Test 1: Python script syntax in rootfs chroot
echo "[*] Test 1: Validating GTK3 Python Installer syntax..."
if chroot /var/tmp/liteoffice-build/rootfs_x86_64 python3 -m py_compile /usr/local/bin/liteoffice-installer 2>/dev/null; then
    pass "GUI Installer (liteoffice-installer) compiles without syntax errors."
else
    fail "GUI Installer failed Python compilation in rootfs."
fi

# Test 2: Shell wrapper syntax
echo "[*] Test 2: Validating CLI / launcher wrapper syntax..."
if bash -n "$PROJECT_ROOT/installer/lite-installer.sh"; then
    pass "CLI wrapper (lite-installer.sh) bash syntax is valid."
else
    fail "CLI wrapper has syntax errors."
fi

# Test 3: Verify minimum 8 GB swap enforcement in code
echo "[*] Test 3: Verifying min 8 GB swap safety buffer enforcement..."
if grep -q "swap_val = 8.0" "$PROJECT_ROOT/installer/liteoffice-installer.py" && \
   grep -q "SWAP_GB=8" "$PROJECT_ROOT/installer/lite-installer.sh"; then
    pass "Minimum 8 GB Swap allocation verified in both GUI and CLI installers."
else
    fail "Minimum 8 GB Swap allocation missing or misconfigured."
fi

# Test 4: Desktop Entry Validity
echo "[*] Test 4: Verifying Desktop Launcher integration..."
DESKTOP_FILE="$PROJECT_ROOT/installer/liteoffice-installer.desktop"
if [ -f "$DESKTOP_FILE" ] && grep -q "Exec=sudo -E /usr/local/bin/liteoffice-installer" "$DESKTOP_FILE"; then
    pass "Desktop shortcut properly configures elevated GUI installer execution."
else
    fail "Desktop entry missing or incorrect Exec target."
fi

echo "=================================================================="
echo -e "${GREEN}Installer Tests Passed: $PASSED / $((PASSED + FAILED))${NC}"
echo "=================================================================="
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
