# ==============================================================================
# Lite Office OS — Master Makefile
# ==============================================================================
.POSIX:
.PHONY: all host-check kernel rootfs iso test-qemu-512m test-qemu-1g test-qemu-2g clean help

SHELL = /usr/bin/env bash
ARCH ?= x86_64
KERNEL_VER ?= 6.6.78
BUILD_DIR = build
OUT_DIR = output

all: host-check kernel rootfs iso

help:
	@echo "Lite Office OS — Build System"
	@echo "----------------------------------------------------"
	@echo "Targets:"
	@echo "  make host-check        Validate host environment and tools"
	@echo "  make kernel            Fetch and compile Linux 6.6 LTS low-RAM kernel"
	@echo "  make rootfs            Bootstrap and construct root filesystem"
	@echo "  make iso               Build bootable hybrid Live ISO (BIOS + UEFI)"
	@echo "  make test-qemu-512m    Run QEMU test with 512 MB RAM"
	@echo "  make test-qemu-1g      Run QEMU test with 1 GB RAM"
	@echo "  make test-qemu-2g      Run QEMU test with 2 GB RAM"
	@echo "  make clean             Remove temporary build artifacts"
	@echo "----------------------------------------------------"
	@echo "Variables:"
	@echo "  ARCH=x86_64 (or i686)"

host-check:
	@bash scripts/01_host_check.sh

kernel:
	@bash scripts/02_build_kernel.sh --arch $(ARCH)

rootfs:
	@bash scripts/03_assemble_rootfs.sh --arch $(ARCH)

iso:
	@bash scripts/04_generate_iso.sh --arch $(ARCH)

test-qemu-512m:
	@bash scripts/05_qemu_test.sh --ram 512M --iso $(OUT_DIR)/LiteOffice-$(ARCH).iso

test-qemu-1g:
	@bash scripts/05_qemu_test.sh --ram 1024M --iso $(OUT_DIR)/LiteOffice-$(ARCH).iso

test-qemu-2g:
	@bash scripts/05_qemu_test.sh --ram 2048M --iso $(OUT_DIR)/LiteOffice-$(ARCH).iso

clean:
	@echo "[*] Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(OUT_DIR)
