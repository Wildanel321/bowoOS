# Software Requirements Specification (SRS) — Lite Office OS

## 1. Introduction

### 1.1 Purpose
This document specifies the software requirements for **Lite Office OS**, defining functional and non-functional requirements, interfaces, system constraints, and verification criteria.

### 1.2 Scope
Lite Office OS includes a customized Linux kernel (6.6 LTS), an early-stage BusyBox initramfs, an OpenRC-based service manager, an X11 graphical display stack, an Openbox window manager with Tint2 panel, a complete suite of office applications, an offline installer, and a hybrid Live ISO.

---

## 2. Overall Description

### 2.1 Hardware Constraints
- **CPU**: x86_64 (Intel 64 / AMD64) and i686 (32-bit x86).
- **RAM**: 512 MB to 2 GB physical RAM.
- **Storage**: 4 GB minimum storage drive (IDE, SATA, NVMe, eMMC, USB flash).
- **Display**: VBE / Framebuffer / DRM-KMS capable display adapter (minimum 800x600 resolution).

### 2.2 System Architecture Overview
```
+-------------------------------------------------------------+
|                  Desktop & Office Layer                     |
|  Openbox WM | Tint2 Panel | PCManFM | AbiWord/LibreOffice   |
+-------------------------------------------------------------+
|                     Display & Audio Layer                   |
|           Xorg Minimal Server | ALSA / Pipewire             |
+-------------------------------------------------------------+
|                     Userland Services                       |
|   OpenRC Init | eudev | D-Bus | ZRAM-Swap | EarlyOOM        |
+-------------------------------------------------------------+
|                     C Library & Core                        |
|             Optimized GNU C Library (glibc)                 |
+-------------------------------------------------------------+
|                     Linux Kernel Layer                      |
|       Custom Linux 6.6 LTS Kernel (Preempt, ZRAM, ext4)     |
+-------------------------------------------------------------+
|                        Bootloader                           |
|            GRUB 2.12 (Hybrid BIOS / UEFI)                   |
+-------------------------------------------------------------+
```

---

## 3. Specific Functional Requirements

### 3.1 Kernel & Early Boot
- **REQ-KER-01**: Kernel version shall be Linux LTS 6.6.y.
- **REQ-KER-02**: Kernel preemption shall be set to `CONFIG_PREEMPT=y` (Low-Latency Desktop).
- **REQ-KER-03**: Memory compaction and swap support shall be compiled-in (`CONFIG_SWAP=y`, `CONFIG_COMPACTION=y`).
- **REQ-KER-04**: ZRAM compressed swap module shall be built-in (`CONFIG_ZRAM=y`) with `CONFIG_CRYPTO_ZSTD=y` and `CONFIG_CRYPTO_LZ4=y`.
- **REQ-KER-05**: Storage drivers (`AHCI`, `SATA`, `NVMe`, `USB_STORAGE`) and filesystems (`ext4`, `vfat`, `iso9660`, `squashfs`) shall be compiled-in or available in initramfs.

### 3.2 Init & Service Management
- **REQ-INIT-01**: Init system shall be `OpenRC` version >= 0.50.
- **REQ-INIT-02**: Device node population and hotplug handling shall be managed by `eudev`.
- **REQ-INIT-03**: Network interface auto-configuration shall be provided via `dhcpcd` or `connman`.
- **REQ-INIT-04**: A dynamic ZRAM service (`zram-swap`) shall detect total RAM at boot and initialize a compressed swap device scaled to 1.5x RAM for <=1 GB or 1x RAM for 2 GB.
- **REQ-INIT-05**: Out-of-memory prevention shall be managed by `earlyoom` with swap thresholds set to terminate high-RSS offending tasks before kernel panics occur.

### 3.3 Graphical User Interface (GUI)
- **REQ-GUI-01**: Display server shall be `Xorg` minimal server with KMS modesetting and legacy DDX drivers.
- **REQ-GUI-02**: Window management shall be handled by `Openbox`.
- **REQ-GUI-03**: Taskbar, system tray, battery monitor, volume, and clock shall be provided by `Tint2`.
- **REQ-GUI-04**: Desktop icons and file navigation shall be handled by `PCManFM`.
- **REQ-GUI-05**: Application menu shall categorize office, system, multimedia, and settings tools.

### 3.4 Office Applications
- **REQ-APP-01**: Default text editor shall support `.docx`, `.odt`, `.rtf`, `.txt`. On <=768 MB RAM, `AbiWord` shall be default; on >768 MB RAM, `LibreOffice Writer` shall be default.
- **REQ-APP-02**: Default spreadsheet editor shall support `.xlsx`, `.ods`, `.csv`. On <=768 MB RAM, `Gnumeric` shall be default; on >768 MB RAM, `LibreOffice Calc` shall be default.
- **REQ-APP-03**: PDF viewer shall render PDF 1.4-1.7 specifications with memory footprint < 30 MB (`qpdfview`).
- **REQ-APP-04**: Printing stack shall provide CUPS daemon and raster filters for common PCL and PostScript printers.

### 3.5 Installer & Media
- **REQ-INST-01**: The OS shall boot in Live Mode with full graphical desktop without writing to the host hard drive.
- **REQ-INST-02**: The installer shall support both MBR/BIOS and GPT/UEFI target disks.
- **REQ-INST-03**: The installer shall format target partitions to `ext4` and configure swap if physical RAM is <= 1 GB.
- **REQ-INST-04**: The installer shall create a standard user account with `sudo` permissions and set system timezone and keyboard layout.

---

## 4. Verification & Testing Matrix

| Requirement ID | Verification Method | Acceptance Criteria |
| :--- | :--- | :--- |
| `REQ-KER-01` | QEMU Boot Test | `uname -r` returns `6.6.x-lite` |
| `REQ-INIT-04` | Memory Test in QEMU (512M) | `swapon -s` shows `/dev/zram0` active with zstd compression |
| `REQ-GUI-02` | Display Test | Openbox desktop renders at 1024x768 without artifacts |
| `REQ-APP-01` | File Open Test | AbiWord/LibreOffice opens sample `.docx` with <150 MB RSS |
| `REQ-INST-01` | ISO Boot Test | Live ISO boots cleanly on Legacy BIOS and UEFI in QEMU |
