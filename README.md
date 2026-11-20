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

## 🛠️ Ringkasan Pembaruan & Perbaikan Bug Terbaru

- **Perbaikan Terminal Hang, Blank Prompt & Tampilan Modern LXTerminal**:
  - *Fix Hang & Layar Hitam (PTY Allocation Failure)*: Memperbaiki masalah LXTerminal macet dengan kursor kotak mati di pojok kiri atas dan tidak responsif. Masalah terjadi karena filesystem virtual `/dev/pts` belum di-mount saat boot OpenRC, sehingga library VTE gagal mengalokasikan pseudo-terminal (`posix_openpt()`). Dibuat service OpenRC baru `devpts` di runlevel `sysinit` yang otomatis me-mount `/dev/pts` (`gid=5,mode=620,ptmxmode=666`) dan `/dev/shm` (`tmpfs mode=1777`).
  - *Fix Shell Prompt & Banner Sambutan*: Memperbaiki `.bashrc` yang sebelumnya keluar terlalu awal karena pengecekan non-interaktif `$PS1`. Kini prompt bergaya modern cyan/hijau dua baris lengkap dengan petunjuk instalasi OS, serta alias cepat: `install` (`sudo lite-installer`), `status` (`liteoffice-health --check`), dan `monitor` (`liteoffice-monitor --cli`).
  - *Tampilan Terminal Fluent Dark Modern*: Mengganti tampilan menubar gepeng (*FileEditTabsHelp*) dengan konfigurasi `hidemenubar=true`, font Monospace 11 yang tajam, palette OneDark 16 warna, dan ukuran jendela default 92x26 yang lapang.
  - *Pintasan Install OS Manual (Terminal Mode)*: Menambahkan ikon desktop `Install OS (Terminal Mode)` (`liteoffice-installer-cli.desktop`) bagi pengguna yang ingin menginstal OS secara langsung via Terminal TUI interaktif tanpa ketergantungan GUI.

- **Perbaikan 4 Bug Utama Sistem Installer (`liteoffice-installer` & `lite-installer.sh`)**:
  1. *Fix GUI GTK3 Tidak Muncul (X11 Authorization & `sudo` Environment)*: Menambahkan `xhost +SI:localuser:root` dan meneruskan variabel `DISPLAY` serta `XAUTHORITY` secara eksplisit setelah `sudo` (bukan mengandalkan `sudo -E` yang di-reset oleh Debian 12), sehingga window GUI GTK3 selalu terbuka sempurna.
  2. *Fix Gagal Copy OS ke HDD (`SOURCE_DIR` Live Rootfs)*: Menambahkan `/run/live/rootfs/filesystem.squashfs` sebagai kandidat utama dan memvalidasi keberadaan subdirektori `/usr` (`[ -d "$candidate/usr" ]`), mencegah penyalinan folder mount kosong.
  3. *Fix `TypeError` CLI Fallback*: Memperbaiki signature lambda progress callback di `run_cli_installer()` dari 2 argumen menjadi `lambda frac, msg, step=1: ...` agar cocok dengan 3 argumen `InstallWorker.set_progress()`.
  4. *Fix Bootloader Hybrid UEFI & Legacy BIOS + Initramfs*: Menambahkan bind-mount `/run` sebelum masuk `chroot`, melakukan update initramfs target (`update-initramfs -u -k all`) sebelum `grub-mkconfig` agar partisi ext4 HDD langsung terbaca, dan memastikan paket bootloader hybrid (`grub-pc-bin`, `grub-efi-amd64-bin`, `efibootmgr`, `dosfstools`, `x11-xserver-utils`) terinstal lengkap.
- **Paket Keamanan Tingkat Tinggi (Hardened Security) & Stabilitas Total (`liteoffice-firewall` & `liteoffice-health`)**:
  - **Stateful Firewall Bawaan**: Service firewall otomatis aktif saat boot (`init/init.d/liteoffice-firewall`), memblokir semua lalu lintas masuk (*inbound traffic DROP*) tanpa izin dari luar jaringan, sementara lalu lintas keluar (*outbound ACCEPT*) tetap lancar untuk browsing dan pekerjaan kantor. Dilengkapi utilitas CLI `liteoffice-firewall status`.
  - **Pengerasan Kernel & Anti-Exploit**: Diterapkan proteksi kernel menyeluruh di `/etc/sysctl.d/99-security.conf` mencakup Full ASLR Level 2, penyembunyian pointer kernel (`kptr_restrict`), pembatasan dmesg, pencegahan injeksi memori (`yama.ptrace_scope`), penonaktifan unprivileged eBPF, pencegahan serangan race condition symlink/hardlink di `/tmp`, serta proteksi jaringan dari SYN Flood, IP spoofing, dan Smurf Attack.
  - **Daemon Pengawas Stabilitas & Self-Healing (`liteoffice-health`)**: Berjalan di latar belakang untuk memantau tekanan RAM/ZRAM, otomatis membersihkan file sementara jika sisa disk < 150 MB, serta langsung menghidupkan ulang (*auto-revive*) window manager Openbox atau taskbar Tint2 jika tertutup tidak sengaja.
  - **Menu "Security" di Control Center**: Menyajikan badge status keamanan real-time (Firewall, ASLR, Exploit Mitigation, dan OOM Guard) dengan tombol audit keamanan sekali klik.
- **Dialog Session & Power Control Modern Fluent Dark (`liteoffice-session`)**:
  - Memperbaiki masalah hilangnya/tidak munculnya antarmuka Session & Power Control. Menggantikan dialog zenity lama dengan aplikasi GUI GTK 3 / Fluent Dark khusus (`liteoffice-session`) yang elegan, responsif, dan ringan (~8 MB RAM).
  - Dilengkapi 5 kartu aksi interaktif berukuran besar dengan visual modern: **Shut Down** (merah), **Restart** (biru), **Sign Out** (kuning/amber), **Lock Screen** (ungu), dan **Sleep / Suspend** (hijau), serta tombol Cancel / tombol `Escape`.
  - Terintegrasi penuh ke semua titik akses desktop: Start Menu (`Win`), Control Center (tab Power), pintasan taskbar Tint2, menu klik kanan desktop Openbox, pintasan keyboard `Super+L` & `Ctrl+Alt+Del`, serta file desktop di `/usr/share/applications/liteoffice-session.desktop`.
  - Eksekusi shutdown dan restart terhubung dengan tampilan wallpaper penutup resmi (`liteoffice-shutdown.png`) dan splash shutdown yang halus dan aman.
- **Windows 11 Fluent Dark Start Menu (`liteoffice-menu`)**:
  - Antarmuka menu aplikasi baru persis Windows 11 modern: bilah pencarian cepat (*Type here to search*), kisi aplikasi tersemat (*Pinned*), tombol navigasi *All apps →* berurutan abjad (A-Z), kartu *Recommended* (Console, System Monitor, Settings, Installer), serta footer profil pengguna dan menu daya (*Shut Down, Restart, Log Out, Lock*). Terhubung dengan tombol taskbar Tint2 dan tombol keyboard `Super` (Windows Key).
- **Pemasangan Driver & Aplikasi Otomatis Pasca-Instalasi (`liteoffice-auto-provision`)**:
  - Mesin cerdas yang otomatis mendeteksi hardware fisik saat instalasi atau boot pertama (CPU microcode Intel/AMD, akselerasi GPU Mesa/Vulkan, chip Wi-Fi/LAN, driver printer CUPS) serta langsung mengunduh dan memasang aplikasi kantor lengkap (LibreOffice Suite, qpdfview, audio control, file-roller) di latar belakang secara otomatis tanpa perlu diinstal satu per satu.
- **Installer Anti-Gagal (Self-Healing Launcher)**: 
  - Jika paket Python atau library belum lengkap, sistem langsung mengunduh/memasang otomatis (*on-the-fly*).
  - Jika display grafis (X11 GUI) gagal terbuka karena kendala driver/resolusi, sistem **segera mengalihkan otomatis** ke Terminal/CLI Installer interaktif tanpa hang atau stuck kursor.
  - Penambahan tombol `< Back` yang selalu responsif, kalkulasi partisi dinamis, serta perlindungan buffer swap minimal 8 GB.
- **Penyalinan Kernel Otomatis ke Harddisk Fisik**:
  - Memperbaiki kegagalan instalasi ke drive fisik (`/dev/sda` / `\\.\PhysicalDrive3`): kernel Linux LTS (`vmlinuz`) dan `initrd.img` kini otomatis disalin ke partisi target `/boot/` dan dibuatkan entri bootloader `grub.cfg` persisten dengan UUID yang valid.
- **Repository Resmi untuk Update & Upgrade Paket**:
  - Dikonfigurasi mirror lengkap Debian 12 (Bookworm) di `/etc/apt/sources.list` (`main`, `contrib`, `non-free`, `non-free-firmware`, `security`, `updates`, dan `backports`).
  - Disediakan utilitas praktis `liteoffice-upgrade` untuk update & upgrade sistem satu perintah.
- **Perbaikan Booting VirtualBox (Mencegah Guru Meditation)**:
  - Mengeliminasi port serial di GRUB default dan menggunakan handover text-mode (`set gfxpayload=text`) untuk mencegah CPU Triple Fault pada mode Hyper-V/NEM Windows.
- **Native OpenRC UDEV & Driver Firmware**:
  - Mengintegrasikan service native `udev` di OpenRC untuk mengenali seluruh hardware secara dinamis, mengaktifkan firmware WiFi/LAN (Realtek, Intel, Atheros), serta device ZRAM swap `/dev/zram0`.
- **Windows 10/11 Task Manager**:
  - System Monitor baru bergaya Fluent Dark modern dengan grafik waveform Cairo real-time, filter proses cepat, dan fitur "End Task".

---

## 📄 License & Documentation
Detailed architectural and implementation documentation can be found in the [`/docs`](docs/) directory.
Licensed under GNU General Public License v2 (GPL-2.0).
