#!/usr/bin/env python3
"""Generate Plymouth theme files and spinner animation frames for LiteOffice OS."""

import math
import os
import shutil
import subprocess

THEME_DIR = os.path.join(os.path.dirname(__file__), "liteoffice")
os.makedirs(THEME_DIR, exist_ok=True)

# 1. Write Plymouth theme metadata
THEME_CONF = """[Plymouth Theme]
Name=LiteOffice
Description=LiteOffice OS clean, low-overhead boot and shutdown splash
ModuleName=two-step

[two-step]
ImageDir=/usr/share/plymouth/themes/liteoffice
HorizontalAlignment=0.5
VerticalAlignment=0.45
Transition=fade
TransitionDuration=0.3
BackgroundStartColor=0x16191f
BackgroundEndColor=0x16191f
WatermarkHorizontalAlignment=0.5
WatermarkVerticalAlignment=0.42
AnimationFrameRate=12
AnimationHorizontalAlignment=0.5
AnimationVerticalAlignment=0.60
ProgressBar=false
"""

with open(os.path.join(THEME_DIR, "liteoffice.plymouth"), "w") as f:
    f.write(THEME_CONF)

# 2. Render watermark (logo with title text below it)
# We can create a 320x180 composite SVG with the 96px icon and clean "LiteOffice OS" text
LOGO_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 160" width="360" height="160">
  <defs>
    <filter id="subtle-shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#000000" flood-opacity="0.35"/>
    </filter>
  </defs>
  
  <!-- Icon container centered at (180, 50) -->
  <g transform="translate(140, 10)">
    <!-- Base Plate -->
    <rect x="0" y="0" width="80" height="80" rx="16" fill="#1e222a" stroke="#282c34" stroke-width="2" filter="url(#subtle-shadow)"/>
    <!-- Folded Document Body -->
    <path d="M 22 16 L 46 16 L 58 28 L 58 64 L 22 64 Z" fill="#2563eb"/>
    <!-- Fold Flap -->
    <path d="M 46 16 L 46 28 L 58 28 Z" fill="#60a5fa" opacity="0.9"/>
    <!-- Content Lines -->
    <rect x="28" y="34" width="24" height="3" rx="1.5" fill="#f8fafc"/>
    <rect x="28" y="42" width="24" height="3" rx="1.5" fill="#f8fafc" opacity="0.8"/>
    <rect x="28" y="50" width="16" height="3" rx="1.5" fill="#f8fafc" opacity="0.8"/>
  </g>

  <!-- Typography -->
  <text x="180" y="115" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-size="22" font-weight="700" fill="#f8fafc" text-anchor="middle" letter-spacing="1">LiteOffice <tspan fill="#3b82f6">OS</tspan></text>
  <text x="180" y="138" font-family="-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif" font-size="11" font-weight="500" fill="#94a3b8" text-anchor="middle" letter-spacing="2">FAST · LEAN · PRODUCTIVE</text>
</svg>
"""

svg_path = os.path.join(THEME_DIR, "watermark.svg")
with open(svg_path, "w") as f:
    f.write(LOGO_SVG)

watermark_png = os.path.join(THEME_DIR, "watermark.png")
subprocess.run(["rsvg-convert", "-w", "360", "-h", "160", svg_path, "-o", watermark_png], check=True)
os.remove(svg_path)

# 3. Render 12-frame smooth spinner animation: throbber-00.png .. throbber-11.png
# Plymouth two-step module searches for throbber-*.png or animation-*.png
for frame in range(12):
    angle_offset = frame * (360 / 12)
    svg_spinner = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="40" height="40">
      <g transform="rotate({angle_offset} 20 20)">
"""
    for i in range(8):
        a = i * (2 * math.pi / 8)
        cx = 20 + 13 * math.cos(a)
        cy = 20 + 13 * math.sin(a)
        opacity = 0.2 + 0.8 * (i / 7)
        r = 2.0 + 0.5 * (i / 7)
        svg_spinner += f'        <circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="#3b82f6" opacity="{opacity:.2f}"/>\n'
    svg_spinner += """      </g>
    </svg>"""

    frame_svg = os.path.join(THEME_DIR, f"temp_{frame}.svg")
    with open(frame_svg, "w") as f:
        f.write(svg_spinner)

    # Plymouth supports progress-*.png and throbber-*.png
    throbber_png = os.path.join(THEME_DIR, f"throbber-{frame:02d}.png")
    subprocess.run(["rsvg-convert", "-w", "40", "-h", "40", frame_svg, "-o", throbber_png], check=True)
    
    # Also save as progress-*.png for maximum compatibility with both two-step and spinner modes
    progress_png = os.path.join(THEME_DIR, f"progress-{frame:02d}.png")
    shutil.copyfile(throbber_png, progress_png)
    
    os.remove(frame_svg)

print(f"Generated Plymouth LiteOffice theme in {THEME_DIR}")
