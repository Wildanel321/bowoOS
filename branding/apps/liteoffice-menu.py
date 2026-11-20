#!/usr/bin/env python3
# ==============================================================================
# LiteOffice OS — Windows 11 Fluent Dark Start Menu
# Memory Footprint: ~10-12 MB RAM | Instant Search | Pinned & All Apps View
# ==============================================================================
import os
import sys
import signal
import subprocess
import getpass
from pathlib import Path

PID_FILE = "/tmp/liteoffice-menu.pid"

# Check single instance / toggle behavior
if os.path.exists(PID_FILE):
    try:
        with open(PID_FILE, "r") as pf:
            old_pid = int(pf.read().strip())
        os.kill(old_pid, signal.SIGTERM)
        os.remove(PID_FILE)
        sys.exit(0)
    except (ValueError, ProcessLookupError, PermissionError):
        pass

with open(PID_FILE, "w") as pf:
    pf.write(str(os.getpid()))

def cleanup_pid():
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except OSError:
        pass

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Gio, Pango

# ------------------------------------------------------------------------------
# Modern Fluent Dark CSS Styling
# ------------------------------------------------------------------------------
CSS_DATA = b"""
window.start-menu-window {
    background-color: #1a1e27;
    border: 1px solid #2d3342;
    border-radius: 14px;
}

.search-box {
    background-color: #12151d;
    border: 1px solid #2a3142;
    border-radius: 8px;
    padding: 6px 12px;
}

.search-box:focus-within {
    border-color: #0078d4;
    box-shadow: 0 0 0 1px #0078d4;
}

.search-entry {
    background: transparent;
    border: none;
    color: #f8fafc;
    font-size: 10.5pt;
    box-shadow: none;
}

.search-entry:focus {
    background: transparent;
    box-shadow: none;
}

.section-title {
    color: #94a3b8;
    font-size: 10.5pt;
    font-weight: 700;
}

.btn-all-apps {
    color: #94a3b8;
    font-size: 9.5pt;
    font-weight: 500;
    background: transparent;
    border: none;
    border-radius: 6px;
    padding: 4px 8px;
}

.btn-all-apps:hover {
    background-color: #282f3f;
    color: #38bdf8;
}

.btn-back {
    color: #38bdf8;
    font-size: 9.5pt;
    font-weight: 600;
    background: transparent;
    border: none;
    border-radius: 6px;
    padding: 4px 8px;
}

.btn-back:hover {
    background-color: #282f3f;
    color: #ffffff;
}

.app-tile {
    background: transparent;
    border: none;
    border-radius: 8px;
    padding: 8px 4px;
    transition: all 100ms ease-in-out;
}

.app-tile:hover {
    background-color: #262c3a;
}

.app-tile-label {
    color: #f1f5f9;
    font-size: 8.5pt;
    font-weight: 500;
    margin-top: 4px;
}

.recommended-card {
    background-color: #202531;
    border: 1px solid #2b3242;
    border-radius: 8px;
    padding: 8px 12px;
    transition: all 100ms ease-in-out;
}

.recommended-card:hover {
    background-color: #272f3e;
    border-color: #38bdf8;
}

.recommended-title {
    color: #f8fafc;
    font-size: 9.5pt;
    font-weight: 600;
}

.recommended-desc {
    color: #64748b;
    font-size: 8pt;
}

.all-apps-row {
    background: transparent;
    border: none;
    border-radius: 6px;
    padding: 6px 10px;
}

.all-apps-row:hover {
    background-color: #252b39;
}

.all-apps-header {
    color: #38bdf8;
    font-size: 11pt;
    font-weight: bold;
    padding: 4px 8px;
}

.footer-bar {
    background-color: #13161e;
    border-top: 1px solid #232835;
    border-bottom-left-radius: 14px;
    border-bottom-right-radius: 14px;
    padding: 10px 18px;
}

.user-name {
    color: #f8fafc;
    font-size: 10pt;
    font-weight: 600;
}

.user-sub {
    color: #64748b;
    font-size: 8pt;
}

.icon-btn {
    background: transparent;
    border: none;
    border-radius: 6px;
    color: #94a3b8;
    padding: 6px 8px;
}

.icon-btn:hover {
    background-color: #262d3c;
    color: #f8fafc;
}

.icon-btn-power:hover {
    background-color: #3b1d24;
    color: #ef4444;
}

menu {
    background-color: #1a1e27;
    border: 1px solid #2d3342;
    border-radius: 8px;
    padding: 4px;
}

menuitem {
    color: #f8fafc;
    border-radius: 4px;
    padding: 6px 12px;
}

menuitem:hover {
    background-color: #0078d4;
    color: #ffffff;
}
"""

class StartMenu(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.set_title("Start Menu")
        self.set_role("liteoffice-start-menu")
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_keep_above(True)
        self.set_default_size(480, 560)
        self.get_style_context().add_class("start-menu-window")

        # Load icon theme
        self.icon_theme = Gtk.IconTheme.get_default()

        # Build UI Structure
        self._build_ui()
        self._load_system_apps()

        # Connect events
        self.connect("destroy", lambda w: cleanup_pid())
        self.connect("focus-out-event", self._on_focus_out)
        self.connect("key-press-event", self._on_key_press)

        # Position window near bottom-left of active screen
        self._position_window()

    def _build_ui(self):
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_box)

        # 1. Top Section (Search Bar)
        top_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        top_box.set_margin_start(16)
        top_box.set_margin_end(16)
        top_box.set_margin_top(16)
        top_box.set_margin_bottom(12)

        search_container = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        search_container.get_style_context().add_class("search-box")

        search_icon = Gtk.Image.new_from_icon_name("system-search-symbolic", Gtk.IconSize.MENU)
        search_container.pack_start(search_icon, False, False, 0)

        self.search_entry = Gtk.Entry()
        self.search_entry.set_placeholder_text("Type here to search")
        self.search_entry.get_style_context().add_class("search-entry")
        self.search_entry.set_hexpand(True)
        self.search_entry.connect("changed", self._on_search_changed)
        self.search_entry.connect("activate", self._on_search_activate)
        search_container.pack_start(self.search_entry, True, True, 0)

        top_box.pack_start(search_container, False, False, 0)
        main_box.pack_start(top_box, False, False, 0)

        # 2. Central Content Stack
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(150)
        main_box.pack_start(self.stack, True, True, 0)

        # Page 1: Pinned & Recommended (Default View matching Image)
        self.page_pinned = self._create_pinned_page()
        self.stack.add_named(self.page_pinned, "pinned")

        # Page 2: All Apps Alphabetical View
        self.page_all_apps = self._create_all_apps_page()
        self.stack.add_named(self.page_all_apps, "all_apps")

        # Page 3: Search Results View
        self.page_search = self._create_search_page()
        self.stack.add_named(self.page_search, "search")

        # 3. Footer Bar (User Avatar + Power & Settings)
        footer_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        footer_box.get_style_context().add_class("footer-bar")

        # User profile
        user_avatar = Gtk.Image.new_from_icon_name("avatar-default-symbolic", Gtk.IconSize.DND)
        footer_box.pack_start(user_avatar, False, False, 0)

        username = getpass.getuser()
        user_info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        lbl_user = Gtk.Label(label=username.capitalize(), xalign=0)
        lbl_user.get_style_context().add_class("user-name")
        lbl_role = Gtk.Label(label="LiteOffice OS User", xalign=0)
        lbl_role.get_style_context().add_class("user-sub")
        user_info_box.pack_start(lbl_user, False, False, 0)
        user_info_box.pack_start(lbl_role, False, False, 0)
        footer_box.pack_start(user_info_box, False, False, 0)

        # Settings Icon Button
        btn_settings = Gtk.Button()
        img_settings = Gtk.Image.new_from_icon_name("preferences-system-symbolic", Gtk.IconSize.BUTTON)
        btn_settings.set_image(img_settings)
        btn_settings.get_style_context().add_class("icon-btn")
        btn_settings.set_tooltip_text("Control Center Settings")
        btn_settings.connect("clicked", lambda b: self._launch_app("/usr/local/bin/liteoffice-control-center"))
        footer_box.pack_end(btn_settings, False, False, 0)

        # Power Icon Button
        btn_power = Gtk.Button()
        img_power = Gtk.Image.new_from_icon_name("system-shutdown-symbolic", Gtk.IconSize.BUTTON)
        btn_power.set_image(img_power)
        btn_power.get_style_context().add_class("icon-btn")
        btn_power.get_style_context().add_class("icon-btn-power")
        btn_power.set_tooltip_text("Power Options")
        btn_power.connect("clicked", self._show_power_menu)
        footer_box.pack_end(btn_power, False, False, 4)

        main_box.pack_end(footer_box, False, False, 0)

    def _create_pinned_page(self):
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        container.set_margin_start(16)
        container.set_margin_end(16)
        container.set_margin_bottom(12)

        # Pinned Header
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        lbl_pinned = Gtk.Label(label="Pinned", xalign=0)
        lbl_pinned.get_style_context().add_class("section-title")
        header_box.pack_start(lbl_pinned, False, False, 0)

        btn_all_apps = Gtk.Button(label="All apps →")
        btn_all_apps.get_style_context().add_class("btn-all-apps")
        btn_all_apps.connect("clicked", lambda b: self.stack.set_visible_child_name("all_apps"))
        header_box.pack_end(btn_all_apps, False, False, 0)
        container.pack_start(header_box, False, False, 0)

        # Pinned Apps Grid (6 items per row matching Image)
        pinned_grid = Gtk.Grid()
        pinned_grid.set_column_spacing(10)
        pinned_grid.set_row_spacing(12)
        pinned_grid.set_column_homogeneous(True)

        pinned_items = [
            ("Firefox", "web-browser", "firefox-esr", "/usr/share/applications/Web-Browser.desktop"),
            ("Files", "system-file-manager", "pcmanfm", "/usr/share/applications/pcmanfm.desktop"),
            ("Software", "system-software-install", "/usr/local/bin/liteoffice-upgrade", ""),
            ("Word", "x-office-document", "abiword", "/usr/share/applications/Word-Processor.desktop"),
            ("Spreadsheet", "x-office-spreadsheet", "gnumeric", "/usr/share/applications/Spreadsheet.desktop"),
            ("PDF", "x-office-drawing", "qpdfview", "/usr/share/applications/PDF-Viewer.desktop"),
            ("Terminal", "utilities-terminal", "lxterminal", "/usr/share/applications/Terminal.desktop"),
            ("Task Mgr", "utilities-system-monitor", "/usr/local/bin/liteoffice-monitor", "/usr/share/applications/liteoffice-monitor.desktop"),
            ("Settings", "preferences-system", "/usr/local/bin/liteoffice-control-center", "/usr/share/applications/liteoffice-control-center.desktop"),
            ("Install OS", "drive-harddisk", "/usr/local/bin/liteoffice-installer-launcher", "/usr/share/applications/liteoffice-installer.desktop"),
            ("About OS", "help-about", "/usr/local/bin/liteoffice-about", "/usr/share/applications/About-LiteOffice.desktop"),
            ("Power", "system-shutdown", "/usr/local/bin/liteoffice-session", "/usr/share/applications/liteoffice-session.desktop"),
        ]

        for i, (name, icon_name, cmd, desktop_file) in enumerate(pinned_items):
            col = i % 6
            row = i // 6
            tile = self._create_app_tile(name, icon_name, cmd, desktop_file)
            pinned_grid.attach(tile, col, row, 1, 1)

        container.pack_start(pinned_grid, False, False, 0)

        # Recommended Section
        lbl_rec = Gtk.Label(label="Recommended", xalign=0)
        lbl_rec.get_style_context().add_class("section-title")
        lbl_rec.set_margin_top(8)
        container.pack_start(lbl_rec, False, False, 0)

        rec_grid = Gtk.Grid()
        rec_grid.set_column_spacing(10)
        rec_grid.set_row_spacing(8)
        rec_grid.set_column_homogeneous(True)

        rec_items = [
            ("Console", "utilities-terminal", "Terminal Command Prompt", "lxterminal"),
            ("System Monitor", "utilities-system-monitor", "Windows 10/11 Task Manager", "/usr/local/bin/liteoffice-monitor"),
            ("Settings", "preferences-system", "LiteOffice Control Center", "/usr/local/bin/liteoffice-control-center"),
            ("Install LiteOffice OS", "drive-harddisk", "Setup OS to Physical Storage", "/usr/local/bin/liteoffice-installer-launcher"),
        ]

        for idx, (title, icon_name, desc, cmd) in enumerate(rec_items):
            col = idx % 2
            row = idx // 2
            card = self._create_recommended_card(title, icon_name, desc, cmd)
            rec_grid.attach(card, col, row, 1, 1)

        container.pack_start(rec_grid, False, False, 0)
        return container

    def _create_app_tile(self, name, icon_name, cmd, desktop_file):
        btn = Gtk.Button()
        btn.get_style_context().add_class("app-tile")

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.set_halign(Gtk.Align.CENTER)

        img = Gtk.Image()
        if self.icon_theme.has_icon(icon_name):
            img.set_from_icon_name(icon_name, Gtk.IconSize.DND)
        elif self.icon_theme.has_icon("application-x-executable"):
            img.set_from_icon_name("application-x-executable", Gtk.IconSize.DND)
        else:
            img.set_from_icon_name("system-run", Gtk.IconSize.DND)

        lbl = Gtk.Label(label=name)
        lbl.get_style_context().add_class("app-tile-label")
        lbl.set_ellipsize(Pango.EllipsizeMode.END)
        lbl.set_max_width_chars(8)

        box.pack_start(img, False, False, 0)
        box.pack_start(lbl, False, False, 0)
        btn.add(box)
        btn.connect("clicked", lambda b: self._launch_app(cmd))
        return btn

    def _create_recommended_card(self, title, icon_name, desc, cmd):
        btn = Gtk.Button()
        btn.get_style_context().add_class("recommended-card")

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        img = Gtk.Image.new_from_icon_name(icon_name if self.icon_theme.has_icon(icon_name) else "application-x-executable", Gtk.IconSize.LARGE_TOOLBAR)
        box.pack_start(img, False, False, 0)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        lbl_title = Gtk.Label(label=title, xalign=0)
        lbl_title.get_style_context().add_class("recommended-title")
        lbl_desc = Gtk.Label(label=desc, xalign=0)
        lbl_desc.get_style_context().add_class("recommended-desc")

        text_box.pack_start(lbl_title, False, False, 0)
        text_box.pack_start(lbl_desc, False, False, 0)
        box.pack_start(text_box, True, True, 0)

        btn.add(box)
        btn.connect("clicked", lambda b: self._launch_app(cmd))
        return btn

    def _create_all_apps_page(self):
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        container.set_margin_start(16)
        container.set_margin_end(16)
        container.set_margin_bottom(12)

        # Header with Back button
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btn_back = Gtk.Button(label="← Back")
        btn_back.get_style_context().add_class("btn-back")
        btn_back.connect("clicked", lambda b: self.stack.set_visible_child_name("pinned"))
        header_box.pack_start(btn_back, False, False, 0)

        lbl_title = Gtk.Label(label="All apps", xalign=0)
        lbl_title.get_style_context().add_class("section-title")
        header_box.pack_start(lbl_title, False, False, 4)
        container.pack_start(header_box, False, False, 0)

        # Scrollable list
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)

        self.all_apps_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scrolled.add(self.all_apps_box)
        container.pack_start(scrolled, True, True, 0)
        return container

    def _create_search_page(self):
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        container.set_margin_start(16)
        container.set_margin_end(16)
        container.set_margin_bottom(12)

        lbl_results = Gtk.Label(label="Search Results", xalign=0)
        lbl_results.get_style_context().add_class("section-title")
        container.pack_start(lbl_results, False, False, 0)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_hexpand(True)
        scrolled.set_vexpand(True)

        self.search_results_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        scrolled.add(self.search_results_box)
        container.pack_start(scrolled, True, True, 0)
        return container

    def _load_system_apps(self):
        self.apps = []
        app_dirs = [
            "/usr/share/applications",
            "/usr/local/share/applications",
            os.path.expanduser("~/.local/share/applications"),
        ]

        seen_names = set()
        for adir in app_dirs:
            if not os.path.isdir(adir):
                continue
            for f in sorted(os.listdir(adir)):
                if not f.endswith(".desktop"):
                    continue
                p = os.path.join(adir, f)
                try:
                    app_info = Gio.DesktopAppInfo.new_from_filename(p)
                    if not app_info or app_info.get_is_hidden() or app_info.get_nodisplay():
                        continue
                    name = app_info.get_name()
                    if not name or name in seen_names:
                        continue
                    seen_names.add(name)
                    icon = app_info.get_icon()
                    icon_name = icon.to_string() if icon else "application-x-executable"
                    exec_cmd = app_info.get_executable() or ""
                    desc = app_info.get_description() or ""
                    self.apps.append({
                        "name": name,
                        "icon_name": icon_name,
                        "cmd": exec_cmd,
                        "desc": desc,
                        "app_info": app_info,
                    })
                except Exception:
                    pass

        self.apps.sort(key=lambda a: a["name"].lower())
        self._populate_all_apps_view()

    def _populate_all_apps_view(self):
        current_letter = ""
        for app in self.apps:
            first_letter = app["name"][0].upper()
            if not first_letter.isalpha():
                first_letter = "#"
            if first_letter != current_letter:
                current_letter = first_letter
                lbl_letter = Gtk.Label(label=current_letter, xalign=0)
                lbl_letter.get_style_context().add_class("all-apps-header")
                self.all_apps_box.pack_start(lbl_letter, False, False, 6)

            row = self._create_app_list_row(app)
            self.all_apps_box.pack_start(row, False, False, 0)

        self.all_apps_box.show_all()

    def _create_app_list_row(self, app):
        btn = Gtk.Button()
        btn.get_style_context().add_class("all-apps-row")

        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)

        icon_name = app["icon_name"]
        img = Gtk.Image.new_from_icon_name(icon_name if self.icon_theme.has_icon(icon_name) else "application-x-executable", Gtk.IconSize.BUTTON)
        box.pack_start(img, False, False, 0)

        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        lbl_name = Gtk.Label(label=app["name"], xalign=0)
        lbl_name.get_style_context().add_class("recommended-title")
        text_box.pack_start(lbl_name, False, False, 0)

        if app["desc"]:
            lbl_desc = Gtk.Label(label=app["desc"], xalign=0)
            lbl_desc.get_style_context().add_class("recommended-desc")
            lbl_desc.set_ellipsize(Pango.EllipsizeMode.END)
            text_box.pack_start(lbl_desc, False, False, 0)

        box.pack_start(text_box, True, True, 0)
        btn.add(box)
        btn.connect("clicked", lambda b: self._launch_desktop_app(app))
        return btn

    def _on_search_changed(self, entry):
        q = entry.get_text().strip().lower()
        if not q:
            self.stack.set_visible_child_name("pinned")
            return

        self.stack.set_visible_child_name("search")
        for child in self.search_results_box.get_children():
            self.search_results_box.remove(child)

        matches = [a for a in self.apps if q in a["name"].lower() or q in a["desc"].lower()]
        if matches:
            for app in matches[:15]:
                row = self._create_app_list_row(app)
                self.search_results_box.pack_start(row, False, False, 0)
        else:
            lbl_empty = Gtk.Label(label=f"No results found for '{q}'")
            lbl_empty.get_style_context().add_class("recommended-desc")
            lbl_empty.set_margin_top(20)
            self.search_results_box.pack_start(lbl_empty, False, False, 0)

        self.search_results_box.show_all()

    def _on_search_activate(self, entry):
        q = entry.get_text().strip().lower()
        if not q:
            return
        matches = [a for a in self.apps if q in a["name"].lower() or q in a["desc"].lower()]
        if matches:
            self._launch_desktop_app(matches[0])

    def _launch_desktop_app(self, app):
        try:
            if app.get("app_info"):
                app["app_info"].launch([], None)
            else:
                self._launch_app(app["cmd"])
        except Exception:
            self._launch_app(app["cmd"])
        self.close_menu()

    def _launch_app(self, cmd):
        if not cmd:
            return
        try:
            subprocess.Popen(cmd, shell=True, start_new_session=True)
        except Exception as e:
            print(f"Error launching {cmd}: {e}")
        self.close_menu()

    def _show_power_menu(self, widget):
        menu = Gtk.Menu()

        items = [
            ("⏻  Shut Down", "/usr/local/bin/lite-logout poweroff"),
            ("↻  Restart", "/usr/local/bin/lite-logout reboot"),
            ("⇥  Sign Out", "/usr/local/bin/lite-logout logout"),
            ("🔒  Lock Screen", "/usr/local/bin/lite-logout lock"),
            ("⚡  Sleep (Suspend)", "/usr/local/bin/lite-logout suspend"),
            ("⋯  All Power Options...", "/usr/local/bin/liteoffice-session"),
        ]

        for label, cmd in items:
            item = Gtk.MenuItem(label=label)
            item.connect("activate", lambda i, c=cmd: self._execute_power_action(c))
            menu.append(item)

        menu.show_all()
        menu.popup_at_widget(widget, Gdk.Gravity.NORTH_WEST, Gdk.Gravity.SOUTH_WEST, None)

    def _execute_power_action(self, cmd):
        self.close_menu()
        subprocess.Popen(cmd, shell=True)

    def _position_window(self):
        screen = Gdk.Screen.get_default()
        if not screen:
            self.set_position(Gtk.WindowPosition.CENTER)
            return

        screen_w = screen.get_width()
        screen_h = screen.get_height()

        menu_w = 480
        menu_h = 560

        # Position above bottom panel: x=12, y=screen_h - menu_h - 40
        pos_x = 12
        pos_y = max(10, screen_h - menu_h - 42)
        self.move(pos_x, pos_y)

    def _on_focus_out(self, widget, event):
        self.close_menu()
        return False

    def _on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close_menu()
            return True
        return False

    def close_menu(self):
        cleanup_pid()
        Gtk.main_quit()

def main():
    Gtk.init(None)

    # Apply Fluent CSS
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS_DATA)
    screen = Gdk.Screen.get_default()
    if screen:
        Gtk.StyleContext.add_provider_for_screen(
            screen,
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    win = StartMenu()
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
