#!/usr/bin/env python3
# ==============================================================================
# LiteOffice OS — Fluent Dark Session & Power Control Dialog
# Memory Footprint: ~8-10 MB RAM | Instant Response | Safe Power Orchestration
# ==============================================================================
import os
import sys
import signal
import subprocess
import getpass
import socket
import atexit

PID_FILE = "/tmp/liteoffice-session.pid"

def cleanup_pid():
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except OSError:
        pass

atexit.register(cleanup_pid)

# Check single instance / toggle behavior
if os.path.exists(PID_FILE):
    try:
        with open(PID_FILE, "r") as pf:
            old_pid = int(pf.read().strip())
        # Verify process is still running and is python
        if os.path.exists(f"/proc/{old_pid}"):
            os.kill(old_pid, signal.SIGTERM)
            cleanup_pid()
            sys.exit(0)
    except (ValueError, ProcessLookupError, PermissionError):
        pass

try:
    with open(PID_FILE, "w") as pf:
        pf.write(str(os.getpid()))
except Exception:
    pass

def execute_action(action_cmd):
    cleanup_pid()
    subprocess.Popen(action_cmd, shell=True)
    sys.exit(0)

def print_cli_menu():
    print("==================================================================")
    print("  LiteOffice OS — Session & Power Control (CLI)")
    print("==================================================================")
    print("1) Shut Down (Power Off)")
    print("2) Restart (Reboot)")
    print("3) Sign Out (Log Out)")
    print("4) Lock Screen")
    print("5) Sleep (Suspend)")
    print("6) Cancel")
    print("------------------------------------------------------------------")
    try:
        choice = input("Select an action [1-6]: ").strip()
    except (KeyboardInterrupt, EOFError):
        print("\nAborted.")
        cleanup_pid()
        sys.exit(0)

    if choice == "1":
        execute_action("/usr/local/bin/lite-logout poweroff")
    elif choice == "2":
        execute_action("/usr/local/bin/lite-logout reboot")
    elif choice == "3":
        execute_action("/usr/local/bin/lite-logout logout")
    elif choice == "4":
        execute_action("/usr/local/bin/lite-logout lock")
    elif choice == "5":
        execute_action("/usr/local/bin/lite-logout suspend")
    else:
        print("Cancelled.")
        cleanup_pid()
        sys.exit(0)

def run_gtk_dialog():
    try:
        import gi
        gi.require_version("Gtk", "3.0")
        gi.require_version("Gdk", "3.0")
        from gi.repository import Gtk, Gdk, GLib, Pango
        if not Gtk.init_check(None)[0]:
            print_cli_menu()
            return
    except Exception as e:
        print(f"[!] Unable to initialize GTK 3: {e}")
        print_cli_menu()
        return

    CSS_DATA = b"""
    window.session-window {
        background-color: #161922;
        border: 1px solid #2d3345;
        border-radius: 14px;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
    }

    .header-box {
        background-color: #12151c;
        border-bottom: 1px solid #222736;
        border-top-left-radius: 14px;
        border-top-right-radius: 14px;
        padding: 16px 20px 14px 20px;
    }

    .header-title {
        color: #f8fafc;
        font-size: 13pt;
        font-weight: 700;
    }

    .header-subtitle {
        color: #94a3b8;
        font-size: 9pt;
        margin-top: 2px;
    }

    .user-chip {
        background-color: #1c212d;
        border: 1px solid #2b3345;
        border-radius: 16px;
        padding: 4px 10px;
    }

    .user-chip-label {
        color: #38bdf8;
        font-size: 8.5pt;
        font-weight: 600;
    }

    .content-box {
        padding: 16px 20px;
    }

    .action-card {
        background-color: #1e2330;
        border: 1px solid #2a3142;
        border-radius: 10px;
        padding: 12px 14px;
        transition: all 120ms ease-in-out;
    }

    .action-card:focus,
    .action-card:hover {
        background-color: #262c3e;
        border-color: #38bdf8;
    }

    .card-shutdown:hover,
    .card-shutdown:focus {
        background-color: #31181c;
        border-color: #ef4444;
    }

    .card-restart:hover,
    .card-restart:focus {
        background-color: #15273b;
        border-color: #38bdf8;
    }

    .card-logout:hover,
    .card-logout:focus {
        background-color: #2b2213;
        border-color: #f59e0b;
    }

    .card-lock:hover,
    .card-lock:focus {
        background-color: #251733;
        border-color: #a855f7;
    }

    .card-suspend:hover,
    .card-suspend:focus {
        background-color: #142a22;
        border-color: #10b981;
    }

    .action-title {
        color: #f8fafc;
        font-size: 10.5pt;
        font-weight: 600;
    }

    .action-desc {
        color: #94a3b8;
        font-size: 8pt;
    }

    .footer-box {
        background-color: #12151c;
        border-top: 1px solid #222736;
        border-bottom-left-radius: 14px;
        border-bottom-right-radius: 14px;
        padding: 12px 20px;
    }

    .btn-cancel {
        background-color: #212634;
        border: 1px solid #333a4d;
        border-radius: 8px;
        color: #e2e8f0;
        font-size: 9.5pt;
        font-weight: 500;
        padding: 6px 18px;
    }

    .btn-cancel:hover {
        background-color: #2d3447;
        color: #ffffff;
    }
    """

    class SessionWindow(Gtk.Window):
        def __init__(self):
            super().__init__(type=Gtk.WindowType.TOPLEVEL)
            self.set_title("Session & Power Options")
            self.set_role("liteoffice-session")
            self.set_decorated(False)
            self.set_skip_taskbar_hint(True)
            self.set_skip_pager_hint(True)
            self.set_keep_above(True)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_default_size(440, 480)
            self.get_style_context().add_class("session-window")

            self.icon_theme = Gtk.IconTheme.get_default()

            self._build_ui()

            self.connect("destroy", lambda w: cleanup_pid())
            self.connect("key-press-event", self._on_key_press)

        def _build_ui(self):
            main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
            self.add(main_box)

            # 1. Header
            header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            header_box.get_style_context().add_class("header-box")

            title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            lbl_title = Gtk.Label(label="Power & Session Options", xalign=0)
            lbl_title.get_style_context().add_class("header-title")
            lbl_sub = Gtk.Label(label="Choose what you want to do with your computer", xalign=0)
            lbl_sub.get_style_context().add_class("header-subtitle")
            title_box.pack_start(lbl_title, False, False, 0)
            title_box.pack_start(lbl_sub, False, False, 0)
            header_box.pack_start(title_box, True, True, 0)

            # User Chip
            username = getpass.getuser()
            hostname = socket.gethostname()
            chip_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
            chip_box.get_style_context().add_class("user-chip")
            user_icon = Gtk.Image.new_from_icon_name("avatar-default-symbolic", Gtk.IconSize.MENU)
            lbl_user = Gtk.Label(label=f"{username}@{hostname}")
            lbl_user.get_style_context().add_class("user-chip-label")
            chip_box.pack_start(user_icon, False, False, 0)
            chip_box.pack_start(lbl_user, False, False, 0)
            header_box.pack_end(chip_box, False, False, 0)

            main_box.pack_start(header_box, False, False, 0)

            # 2. Action Cards List
            content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            content_box.get_style_context().add_class("content-box")

            actions = [
                ("Shut Down", "Saves your work and completely powers off the PC",
                 "system-shutdown-symbolic", "card-shutdown", "/usr/local/bin/lite-logout poweroff"),
                ("Restart", "Closes all open apps and restarts the computer",
                 "system-reboot-symbolic", "card-restart", "/usr/local/bin/lite-logout reboot"),
                ("Sign Out", "Closes open programs and ends your current desktop session",
                 "system-log-out-symbolic", "card-logout", "/usr/local/bin/lite-logout logout"),
                ("Lock Screen", "Locks display to secure files while keeping tasks running",
                 "system-lock-screen-symbolic", "card-lock", "/usr/local/bin/lite-logout lock"),
                ("Sleep", "Saves state to memory and enters low-power sleep mode",
                 "system-suspend-symbolic", "card-suspend", "/usr/local/bin/lite-logout suspend"),
            ]

            for title, desc, icon_name, css_class, cmd in actions:
                card = self._create_action_card(title, desc, icon_name, css_class, cmd)
                content_box.pack_start(card, False, False, 0)

            main_box.pack_start(content_box, True, True, 0)

            # 3. Footer with Cancel
            footer_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
            footer_box.get_style_context().add_class("footer-box")

            lbl_hint = Gtk.Label(label="Tip: Press Esc or click Cancel to return to desktop", xalign=0)
            lbl_hint.get_style_context().add_class("header-subtitle")
            footer_box.pack_start(lbl_hint, True, True, 0)

            btn_cancel = Gtk.Button(label="Cancel")
            btn_cancel.get_style_context().add_class("btn-cancel")
            btn_cancel.connect("clicked", lambda b: self._close_dialog())
            footer_box.pack_end(btn_cancel, False, False, 0)

            main_box.pack_end(footer_box, False, False, 0)

        def _create_action_card(self, title, desc, icon_name, css_class, cmd):
            btn = Gtk.Button()
            btn.get_style_context().add_class("action-card")
            btn.get_style_context().add_class(css_class)

            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)

            # Icon
            img = Gtk.Image()
            if self.icon_theme.has_icon(icon_name):
                img.set_from_icon_name(icon_name, Gtk.IconSize.DND)
            elif self.icon_theme.has_icon("system-run"):
                img.set_from_icon_name("system-run", Gtk.IconSize.DND)
            else:
                img.set_from_icon_name("application-x-executable", Gtk.IconSize.DND)
            box.pack_start(img, False, False, 4)

            # Text
            text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            lbl_title = Gtk.Label(label=title, xalign=0)
            lbl_title.get_style_context().add_class("action-title")
            lbl_desc = Gtk.Label(label=desc, xalign=0)
            lbl_desc.get_style_context().add_class("action-desc")

            text_box.pack_start(lbl_title, False, False, 0)
            text_box.pack_start(lbl_desc, False, False, 0)
            box.pack_start(text_box, True, True, 0)

            btn.add(box)
            btn.connect("clicked", lambda b, c=cmd: execute_action(c))
            return btn

        def _on_key_press(self, widget, event):
            if event.keyval == Gdk.KEY_Escape:
                self._close_dialog()
                return True
            return False

        def _close_dialog(self):
            cleanup_pid()
            Gtk.main_quit()

    provider = Gtk.CssProvider()
    provider.load_from_data(CSS_DATA)
    screen = Gdk.Screen.get_default()
    if screen:
        Gtk.StyleContext.add_provider_for_screen(
            screen,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    win = SessionWindow()
    win.show_all()
    Gtk.main()

def main():
    if "--cli" in sys.argv or not os.environ.get("DISPLAY"):
        print_cli_menu()
    else:
        run_gtk_dialog()

if __name__ == "__main__":
    main()
