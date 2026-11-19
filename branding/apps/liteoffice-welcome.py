#!/usr/bin/env python3
import os
import sys
import subprocess

try:
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, GdkPixbuf
except ImportError:
    print("Error: PyGObject and GTK 3 are required.")
    sys.exit(1)

CONFIG_PATH = os.path.expanduser("~/.config/liteoffice-welcome.conf")

def run_cmd(cmd):
    try:
        subprocess.Popen(cmd, shell=True)
    except Exception as e:
        print(f"Error executing {cmd}: {e}")

class WelcomeWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Welcome to LiteOffice OS")
        self.set_default_size(680, 480)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_border_width(12)

        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.add(main_box)

        # Header with Logo & Welcome
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        main_box.pack_start(header_box, False, False, 0)

        logo_path = "/usr/share/icons/LiteOffice/liteoffice-icon-64.png"
        if not os.path.exists(logo_path):
            logo_path = os.path.join(os.path.dirname(__file__), "../logo/liteoffice-icon-64.png")

        if os.path.exists(logo_path):
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(logo_path, 54, 54, True)
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            header_box.pack_start(image, False, False, 0)

        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        header_box.pack_start(title_box, True, True, 0)

        w_title = Gtk.Label()
        w_title.set_markup("<span size='large' weight='bold'>Welcome to LiteOffice OS</span>")
        w_title.set_xalign(0)
        title_box.pack_start(w_title, False, False, 0)

        w_sub = Gtk.Label(label="High-performance, lightweight office operating system engineered for minimal RAM usage.")
        w_sub.set_xalign(0)
        title_box.pack_start(w_sub, False, False, 0)

        main_box.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 0)

        # Notebook tabs
        notebook = Gtk.Notebook()
        main_box.pack_start(notebook, True, True, 0)

        # Tab 1: Overview
        t1_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        t1_box.set_border_width(12)
        t1_lbl = Gtk.Label()
        t1_lbl.set_markup(
            "<b>Welcome to your new desktop workspace!</b>\n\n"
            "LiteOffice OS is engineered from the ground up for responsiveness, security, and low memory consumption.\n\n"
            "<b>Key Features:</b>\n"
            "• Idle RAM footprint under 70 MB on low-specification systems.\n"
            "• High-speed OpenRC initialization with dynamic compressed ZRAM swap.\n"
            "• Adaptive Office application profiling based on physical hardware memory.\n"
            "• Clean, modern productivity-focused user experience."
        )
        t1_lbl.set_xalign(0)
        t1_lbl.set_line_wrap(True)
        t1_box.pack_start(t1_lbl, False, False, 0)
        notebook.append_page(t1_box, Gtk.Label(label="Overview"))

        # Tab 2: Keyboard Shortcuts
        t2_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        t2_box.set_border_width(12)
        grid = Gtk.Grid()
        grid.set_column_spacing(24)
        grid.set_row_spacing(8)
        t2_box.pack_start(grid, False, False, 0)

        shortcuts = [
            ("Super (Windows key) + Space", "Open Application Start Menu"),
            ("Super + E", "Open File Manager (PCManFM)"),
            ("Super + T", "Open Terminal (LXTerminal)"),
            ("Super + D", "Show / Toggle Desktop"),
            ("Super + L", "Session & Power Dialog"),
            ("Alt + Tab", "Switch Running Windows"),
            ("Alt + F4", "Close Current Window"),
            ("Super + Left / Right Arrow", "Snap Window to Left / Right Half"),
            ("Super + Up Arrow", "Maximize Window")
        ]

        for r, (key, desc) in enumerate(shortcuts):
            k = Gtk.Label()
            k.set_markup(f"<tt>{key}</tt>")
            k.set_xalign(0)
            d = Gtk.Label(label=desc)
            d.set_xalign(0)
            grid.attach(k, 0, r, 1, 1)
            grid.attach(d, 1, r, 1, 1)

        notebook.append_page(t2_box, Gtk.Label(label="Shortcuts"))

        # Tab 3: Quick Setup & Tools
        t3_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        t3_box.set_border_width(12)
        q_lbl = Gtk.Label()
        q_lbl.set_markup("<b>Quick Launch Applications</b>\nClick below to immediately access key system utilities:")
        q_lbl.set_xalign(0)
        t3_box.pack_start(q_lbl, False, False, 0)

        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        t3_box.pack_start(btn_row, False, False, 0)

        b1 = Gtk.Button(label="Control Center")
        b1.connect("clicked", lambda b: run_cmd("/usr/local/bin/liteoffice-control-center"))
        btn_row.pack_start(b1, True, True, 0)

        b2 = Gtk.Button(label="System Monitor")
        b2.connect("clicked", lambda b: run_cmd("/usr/local/bin/liteoffice-monitor"))
        btn_row.pack_start(b2, True, True, 0)

        b3 = Gtk.Button(label="Word Processor")
        b3.connect("clicked", lambda b: run_cmd("/usr/local/bin/lite-launch-office"))
        btn_row.pack_start(b3, True, True, 0)

        notebook.append_page(t3_box, Gtk.Label(label="Quick Launch"))

        # Footer
        footer_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        main_box.pack_end(footer_box, False, False, 0)

        self.check_btn = Gtk.CheckButton(label="Show this welcome window on startup")
        self.check_btn.set_active(self.should_show_on_startup())
        self.check_btn.connect("toggled", self.on_show_toggled)
        footer_box.pack_start(self.check_btn, False, False, 0)

        close_btn = Gtk.Button(label="Get Started")
        close_btn.get_style_context().add_class("suggested-action")
        close_btn.connect("clicked", lambda b: Gtk.main_quit())
        footer_box.pack_end(close_btn, False, False, 0)

    def should_show_on_startup(self):
        if os.path.exists(CONFIG_PATH):
            try:
                with open(CONFIG_PATH, "r") as f:
                    return "show=false" not in f.read().lower()
            except Exception:
                pass
        return True

    def on_show_toggled(self, btn):
        val = "true" if btn.get_active() else "false"
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        try:
            with open(CONFIG_PATH, "w") as f:
                f.write(f"show={val}\n")
        except Exception as e:
            print(f"Error saving config: {e}")

def main():
    win = WelcomeWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
