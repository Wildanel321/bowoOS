#!/usr/bin/env python3
import os
import sys
import subprocess
import glob

WALLPAPER_DIR = "/usr/share/wallpapers/liteoffice"

def get_screen_modes():
    modes = []
    try:
        out = subprocess.check_output("xrandr 2>/dev/null", shell=True).decode()
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 1 and "x" in parts[0] and parts[0][0].isdigit():
                mode = parts[0]
                if mode not in modes:
                    modes.append(mode)
    except Exception:
        pass
    if not modes:
        modes = ["1280x800", "1024x768", "800x600", "1920x1080"]
    return modes

def get_network_info():
    lines = []
    try:
        out = subprocess.check_output("ip -br addr show 2>/dev/null", shell=True).decode()
        for line in out.splitlines():
            if line.strip():
                lines.append(line.strip())
    except Exception:
        pass
    return lines or ["lo UNKNOWN 127.0.0.1/8", "eth0 DOWN"]

def set_wallpaper(path):
    conf_dir = os.path.expanduser("~/.config/pcmanfm/default")
    os.makedirs(conf_dir, exist_ok=True)
    conf_file = os.path.join(conf_dir, "desktop-items-0.conf")
    lines = []
    has_wp = False
    has_mode = False
    if os.path.exists(conf_file):
        with open(conf_file, "r") as f:
            for l in f:
                if l.startswith("wallpaper="):
                    lines.append(f"wallpaper={path}\n")
                    has_wp = True
                elif l.startswith("wallpaper_mode="):
                    lines.append("wallpaper_mode=stretch\n")
                    has_mode = True
                else:
                    lines.append(l)
    if not has_wp:
        if not lines or lines[0].strip() != "[*]":
            lines.insert(0, "[*]\n")
        lines.append(f"wallpaper={path}\n")
    if not has_mode:
        lines.append("wallpaper_mode=stretch\n")
    with open(conf_file, "w") as f:
        f.writelines(lines)
    subprocess.call(f"pcmanfm --set-wallpaper=\"{path}\" --wallpaper-mode=stretch 2>/dev/null || pcmanfm --reconfigure 2>/dev/null || true", shell=True)

def print_cli_status():
    print("==================================================")
    print("  LiteOffice OS Control Center (CLI Mode)")
    print("==================================================")
    print("Available Screen Modes :", ", ".join(get_screen_modes()))
    print("Network Interfaces:")
    for iface in get_network_info():
        print("  -", iface)
    print("==================================================")

def run_gtk_mode():
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk, GdkPixbuf, GLib
    except ImportError:
        print("PyGObject / GTK 3 not available; falling back to CLI mode.")
        print_cli_status()
        return

    class ControlCenterWindow(Gtk.Window):
        def __init__(self):
            super().__init__(title="LiteOffice OS Control Center")
            self.set_default_size(720, 500)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_border_width(12)

            main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
            self.add(main_box)

            # Left Sidebar (StackSidebar)
            self.stack = Gtk.Stack()
            self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
            self.stack.set_transition_duration(150)

            sidebar = Gtk.StackSidebar()
            sidebar.set_stack(self.stack)
            sidebar.set_size_request(160, -1)
            main_box.pack_start(sidebar, False, False, 0)

            main_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL), False, False, 0)

            # Right Container
            main_box.pack_start(self.stack, True, True, 0)

            self.build_display_page()
            self.build_wallpaper_page()
            self.build_audio_page()
            self.build_network_page()
            self.build_security_page()
            self.build_power_page()

        def build_display_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
            box.set_border_width(12)

            lbl = Gtk.Label()
            lbl.set_markup("<span size='large' weight='bold'>Display &amp; Resolution</span>")
            lbl.set_xalign(0)
            box.pack_start(lbl, False, False, 0)

            modes = get_screen_modes()
            self.mode_combo = Gtk.ComboBoxText()
            for m in modes:
                self.mode_combo.append_text(m)
            self.mode_combo.set_active(0)

            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            row.pack_start(Gtk.Label(label="Screen Resolution:"), False, False, 0)
            row.pack_start(self.mode_combo, False, False, 0)
            box.pack_start(row, False, False, 0)

            apply_btn = Gtk.Button(label="Apply Resolution")
            apply_btn.get_style_context().add_class("suggested-action")
            apply_btn.connect("clicked", self.on_apply_resolution)
            row.pack_start(apply_btn, False, False, 0)

            self.stack.add_titled(box, "display", "Display")

        def on_apply_resolution(self, btn):
            mode = self.mode_combo.get_active_text()
            if mode:
                subprocess.call(f"xrandr -s {mode} 2>/dev/null", shell=True)

        def build_wallpaper_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            box.set_border_width(12)

            lbl = Gtk.Label()
            lbl.set_markup("<span size='large' weight='bold'>Desktop Wallpaper</span>")
            lbl.set_xalign(0)
            box.pack_start(lbl, False, False, 0)

            flow = Gtk.FlowBox()
            flow.set_valign(Gtk.Align.START)
            flow.set_max_children_per_line(3)
            flow.set_selection_mode(Gtk.SelectionMode.NONE)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            scrolled.add(flow)
            box.pack_start(scrolled, True, True, 0)

            wallpapers = glob.glob(f"{WALLPAPER_DIR}/*.png")
            if not wallpapers:
                wallpapers = glob.glob(os.path.join(os.path.dirname(__file__), "../wallpapers/*.png"))

            for wp in wallpapers:
                b = Gtk.Button()
                vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                try:
                    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(wp, 160, 100, False)
                    img = Gtk.Image.new_from_pixbuf(pb)
                    vbox.pack_start(img, False, False, 0)
                except Exception:
                    pass
                name_lbl = Gtk.Label(label=os.path.splitext(os.path.basename(wp))[0])
                vbox.pack_start(name_lbl, False, False, 0)
                b.add(vbox)
                b.connect("clicked", lambda btn, p=wp: set_wallpaper(p))
                flow.add(b)

            self.stack.add_titled(box, "wallpaper", "Wallpaper")

        def build_audio_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
            box.set_border_width(12)

            lbl = Gtk.Label()
            lbl.set_markup("<span size='large' weight='bold'>Audio Settings</span>")
            lbl.set_xalign(0)
            box.pack_start(lbl, False, False, 0)

            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            box.pack_start(row, False, False, 0)
            row.pack_start(Gtk.Label(label="Master Volume:"), False, False, 0)

            scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
            scale.set_value(75)
            scale.set_hexpand(True)
            scale.connect("value-changed", self.on_volume_changed)
            row.pack_start(scale, True, True, 0)

            mixer_btn = Gtk.Button(label="Open Full Mixer")
            mixer_btn.connect("clicked", lambda b: subprocess.Popen("pavucontrol 2>/dev/null || alsamixer", shell=True))
            box.pack_start(mixer_btn, False, False, 0)

            self.stack.add_titled(box, "audio", "Audio")

        def on_volume_changed(self, scale):
            vol = int(scale.get_value())
            subprocess.call(f"amixer sset Master {vol}% 2>/dev/null || amixer sset PCM {vol}% 2>/dev/null", shell=True)

        def build_network_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            box.set_border_width(12)

            lbl = Gtk.Label()
            lbl.set_markup("<span size='large' weight='bold'>Network Status &amp; Connections</span>")
            lbl.set_xalign(0)
            box.pack_start(lbl, False, False, 0)

            net_info = get_network_info()
            for iface in net_info:
                clean_iface = GLib.markup_escape_text(iface)
                r = Gtk.Label()
                r.set_markup(f"<tt>{clean_iface}</tt>")
                r.set_xalign(0)
                box.pack_start(r, False, False, 0)

            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            box.pack_start(btn_box, False, False, 8)

            c_btn = Gtk.Button(label="Network Connections Editor")
            c_btn.connect("clicked", lambda b: subprocess.Popen("nm-connection-editor 2>/dev/null", shell=True))
            btn_box.pack_start(c_btn, False, False, 0)

            self.stack.add_titled(box, "network", "Network")

        def build_security_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
            box.set_border_width(14)

            lbl = Gtk.Label()
            lbl.set_markup("<span size='large' weight='bold'>Security &amp; System Hardening</span>")
            lbl.set_xalign(0)
            box.pack_start(lbl, False, False, 0)

            # Security Badges
            grid = Gtk.Grid()
            grid.set_column_spacing(16)
            grid.set_row_spacing(10)

            badges = [
                ("🛡️ Stateful Firewall", "Active (Inbound DROP, Outbound ALLOW)", "#10b981"),
                ("🔒 Kernel Memory ASLR", "Full ASLR (Level 2 Protection)", "#10b981"),
                ("⚡ Exploit Mitigation", "YAMA ptrace &amp; unpriv BPF disabled", "#10b981"),
                ("🧠 System OOM Guard", "EarlyOOM &amp; ZRAM compressed swap", "#10b981"),
            ]

            for idx, (title, desc, color) in enumerate(badges):
                col = idx % 2
                row = idx // 2
                card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
                card.set_margin_top(4)
                card.set_margin_bottom(4)
                t_lbl = Gtk.Label()
                t_lbl.set_markup(f"<b>{title}</b>")
                t_lbl.set_xalign(0)
                d_lbl = Gtk.Label()
                d_lbl.set_markup(f"<span foreground='{color}'>{desc}</span>")
                d_lbl.set_xalign(0)
                card.pack_start(t_lbl, False, False, 0)
                card.pack_start(d_lbl, False, False, 0)
                grid.attach(card, col, row, 1, 1)

            box.pack_start(grid, False, False, 0)
            box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Action Buttons
            btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            fw_btn = Gtk.Button(label="Check Firewall Status")
            fw_btn.connect("clicked", lambda b: subprocess.Popen("lxterminal -e 'sudo /usr/local/bin/liteoffice-firewall status; read -p \"Press Enter to exit...\"'", shell=True))
            btn_box.pack_start(fw_btn, False, False, 0)

            health_btn = Gtk.Button(label="Run System Health Diagnostic")
            health_btn.connect("clicked", lambda b: subprocess.Popen("lxterminal -e 'sudo /usr/local/bin/liteoffice-health --check; read -p \"Press Enter to exit...\"'", shell=True))
            btn_box.pack_start(health_btn, False, False, 0)

            box.pack_start(btn_box, False, False, 0)
            self.stack.add_titled(box, "security", "Security")

        def build_power_page(self):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
            box.set_border_width(14)

            # Section 1: Session & Power Options
            lbl_session = Gtk.Label()
            lbl_session.set_markup("<span size='large' weight='bold'>Session &amp; Power Control</span>")
            lbl_session.set_xalign(0)
            box.pack_start(lbl_session, False, False, 0)

            btn_session_dialog = Gtk.Button(label="⏻ Open Power &amp; Session Dialog...")
            btn_session_dialog.connect("clicked", lambda b: subprocess.Popen("/usr/local/bin/liteoffice-session", shell=True))
            box.pack_start(btn_session_dialog, False, False, 0)

            # Quick Action Buttons Grid
            quick_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            quick_box.set_homogeneous(True)

            btn_shutdown = Gtk.Button(label="Shut Down")
            btn_shutdown.connect("clicked", lambda b: subprocess.Popen("/usr/local/bin/lite-logout poweroff", shell=True))
            quick_box.pack_start(btn_shutdown, True, True, 0)

            btn_reboot = Gtk.Button(label="Restart")
            btn_reboot.connect("clicked", lambda b: subprocess.Popen("/usr/local/bin/lite-logout reboot", shell=True))
            quick_box.pack_start(btn_reboot, True, True, 0)

            btn_logout = Gtk.Button(label="Sign Out")
            btn_logout.connect("clicked", lambda b: subprocess.Popen("/usr/local/bin/lite-logout logout", shell=True))
            quick_box.pack_start(btn_logout, True, True, 0)

            btn_lock = Gtk.Button(label="Lock Screen")
            btn_lock.connect("clicked", lambda b: subprocess.Popen("/usr/local/bin/lite-logout lock", shell=True))
            quick_box.pack_start(btn_lock, True, True, 0)

            box.pack_start(quick_box, False, False, 0)

            # Separator
            box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Section 2: Display Blanking & Sleep
            lbl_sleep = Gtk.Label()
            lbl_sleep.set_markup("<span size='large' weight='bold'>Display Blanking &amp; Screen Saver</span>")
            lbl_sleep.set_xalign(0)
            box.pack_start(lbl_sleep, False, False, 0)

            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            box.pack_start(row, False, False, 0)
            row.pack_start(Gtk.Label(label="Turn off display after:"), False, False, 0)

            sleep_combo = Gtk.ComboBoxText()
            sleep_combo.append("never", "Never (Always On)")
            sleep_combo.append("300", "5 Minutes")
            sleep_combo.append("600", "10 Minutes")
            sleep_combo.append("900", "15 Minutes")
            sleep_combo.set_active(0)
            sleep_combo.connect("changed", self.on_sleep_changed)
            row.pack_start(sleep_combo, False, False, 0)

            self.stack.add_titled(box, "power", "Power")

        def on_sleep_changed(self, combo):
            choice = combo.get_active_id()
            if choice == "never":
                subprocess.call("xset s off -dpms 2>/dev/null", shell=True)
            else:
                sec = int(choice)
                subprocess.call(f"xset s {sec} {sec} +dpms 2>/dev/null", shell=True)

    win = ControlCenterWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

def main():
    if "--cli" in sys.argv or not os.environ.get("DISPLAY"):
        print_cli_status()
    else:
        run_gtk_mode()

if __name__ == "__main__":
    main()
