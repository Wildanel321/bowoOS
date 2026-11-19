#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Stage 1: Build Host Validation Script
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Stage 1: Host Environment & Toolchain Validator${NC}"
echo -e "${BLUE}==============================================================================${NC}"

ERRORS=0
WARNINGS=0
MISSING_PKGS=()

# 1. Architecture Check
HOST_ARCH=$(uname -m)
echo -n "[*] Checking host architecture... "
if [ "$HOST_ARCH" = "x86_64" ]; then
    echo -e "${GREEN}PASS ($HOST_ARCH)${NC}"
else
    echo -e "${YELLOW}WARNING: Host is $HOST_ARCH. Cross-compilation required for x86_64.${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 2. Linux Kernel & Shell Environment
echo -n "[*] Checking operating system... "
if [ -f /etc/os-release ]; then
    OS_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    echo -e "${GREEN}PASS ($OS_NAME)${NC}"
else
    echo -e "${YELLOW}WARNING (Generic Linux: $(uname -s))${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. Available Storage Check
echo -n "[*] Checking available disk space... "
AVAIL_KB=$(df -k . | awk 'NR==2 {print $4}')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
if [ "$AVAIL_GB" -ge 10 ]; then
    echo -e "${GREEN}PASS (${AVAIL_GB} GB available on current mount)${NC}"
else
    # Check if native /var/tmp or /tmp has plenty of space (e.g. inside WSL2)
    NATIVE_AVAIL_KB=$(df -k /var/tmp | awk 'NR==2 {print $4}')
    NATIVE_AVAIL_GB=$((NATIVE_AVAIL_KB / 1024 / 1024))
    if [ "$NATIVE_AVAIL_GB" -ge 15 ]; then
        echo -e "${GREEN}PASS (${NATIVE_AVAIL_GB} GB available on native Linux partition /var/tmp)${NC}"
        echo -e "    ${YELLOW}NOTE: Current directory has ${AVAIL_GB} GB. Build cache will automatically use fast native /var/tmp/liteoffice-build.${NC}"
    else
        echo -e "${RED}FAIL (${AVAIL_GB} GB available on current mount and only ${NATIVE_AVAIL_GB} GB on /var/tmp, minimum 10 GB required)${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# 4. Mandatory Executables
CHECK_BINS=(
    gcc
    g++
    make
    bc
    bison
    flex
    git
    rsync
    tar
    gzip
    xz
    debootstrap
    xorriso
    mcopy
    mkfs.vfat
    mksquashfs
    kmod
)

echo "[*] Checking required build binaries..."
for bin in "${CHECK_BINS[@]}"; do
    echo -n "    - $bin: "
    if command -v "$bin" >/dev/null 2>&1; then
        BIN_VER=$( "$bin" --version 2>&1 | head -n 1 || echo "installed" )
        echo -e "${GREEN}OK${NC} ($BIN_VER)"
    else
        echo -e "${RED}MISSING${NC}"
        ERRORS=$((ERRORS + 1))
        case "$bin" in
            gcc|g++) MISSING_PKGS+=("build-essential") ;;
            bc) MISSING_PKGS+=("bc") ;;
            bison) MISSING_PKGS+=("bison") ;;
            flex) MISSING_PKGS+=("flex") ;;
            git) MISSING_PKGS+=("git") ;;
            rsync) MISSING_PKGS+=("rsync") ;;
            debootstrap) MISSING_PKGS+=("debootstrap") ;;
            xorriso) MISSING_PKGS+=("xorriso") ;;
            mcopy) MISSING_PKGS+=("mtools") ;;
            mkfs.vfat) MISSING_PKGS+=("dosfstools") ;;
            mksquashfs) MISSING_PKGS+=("squashfs-tools") ;;
            kmod) MISSING_PKGS+=("kmod") ;;
            *) MISSING_PKGS+=("$bin") ;;
        esac
    fi
done

# 5. Header Libraries needed for Kernel compilation (libssl-dev, libelf-dev)
echo "[*] Checking kernel build development libraries..."
if dpkg -s libssl-dev >/dev/null 2>&1 || pkg-config --exists openssl 2>/dev/null; then
    echo -e "    - OpenSSL headers: ${GREEN}OK${NC}"
else
    echo -e "    - OpenSSL headers: ${RED}MISSING (libssl-dev)${NC}"
    ERRORS=$((ERRORS + 1))
    MISSING_PKGS+=("libssl-dev")
fi

if dpkg -s libelf-dev >/dev/null 2>&1 || pkg-config --exists libelf 2>/dev/null; then
    echo -e "    - Libelf headers: ${GREEN}OK${NC}"
else
    echo -e "    - Libelf headers: ${RED}MISSING (libelf-dev)${NC}"
    ERRORS=$((ERRORS + 1))
    MISSING_PKGS+=("libelf-dev")
fi

# 6. QEMU Virtualization (for testing)
echo -n "[*] Checking QEMU emulator (qemu-system-x86_64)... "
if command -v qemu-system-x86_64 >/dev/null 2>&1; then
    QEMU_VER=$(qemu-system-x86_64 --version | head -n 1)
    echo -e "${GREEN}OK ($QEMU_VER)${NC}"
else
    echo -e "${YELLOW}NOT FOUND (qemu-system-x86 required for Stage 8 test suite)${NC}"
    WARNINGS=$((WARNINGS + 1))
    MISSING_PKGS+=("qemu-system-x86" "qemu-utils")
fi

# 7. Root / Sudo Capability (needed for debootstrap / loop mounts)
echo -n "[*] Checking root privilege access... "
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${GREEN}PASS (Running as root)${NC}"
elif sudo -n true 2>/dev/null; then
    echo -e "${GREEN}PASS (Passwordless sudo available)${NC}"
else
    echo -e "${YELLOW}NOTE (Interactive sudo will be required during rootfs assembly)${NC}"
fi

echo -e "${BLUE}==============================================================================${NC}"
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}[X] HOST VALIDATION FAILED with $ERRORS error(s) and $WARNINGS warning(s).${NC}"
    # Deduplicate missing packages
    UNIQUE_PKGS=($(printf "%s\n" "${MISSING_PKGS[@]}" | sort -u))
    echo -e "To install all missing packages on Ubuntu/Debian, execute:"
    echo -e "${YELLOW}sudo apt-get update && sudo apt-get install -y ${UNIQUE_PKGS[*]}${NC}"
    exit 1
else
    echo -e "${GREEN}[V] HOST ENVIRONMENT VALIDATED SUCCESSFULLY! ($WARNINGS warning(s))${NC}"
    echo -e "Ready to proceed to Stage 2: Kernel Build."
    exit 0
fi
