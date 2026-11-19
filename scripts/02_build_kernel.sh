#!/usr/bin/env bash
# ==============================================================================
# Lite Office OS — Stage 2: Linux Kernel 6.6 LTS Build Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ARCH="x86_64"
KERNEL_VER="6.6.78"
KERNEL_MAJOR="v6.x"
TARBALL="linux-${KERNEL_VER}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/${KERNEL_MAJOR}/${TARBALL}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --ver)
            KERNEL_VER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Lite Office OS — Building Linux Kernel ${KERNEL_VER} for ${ARCH}${NC}"
echo -e "${BLUE}==============================================================================${NC}"

BUILD_DIR="/var/tmp/liteoffice-build"
SRC_CACHE="$BUILD_DIR/sources"
OUTPUT_DIR="$PROJECT_ROOT/output"
BOOT_DIR="$PROJECT_ROOT/build/boot"

mkdir -p "$SRC_CACHE" "$OUTPUT_DIR" "$BOOT_DIR"

# 1. Download official LTS Kernel Tarball
cd "$SRC_CACHE"
if [ ! -f "$TARBALL" ]; then
    echo -e "[*] Downloading official kernel source: ${YELLOW}${KERNEL_URL}${NC} ..."
    curl -L -C - --retry 5 --retry-delay 3 -O "$KERNEL_URL"
else
    echo -e "[*] Found existing kernel tarball: ${GREEN}${TARBALL}${NC}"
fi

# 2. Extract Kernel Source
SRC_DIR="$BUILD_DIR/linux-${KERNEL_VER}"
if [ ! -d "$SRC_DIR" ]; then
    echo -e "[*] Extracting ${TARBALL} into fast ext4 workspace (${SRC_DIR})..."
    tar -xf "$TARBALL" -C "$BUILD_DIR"
else
    echo -e "[*] Source directory already extracted: ${GREEN}${SRC_DIR}${NC}"
fi

cd "$SRC_DIR"

# 2.5 Apply Kernel Patches (e.g. GCC 15 / C23 compatibility)
PATCH_DIR="$PROJECT_ROOT/kernel/patches"
if [ -d "$PATCH_DIR" ]; then
    for patchfile in "$PATCH_DIR"/*.patch; do
        if [ -f "$patchfile" ]; then
            echo -e "[*] Applying kernel patch: ${YELLOW}$(basename "$patchfile")${NC} ..."
            patch -p1 -N -r - < "$patchfile" || true
        fi
    done
fi

# 3. Apply Custom Lite Defconfig
DEFCONFIG_SRC="$PROJECT_ROOT/kernel/config/${ARCH}_lite_defconfig"
if [ ! -f "$DEFCONFIG_SRC" ]; then
    echo -e "${RED}[-] Error: Configuration file '$DEFCONFIG_SRC' not found!${NC}"
    exit 1
fi

echo -e "[*] Applying low-memory configuration: ${YELLOW}${DEFCONFIG_SRC}${NC} ..."
cp "$DEFCONFIG_SRC" .config

# Configure arch options for cross or 32-bit builds
MAKE_ARGS=()
if [ "$ARCH" = "i686" ]; then
    MAKE_ARGS+=("ARCH=i386")
else
    MAKE_ARGS+=("ARCH=x86_64")
fi

echo "[*] Synchronizing kernel configuration with olddefconfig..."
make "${MAKE_ARGS[@]}" olddefconfig

# 4. Compile Kernel bzImage
NPROCS=$(nproc)
echo -e "[*] Compiling Linux Kernel bzImage using ${GREEN}${NPROCS}${NC} parallel threads..."
START_TIME=$(date +%s)

make "${MAKE_ARGS[@]}" -j"${NPROCS}" bzImage

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo -e "[+] Kernel compilation finished in ${GREEN}${ELAPSED} seconds${NC}."

# 5. Compile Essential Modules
echo -e "[*] Compiling essential device driver modules..."
make "${MAKE_ARGS[@]}" -j"${NPROCS}" modules

# 6. Install Modules into Staging
MODULES_STAGING="$BUILD_DIR/modules_staging_${ARCH}"
rm -rf "$MODULES_STAGING"
mkdir -p "$MODULES_STAGING"
echo -e "[*] Installing modules to staging area (${MODULES_STAGING})..."
make "${MAKE_ARGS[@]}" INSTALL_MOD_PATH="$MODULES_STAGING" modules_install

# 7. Copy Kernel bzImage to Outputs
KERNEL_BIN="arch/x86/boot/bzImage"
TARGET_VMLINUZ="$OUTPUT_DIR/vmlinuz-6.6-lite"
TARGET_BOOT_VMLINUZ="$BOOT_DIR/vmlinuz-6.6-lite"

if [ -f "$KERNEL_BIN" ]; then
    cp "$KERNEL_BIN" "$TARGET_VMLINUZ"
    cp "$KERNEL_BIN" "$TARGET_BOOT_VMLINUZ"
    KERNEL_SIZE=$(du -h "$TARGET_VMLINUZ" | cut -f1)
    echo -e "${GREEN}[V] Kernel binary installed successfully: ${TARGET_VMLINUZ} (Size: ${KERNEL_SIZE})${NC}"
else
    echo -e "${RED}[-] Error: Kernel bzImage was not generated!${NC}"
    exit 1
fi

# 8. Ensure Initramfs is built
echo "[*] Building / verifying early initramfs..."
bash "$PROJECT_ROOT/initramfs/build_initramfs.sh" "$ARCH" "$OUTPUT_DIR"
cp "$OUTPUT_DIR/initramfs-${ARCH}.img" "$BOOT_DIR/initramfs.img"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${GREEN}[V] STAGE 2 KERNEL & INITRAMFS BUILD COMPLETE!${NC}"
echo -e "Kernel Image: ${TARGET_VMLINUZ} (${KERNEL_SIZE})"
echo -e "Initramfs   : ${OUTPUT_DIR}/initramfs-${ARCH}.img"
echo -e "${BLUE}==============================================================================${NC}"
