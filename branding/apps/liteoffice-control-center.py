#!/usr/bin/env python3
import os
import sys
import subprocess
import glob

try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, GdkPixbuf
except ImportError:
    print("Error: PyGObject and GTK 3 are required.")
    sys.exit(1)

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
    conf_file = os.path.expanduser("~/.config/pcmanfm/default/desktop-items-0.conf")
    if os.path.exists(conf_file):
        lines = []
        with open(conf_file, "r") as f:
            for l in f:
                if l.startswith("wallpaper="):
                    lines.append(f"wallpaper={path}\n")
                elif l.startswith("wallpaper_mode="):
                    lines.append("wallpaper_mode=stretch\n")
                else:
                    lines.append(l)
        with open(conf_file, "w") as f:
            f.writelines(lines)
    subprocess.call("pcmanfm --reconfigure 2>/dev/null || true", shell=True)

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
            b.add(vbox)
            try:
                pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(wp, 160, 90, False)
                img = Gtk.Image.new_from_pixbuf(pix)
                vbox.pack_start(img, False, False, 0)
            except Exception:
                pass
            title = os.path.basename(wp).replace(".png", "")
            vbox.pack_start(Gtk.Label(label=title), False, False, 0)
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

        self.volume_scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
        self.volume_scale.set_value(75)
        self.volume_scale.connect("value-changed", self.on_volume_changed)
        row.pack_start(self.volume_scale, True, True, 0)

        mute_btn = Gtk.CheckButton(label="Mute Audio")
        mute_btn.connect("toggled", self.on_mute_toggled)
        box.pack_start(mute_btn, False, False, 0)

        self.stack.add_titled(box, "audio", "Audio")

    def on_volume_changed(self, scale):
        vol = int(scale.get_value())
        subprocess.call(f"amixer -q set Master {vol}% 2>/dev/null || true", shell=True)

    def on_mute_toggled(self, btn):
        state = "mute" if btn.get_active() else "unmute"
        subprocess.call(f"amixer -q set Master {state} 2>/dev/null || true", shell=True)

    def build_network_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_border_width(12)

        lbl = Gtk.Label()
        lbl.set_markup("<span size='large' weight='bold'>Network Status</span>")
        lbl.set_xalign(0)
        box.pack_start(lbl, False, False, 0)

        self.net_label = Gtk.Label()
        self.net_label.set_xalign(0)
        self.update_network_display()
        box.pack_start(self.net_label, True, True, 0)

        refresh_btn = Gtk.Button(label="Refresh Network Status")
        refresh_btn.connect("clicked", lambda b: self.update_network_display())
        box.pack_start(refresh_btn, False, False, 0)

        self.stack.add_titled(box, "network", "Network")

    def update_network_display(self):
        interfaces = get_network_info()
        text = "<b>Active Network Interfaces:</b>\n\n"
        for iface in interfaces:
            text += f"• <tt>{iface}</tt>\n"
        self.net_label.set_markup(text)

    def build_power_page(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_border_width(12)

        lbl = Gtk.Label()
        lbl.set_markup("<span size='large' weight='bold'>Power &amp; Display Sleep</span>")
        lbl.set_xalign(0)
        box.pack_start(lbl, False, False, 0)

        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.pack_start(row, False, False, 0)
        row.pack_start(Gtk.Label(label="Display Blanking:"), False, False, 0)

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

def main():
    win = ControlCenterWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
