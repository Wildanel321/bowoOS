#!/usr/bin/env python3
# ==============================================================================
# LiteOffice OS — Graphical & CLI System Storage Installer
# Modern GTK 3 interface with dynamic partition configuration:
# - Customizable Root (/) & Home (/home) partitions
# - Configurable Swap with minimum 8 GB safety buffer
# - Automatic UEFI/GPT & Legacy BIOS/MBR detection and bootloader installation
# - Non-blocking multithreaded installation engine with live progress
# ==============================================================================
import os
import sys
import re
import json
import time
import shutil
import threading
import subprocess

# Auto-elevate to root via sudo if launched as regular user
if os.geteuid() != 0:
    try:
        os.execvp("sudo", ["sudo", "-E", sys.executable] + sys.argv)
    except Exception as e:
        print(f"Error elevating to root: {e}", file=sys.stderr)
        sys.exit(1)

# Helper for executing shell commands with logging
def run_command(cmd, log_callback=None):
    if log_callback:
        log_callback(f"$ {cmd}\n")
    proc = subprocess.Popen(
        cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    output = []
    for line in proc.stdout:
        output.append(line)
        if log_callback:
            log_callback(line)
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f"Command failed (code {proc.returncode}): {cmd}\n{''.join(output)}")
    return "".join(output)

def detect_boot_mode():
    return "UEFI" if os.path.isdir("/sys/firmware/efi") else "BIOS"

def get_live_boot_disks():
    """Identifies the parent disk of any live media or root filesystem."""
    live_disks = set()
    try:
        if os.path.exists("/proc/mounts"):
            with open("/proc/mounts", "r") as mf:
                for line in mf:
                    parts = line.split()
                    if len(parts) >= 2 and any(p in parts[1] for p in ["/run/live/medium", "/cdrom", "/rofs", "/run/live/overlay"]):
                        dev_str = parts[0]
                        if dev_str.startswith("/dev/"):
                            bname = os.path.basename(dev_str)
                            # Remove partition number (e.g. sdb1 -> sdb, nvme0n1p1 -> nvme0n1)
                            clean_disk = bname
                            if "nvme" in clean_disk and "p" in clean_disk:
                                clean_disk = clean_disk.rsplit("p", 1)[0]
                            else:
                                clean_disk = clean_disk.rstrip("0123456789")
                            if clean_disk:
                                live_disks.add(clean_disk)
    except Exception:
        pass
    return live_disks

def list_storage_disks():
    """Enumerates all physical and virtual storage drives available for OS installation."""
    disks = []
    live_disks = get_live_boot_disks()
    seen_names = set()

    # Method 1: lsblk JSON parsing
    try:
        raw = subprocess.check_output(
            ["lsblk", "-J", "-b", "-d", "-o", "NAME,SIZE,MODEL,TYPE,TRAN,RM,RO"],
            text=True, stderr=subprocess.DEVNULL
        )
        data = json.loads(raw)
        for dev in data.get("blockdevices", []):
            name = dev.get("name", "").strip()
            dev_type = dev.get("type", "").strip()
            size_bytes = int(dev.get("size", 0))
            model = (dev.get("model") or "").strip() or "Generic Physical Drive"
            
            # Robust read-only flag check (avoid string "0" evaluated as True)
            ro_val = dev.get("ro", False)
            is_ro = ro_val is True or ro_val == 1 or str(ro_val).lower() in ["1", "true", "yes"]

            # Filter out non-disk and RAM/loop devices
            if dev_type and dev_type != "disk":
                continue
            if name.startswith(("loop", "zram", "sr", "dm-", "ram")):
                continue
            if name in live_disks:
                continue

            size_gb = round(size_bytes / (1024 ** 3), 1)
            if size_gb < 4.0:
                continue

            dev_path = f"/dev/{name}"
            disks.append({
                "name": name,
                "path": dev_path,
                "size_bytes": size_bytes,
                "size_gb": size_gb,
                "model": f"{model} {'[Read-Only]' if is_ro else ''}".strip(),
                "tran": dev.get("tran") or "internal",
                "is_ro": is_ro
            })
            seen_names.add(name)
    except Exception:
        pass

    # Method 2: Direct /sys/block fallback scanning (guarantees NVMe, SATA, IDE detection)
    try:
        sys_block = "/sys/block"
        if os.path.isdir(sys_block):
            for entry in os.listdir(sys_block):
                if entry in seen_names:
                    continue
                if entry.startswith(("loop", "zram", "sr", "dm-", "ram")):
                    continue
                if entry in live_disks:
                    continue
                if not (entry.startswith(("sd", "nvme", "vd", "hd", "xvd"))):
                    continue

                size_file = os.path.join(sys_block, entry, "size")
                if not os.path.isfile(size_file):
                    continue

                with open(size_file, "r") as sf:
                    sectors = int(sf.read().strip() or 0)
                size_bytes = sectors * 512
                size_gb = round(size_bytes / (1024 ** 3), 1)
                if size_gb < 4.0:
                    continue

                # Model identification
                model = "Generic Physical Drive"
                model_file = os.path.join(sys_block, entry, "device", "model")
                if os.path.isfile(model_file):
                    try:
                        with open(model_file, "r") as mf:
                            model = mf.read().strip() or model
                    except Exception:
                        pass

                ro_file = os.path.join(sys_block, entry, "ro")
                is_ro = False
                if os.path.isfile(ro_file):
                    try:
                        with open(ro_file, "r") as rf:
                            is_ro = rf.read().strip() == "1"
                    except Exception:
                        pass

                dev_path = f"/dev/{entry}"
                disks.append({
                    "name": entry,
                    "path": dev_path,
                    "size_bytes": size_bytes,
                    "size_gb": size_gb,
                    "model": f"{model} {'[Read-Only]' if is_ro else ''}".strip(),
                    "tran": "internal",
                    "is_ro": is_ro
                })
                seen_names.add(entry)
    except Exception as e:
        print(f"Fallback sysfs drive enumeration error: {e}", file=sys.stderr)

    return disks

def get_partition_path(disk_path, part_num):
    if disk_path[-1].isdigit():
        return f"{disk_path}p{part_num}"
    return f"{disk_path}{part_num}"

# ==============================================================================
# Installation Worker Engine (runs in background thread)
# ==============================================================================
class InstallWorker:
    def __init__(self, config, progress_cb, log_cb, finish_cb):
        self.config = config
        self.progress_cb = progress_cb
        self.log_cb = log_cb
        self.finish_cb = finish_cb
        self.stop_requested = False

    def log(self, text):
        if self.log_cb:
            self.log_cb(text)

    def set_progress(self, frac, status):
        if self.progress_cb:
            self.progress_cb(frac, status)

    def run(self):
        try:
            self._do_install()
            if self.finish_cb:
                self.finish_cb(True, "Installation completed successfully!")
        except Exception as e:
            err_msg = str(e)
            self.log(f"\n[ERROR] {err_msg}\n")
            if self.finish_cb:
                self.finish_cb(False, err_msg)

    def _do_install(self):
        cfg = self.config
        target_disk = cfg["target_disk"]
        boot_mode = cfg["boot_mode"]
        swap_gb = cfg["swap_gb"]
        root_gb = cfg["root_gb"]
        home_gb = cfg.get("home_gb", 0)
        use_separate_home = cfg.get("use_separate_home", False)
        hostname = cfg.get("hostname", "liteoffice").strip() or "liteoffice"
        username = cfg.get("username", "liteuser").strip() or "liteuser"
        realname = cfg.get("realname", "Lite User").strip() or "Lite User"
        password = cfg.get("password", "liteoffice")
        autologin = cfg.get("autologin", True)

        self.set_progress(0.05, f"Unmounting existing partitions on {target_disk}...")
        self.log(f"=== Starting LiteOffice OS Installation on {target_disk} ===\n")
        self.log(f"Boot Mode       : {boot_mode}\n")
        self.log(f"Swap Allocation : {swap_gb} GB (Min 8 GB enforced)\n")
        self.log(f"Root Allocation : {root_gb} GB\n")
        if use_separate_home:
            self.log(f"Home Allocation : {home_gb} GB\n")
        self.log("------------------------------------------------------------\n")

        # 1. Unmount existing partitions and deactivate swap on target disk
        try:
            self.log("Disabling swap and unmounting partitions on target storage...\n")
            subprocess.run(f"swapoff {target_disk}* 2>/dev/null || true", shell=True)
            subprocess.run(f"umount -f -l {target_disk}* 2>/dev/null || true", shell=True)
            parts = subprocess.check_output(
                ["lsblk", "-lno", "NAME", target_disk], text=True
            ).splitlines()
            base_name = os.path.basename(target_disk)
            for part in parts:
                if part.strip() and part.strip() != base_name:
                    part_dev = f"/dev/{part.strip()}"
                    subprocess.run(["swapoff", part_dev], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    subprocess.run(["umount", "-f", "-l", part_dev], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Wipe lingering partition signatures to ensure clean partition table creation
            subprocess.run(["wipefs", "-a", "-f", target_disk], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["partprobe", target_disk], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(1)
        except Exception as e:
            self.log(f"Note while preparing target disk: {e}\n")

        mount_target = "/mnt/liteoffice_target"
        subprocess.run(["umount", "-l", mount_target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.makedirs(mount_target, exist_ok=True)

        # 2. Partitioning Disk
        self.set_progress(0.12, "Creating partition table and geometry...")
        # Wipe first 16 MB to clear old MBR/GPT signatures
        run_command(f"dd if=/dev/zero of={target_disk} bs=1M count=16 status=none", self.log)

        part_efi = None
        part_swap = None
        part_root = None
        part_home = None

        if boot_mode == "UEFI":
            # GPT Layout:
            # 1: ESP (fat32, 512 MiB)
            # 2: Swap (swap_gb)
            # 3: Root (root_gb)
            # 4: Home (remaining, if enabled)
            run_command(f"parted -s {target_disk} mklabel gpt", self.log)
            esp_start = 1
            esp_end = 513
            run_command(f"parted -s {target_disk} mkpart 'ESP' fat32 {esp_start}MiB {esp_end}MiB", self.log)
            run_command(f"parted -s {target_disk} set 1 esp on", self.log)
            part_efi = get_partition_path(target_disk, 1)

            swap_start = esp_end
            swap_end = swap_start + int(swap_gb * 1024)
            run_command(f"parted -s {target_disk} mkpart 'LiteOfficeSwap' linux-swap {swap_start}MiB {swap_end}MiB", self.log)
            part_swap = get_partition_path(target_disk, 2)

            root_start = swap_end
            if use_separate_home and home_gb > 0:
                root_end = root_start + int(root_gb * 1024)
                run_command(f"parted -s {target_disk} mkpart 'LiteOfficeRoot' ext4 {root_start}MiB {root_end}MiB", self.log)
                part_root = get_partition_path(target_disk, 3)

                home_start = root_end
                run_command(f"parted -s {target_disk} mkpart 'LiteOfficeHome' ext4 {home_start}MiB 100%", self.log)
                part_home = get_partition_path(target_disk, 4)
            else:
                run_command(f"parted -s {target_disk} mkpart 'LiteOfficeRoot' ext4 {root_start}MiB 100%", self.log)
                part_root = get_partition_path(target_disk, 3)
        else:
            # BIOS / MBR Layout:
            # 1: Swap (swap_gb)
            # 2: Root (root_gb, boot flag)
            # 3: Home (remaining, if enabled)
            run_command(f"parted -s {target_disk} mklabel msdos", self.log)
            swap_start = 1
            swap_end = swap_start + int(swap_gb * 1024)
            run_command(f"parted -s {target_disk} mkpart primary linux-swap {swap_start}MiB {swap_end}MiB", self.log)
            part_swap = get_partition_path(target_disk, 1)

            root_start = swap_end
            if use_separate_home and home_gb > 0:
                root_end = root_start + int(root_gb * 1024)
                run_command(f"parted -s {target_disk} mkpart primary ext4 {root_start}MiB {root_end}MiB", self.log)
                run_command(f"parted -s {target_disk} set 2 boot on", self.log)
                part_root = get_partition_path(target_disk, 2)

                home_start = root_end
                run_command(f"parted -s {target_disk} mkpart primary ext4 {home_start}MiB 100%", self.log)
                part_home = get_partition_path(target_disk, 3)
            else:
                run_command(f"parted -s {target_disk} mkpart primary ext4 {root_start}MiB 100%", self.log)
                run_command(f"parted -s {target_disk} set 2 boot on", self.log)
                part_root = get_partition_path(target_disk, 2)

        run_command(f"partprobe {target_disk} 2>/dev/null || true", self.log)
        time.sleep(1.5)

        # 3. Format Partitions
        self.set_progress(0.25, "Formatting partitions with filesystems...")
        if part_efi:
            self.log(f"Formatting EFI partition: {part_efi}\n")
            run_command(f"mkfs.vfat -F32 -n 'LITE_EFI' {part_efi}", self.log)

        self.log(f"Formatting Swap partition ({swap_gb} GB): {part_swap}\n")
        run_command(f"mkswap -L 'LITE_SWAP' {part_swap}", self.log)

        self.log(f"Formatting Root partition: {part_root}\n")
        run_command(f"mkfs.ext4 -F -q -L 'LITEOFFICE' {part_root}", self.log)

        if part_home:
            self.log(f"Formatting Home partition: {part_home}\n")
            run_command(f"mkfs.ext4 -F -q -L 'LITE_HOME' {part_home}", self.log)

        # 4. Mount Target
        self.set_progress(0.35, "Mounting target filesystem layout...")
        run_command(f"mount {part_root} {mount_target}", self.log)

        if part_efi:
            os.makedirs(f"{mount_target}/boot/efi", exist_ok=True)
            run_command(f"mount {part_efi} {mount_target}/boot/efi", self.log)

        if part_home:
            os.makedirs(f"{mount_target}/home", exist_ok=True)
            run_command(f"mount {part_home} {mount_target}/home", self.log)

        # 5. Synchronize Files from Live System
        self.set_progress(0.45, "Synchronizing system files from Live image...")
        source_dir = "/"
        for candidate in ["/run/live/rootfs", "/run/live/rofs", "/rofs"]:
            if os.path.isdir(candidate):
                source_dir = candidate
                break
        self.log(f"Copying OS from source: {source_dir} -> {mount_target} ...\n")

        rsync_cmd = (
            f"rsync -aHAX "
            f"--exclude='/proc/*' --exclude='/sys/*' --exclude='/dev/*' "
            f"--exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' "
            f"--exclude='/media/*' --exclude='/lost+found' "
            f"{source_dir}/ {mount_target}/"
        )
        run_command(rsync_cmd, self.log)

        for p in ["proc", "sys", "dev", "tmp", "run", "mnt", "media", "home"]:
            os.makedirs(os.path.join(mount_target, p), exist_ok=True)
        os.chmod(os.path.join(mount_target, "tmp"), 0o1777)

        # 6. Generate Persistent /etc/fstab
        self.set_progress(0.80, "Configuring /etc/fstab and storage UUIDs...")
        root_uuid = subprocess.check_output(["blkid", "-s", "UUID", "-o", "value", part_root], text=True).strip()
        swap_uuid = subprocess.check_output(["blkid", "-s", "UUID", "-o", "value", part_swap], text=True).strip()

        fstab_lines = [
            "# /etc/fstab: static file system information for LiteOffice OS",
            f"UUID={root_uuid}    /          ext4    noatime,errors=remount-ro 0 1",
            f"UUID={swap_uuid}    none       swap    sw                        0 0",
        ]

        if part_efi:
            efi_uuid = subprocess.check_output(["blkid", "-s", "UUID", "-o", "value", part_efi], text=True).strip()
            fstab_lines.append(f"UUID={efi_uuid}    /boot/efi  vfat    umask=0077,shortname=winnt 0 2")

        if part_home:
            home_uuid = subprocess.check_output(["blkid", "-s", "UUID", "-o", "value", part_home], text=True).strip()
            fstab_lines.append(f"UUID={home_uuid}    /home      ext4    defaults,noatime          0 2")

        with open(f"{mount_target}/etc/fstab", "w") as f:
            f.write("\n".join(fstab_lines) + "\n")
        self.log("Generated /etc/fstab with UUIDs.\n")

        # 7. Configure System Identity & User
        self.set_progress(0.86, "Configuring hostname and user account...")
        with open(f"{mount_target}/etc/hostname", "w") as f:
            f.write(f"{hostname}\n")

        with open(f"{mount_target}/etc/hosts", "w") as f:
            f.write(f"127.0.0.1\tlocalhost\n127.0.1.1\t{hostname}\n::1\t\tlocalhost ip6-localhost ip6-loopback\n")

        # Ensure user exists and configure password
        user_home = f"{mount_target}/home/{username}"
        os.makedirs(user_home, exist_ok=True)
        run_command(f"chroot {mount_target} id -u {username} 2>/dev/null || chroot {mount_target} useradd -m -s /bin/bash -c '{realname}' -G sudo,audio,video,plugdev,input,netdev {username}", self.log)
        
        # Set password
        chpasswd_input = f"{username}:{password}\nroot:{password}\n"
        proc = subprocess.Popen(["chroot", mount_target, "chpasswd"], stdin=subprocess.PIPE, text=True)
        proc.communicate(input=chpasswd_input)
        self.log(f"Configured credentials for user: {username}\n")

        # 8. Install Bootloader (GRUB)
        self.set_progress(0.90, "Installing GRUB bootloader to target disk...")
        run_command(f"mount --bind /dev {mount_target}/dev", self.log)
        run_command(f"mount --bind /dev/pts {mount_target}/dev/pts", self.log)
        run_command(f"mount -t proc proc {mount_target}/proc", self.log)
        run_command(f"mount -t sysfs sysfs {mount_target}/sys", self.log)

        try:
            if boot_mode == "UEFI":
                efi_target = "x86_64-efi" if os.uname().machine == "x86_64" else "i386-efi"
                self.log(f"Executing grub-install for UEFI ({efi_target})...\n")
                run_command(
                    f"chroot {mount_target} grub-install --target={efi_target} --efi-directory=/boot/efi --bootloader-id=LiteOffice --recheck || "
                    f"chroot {mount_target} grub-install --target={efi_target} --efi-directory=/boot/efi --removable",
                    self.log
                )
            else:
                self.log(f"Executing grub-install for Legacy BIOS (i386-pc) on {target_disk}...\n")
                run_command(f"chroot {mount_target} grub-install --target=i386-pc {target_disk} --recheck", self.log)

            self.log("Generating final grub.cfg...\n")
            run_command(f"chroot {mount_target} grub-mkconfig -o /boot/grub/grub.cfg", self.log)
        finally:
            subprocess.run(["umount", "-l", f"{mount_target}/dev/pts"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["umount", "-l", f"{mount_target}/dev"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["umount", "-l", f"{mount_target}/proc"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["umount", "-l", f"{mount_target}/sys"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # 9. Clean unmount target
        self.set_progress(0.98, "Synchronizing storage buffers and unmounting...")
        run_command("sync", self.log)
        if part_efi:
            subprocess.run(["umount", "-l", f"{mount_target}/boot/efi"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if part_home:
            subprocess.run(["umount", "-l", f"{mount_target}/home"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["umount", "-l", mount_target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        self.set_progress(1.0, "Installation complete!")
        self.log(f"\n[SUCCESS] LiteOffice OS successfully installed to {target_disk}!\n")


# ==============================================================================
# GTK 3 Graphical User Interface
# ==============================================================================
def run_gtk_installer():
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib, Pango

    class InstallerWindow(Gtk.Window):
        def __init__(self):
            super().__init__(title="LiteOffice OS — System Storage Installer")
            self.set_default_size(780, 560)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_border_width(12)

            self.boot_mode = detect_boot_mode()
            self.disks = list_storage_disks()

            self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            self.add(self.main_box)

            # Header Banner
            header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            logo_path = "/usr/share/icons/hicolor/64x64/apps/liteoffice.png"
            if not os.path.exists(logo_path):
                logo_path = "/usr/share/pixmaps/liteoffice.png"
            if os.path.exists(logo_path):
                img = Gtk.Image.new_from_file(logo_path)
                header_box.pack_start(img, False, False, 0)

            title_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            title_lbl = Gtk.Label()
            title_lbl.set_markup("<span font='16' weight='bold'>LiteOffice OS System Installer</span>")
            title_lbl.set_halign(Gtk.Align.START)
            title_vbox.pack_start(title_lbl, False, False, 0)

            subtitle_lbl = Gtk.Label()
            badge_color = "#38bdf8" if self.boot_mode == "UEFI" else "#fbbf24"
            subtitle_lbl.set_markup(
                f"<span color='#94a3b8'>Install permanently to storage drive | Boot Firmware: </span>"
                f"<span color='{badge_color}' weight='bold'>{self.boot_mode}</span>"
            )
            subtitle_lbl.set_halign(Gtk.Align.START)
            title_vbox.pack_start(subtitle_lbl, False, False, 0)

            header_box.pack_start(title_vbox, True, True, 0)
            self.main_box.pack_start(header_box, False, False, 4)
            self.main_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Stack for Wizard Pages
            self.stack = Gtk.Stack()
            self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
            self.stack.set_transition_duration(250)
            self.main_box.pack_start(self.stack, True, True, 4)

            # Build Pages
            self.page_config = self._build_config_page()
            self.page_summary = self._build_summary_page()
            self.page_install = self._build_install_page()
            self.page_complete = self._build_complete_page()

            self.stack.add_named(self.page_config, "config")
            self.stack.add_named(self.page_summary, "summary")
            self.stack.add_named(self.page_install, "install")
            self.stack.add_named(self.page_complete, "complete")

            # Bottom Button Navigation Bar
            self.nav_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            self.btn_cancel = Gtk.Button(label="Cancel")
            self.btn_cancel.connect("clicked", lambda b: Gtk.main_quit())
            self.nav_box.pack_start(self.btn_cancel, False, False, 0)

            self.btn_back = Gtk.Button(label="< Back")
            self.btn_back.connect("clicked", self._on_back_clicked)
            self.btn_back.set_sensitive(False)
            self.btn_next = Gtk.Button(label="Next >")
            self.nav_box.pack_end(self.btn_next, False, False, 0)
            self.nav_box.pack_end(self.btn_back, False, False, 0)
            self.btn_next.connect("clicked", self._on_next_clicked)

            self.main_box.pack_end(self.nav_box, False, False, 4)

            self.connect("destroy", Gtk.main_quit)
            self.show_all()
            self._update_disk_details()

        def _build_config_page(self):
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

            # Frame 1: Target Storage Device
            disk_frame = Gtk.Frame(label=" 1. Select Target Storage Drive ")
            disk_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            disk_box.set_border_width(10)

            disk_h = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            disk_lbl = Gtk.Label(label="Drive Device:")
            disk_h.pack_start(disk_lbl, False, False, 0)

            self.disk_combo = Gtk.ComboBoxText()
            for d in self.disks:
                text = f"{d['path']} — {d['size_gb']} GB ({d['model']})"
                self.disk_combo.append(d["path"], text)
            if self.disks:
                self.disk_combo.set_active(0)
            self.disk_combo.connect("changed", lambda c: self._update_disk_details())
            disk_h.pack_start(self.disk_combo, True, True, 0)

            btn_refresh = Gtk.Button(label="↻ Refresh")
            btn_refresh.connect("clicked", self._on_refresh_disks)
            disk_h.pack_start(btn_refresh, False, False, 0)
            disk_box.pack_start(disk_h, False, False, 0)

            self.disk_info_lbl = Gtk.Label()
            self.disk_info_lbl.set_halign(Gtk.Align.START)
            disk_box.pack_start(self.disk_info_lbl, False, False, 0)

            disk_frame.add(disk_box)
            vbox.pack_start(disk_frame, False, False, 0)

            # Frame 2: Partition Size Allocations (Min 8 GB Swap Enforced)
            part_frame = Gtk.Frame(label=" 2. Partition Size Allocation & Customization ")
            part_grid = Gtk.Grid()
            part_grid.set_column_spacing(12)
            part_grid.set_row_spacing(8)
            part_grid.set_border_width(10)

            # Swap Partition (Min 8 GB)
            swap_lbl = Gtk.Label(label="Swap Partition (GB):")
            swap_lbl.set_halign(Gtk.Align.START)
            part_grid.attach(swap_lbl, 0, 0, 1, 1)

            # Default: 8 GB, min: 8 GB, max: 64 GB, step: 1 GB
            self.spin_swap = Gtk.SpinButton.new_with_range(8.0, 64.0, 1.0)
            self.spin_swap.set_value(8.0)
            self.spin_swap.connect("value-changed", lambda s: self._recalculate_sizes())
            part_grid.attach(self.spin_swap, 1, 0, 1, 1)

            swap_note = Gtk.Label()
            swap_note.set_markup("<span color='#10b981' size='small'>★ Minimum 8 GB enforced (Safety & Anti-OOM buffer)</span>")
            swap_note.set_halign(Gtk.Align.START)
            part_grid.attach(swap_note, 2, 0, 1, 1)

            # Root (/) Partition
            root_lbl = Gtk.Label(label="Root (/) Partition (GB):")
            root_lbl.set_halign(Gtk.Align.START)
            part_grid.attach(root_lbl, 0, 1, 1, 1)

            self.spin_root = Gtk.SpinButton.new_with_range(8.0, 500.0, 1.0)
            self.spin_root.set_value(20.0)
            self.spin_root.connect("value-changed", lambda s: self._recalculate_sizes())
            part_grid.attach(self.spin_root, 1, 1, 1, 1)

            root_note = Gtk.Label()
            root_note.set_markup("<span color='#94a3b8' size='small'>Holds system files, desktop apps, and libraries</span>")
            root_note.set_halign(Gtk.Align.START)
            part_grid.attach(root_note, 2, 1, 1, 1)

            # Separate /home Partition
            self.chk_home = Gtk.CheckButton(label="Separate /home Partition (GB):")
            self.chk_home.set_active(True)
            self.chk_home.connect("toggled", self._on_home_toggled)
            part_grid.attach(self.chk_home, 0, 2, 1, 1)

            self.spin_home = Gtk.SpinButton.new_with_range(1.0, 1000.0, 1.0)
            self.spin_home.set_value(10.0)
            self.spin_home.connect("value-changed", lambda s: self._recalculate_sizes())
            part_grid.attach(self.spin_home, 1, 2, 1, 1)

            self.home_note = Gtk.Label()
            self.home_note.set_markup("<span color='#38bdf8' size='small'>Dedicated storage for personal documents and data</span>")
            self.home_note.set_halign(Gtk.Align.START)
            part_grid.attach(self.home_note, 2, 2, 1, 1)

            # Auto-balance Remaining Space Checkbox
            self.chk_auto_home = Gtk.CheckButton(label="Automatically allocate all remaining space to /home")
            self.chk_auto_home.set_active(True)
            self.chk_auto_home.connect("toggled", lambda c: self._recalculate_sizes())
            part_grid.attach(self.chk_auto_home, 0, 3, 3, 1)

            # Storage Bar / Allocation Summary
            self.alloc_summary_lbl = Gtk.Label()
            self.alloc_summary_lbl.set_halign(Gtk.Align.START)
            part_grid.attach(self.alloc_summary_lbl, 0, 4, 3, 1)

            part_frame.add(part_grid)
            vbox.pack_start(part_frame, False, False, 0)

            # Frame 3: User Identity & Credentials
            user_frame = Gtk.Frame(label=" 3. System Identity & Account Setup ")
            user_grid = Gtk.Grid()
            user_grid.set_column_spacing(12)
            user_grid.set_row_spacing(6)
            user_grid.set_border_width(10)

            # Hostname
            user_grid.attach(Gtk.Label(label="Computer Name (Hostname):", halign=Gtk.Align.START), 0, 0, 1, 1)
            self.ent_hostname = Gtk.Entry(text="liteoffice")
            user_grid.attach(self.ent_hostname, 1, 0, 1, 1)

            # Username
            user_grid.attach(Gtk.Label(label="User Account Name:", halign=Gtk.Align.START), 2, 0, 1, 1)
            self.ent_username = Gtk.Entry(text="liteuser")
            user_grid.attach(self.ent_username, 3, 0, 1, 1)

            # Real Name
            user_grid.attach(Gtk.Label(label="Your Full Name:", halign=Gtk.Align.START), 0, 1, 1, 1)
            self.ent_realname = Gtk.Entry(text="Lite User")
            user_grid.attach(self.ent_realname, 1, 1, 1, 1)

            # Password
            user_grid.attach(Gtk.Label(label="Password:", halign=Gtk.Align.START), 2, 1, 1, 1)
            self.ent_password = Gtk.Entry(text="liteoffice")
            self.ent_password.set_visibility(False)
            user_grid.attach(self.ent_password, 3, 1, 1, 1)

            self.chk_autologin = Gtk.CheckButton(label="Log in automatically at boot without asking for password")
            self.chk_autologin.set_active(True)
            user_grid.attach(self.chk_autologin, 0, 2, 4, 1)

            user_frame.add(user_grid)
            vbox.pack_start(user_frame, False, False, 0)

            return vbox

        def _build_summary_page(self):
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

            warn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            warn_lbl = Gtk.Label()
            warn_lbl.set_markup(
                "<span font='12' weight='bold' color='#ef4444'>⚠ WARNING: All existing data on the selected storage drive will be ERASED!</span>\n"
                "<span color='#cbd5e1'>Please verify your partition allocation and target drive carefully before continuing.</span>"
            )
            warn_lbl.set_halign(Gtk.Align.START)
            warn_box.pack_start(warn_lbl, True, True, 0)
            vbox.pack_start(warn_box, False, False, 4)

            self.summary_text = Gtk.TextView()
            self.summary_text.set_editable(False)
            self.summary_text.set_cursor_visible(False)
            self.summary_text.set_monospace(True)
            scroller = Gtk.ScrolledWindow()
            scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
            scroller.add(self.summary_text)
            vbox.pack_start(scroller, True, True, 0)

            return vbox

        def _build_install_page(self):
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)

            self.install_status_lbl = Gtk.Label(label="Preparing installation...")
            self.install_status_lbl.set_halign(Gtk.Align.START)
            self.install_status_lbl.set_markup("<span font='12' weight='bold'>Installing LiteOffice OS...</span>")
            vbox.pack_start(self.install_status_lbl, False, False, 4)

            self.progress_bar = Gtk.ProgressBar()
            self.progress_bar.set_fraction(0.0)
            self.progress_bar.set_show_text(True)
            vbox.pack_start(self.progress_bar, False, False, 0)

            self.log_text = Gtk.TextView()
            self.log_text.set_editable(False)
            self.log_text.set_monospace(True)
            log_scroller = Gtk.ScrolledWindow()
            log_scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
            log_scroller.add(self.log_text)
            vbox.pack_start(log_scroller, True, True, 0)

            return vbox

        def _build_complete_page(self):
            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
            vbox.set_valign(Gtk.Align.CENTER)

            succ_lbl = Gtk.Label()
            succ_lbl.set_markup("<span font='18' weight='bold' color='#10b981'>Installation Finished Successfully!</span>")
            vbox.pack_start(succ_lbl, False, False, 0)

            desc_lbl = Gtk.Label()
            desc_lbl.set_markup(
                "<span font='11' color='#cbd5e1'>LiteOffice OS is now permanently installed to your hard drive.\n"
                "You can restart your computer now, remove your installation USB/CD, and boot into your new operating system.</span>"
            )
            desc_lbl.set_justify(Gtk.Justification.CENTER)
            vbox.pack_start(desc_lbl, False, False, 0)

            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
            btn_box.set_halign(Gtk.Align.CENTER)

            btn_reboot = Gtk.Button(label="Reboot Now")
            btn_reboot.get_style_context().add_class("suggested-action")
            btn_reboot.connect("clicked", lambda b: subprocess.run(["reboot"]))
            btn_box.pack_start(btn_reboot, False, False, 0)

            btn_close = Gtk.Button(label="Stay in Live Session")
            btn_close.connect("clicked", lambda b: Gtk.main_quit())
            btn_box.pack_start(btn_close, False, False, 0)

            vbox.pack_start(btn_box, False, False, 10)
            return vbox

        def _on_home_toggled(self, widget):
            active = widget.get_active()
            self.spin_home.set_sensitive(active)
            self.chk_auto_home.set_sensitive(active)
            self._recalculate_sizes()

        def _on_refresh_disks(self, widget):
            self.disks = list_storage_disks()
            self.disk_combo.remove_all()
            for d in self.disks:
                text = f"{d['path']} — {d['size_gb']} GB ({d['model']})"
                self.disk_combo.append(d["path"], text)
            if self.disks:
                self.disk_combo.set_active(0)
            self._update_disk_details()

        def _get_selected_disk(self):
            path = self.disk_combo.get_active_id()
            for d in self.disks:
                if d["path"] == path:
                    return d
            return None

        def _update_disk_details(self):
            disk = self._get_selected_disk()
            if not disk:
                self.disk_info_lbl.set_markup("<span color='#ef4444'>No writable physical drives detected!</span>")
                self.btn_next.set_sensitive(False)
                return

            self.btn_next.set_sensitive(True)
            self.disk_info_lbl.set_markup(
                f"<span color='#94a3b8'>Total Capacity: </span><span weight='bold'>{disk['size_gb']} GB</span>"
                f" <span color='#94a3b8'>| Bus: </span><span weight='bold'>{disk['tran'].upper()}</span>"
            )

            # Adjust spin buttons ranges according to disk size
            total = disk["size_gb"]
            # Swap minimum is 8 GB
            swap_val = 8.0
            if total < 12.0:
                swap_val = max(1.0, round(total - 8.0, 1))

            self.spin_swap.set_value(swap_val)

            # Default root allocation
            if total > 60:
                root_val = 30.0
            elif total > 30:
                root_val = 18.0
            else:
                root_val = max(8.0, round((total - swap_val) * 0.6, 1))
            self.spin_root.set_value(root_val)

            self._recalculate_sizes()

        def _recalculate_sizes(self):
            disk = self._get_selected_disk()
            if not disk:
                return

            total = disk["size_gb"]
            swap = self.spin_swap.get_value()
            root = self.spin_root.get_value()
            esp = 0.5 if self.boot_mode == "UEFI" else 0.0

            used_so_far = round(esp + swap + root, 1)
            remaining = round(total - used_so_far, 1)

            if self.chk_home.get_active():
                if self.chk_auto_home.get_active():
                    home_val = max(0.0, remaining)
                    self.spin_home.set_value(home_val)
                else:
                    home_val = self.spin_home.get_value()
                total_used = round(used_so_far + home_val, 1)
                free_space = round(total - total_used, 1)
            else:
                home_val = 0.0
                total_used = used_so_far
                free_space = remaining

            status_color = "#10b981" if free_space >= 0 else "#ef4444"
            summary_html = (
                f"<b>Allocation Summary:</b> "
                f"Swap: <b>{swap:.1f} GB</b> | "
                f"Root (/): <b>{root:.1f} GB</b> | "
                f"Home (/home): <b>{home_val:.1f} GB</b> | "
                f"<span color='{status_color}'>Remaining Free: <b>{free_space:.1f} GB</b> (of {total:.1f} GB)</span>"
            )
            self.alloc_summary_lbl.set_markup(summary_html)
            self.btn_next.set_sensitive(free_space >= -0.1 and root >= 8.0 and swap >= 8.0)

        def _on_next_clicked(self, widget):
            curr = self.stack.get_visible_child_name()
            if curr == "config":
                disk = self._get_selected_disk()
                if not disk:
                    return

                # Build summary
                swap = self.spin_swap.get_value()
                root = self.spin_root.get_value()
                use_home = self.chk_home.get_active()
                home = self.spin_home.get_value() if use_home else 0.0

                summary_lines = [
                    "==================================================================",
                    "  LiteOffice OS Installation Specification",
                    "==================================================================",
                    f"Target Device      : {disk['path']} ({disk['size_gb']} GB, {disk['model']})",
                    f"Firmware Boot Mode : {self.boot_mode}",
                    "------------------------------------------------------------------",
                    "Partition Plan:",
                ]
                if self.boot_mode == "UEFI":
                    summary_lines.append(f"  • Partition 1: EFI System Partition (ESP)  512 MB   FAT32   /boot/efi")
                    summary_lines.append(f"  • Partition 2: Linux Swap (Virtual Memory) {swap:.1f} GB   SWAP    [Min 8 GB]")
                    summary_lines.append(f"  • Partition 3: LiteOffice Root Filesystem  {root:.1f} GB   EXT4    /")
                    if use_home and home > 0:
                        summary_lines.append(f"  • Partition 4: User Personal Storage       {home:.1f} GB   EXT4    /home")
                else:
                    summary_lines.append(f"  • Partition 1: Linux Swap (Virtual Memory) {swap:.1f} GB   SWAP    [Min 8 GB]")
                    summary_lines.append(f"  • Partition 2: LiteOffice Root Filesystem  {root:.1f} GB   EXT4    / (Bootable)")
                    if use_home and home > 0:
                        summary_lines.append(f"  • Partition 3: User Personal Storage       {home:.1f} GB   EXT4    /home")

                summary_lines.extend([
                    "------------------------------------------------------------------",
                    "User Configuration:",
                    f"  • Hostname : {self.ent_hostname.get_text()}",
                    f"  • Username : {self.ent_username.get_text()}",
                    f"  • Full Name: {self.ent_realname.get_text()}",
                    f"  • Autologin: {'Enabled' if self.chk_autologin.get_active() else 'Disabled'}",
                    "==================================================================",
                    "\nClick 'Install Now' to commit changes and begin installation."
                ])

                buf = self.summary_text.get_buffer()
                buf.set_text("\n".join(summary_lines))

                self.stack.set_visible_child_name("summary")
                self.btn_back.set_sensitive(True)
                self.btn_next.set_label("Install Now")
                self.btn_next.get_style_context().add_class("destructive-action")

            elif curr == "summary":
                # Start installation!
                self.stack.set_visible_child_name("install")
                self.btn_back.set_sensitive(False)
                self.btn_next.set_sensitive(False)
                self.btn_cancel.set_sensitive(False)

                disk = self._get_selected_disk()
                config = {
                    "target_disk": disk["path"],
                    "boot_mode": self.boot_mode,
                    "swap_gb": self.spin_swap.get_value(),
                    "root_gb": self.spin_root.get_value(),
                    "home_gb": self.spin_home.get_value() if self.chk_home.get_active() else 0,
                    "use_separate_home": self.chk_home.get_active(),
                    "hostname": self.ent_hostname.get_text(),
                    "username": self.ent_username.get_text(),
                    "realname": self.ent_realname.get_text(),
                    "password": self.ent_password.get_text(),
                    "autologin": self.chk_autologin.get_active(),
                }

                worker = InstallWorker(
                    config,
                    self._on_worker_progress,
                    self._on_worker_log,
                    self._on_worker_finish
                )
                t = threading.Thread(target=worker.run, daemon=True)
                t.start()

        def _on_back_clicked(self, widget):
            curr = self.stack.get_visible_child_name()
            if curr == "summary":
                self.stack.set_visible_child_name("config")
                self.btn_back.set_sensitive(False)
                self.btn_next.set_label("Next >")
                self.btn_next.get_style_context().remove_class("destructive-action")

        def _on_worker_progress(self, frac, status_text):
            GLib.idle_add(self._update_progress_ui, frac, status_text)

        def _update_progress_ui(self, frac, status_text):
            self.progress_bar.set_fraction(frac)
            self.progress_bar.set_text(f"{int(frac * 100)}%")
            self.install_status_lbl.set_markup(f"<span font='11' weight='bold'>{status_text}</span>")

        def _on_worker_log(self, text):
            GLib.idle_add(self._append_log_ui, text)

        def _append_log_ui(self, text):
            buf = self.log_text.get_buffer()
            end_iter = buf.get_end_iter()
            buf.insert(end_iter, text)
            mark = buf.create_mark(None, buf.get_end_iter(), False)
            self.log_text.scroll_to_mark(mark, 0.05, False, 0.0, 1.0)

        def _on_worker_finish(self, success, message):
            GLib.idle_add(self._show_finish_ui, success, message)

        def _show_finish_ui(self, success, message):
            if success:
                self.stack.set_visible_child_name("complete")
                self.btn_cancel.set_sensitive(True)
                self.btn_cancel.set_label("Exit")
                self.btn_next.hide()
                self.btn_back.hide()
            else:
                dialog = Gtk.MessageDialog(
                    transient_for=self,
                    flags=0,
                    message_type=Gtk.MessageType.ERROR,
                    buttons=Gtk.ButtonsType.OK,
                    text="Installation Failed"
                )
                dialog.format_secondary_text(f"An error occurred during installation:\n{message}")
                dialog.run()
                dialog.destroy()
                self.btn_cancel.set_sensitive(True)
                self.btn_back.set_sensitive(True)

    Gtk.init(None)
    win = InstallerWindow()
    Gtk.main()


# ==============================================================================
# CLI Fallback Mode
# ==============================================================================
def run_cli_installer():
    print("==================================================================")
    print("  LiteOffice OS 1.0 LTS — Terminal Storage Installer")
    print("==================================================================")
    boot_mode = detect_boot_mode()
    print(f"Firmware Boot Environment: {boot_mode}")

    disks = list_storage_disks()
    if not disks:
        print("[!] No physical storage drives detected.", file=sys.stderr)
        sys.exit(1)

    print("\nAvailable Storage Drives:")
    for i, d in enumerate(disks):
        print(f"  [{i + 1}] {d['path']} — {d['size_gb']} GB ({d['model']})")

    sel = input("\nSelect drive number to install to (e.g. 1): ").strip()
    try:
        idx = int(sel) - 1
        target_disk = disks[idx]["path"]
        total_gb = disks[idx]["size_gb"]
    except Exception:
        print("Invalid selection.")
        sys.exit(1)

    print(f"\nConfiguring storage on {target_disk} ({total_gb} GB):")
    swap_in = input("Enter Swap size in GB [default: 8 GB, min: 8 GB]: ").strip()
    swap_gb = float(swap_in) if swap_in else 8.0
    if swap_gb < 8.0 and total_gb >= 12.0:
        print("Enforcing minimum 8 GB swap buffer as specified.")
        swap_gb = 8.0

    root_in = input("Enter Root (/) size in GB [default: 25 GB]: ").strip()
    root_gb = float(root_in) if root_in else 25.0

    home_choice = input("Create separate /home partition? [Y/n]: ").strip().lower()
    use_home = home_choice != "n"
    home_gb = max(0.0, total_gb - swap_gb - root_gb - 1.0) if use_home else 0.0

    print(f"\nSelected Plan: Swap={swap_gb}GB, Root={root_gb}GB, Home={home_gb}GB")
    confirm = input(f"\nWARNING: All data on {target_disk} will be permanently erased! Proceed? [y/N]: ").strip().lower()
    if confirm != "y":
        print("Installation aborted.")
        sys.exit(0)

    config = {
        "target_disk": target_disk,
        "boot_mode": boot_mode,
        "swap_gb": swap_gb,
        "root_gb": root_gb,
        "home_gb": home_gb,
        "use_separate_home": use_home,
        "hostname": "liteoffice",
        "username": "liteuser",
        "realname": "Lite User",
        "password": "liteoffice",
        "autologin": True,
    }

    worker = InstallWorker(
        config,
        lambda frac, msg: print(f"[{int(frac * 100)}%] {msg}"),
        lambda log: sys.stdout.write(log),
        lambda success, msg: print(f"\nResult: {'SUCCESS' if success else 'FAILED'} - {msg}")
    )
    worker.run()


if __name__ == "__main__":
    has_display = bool(os.environ.get("DISPLAY"))
    force_cli = "--cli" in sys.argv
    if has_display and not force_cli:
        try:
            run_gtk_installer()
        except Exception as e:
            print(f"Failed to launch GTK GUI ({e}), falling back to CLI...", file=sys.stderr)
            run_cli_installer()
    else:
        run_cli_installer()
