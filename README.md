# Lite Office OS

> **A Lightweight Linux-Based Desktop Operating System for Legacy and Low-End Computers (RAM 512 MB – 2 GB).**

Lite Office OS is an engineered, modular Linux distribution built specifically to provide high performance, low memory footprint, rock-solid stability, and out-of-the-box office productivity on resource-constrained personal computers.

---

## 🎯 Target Specifications

| Component | Minimum | Recommended |
| :--- | :--- | :--- |
| **Processor** | x86 32-bit (i686) or x86_64 | x86_64 Dual-Core |
| **RAM** | 512 MB | 1 GB – 2 GB |
| **Storage** | 4 GB | 16 GB SSD/HDD |
| **Graphics** | Basic VGA (VBE / Framebuffer / KMS) | Intel / AMD Integrated Graphics |
| **Boot Mode** | Legacy BIOS | BIOS + UEFI |
| **Filesystem** | ext4 | ext4 |

---

## 🚀 Key Architectural Highlights

- **Custom Linux 6.6 LTS Kernel**: Highly tuned defconfig with aggressive preemption, minimal driver bloat, integrated ZRAM, and zstd/lz4 compression.
- **OpenRC + eudev Init System**: Ultra-fast boot times, modular runlevels, and negligible idle memory consumption compared to systemd.
- **Ultra-Lightweight Desktop**: Modern, distraction-free Openbox window manager, Tint2 panel, PCManFM file manager, and customized high-contrast lightweight themes.
- **Adaptive Office Profiling**:
  - **512 MB RAM Mode**: AbiWord + Gnumeric + qpdfview + minimal single-process web browser (~100 MB idle).
  - **1 GB – 2 GB RAM Mode**: LibreOffice Suite + Firefox ESR tuned with process limits (~180–230 MB idle).
- **Integrated Memory Guard**: Dynamic ZRAM swap allocation + early OOM daemon to prevent lockups during heavy document workloads.
- **Hybrid Live / Installer ISO**: Boots on both Legacy BIOS and UEFI systems; includes an offline, step-by-step partitioner and installer.

---

## 📁 Repository Layout

```
lite-office-os/
├── docs/             # Technical specifications (PRD, SRS, ADD, TDD, Backlog)
├── kernel/           # Linux Kernel 6.6 LTS defconfigs & build scripts
├── initramfs/        # Custom BusyBox early userspace generator
├── rootfs/           # Root filesystem creation scripts and skeleton configs
├── init/             # OpenRC service scripts (ZRAM, OOM guard, profile detector)
├── desktop/          # Openbox, Tint2, and PCManFM configurations and themes
├── office/           # Office suite configurations and MIME associations
├── installer/        # TUI/CLI offline system installer
├── iso/              # Live ISO generator (xorriso + GRUB 2.12 hybrid)
├── scripts/          # Numbered stage scripts (01_host_check.sh, etc.)
├── tests/            # Automated QEMU test harnesses
├── Makefile          # Build orchestration entry point
├── build.sh          # Interactive / batch build script
├── GEMINI.md         # Architecture directives and developer context
└── LEARNINGS.gemini.md # Engineering learning log
```

---

## 🛠️ Build Requirements & Quick Start

### Prerequisites (Host System: Ubuntu 24.04/26.04 or Debian 12+)
To build Lite Office OS, install the build dependencies on your Linux host or WSL2 environment:

```bash
sudo apt-get update && sudo apt-get install -y \
    build-essential bison flex libssl-dev libelf-dev bc \
    debootstrap xorriso mtools dosfstools squashfs-tools \
    qemu-system-x86 qemu-utils git rsync kmod
```

### Build Steps

1. **Verify host environment**:
   ```bash
   make host-check
   ```
2. **Build custom kernel and modules**:
   ```bash
   make kernel
   ```
3. **Assemble base root filesystem and desktop**:
   ```bash
   make rootfs
   ```
4. **Generate bootable Live ISO**:
   ```bash
   make iso
   ```
5. **Test in QEMU (e.g., 512 MB RAM simulation)**:
   ```bash
   make test-qemu-512m
   ```

---

## 📄 License & Documentation
Detailed architectural and implementation documentation can be found in the [`/docs`](docs/) directory.
Licensed under GNU General Public License v2 (GPL-2.0).
