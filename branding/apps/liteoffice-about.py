#!/usr/bin/env python3
import os
import sys
import platform
import subprocess

def get_cpu_info():
    model = "Generic x86 CPU"
    cores = 0
    try:
        with open("/proc/cpuinfo", "r") as f:
            for line in f:
                if line.startswith("model name") and model == "Generic x86 CPU":
                    model = line.split(":", 1)[1].strip()
                if line.startswith("processor"):
                    cores += 1
    except Exception:
        pass
    if cores == 0:
        cores = os.cpu_count() or 1
    return f"{model} ({cores} Cores)"

def get_mem_info():
    total_mb = 0
    avail_mb = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    total_mb = int(line.split()[1]) // 1024
                elif line.startswith("MemAvailable:"):
                    avail_mb = int(line.split()[1]) // 1024
    except Exception:
        pass
    used_mb = total_mb - avail_mb
    return f"{used_mb} MB / {total_mb} MB ({avail_mb} MB Free)"

def get_disk_info():
    try:
        st = os.statvfs("/")
        total_gb = (st.f_blocks * st.f_frsize) / (1024**3)
        free_gb = (st.f_bavail * st.f_frsize) / (1024**3)
        used_gb = total_gb - free_gb
        pct = (used_gb / total_gb) * 100 if total_gb > 0 else 0
        return f"{used_gb:.1f} GB / {total_gb:.1f} GB ({pct:.0f}% Used)"
    except Exception:
        return "Unknown Storage"

def get_os_release():
    info = {"NAME": "LiteOffice OS", "VERSION": "1.0 LTS", "ID": "liteoffice"}
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release", "r") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    info[k] = v.strip('"')
    return info

def print_cli_about():
    os_info = get_os_release()
    print("==================================================")
    print(f"  {os_info.get('NAME', 'LiteOffice OS')} - System Specifications")
    print("==================================================")
    print(f"Version      : {os_info.get('VERSION', '1.0 LTS')}")
    print(f"Architecture : {platform.machine()}")
    print(f"Kernel       : Linux {platform.release()}")
    print(f"Processor    : {get_cpu_info()}")
    print(f"Memory       : {get_mem_info()}")
    print(f"Storage      : {get_disk_info()}")
    print(f"Desktop      : Openbox 3.6 + Tint2")
    print(f"Init System  : OpenRC with Compressed ZRAM")
    print("==================================================")

def run_gtk_mode():
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk, GdkPixbuf, Pango
    except ImportError:
        print("PyGObject / GTK 3 not available; falling back to CLI mode.")
        print_cli_about()
        return

    class AboutWindow(Gtk.Window):
        def __init__(self):
            super().__init__(title="About LiteOffice OS")
            self.set_default_size(520, 360)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_resizable(False)
            self.set_border_width(16)

            os_info = get_os_release()

            main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=20)
            self.add(main_box)

            # Left Column: Logo
            logo_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            logo_paths = [
                "/usr/share/icons/LiteOffice/128x128/apps/liteoffice.png",
                "/usr/share/icons/LiteOffice/liteoffice-icon-128.png",
                "/usr/share/pixmaps/liteoffice-logo.png",
                "/usr/share/pixmaps/liteoffice.png",
                os.path.join(os.path.dirname(__file__), "../logo/liteoffice-icon-128.png")
            ]
            logo_path = None
            for lp in logo_paths:
                if os.path.exists(lp):
                    logo_path = lp
                    break

            if logo_path and os.path.exists(logo_path):
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 110, 110, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                logo_box.pack_start(image, False, False, 0)
            else:
                image = Gtk.Image.new_from_icon_name("system-help", Gtk.IconSize.DIALOG)
                logo_box.pack_start(image, False, False, 0)

            main_box.pack_start(logo_box, False, False, 0)

            # Right Column: Specs
            specs_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            main_box.pack_start(specs_box, True, True, 0)

            title_lbl = Gtk.Label()
            title_lbl.set_markup(f"<span size='x-large' weight='bold'>{os_info.get('NAME', 'LiteOffice OS')}</span>")
            title_lbl.set_xalign(0)
            specs_box.pack_start(title_lbl, False, False, 0)

            sub_lbl = Gtk.Label(label="Lightweight Desktop Operating System")
            sub_lbl.set_xalign(0)
            specs_box.pack_start(sub_lbl, False, False, 0)

            specs_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            grid = Gtk.Grid()
            grid.set_column_spacing(14)
            grid.set_row_spacing(6)
            specs_box.pack_start(grid, True, True, 0)

            specs = [
                ("Version:", os_info.get("VERSION", "1.0 LTS")),
                ("Architecture:", platform.machine()),
                ("Kernel:", f"Linux {platform.release()}"),
                ("Processor:", get_cpu_info()),
                ("Memory:", get_mem_info()),
                ("Storage:", get_disk_info()),
                ("Desktop:", "Openbox 3.6 + Tint2"),
                ("Init System:", "OpenRC with Compressed ZRAM"),
                ("License:", "Open Source (GPLv2 / MIT)")
            ]

            for row, (lbl, val) in enumerate(specs):
                k_lbl = Gtk.Label()
                k_lbl.set_markup(f"<span weight='bold'>{lbl}</span>")
                k_lbl.set_xalign(0)
                v_lbl = Gtk.Label(label=val)
                v_lbl.set_xalign(0)
                v_lbl.set_line_wrap(True)
                v_lbl.set_max_width_chars(32)
                grid.attach(k_lbl, 0, row, 1, 1)
                grid.attach(v_lbl, 1, row, 1, 1)

            # Bottom Button Row
            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            btn_box.set_halign(Gtk.Align.END)
            specs_box.pack_end(btn_box, False, False, 0)

            close_btn = Gtk.Button(label="Close")
            close_btn.connect("clicked", lambda b: Gtk.main_quit())
            btn_box.pack_start(close_btn, False, False, 0)

    win = AboutWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

def main():
    if "--cli" in sys.argv or not os.environ.get("DISPLAY"):
        print_cli_about()
    else:
        run_gtk_mode()

if __name__ == "__main__":
    main()
