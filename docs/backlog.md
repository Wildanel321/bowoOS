# Project Backlog — Lite Office OS

## Phase Tracker

| Stage | Description | Status | Deliverables |
| :--- | :--- | :--- | :--- |
| **Stage 1** | Foundation, Documentation & Host Check | **COMPLETED** | Specifications, Project Docs, Repository Tree, Host Validator |
| **Stage 2** | Kernel 6.6 LTS & Minimal BusyBox Initramfs | **COMPLETED** | `x86_64_lite_defconfig`, compiled `vmlinuz-6.6-lite`, initramfs, QEMU early boot (Verified) |
| **Stage 3** | Base Rootfs & OpenRC Init Integration | **COMPLETED** | Base filesystem skeleton, OpenRC services (`zram-swap`, `lite-profile-detect`, `lite-oom`), agetty consoles, unprivileged `liteuser` (Verified in QEMU at 512M) |
| **Stage 4** | X11 Display Server & Openbox Desktop Shell | **NEXT (PENDING APPROVAL)** | Xorg minimal, Openbox WM, Tint2 panel, PCManFM desktop, clean theme |
| **Stage 5** | Office Suite & Document Processing Stack | PENDING | AbiWord, Gnumeric, LibreOffice, PDF viewer, CUPS printing daemon |
| **Stage 6** | RAM Optimization Daemons & Memory Profiling | PENDING | ZRAM autoscaler, earlyoom supervisor, sysctl low-RAM tuning |
| **Stage 7** | Offline Installer & Live Hybrid ISO | PENDING | CLI/TUI installer, GRUB EFI/BIOS hybrid ISO generator |
| **Stage 8** | QEMU Benchmark & Verification Suite | PENDING | Multi-RAM profile benchmarks (512M, 1G, 2G), test report |

---

## Detailed Task Backlog

### Stage 1: Foundation & Specifications
- [x] Create project directivess (`GEMINI.md`)
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
- [ ] Configure minimal Xorg server and video drivers
- [ ] Implement Openbox configuration (`desktop/openbox/rc.xml`, `menu.xml`, `autostart`)
- [ ] Implement Tint2 configuration (`desktop/tint2/tint2rc`)
- [ ] Implement PCManFM desktop configuration
- [ ] Apply modern, clean, lightweight GTK/Openbox theme

### Stage 5: Office Applications
- [ ] Configure AbiWord & Gnumeric for low-RAM tier
- [ ] Configure LibreOffice for standard tier
- [ ] Integrate lightweight PDF viewer (`qpdfview`)
- [ ] Configure CUPS printer daemon
- [ ] Configure MIME associations (`office/mimeapps.list`)

### Stage 6: RAM Optimization
- [ ] Implement `/etc/sysctl.d/99-lowmem.conf`
- [ ] Configure `earlyoom` service
- [ ] Benchmark idle memory consumption

### Stage 7: Installer & Live ISO
- [ ] Implement installer engine (`installer/lite-installer.sh`)
- [ ] Configure GRUB hybrid bootloader (`bootloader/grub-bios.cfg`, `grub-uefi.cfg`)
- [ ] Implement ISO generator script (`scripts/04_generate_iso.sh`)

### Stage 8: Automated Verification
- [ ] Implement automated QEMU test harness (`scripts/05_qemu_test.sh`)
- [ ] Run 512 MB, 1 GB, 2 GB test matrices
- [ ] Generate final benchmark and compatibility report (`docs/benchmark-report.md`)
