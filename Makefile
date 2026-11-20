# ==============================================================================
# Lite Office OS — Master Makefile
# ==============================================================================
.POSIX:
.PHONY: all host-check kernel rootfs desktop liteoffice office memory iso test test-qemu-512m test-qemu-1g test-qemu-2g clean help

SHELL = /usr/bin/env bash
ARCH ?= x86_64
KERNEL_VER ?= 6.6.78
BUILD_DIR = build
OUT_DIR = output

all: host-check kernel rootfs desktop liteoffice office memory iso

help:
	@echo "Lite Office OS — Build System"
	@echo "----------------------------------------------------"
	@echo "Targets:"
	@echo "  make host-check        Validate host environment and tools (Stage 1)"
	@echo "  make kernel            Fetch and compile Linux 6.6 LTS low-RAM kernel (Stage 2)"
	@echo "  make rootfs            Bootstrap base root filesystem (Stage 3)"
	@echo "  make desktop           Install X11, Openbox, Tint2 desktop stack (Stage 4)"
	@echo "  make liteoffice        Install branding, GTK apps, system daemons (Stage 5)"
	@echo "  make office            Install adaptive office suite & CUPS printing (Stage 6)"
	@echo "  make memory            Apply memory tuning, sysctl, ZRAM & earlyoom (Stage 7)"
	@echo "  make iso               Build bootable hybrid Live ISO (BIOS + UEFI) (Stage 8)"
	@echo "  make test              Run automated test suite"
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

desktop:
	@bash scripts/04_install_desktop.sh --arch $(ARCH)

liteoffice:
	@bash scripts/05_install_liteoffice_suite.sh --arch $(ARCH)

office:
	@bash scripts/06_install_office_suite.sh --arch $(ARCH)

memory:
	@bash scripts/07_optimize_memory.sh --arch $(ARCH)

iso:
	@bash scripts/08_generate_iso.sh --arch $(ARCH)

test:
	@bash tests/test_liteoffice_suite.sh $(ARCH)
	@bash tests/test_office_suite.sh $(ARCH)
	@bash tests/test_memory_optimization.sh $(ARCH)
	@bash tests/test_live_iso.sh $(ARCH)

test-qemu-512m:
	@bash tests/test_desktop_boot.sh $(ARCH) 512M

test-qemu-1g:
	@bash tests/test_desktop_boot.sh $(ARCH) 1024M

test-qemu-2g:
	@bash tests/test_desktop_boot.sh $(ARCH) 2048M

clean:
	@echo "[*] Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR) $(OUT_DIR)
