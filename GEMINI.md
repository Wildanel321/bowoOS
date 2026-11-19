# GEMINI.md — Lite Office OS Project Directives and Context

## Project Overview
**Lite Office OS** is a lightweight, modular, Linux-based desktop operating system engineered from the ground up for low-specification personal computers (minimum RAM 512 MB, recommended 1–2 GB). The OS is specifically designed for office workflows (document editing, spreadsheets, PDF viewing, printing, file management, and light web browsing).

## Target Architectures
- **Primary**: `x86_64` (64-bit AMD/Intel)
- **Secondary**: `i686` (32-bit legacy x86 architectures, e.g., Intel Atom, Pentium 4, Core Duo)

## Architectural Tenets
1. **RAM Footprint First**: System idle memory consumption must not exceed 120 MB on 512 MB systems, 180 MB on 1 GB systems, and 250 MB on 2 GB systems.
2. **Deterministic & Modular Architecture**:
   - **Linux LTS Kernel (6.6)**: Stripped defconfig, high-efficiency preemption, compressed ZRAM swap enabled by default.
   - **Init System**: `OpenRC` with `eudev` for minimal memory overhead and fast startup.
   - **Display Stack**: `Xorg` minimal server with `Openbox` window manager and `Tint2` panel.
   - **Adaptive Office Profile**: 
     - 512 MB RAM Tier: `AbiWord` + `Gnumeric` + lightweight PDF viewer (`qpdfview`) + minimal single-process WebKitGTK browser.
     - 1 GB–2 GB RAM Tier: Full `LibreOffice` suite + tuned `Firefox ESR`.
3. **Reproducibility**: Pure script-driven build pipeline (`Makefile` and modular bash scripts in `/scripts`).
4. **Safety & Stability**: Non-root default desktop user (`liteuser`), memory pressure supervision (`earlyoom`), and verified software components.

## Repository Layout
- `/docs`: Comprehensive project specifications, architecture documents, and backlog.
- `/kernel`: Custom low-memory kernel configurations (`x86_64` & `i686`) and build scripts.
- `/initramfs`: Minimal BusyBox-based early userspace initramfs builder.
- `/rootfs`: Root filesystem construction engine and base skeleton configurations.
- `/init`: OpenRC service scripts (`zram-swap`, `lite-profile-detect`, `lite-oom`).
- `/desktop`: Openbox WM configurations, Tint2 panel layouts, PCManFM file manager settings, and custom clean themes.
- `/office`: MIME type associations, desktop shortcuts, and adaptive application profile switches.
- `/installer`: Modular TUI/CLI system installer supporting Legacy BIOS and UEFI/GPT.
- `/iso`: Hybrid bootable Live ISO creation engine (`xorriso` + GRUB 2.12).
- `/scripts`: Automated, numbered stage scripts (`01_host_check.sh`, `02_build_kernel.sh`, etc.).
- `/tests`: Automated test suites for QEMU emulation and RAM profiling.

## Operating Standards & Verification
- All scripts must have `set -euo pipefail`, explicit error handling, and structured logging.
- Any change to kernel configs, services, or rootfs must be validated against QEMU boot tests.
- Every development cycle must follow the PRAR (Perceive, Reason, Act, Refine) framework and log learnings in `LEARNINGS.gemini.md`.
