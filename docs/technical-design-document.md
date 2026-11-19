# Technical Design Document (TDD) — Lite Office OS

## 1. Build Pipeline & Toolchain Architecture

The build pipeline is designed to execute cleanly inside a standard Linux build host (or WSL2 Ubuntu environment) with minimal external assumptions.

### 1.1 Master Build Pipeline Stages
```
+-------------------------------------------------------------+
| Stage 1: scripts/01_host_check.sh                           |
| Validates host packages, compiler, disk space, and root/sudo|
+-------------------------------------------------------------+
                               |
+-------------------------------------------------------------+
| Stage 2: scripts/02_build_kernel.sh                         |
| Fetches Linux 6.6 LTS, applies lowmem defconfig, compiles   |
| kernel image (vmlinuz) and essential modules                |
+-------------------------------------------------------------+
                               |
+-------------------------------------------------------------+
| Stage 3: scripts/03_assemble_rootfs.sh                      |
| Bootstraps minimal base, installs OpenRC, Xorg, Openbox,    |
| office applications, and applies skeleton configs           |
+-------------------------------------------------------------+
                               |
+-------------------------------------------------------------+
| Stage 4: scripts/04_generate_iso.sh                         |
| Compresses rootfs into SquashFS, configures GRUB hybrid     |
| (BIOS/UEFI), generates bootable LiteOffice.iso              |
+-------------------------------------------------------------+
                               |
+-------------------------------------------------------------+
| Stage 5: scripts/05_qemu_test.sh                            |
| Runs automated QEMU instances at 512MB, 1GB, 2GB RAM        |
+-------------------------------------------------------------+
```

---

## 2. Kernel Defconfig Technical Specifications

### 2.1 File Location
- `kernel/config/x86_64_lite_defconfig`
- `kernel/config/i686_lite_defconfig`

### 2.2 Critical Kernel Flags
```kconfig
# General Setup
CONFIG_LOCALVERSION="-lite"
CONFIG_DEFAULT_HOSTNAME="liteoffice"
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y
CONFIG_NO_HZ_IDLE=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_PREEMPT=y
CONFIG_PREEMPT_COUNT=y

# Memory Management
CONFIG_SWAP=y
CONFIG_ZSWAP=n
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_ZRAM_WRITEBACK=n
CONFIG_COMPACTION=y
CONFIG_MIGRATION=y
CONFIG_KSM=n

# Filesystem Support
CONFIG_EXT4_FS=y
CONFIG_EXT4_USE_FOR_EXT2=y
CONFIG_VFAT_FS=y
CONFIG_ISO9660_FS=y
CONFIG_JOLIET=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_XZ=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_OVERLAY_FS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y

# Drivers
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
CONFIG_ATA_PIIX=y
CONFIG_BLK_DEV_NVME=y
CONFIG_NET_ETHERNET=y
CONFIG_E1000=m
CONFIG_E1000E=m
CONFIG_R8169=m
CONFIG_WLAN=y
CONFIG_INPUT_EVDEV=y
CONFIG_INPUT_KEYBOARD=y
CONFIG_INPUT_MOUSE=y
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_DRM_I915=m
CONFIG_DRM_RADEON=m
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HDA_INTEL=m
```

---

## 3. Rootfs Base Skeleton Specifications

### 3.1 `/etc/fstab`
```fstab
# /etc/fstab: static file system information
UUID=ROOT_UUID_PLACEHOLDER / ext4 noatime,commit=60,errors=remount-ro 0 1
tmpfs /tmp tmpfs nosuid,nodev,size=256M 0 0
tmpfs /run tmpfs mode=0755,nosuid,nodev 0 0
devpts /dev/pts devpts gid=5,mode=620 0 0
sysfs /sys sysfs defaults 0 0
proc /proc proc defaults 0 0
```

### 3.2 `/etc/sysctl.d/99-lowmem.conf`
```ini
# Memory optimization for low-RAM machines
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.page-cluster = 0
kernel.panic = 10
```

---

## 4. Live ISO Generation Specifications

The ISO is built using `xorriso` with hybrid boot parameters compatible with:
1. **Legacy BIOS**: El Torito bootable MBR with Syslinux or GRUB `i386-pc`.
2. **Modern UEFI**: El Torito EFI System Partition image (`efi.img` formatted FAT16 containing `/EFI/BOOT/BOOTX64.EFI`).

Command structure:
```bash
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso-9660-filenames \
    -volid "LITEOFFICE_LIVE" \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -eltorito-catalog boot/grub/i386-pc/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    --eltorito-alt-boot \
    -e EFI/boot/efiboot.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    -output "LiteOffice-x86_64.iso" \
    "iso_build_dir/"
```
