# LEARNINGS.gemini.md — Lite Office OS Engineering Log

This file serves as an immutable, timestamped record of PRAR (Perceive, Reason, Act, Refine) cycles, technical decisions, experimental findings, and system benchmarks for Lite Office OS.

---

## [2026-11-19T13:00:00+07:00] Stage 1: Architectural Inception, Feasibility Assessment & Host Validation

### 1. Perceive
- **Input**: User requested the design and ground-up engineering of *Lite Office OS*, a lightweight Linux-based desktop operating system tailored for legacy and low-end hardware (RAM 512 MB to 2 GB, storage 4 to 16 GB, Legacy BIOS & UEFI).
- **Environment Analysis**: Host machine is Windows 11 with WSL2 Ubuntu 26.04 available. Disk space inside WSL root filesystem has 950+ GB available. WSL has `gcc`, `make`, `bc`, `git`, `debootstrap`, `xorriso`, and `mtools`.
- **Constraint Matrix**:
  - 512 MB target requires strict memory budgeting: idle RAM must stay below 120 MB.
  - LibreOffice and modern Chromium-based browsers exceed 512 MB memory envelopes when multitasking.
  - Wayland compositors on legacy graphics (Intel GMA, older AMD/Nvidia) lack hardware acceleration and trigger heavy CPU software rendering (`llvmpipe`).

### 2. Reason
- **C Library Decision**: Selected optimized GNU C Library (`glibc`) over `musl` for the primary desktop OS. While `musl` saves ~20-30 MB in memory, it introduces severe compatibility barriers with LibreOffice, proprietary printer drivers (CUPS filter stacks), and international locale fonts. Initramfs will still leverage static `busybox` / minimal linking.
- **Init System Decision**: Selected `OpenRC` + `eudev`. Unlike `systemd` (~40 MB idle daemon memory), OpenRC scripts run at boot and terminate, consuming virtually 0 MB at idle.
- **Display & Window Manager Decision**: Selected `Xorg` minimal + `Openbox` + `Tint2` + `PCManFM`. This combination uses under 40 MB RAM combined, compared to XFCE (~180 MB) or GNOME (~500 MB).
- **Office Application Strategy**: Implemented adaptive dual-tier profiling:
  - 512 MB Tier: `AbiWord` + `Gnumeric` + `qpdfview` + minimal WebKitGTK browser.
  - 1 GB - 2 GB Tier: Full `LibreOffice` suite + tuned `Firefox ESR`.
- **Build Methodology**: Modular Hybrid Rootfs engine with custom upstream Linux 6.6 LTS Kernel and custom initramfs to guarantee reproducibility and full source control.

### 3. Act
- Formulated the comprehensive Project Requirements Document (PRD), Software Requirements Specification (SRS), Architecture Design Document (ADD), and Technical Design Document (TDD).
- Initialized project backlog (`docs/backlog.md`).
- Established the directory structure for kernel, initramfs, rootfs, init, desktop, office, installer, iso, scripts, and tests.
- Created `scripts/01_host_check.sh` and top-level `Makefile` to validate dependencies on the build host.

### 4. Refine
- Verified host tools inside WSL2 Ubuntu environment.
- Configured check routines for build prerequisites (`bison`, `flex`, `libssl-dev`, `libelf-dev`, `qemu-system-x86_64`, `squashfs-tools`).
- Successfully validated host environment: 0 errors, 0 warnings.

---

## [2026-11-19T13:45:00+07:00] Stage 2: Linux 6.6 LTS Kernel & BusyBox Early Userspace Initramfs

### 1. Perceive
- **Input**: User approved proceeding with Stage 2: Compiling official Linux Kernel 6.6 LTS and assembling an early userspace initramfs capable of booting in QEMU at 512 MB RAM.
- **Artifacts**: Official upstream `linux-6.6.78.tar.xz`, `kernel/config/x86_64_lite_defconfig`, `kernel/config/i686_lite_defconfig`, `initramfs/build_initramfs.sh`, `scripts/02_build_kernel.sh`, `tests/test_early_boot.sh`.

### 2. Reason & Engineering Diagnostics
- **Diagnostic 1 (GCC 15 / C23 Keyword Conflict in Realmode Code)**:
  - *Symptom*: Compilation failed with `error: cannot use keyword 'false' as enumeration constant` and `error: 'bool' cannot be defined via 'typedef'` in `arch/x86/realmode/rm/`.
  - *Root Cause*: GCC 15 defaults to `-std=gnu23`. While the top-level kernel Makefile specifies `-std=gnu11`, `arch/x86/realmode/rm/Makefile` and `arch/x86/boot/Makefile` override `KBUILD_CFLAGS` with `$(REALMODE_CFLAGS)` which did not pass `-std=gnu11`.
  - *Resolution*: Created and applied `kernel/patches/0001-gcc15-c23-realmode-gnu11.patch` appending `-std=gnu11` to `REALMODE_CFLAGS` in `arch/x86/Makefile`.
- **Diagnostic 2 (Early Boot Unknown Block 0,0 Panic)**:
  - *Symptom*: QEMU boot test failed with `Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)`.
  - *Root Cause*: `CONFIG_BLK_DEV_INITRD` was disabled in `x86_64_lite_defconfig`, causing the kernel to ignore the initramfs passed via QEMU `-initrd`.
  - *Resolution*: Enabled `CONFIG_BLK_DEV_INITRD=y`, `CONFIG_RD_GZIP=y`, `CONFIG_RD_XZ=y`, `CONFIG_RD_ZSTD=y`. Recompiled kernel.
- **Diagnostic 3 (Broken Absolute Symlinks in BusyBox Initramfs)**:
  - *Symptom*: Kernel unpacked initramfs, but failed with `No working init found`.
  - *Root Cause*: `busybox --install -s bin` created absolute symlinks pointing to `/var/tmp/liteoffice-build/...` on the host, which failed when executed inside the VM.
  - *Resolution*: Generated clean relative symlinks (`ln -sf busybox "$applet"`) inside `bin/` and `sbin/`.

### 3. Act & Verify
- Compiled custom `vmlinuz-6.6-lite` (13 MB) and packed `initramfs-x86_64.img` (1.1 MB).
- Executed `tests/test_early_boot.sh 512M` in QEMU:
  - Kernel loaded in 512 MB memory envelope (`Memory: 475468K/523768K available`).
  - ZRAM device initialized (`zram: Added device: zram0`).
  - Initramfs `/init` executed cleanly and displayed the Lite Office OS boot banner.
  - Interactive maintenance shell entered successfully without kernel panics or crashes.
