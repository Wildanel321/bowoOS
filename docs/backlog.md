# Project Backlog — LiteOffice OS

## Phase Tracker

| Stage | Description | Status | Deliverables |
| :--- | :--- | :--- | :--- |
| **Stage 1** | Foundation, Documentation & Host Check | **COMPLETED** | Specifications, Project Docs, Repository Tree, Host Validator |
| **Stage 2** | Kernel 6.6 LTS & Minimal BusyBox Initramfs | **COMPLETED** | `x86_64_lite_defconfig`, compiled `vmlinuz-6.6-lite`, initramfs, QEMU early boot (Verified) |
| **Stage 3** | Base Rootfs & OpenRC Init Integration | **COMPLETED** | Base filesystem skeleton, OpenRC services (`zram-swap`, `lite-profile-detect`, `lite-oom`), agetty consoles, unprivileged `liteuser` (Verified in QEMU at 512M) |
| **Stage 4** | X11 Display Server & Openbox Desktop Shell | **COMPLETED** | Xorg minimal, Openbox WM, Tint2 modern panel, PCManFM desktop, 63 MB Idle RAM (Verified in QEMU) |
| **Stage 5** | Branding, Native GUI Suite & System Services | **COMPLETED** | Official LiteOffice OS identity, vector icons, wallpapers, GRUB & Plymouth splash themes, GTK theme, native Python GTK apps (About, Welcome, Control Center, Monitor), healthd daemon, automation/manifest/security tools, 74 MB Idle RAM (100% Verified) |
| **Stage 6** | Adaptive Office Suite & Printing Stack | **COMPLETED** | AbiWord, Gnumeric, LibreOffice, qpdfview, adaptive launchers, CUPS daemon (7.6 MB RSS), MIME associations, 74 MB Idle RAM (Verified in QEMU) |
| **Stage 7** | RAM Optimization Daemons & Memory Profiling | **COMPLETED** | `/etc/sysctl.d/99-lowmem.conf`, dynamic ZRAM auto-scaler (702 MB active), earlyoom supervisor, hardware profile detector (Verified in QEMU) |
| **Stage 8** | Offline Installer & Live Hybrid ISO | **COMPLETED** | Modular CLI/TUI installer (`installer/lite-installer.sh`), bootable hybrid ISO (`output/liteoffice-1.0-x86_64.iso`, 414 MB, BIOS + UEFI) |
| **Stage 9** | Multi-RAM Performance Benchmarking & Release | **COMPLETED** | 512M (75 MB), 1G (85 MB), 2G (98 MB) matrix verified; documentation report (`docs/benchmark-report.md`) |

---

## Detailed Task Backlog

### Stage 1: Foundation & Specifications
- [x] Create project directives (`GEMINI.md`)
- [x] Establish immutable learning log (`LEARNINGS.gemini.md`)
- [x] Create Project Requirements Document (`docs/product-requirements-document.md`)
- [x] Create Software Requirements Specification (`docs/software-requirements-specification.md`)
- [x] Create Architecture Design Document (`docs/architecture-design-document.md`)
- [x] Create Technical Design Document (`docs/technical-design-document.md`)
- [x] Create Project Backlog (`docs/backlog.md`)
- [x] Create repository directory layout
- [x] Create host check script (`scripts/01_host_check.sh`)
- [x] Create top-level `Makefile` and `build.sh`
- [x] Execute and verify host environment inside WSL2 Ubuntu (0 errors, 0 warnings)

### Stage 2: Kernel & Early Userspace
- [x] Create `kernel/config/x86_64_lite_defconfig`
- [x] Create `kernel/config/i686_lite_defconfig`
- [x] Create `scripts/02_build_kernel.sh` (Kernel download, verify checksum, build)
- [x] Create GCC 15 / C23 compatibility patch (`kernel/patches/0001-gcc15-c23-realmode-gnu11.patch`)
- [x] Create minimal BusyBox initramfs generator (`initramfs/build_initramfs.sh`)
- [x] Test and verify early kernel + initramfs boot in QEMU at 512M RAM (Verified PASS)

### Stage 3: Base Rootfs & OpenRC
- [x] Create rootfs assembly script (`scripts/03_assemble_rootfs.sh`)
- [x] Configure OpenRC runlevels and `/etc/inittab`
- [x] Implement `init/init.d/zram-swap` service
- [x] Implement `init/init.d/lite-profile-detect` service
- [x] Configure default unprivileged user `liteuser` and permissions
- [x] Test and verify full OpenRC boot and getty login in QEMU at 512M RAM (Verified PASS)

### Stage 4: Graphical Desktop
- [x] Configure minimal Xorg server, modesetting KMS, and input drivers
- [x] Implement Openbox configuration (`desktop/openbox/rc.xml`, `menu.xml`, `autostart`)
- [x] Implement Tint2 modern flat panel (`desktop/tint2/tint2rc`)
- [x] Implement PCManFM desktop configuration and shortcuts
- [x] Configure zero-overhead autologin on `tty1` into graphical desktop session
- [x] Test and verify in QEMU: Achieved 63 MB idle RAM (Target: <= 120 MB) [PASS]

### Stage 5: Branding, Native GUI Applications & System Services
- [x] Design vector SVG logo, Hi-DPI PNG icon set (16x16 to 512x512), and desktop wallpapers
- [x] Create LiteOffice OS GRUB boot theme (`branding/grub/liteoffice/`)
- [x] Create LiteOffice OS Plymouth boot/shutdown splash theme (`branding/plymouth/liteoffice/`)
- [x] Design custom GTK-3, GTK-2, and Openbox window theme `LiteOffice-Dark` (`#16191f` base, `#2563eb` cobalt)
- [x] Develop native GTK applications:
  - [x] `liteoffice-about` (hardware specs, kernel, RAM, storage, OS release)
  - [x] `liteoffice-welcome` (offline user guide, features, quick start settings)
  - [x] `liteoffice-control-center` (display resolution, sound volume, wallpaper picker, power)
  - [x] `liteoffice-monitor` (live CPU, memory, disk, network, and process tree)
- [x] Develop system health daemon `liteoffice-healthd` and OpenRC service `init.d/liteoffice-health`
- [x] Develop CLI administrative tools:
  - [x] `liteoffice-pkg` (package installer, checker, search, cache cleaner)
  - [x] `liteoffice-automate` (declarative `prepare` -> `plan` -> `apply` configuration lifecycle)
  - [x] `liteoffice-manifest` (SHA-256 and octal permission tracker `/etc/liteoffice/manifest.json`)
  - [x] `liteoffice-security` (permissions audit, configuration backup, restore)
- [x] Configure default user skeleton `/etc/skel` (100% desktop shortcuts, panel, theme inheritance)
- [x] Build and run master installer (`scripts/05_install_liteoffice_suite.sh`)
- [x] Build and execute automated test suite (`tests/test_liteoffice_suite.sh`): 14/14 PASS (100%)
- [x] Verify QEMU boot and idle memory: **74 MB idle RAM** (Target: <= 120 MB)

### Stage 6: Office Applications & Printing Stack
- [x] Configure AbiWord & Gnumeric for low-RAM tier (512 MB profile)
- [x] Configure LibreOffice for standard tier (1 GB–2 GB profile)
- [x] Implement adaptive launchers: `lite-launch-office`, `lite-launch-spreadsheet`, `lite-launch-pdf`
- [x] Integrate lightweight PDF viewer (`qpdfview`)
- [x] Configure and tune CUPS printer daemon (`/etc/cups/cupsd.conf`, 7.6 MB RSS)
- [x] Configure MIME associations (`/etc/xdg/mimeapps.list`)
- [x] Execute installer `scripts/06_install_office_suite.sh`
- [x] Build and execute test suite `tests/test_office_suite.sh`: 9/9 PASS (100%)
- [x] Verify QEMU idle RAM with desktop and CUPS daemon: **74 MB** (Target: <= 120 MB)

### Stage 7: RAM Optimization & Memory Daemons
- [x] Implement `/etc/sysctl.d/99-lowmem.conf` with low-memory kernel parameters
- [x] Configure `earlyoom` OOM supervisor service in OpenRC (`/etc/init.d/lite-oom`)
- [x] Configure dynamic ZRAM compressed swap auto-scaler (`/etc/init.d/zram-swap`, 150% RAM scaling)
- [x] Configure hardware memory profile detection daemon (`/etc/init.d/lite-profile-detect`)
- [x] Execute installer `scripts/07_optimize_memory.sh`
- [x] Build and execute test suite `tests/test_memory_optimization.sh`: 6/6 PASS (100%)

### Stage 8: Offline Installer & Live Hybrid ISO
- [x] Implement modular system installer (`installer/lite-installer.sh`) supporting BIOS (MBR) and UEFI (GPT)
- [x] Create desktop shortcut and menu launcher for installer (`installer/liteoffice-installer.desktop`)
- [x] Implement hybrid live ISO builder (`scripts/08_generate_iso.sh`) using multi-threaded zstd SquashFS and GRUB 2.14
- [x] Support dual console boot (`console=ttyS0 console=tty1`) in GRUB menu and live initramfs
- [x] Build and execute test suite `tests/test_live_iso.sh`: 3/3 PASS (100%)
- [x] Generated artifact: `output/liteoffice-1.0-x86_64.iso` (414 MB, Hybrid BIOS + UEFI)

### Stage 9: Performance Benchmarking & Final Documentation
- [x] Implement multi-RAM tier benchmark harness (`tests/test_multi_ram_matrix.sh`)
- [x] Verify 512 MB RAM Tier: **75 MB used RAM** (Limit <= 120 MB) [PASS]
- [x] Verify 1 GB RAM Tier: **85 MB used RAM** (Limit <= 180 MB) [PASS]
- [x] Verify 2 GB RAM Tier: **98 MB used RAM** (Limit <= 250 MB) [PASS]
- [x] Create formal benchmark report (`docs/benchmark-report.md`)
