#!/usr/bin/env python3
"""
liteoffice-about.py — Official "About LiteOffice OS" System Information App
Presents brand identity, hardware profiling, kernel, RAM, storage, and desktop stack.
Supports both modern GTK 3 GUI and scriptable CLI (--cli).
"""

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

def get_swap_info():
    total_swap = 0
    free_swap = 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("SwapTotal:"):
                    total_swap = int(line.split()[1]) // 1024
                elif line.startswith("SwapFree:"):
                    free_swap = int(line.split()[1]) // 1024
    except Exception:
        pass
    if total_swap > 0:
        used_swap = total_swap - free_swap
        return f"{used_swap} MB / {total_swap} MB (ZRAM/Swap Active)"
    return "None (Inactive)"

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

def get_adaptive_tier():
    if os.path.exists("/etc/lite-profile"):
        try:
            with open("/etc/lite-profile", "r") as f:
                content = f.read()
                if "2 GB Tier" in content or "PROFILE_TIER=\"2G\"" in content:
                    return "2 GB Tier (Full LibreOffice & Firefox ESR)"
                elif "1 GB Tier" in content or "PROFILE_TIER=\"1G\"" in content:
                    return "1 GB Tier (Optimized LibreOffice & Firefox)"
                elif "512 MB Tier" in content or "PROFILE_TIER=\"512M\"" in content:
                    return "512 MB Tier (AbiWord & Gnumeric Light Mode)"
        except Exception:
            pass
    return "Optimized Office Profile (Active)"

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
    print("  office lite — LiteOffice OS System Information")
    print("==================================================")
    print(f"OS Name      : {os_info.get('NAME', 'LiteOffice OS')}")
    print(f"Edition      : 1.0 LTS (Office Productivity Edition)")
    print(f"Architecture : {platform.machine()}")
    print(f"Kernel       : Linux {platform.release()}")
    print(f"Processor    : {get_cpu_info()}")
    print(f"Memory (RAM) : {get_mem_info()}")
    print(f"Swap / ZRAM  : {get_swap_info()}")
    print(f"Storage (/)  : {get_disk_info()}")
    print(f"Profile Mode : {get_adaptive_tier()}")
    print(f"Desktop      : Openbox 3.6 + Tint2 + PCManFM")
    print(f"Init System  : OpenRC + eudev")
    print("==================================================")

def run_gtk_mode():
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk, Gdk, GdkPixbuf, Pango
    except ImportError:
        print("PyGObject / GTK 3 not available; falling back to CLI mode.")
        print_cli_about()
        return

    class AboutWindow(Gtk.Window):
        def __init__(self):
            super().__init__(title="About office lite")
            self.set_default_size(580, 420)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_resizable(False)
            self.set_border_width(18)

            # Apply custom CSS for modern theme styling
            css_provider = Gtk.CssProvider()
            css_data = b"""
                window {
                    background-color: #0b111e;
                    color: #f8fafc;
                }
                .brand-title {
                    font-size: 24px;
                    font-weight: 800;
                    color: #ffffff;
                    letter-spacing: 2px;
                }
                .brand-sub {
                    font-size: 12px;
                    color: #38bdf8;
                    font-weight: 600;
                    letter-spacing: 1px;
                }
                .spec-key {
                    font-weight: 700;
                    color: #94a3b8;
                    font-size: 12px;
                }
                .spec-val {
                    color: #f1f5f9;
                    font-size: 12px;
                }
                .action-btn {
                    padding: 6px 14px;
                    font-weight: 600;
                    border-radius: 6px;
                }
            """
            css_provider.load_from_data(css_data)
            Gtk.StyleContext.add_provider_for_screen(
                Gdk.Screen.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

            os_info = get_os_release()

            main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
            self.add(main_box)

            # Top Header: Logo + Title
            header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=18)
            main_box.pack_start(header_box, False, False, 0)

            # Locate Palm Tree Logo
            logo_paths = [
                "/usr/share/icons/LiteOffice/liteoffice-icon-128.png",
                "/usr/share/pixmaps/liteoffice-logo.png",
                "/usr/share/pixmaps/liteoffice.png",
                os.path.join(os.path.dirname(__file__), "../logo/liteoffice-icon-128.png"),
                os.path.join(os.path.dirname(__file__), "../logo/liteoffice-logo.png")
            ]
            logo_path = None
            for lp in logo_paths:
                if os.path.exists(lp):
                    logo_path = lp
                    break

            if logo_path:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 96, 96, True)
                image = Gtk.Image.new_from_pixbuf(pixbuf)
                header_box.pack_start(image, False, False, 0)
            else:
                image = Gtk.Image.new_from_icon_name("help-about", Gtk.IconSize.DIALOG)
                header_box.pack_start(image, False, False, 0)

            # Title & Subtitle Info
            title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            header_box.pack_start(title_box, True, True, 0)

            title_lbl = Gtk.Label(label="office lite")
            title_lbl.get_style_context().add_class("brand-title")
            title_lbl.set_xalign(0)
            title_box.pack_start(title_lbl, False, False, 0)

            sub_lbl = Gtk.Label(label="LiteOffice OS 1.0 LTS — Productivity Edition")
            sub_lbl.get_style_context().add_class("brand-sub")
            sub_lbl.set_xalign(0)
            title_box.pack_start(sub_lbl, False, False, 0)

            desc_lbl = Gtk.Label(label="Fast, modular, memory-efficient operating system built for office productivity.")
            desc_lbl.set_xalign(0)
            desc_lbl.set_line_wrap(True)
            title_box.pack_start(desc_lbl, False, False, 0)

            # Divider
            main_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 2)

            # Middle: Specifications Grid inside a styled Frame
            grid = Gtk.Grid()
            grid.set_column_spacing(18)
            grid.set_row_spacing(7)
            main_box.pack_start(grid, True, True, 0)

            specs = [
                ("Operating System:", f"{os_info.get('NAME', 'LiteOffice OS')} 1.0 LTS"),
                ("Linux Kernel:", f"Linux {platform.release()} ({platform.machine()})"),
                ("Processor (CPU):", get_cpu_info()),
                ("Memory (RAM):", get_mem_info()),
                ("Swap Storage:", get_swap_info()),
                ("Storage (Disk):", get_disk_info()),
                ("Hardware Profile:", get_adaptive_tier()),
                ("Desktop Stack:", "Openbox 3.6 + Tint2 Panel + PCManFM"),
                ("Init System:", "OpenRC with Compressed ZRAM (zstd)"),
                ("License:", "Open Source (GPLv2 / MIT)")
            ]

            for row, (lbl, val) in enumerate(specs):
                k_lbl = Gtk.Label(label=lbl)
                k_lbl.get_style_context().add_class("spec-key")
                k_lbl.set_xalign(0)

                v_lbl = Gtk.Label(label=val)
                v_lbl.get_style_context().add_class("spec-val")
                v_lbl.set_xalign(0)
                v_lbl.set_line_wrap(True)
                v_lbl.set_max_width_chars(36)

                grid.attach(k_lbl, 0, row, 1, 1)
                grid.attach(v_lbl, 1, row, 1, 1)

            # Bottom: Actions Bar
            bottom_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            main_box.pack_end(bottom_box, False, False, 0)

            # System Monitor launcher
            mon_btn = Gtk.Button(label="System Monitor")
            mon_btn.get_style_context().add_class("action-btn")
            mon_btn.connect("clicked", lambda b: subprocess.Popen(["/usr/local/bin/liteoffice-monitor"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            bottom_box.pack_start(mon_btn, False, False, 0)

            # Control Center launcher
            cc_btn = Gtk.Button(label="Control Center")
            cc_btn.get_style_context().add_class("action-btn")
            cc_btn.connect("clicked", lambda b: subprocess.Popen(["/usr/local/bin/liteoffice-control-center"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
            bottom_box.pack_start(cc_btn, False, False, 0)

            # Close button (Right aligned)
            close_btn = Gtk.Button(label="Close")
            close_btn.get_style_context().add_class("action-btn")
            close_btn.connect("clicked", lambda b: Gtk.main_quit())
            bottom_box.pack_end(close_btn, False, False, 0)

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
