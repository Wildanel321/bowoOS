#!/usr/bin/env python3
import os
import sys
import time
import subprocess

def get_cpu_usage_sample():
    try:
        with open("/proc/stat", "r") as f:
            fields = [float(x) for x in f.readline().strip().split()[1:8]]
            idle = fields[3] + fields[4]
            total = sum(fields)
            return idle, total
    except Exception:
        return 0, 1

def read_mem_real():
    mem = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    mem[parts[0].strip()] = int(parts[1].split()[0]) // 1024
    except Exception:
        pass
    total = mem.get("MemTotal", 512)
    avail = mem.get("MemAvailable", 256)
    used = total - avail
    pct = (used / total) * 100 if total > 0 else 0
    return total, used, avail, pct

def read_zram_real():
    zram_mb = 0
    algo = "none"
    if os.path.exists("/sys/block/zram0/disksize"):
        try:
            with open("/sys/block/zram0/disksize", "r") as f:
                zram_mb = int(f.read().strip()) // (1024 * 1024)
            with open("/sys/block/zram0/comp_algorithm", "r") as f:
                algo = f.read().strip()
        except Exception:
            pass
    return zram_mb, algo

def read_disk_real():
    try:
        st = os.statvfs("/")
        total_gb = (st.f_blocks * st.f_frsize) / (1024**3)
        free_gb = (st.f_bavail * st.f_frsize) / (1024**3)
        used_gb = total_gb - free_gb
        pct = (used_gb / total_gb) * 100 if total_gb > 0 else 0
        return total_gb, used_gb, free_gb, pct
    except Exception:
        return 4.0, 1.0, 3.0, 25.0

def read_processes_top(n=10):
    procs = []
    try:
        out = subprocess.check_output(f"ps -eo pid,user,comm,%cpu,%mem,rss --sort=-rss | head -n {n+1}", shell=True).decode()
        lines = out.strip().splitlines()
        for l in lines[1:]:
            parts = l.split(None, 5)
            if len(parts) >= 6:
                try:
                    rss_val = f"{int(parts[5]) // 1024} MB"
                except (ValueError, TypeError):
                    rss_val = f"{parts[5]} KB"
                procs.append({
                    "pid": parts[0],
                    "user": parts[1],
                    "cmd": parts[2],
                    "cpu": parts[3],
                    "mem": parts[4],
                    "rss_mb": rss_val
                })
    except Exception:
        pass
    return procs

def run_cli_mode():
    i1, t1 = get_cpu_usage_sample()
    time.sleep(0.5)
    i2, t2 = get_cpu_usage_sample()
    diff_total = t2 - t1
    diff_idle = i2 - i1
    cpu_pct = 100.0 * (1.0 - (diff_idle / diff_total)) if diff_total > 0 else 0.0

    mem_tot, mem_used, mem_avail, mem_pct = read_mem_real()
    zram_mb, zram_algo = read_zram_real()
    d_tot, d_used, d_free, d_pct = read_disk_real()

    print("==================================================")
    print("  LiteOffice OS — System Health & Live Metrics")
    print("==================================================")
    print(f"CPU Utilization   : {cpu_pct:.1f}%")
    print(f"Memory (RAM)      : {mem_used} MB / {mem_tot} MB used ({mem_pct:.1f}%), {mem_avail} MB Available")
    print(f"ZRAM Swap         : {zram_mb} MB configured (algorithm: {zram_algo})")
    print(f"Storage (/)       : {d_used:.2f} GB / {d_tot:.2f} GB used ({d_pct:.1f}%), {d_free:.2f} GB Free")
    print("\nTop Active Processes:")
    print(f"{'PID':<7} {'USER':<10} {'CPU%':<6} {'MEM%':<6} {'RESIDENT':<10} {'COMMAND'}")
    for p in read_processes_top(8):
        print(f"{p['pid']:<7} {p['user']:<10} {p['cpu']:<6} {p['mem']:<6} {p['rss_mb']:<10} {p['cmd']}")
    print("==================================================")
    sys.exit(0)

# GTK Mode
def run_gtk_mode():
    try:
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk, GLib
    except ImportError:
        print("PyGObject not available; falling back to CLI mode.")
        run_cli_mode()

    class MonitorWindow(Gtk.Window):
        def __init__(self):
            super().__init__(title="LiteOffice OS System Monitor")
            self.set_default_size(650, 480)
            self.set_position(Gtk.WindowPosition.CENTER)
            self.set_border_width(12)

            self.prev_idle, self.prev_total = get_cpu_usage_sample()

            vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            self.add(vbox)

            # Overview Gauges
            grid = Gtk.Grid()
            grid.set_column_spacing(16)
            grid.set_row_spacing(8)
            vbox.pack_start(grid, False, False, 0)

            # CPU Bar
            grid.attach(Gtk.Label(label="CPU Usage:"), 0, 0, 1, 1)
            self.cpu_bar = Gtk.ProgressBar()
            self.cpu_bar.set_show_text(True)
            self.cpu_bar.set_hexpand(True)
            grid.attach(self.cpu_bar, 1, 0, 1, 1)

            # RAM Bar
            grid.attach(Gtk.Label(label="Memory (RAM):"), 0, 1, 1, 1)
            self.mem_bar = Gtk.ProgressBar()
            self.mem_bar.set_show_text(True)
            self.mem_bar.set_hexpand(True)
            grid.attach(self.mem_bar, 1, 1, 1, 1)

            # Storage Bar
            grid.attach(Gtk.Label(label="Root Storage:"), 0, 2, 1, 1)
            self.disk_bar = Gtk.ProgressBar()
            self.disk_bar.set_show_text(True)
            self.disk_bar.set_hexpand(True)
            grid.attach(self.disk_bar, 1, 2, 1, 1)

            vbox.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 4)

            # Process List
            lbl = Gtk.Label()
            lbl.set_markup("<b>Active Processes (Sorted by Memory)</b>")
            lbl.set_xalign(0)
            vbox.pack_start(lbl, False, False, 0)

            scrolled = Gtk.ScrolledWindow()
            scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
            vbox.pack_start(scrolled, True, True, 0)

            self.store = Gtk.ListStore(str, str, str, str, str, str)
            self.tree = Gtk.TreeView(model=self.store)
            scrolled.add(self.tree)

            headers = ["PID", "User", "Command", "CPU %", "MEM %", "Memory (MB)"]
            for idx, h in enumerate(headers):
                renderer = Gtk.CellRendererText()
                col = Gtk.TreeViewColumn(h, renderer, text=idx)
                self.tree.append_column(col)

            # Initial Update
            self.update_metrics()
            GLib.timeout_add(1500, self.update_metrics)

        def update_metrics(self):
            # CPU
            i2, t2 = get_cpu_usage_sample()
            diff_total = t2 - self.prev_total
            diff_idle = i2 - self.prev_idle
            self.prev_total, self.prev_idle = t2, i2
            cpu_pct = 1.0 - (diff_idle / diff_total) if diff_total > 0 else 0.0
            self.cpu_bar.set_fraction(max(0.0, min(1.0, cpu_pct)))
            self.cpu_bar.set_text(f"{cpu_pct * 100:.1f}%")

            # RAM
            tot, used, avail, pct = read_mem_real()
            self.mem_bar.set_fraction(max(0.0, min(1.0, pct / 100.0)))
            self.mem_bar.set_text(f"{used} MB / {tot} MB ({pct:.1f}%)")

            # Disk
            d_tot, d_used, d_free, d_pct = read_disk_real()
            self.disk_bar.set_fraction(max(0.0, min(1.0, d_pct / 100.0)))
            self.disk_bar.set_text(f"{d_used:.1f} GB / {d_tot:.1f} GB ({d_pct:.1f}%)")

            # Processes
            self.store.clear()
            for p in read_processes_top(15):
                self.store.append([p['pid'], p['user'], p['cmd'], p['cpu'], p['mem'], p['rss_mb']])
            return True

    win = MonitorWindow()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    if "--cli" in sys.argv or not os.environ.get("DISPLAY"):
        run_cli_mode()
    else:
        run_gtk_mode()
