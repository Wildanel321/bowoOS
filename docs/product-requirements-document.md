# Product Requirements Document (PRD) — Lite Office OS

## 1. Vision & Executive Summary
**Lite Office OS** is a specialized, lightweight desktop operating system tailored for resource-constrained personal computers with 512 MB to 2 GB of RAM. The objective is to revive older PCs and enable cost-effective, distraction-free office computing in educational institutions, government administrative posts, rural development centers, and small offices without sacrificing security, aesthetic appeal, or hardware compatibility.

## 2. Target Personas & Use Cases
- **School & Educational Computer Labs**: Operating legacy desktop computers (Pentium Dual-Core, Core 2 Duo, early Celeron/Atom) for word processing, basic spreadsheets, and reading textbooks in PDF.
- **Micro / Small Office Administration**: Invoicing, document creation, offline printing, and inventory spreadsheets.
- **Budget Hardware Users**: End-users seeking a fast, responsive desktop experience on netbooks or older laptops without modern OS bloat.

## 3. Core Feature Requirements

### 3.1 Memory & System Efficiency
- **Idle Memory Ceiling**:
  - 512 MB hardware: System must idle below 120 MB RAM.
  - 1 GB hardware: System must idle below 180 MB RAM.
  - 2 GB hardware: System must idle below 250 MB RAM.
- **Storage Footprint**: Full operating system installation must fit in under 4 GB of storage, with Live ISO image under 1.2 GB.

### 3.2 Office Productivity Stack
- Full capability to create, read, and edit:
  - Text Documents: `.docx`, `.odt`, `.txt`, `.rtf`.
  - Spreadsheets: `.xlsx`, `.ods`, `.csv`.
  - Presentations: `.pptx`, `.odp`.
  - Portable Documents: `.pdf`.
- Reliable printing and scanning subsystem via CUPS and SANE.

### 3.3 User Experience & Desktop Interface
- Intuitive traditional desktop layout:
  - Bottom panel with start menu, active window taskbar, system tray, volume slider, network indicator, and clock.
  - Desktop shortcut icons with single/double-click execution.
  - Clean, high-contrast GTK3/Openbox theme avoiding generic AI-slop visual styles.
- Responsive file management with thumbnail previews and archive decompression (`.zip`, `.tar.gz`, `.rar`).

### 3.4 Installation & Deployment
- Hybrid Live ISO supporting boot via Legacy BIOS (Syslinux/ISOLINUX or GRUB) and modern UEFI (x86_64 EFI binary).
- User-friendly installer with automated "Use Entire Disk" partitioning and manual partition manager.
- 100% offline installation capability without requiring internet connectivity during setup.

## 4. Non-Functional Requirements
- **Reliability**: No kernel panics or hard system freeze when RAM is exhausted; ZRAM and early OOM daemon must preserve system responsiveness.
- **Security**: Non-root desktop account by default, unprivileged Xorg server, verified package signatures, minimal background network ports open.
- **Determinism**: 100% script-driven build pipeline capable of automated execution.
