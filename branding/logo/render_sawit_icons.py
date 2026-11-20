#!/usr/bin/env python3
"""
render_sawit_icons.py — Renders all system icons from the palm oil tree emblem
in sizes: 16, 24, 32, 48, 64, 128, 256, 512 and liteoffice-logo.png.
"""

import os
import sys
import math
from PySide6 import QtCore, QtGui, QtSvg

def generate_palm_icon_svg(size):
    cx = size / 2.0
    cy = size / 2.0
    scale = size / 256.0
    r_badge = 112.0 * scale
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}" width="{size}" height="{size}">
  <defs>
    <radialGradient id="badgeGrad" cx="50%" cy="35%" r="68%">
      <stop offset="0%" stop-color="#14213d"/>
      <stop offset="60%" stop-color="#0c1527"/>
      <stop offset="100%" stop-color="#040812"/>
    </radialGradient>

    <linearGradient id="rimGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="35%" stop-color="#34d399"/>
      <stop offset="70%" stop-color="#fbbf24"/>
      <stop offset="100%" stop-color="#10b981"/>
    </linearGradient>

    <linearGradient id="centerFrondGrad" x1="0%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#047857"/>
      <stop offset="40%" stop-color="#10b981"/>
      <stop offset="80%" stop-color="#6ee7b7"/>
      <stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>

    <linearGradient id="leftFrondGrad" x1="100%" y1="50%" x2="0%" y2="50%">
      <stop offset="0%" stop-color="#047857"/>
      <stop offset="35%" stop-color="#10b981"/>
      <stop offset="80%" stop-color="#6ee7b7"/>
      <stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>

    <linearGradient id="rightFrondGrad" x1="0%" y1="50%" x2="100%" y2="50%">
      <stop offset="0%" stop-color="#047857"/>
      <stop offset="35%" stop-color="#10b981"/>
      <stop offset="80%" stop-color="#6ee7b7"/>
      <stop offset="100%" stop-color="#ffffff"/>
    </linearGradient>

    <linearGradient id="trunkGrad" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#94a3b8"/>
      <stop offset="40%" stop-color="#64748b"/>
      <stop offset="100%" stop-color="#334155"/>
    </linearGradient>

    <linearGradient id="fruitGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#fef08a"/>
      <stop offset="30%" stop-color="#f59e0b"/>
      <stop offset="75%" stop-color="#d97706"/>
      <stop offset="100%" stop-color="#78350f"/>
    </linearGradient>
  </defs>

  <!-- Outer Orbit Rim -->
  <circle cx="{cx}" cy="{cy}" r="{r_badge + 11 * scale}" fill="none" stroke="url(#rimGrad)" stroke-width="{2.5 * scale}" opacity="0.85" stroke-dasharray="{7 * scale} {4 * scale}"/>
  
  <!-- Medallion Disc -->
  <circle cx="{cx}" cy="{cy}" r="{r_badge}" fill="url(#badgeGrad)" stroke="#ffffff" stroke-width="{1.8 * scale}" stroke-opacity="0.4"/>

  <!-- Palm Tree Group -->
  <g transform="translate({cx}, {cy + 6 * scale})">
    <!-- Base Mound -->
    <path d="M {-55 * scale} {72 * scale} Q 0 {64 * scale} {55 * scale} {72 * scale} Z" fill="#060b14"/>

    <!-- Trunk -->
    <path d="M {-11 * scale} {8 * scale} L {11 * scale} {8 * scale} L {18 * scale} {70 * scale} L {-18 * scale} {70 * scale} Z" 
          fill="url(#trunkGrad)" stroke="#cbd5e1" stroke-width="{0.8 * scale}"/>

    <!-- Diamond Scars -->
'''
    for row in range(5):
        y_pos = (16.0 + row * 11.0) * scale
        half_w = (12.0 + row * 1.0) * scale
        svg += f'''    <polygon points="0,{y_pos - 4 * scale} {half_w * 0.82},{y_pos} 0,{y_pos + 4 * scale} {-half_w * 0.82},{y_pos}" fill="#0f172a" stroke="#cbd5e1" stroke-width="{0.8 * scale}" opacity="0.75"/>\n'''

    # Fruit Bunches
    svg += f'''
    <!-- Fruit Bunches -->
    <g transform="translate({-15 * scale}, {11 * scale}) rotate(-14)">
      <ellipse cx="0" cy="0" rx="{8.5 * scale}" ry="{12 * scale}" fill="url(#fruitGrad)"/>
      <circle cx="{-3 * scale}" cy="{-5 * scale}" r="{2.4 * scale}" fill="#fef08a"/>
      <circle cx="{2 * scale}" cy="{-5 * scale}" r="{2.3 * scale}" fill="#fbbf24"/>
      <circle cx="{-1 * scale}" cy="{1 * scale}" r="{2.5 * scale}" fill="#f59e0b"/>
    </g>

    <g transform="translate({15 * scale}, {11 * scale}) rotate(14)">
      <ellipse cx="0" cy="0" rx="{8.5 * scale}" ry="{12 * scale}" fill="url(#fruitGrad)"/>
      <circle cx="{3 * scale}" cy="{-5 * scale}" r="{2.4 * scale}" fill="#fef08a"/>
      <circle cx="{-2 * scale}" cy="{-5 * scale}" r="{2.3 * scale}" fill="#fbbf24"/>
      <circle cx="{1 * scale}" cy="{1 * scale}" r="{2.5 * scale}" fill="#f59e0b"/>
    </g>

    <!-- Center Upright Frond -->
    <g transform="translate(0, 0)">
'''
    for i in range(1, 10):
        t = i / 10.0
        ly = 4.0 * scale - (86.0 * scale) * t
        lw = (24.0 * math.sin(t * math.pi)) * scale
        svg += f'''      <path d="M 0 {ly} C {-lw * 0.5} {ly - 3 * scale} {-lw * 0.85} {ly - 1 * scale} {-lw} {ly + 4 * scale} C {-lw * 0.7} {ly + 1 * scale} {-lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)"/>\n'''
        svg += f'''      <path d="M 0 {ly} C {lw * 0.5} {ly - 3 * scale} {lw * 0.85} {ly - 1 * scale} {lw} {ly + 4 * scale} C {lw * 0.7} {ly + 1 * scale} {lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)"/>\n'''
    svg += f'''      <path d="M 0 4 Q 0 -45 0 -88" fill="none" stroke="#ffffff" stroke-width="{2 * scale}" stroke-linecap="round"/>
    </g>\n'''

    # Left & Right Fronds
    left_fronds = [
        {"ang": -20, "flen": 82 * scale, "curv": -10 * scale, "n": 9, "grad": "leftFrondGrad"},
        {"ang": -44, "flen": 86 * scale, "curv": -18 * scale, "n": 10, "grad": "leftFrondGrad"},
        {"ang": -70, "flen": 88 * scale, "curv": -26 * scale, "n": 10, "grad": "leftFrondGrad"},
        {"ang": -92, "flen": 80 * scale, "curv": -32 * scale, "n": 9, "grad": "leftFrondGrad"},
    ]
    right_fronds = [
        {"ang": 20, "flen": 82 * scale, "curv": 10 * scale, "n": 9, "grad": "rightFrondGrad"},
        {"ang": 44, "flen": 86 * scale, "curv": 18 * scale, "n": 10, "grad": "rightFrondGrad"},
        {"ang": 70, "flen": 88 * scale, "curv": 26 * scale, "n": 10, "grad": "rightFrondGrad"},
        {"ang": 92, "flen": 80 * scale, "curv": 32 * scale, "n": 9, "grad": "rightFrondGrad"},
    ]

    for f in left_fronds + right_fronds:
        ang = f["ang"]
        flen = f["flen"]
        curv = f["curv"]
        n_leaf = f["n"]
        grad = f["grad"]
        sgn = -1 if ang < 0 else 1

        svg += f'''    <g transform="translate(0, 2) rotate({ang})">\n'''
        for i in range(1, n_leaf + 1):
            t = i / (n_leaf + 1)
            lx = 2 * (1 - t) * t * (curv * 0.4) + (t ** 2) * curv
            ly = -flen * t
            lw = (23.0 * math.sin(t * math.pi)) * scale
            lw = max(lw, 6.0 * scale)

            svg += f'''      <path d="M {lx} {ly} C {lx - sgn * lw * 0.5} {ly - 4 * scale} {lx - sgn * lw * 0.85} {ly} {lx - sgn * lw} {ly + 6 * scale} C {lx - sgn * lw * 0.7} {ly + 2 * scale} {lx - sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})"/>\n'''
            svg += f'''      <path d="M {lx} {ly} C {lx + sgn * lw * 0.5} {ly - 4 * scale} {lx + sgn * lw * 0.85} {ly} {lx + sgn * lw} {ly + 6 * scale} C {lx + sgn * lw * 0.7} {ly + 2 * scale} {lx + sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})"/>\n'''
        svg += f'''      <path d="M 0 0 Q {curv * 0.4} {-flen * 0.5} {curv} {-flen}" fill="none" stroke="#ffffff" stroke-width="{2 * scale}" stroke-linecap="round"/>
    </g>\n'''

    # Golden Center Jewel
    svg += f'''    <circle cx="0" cy="2" r="{5 * scale}" fill="#fbbf24" stroke="#ffffff" stroke-width="{1.5 * scale}"/>
  </g>
</svg>
'''
    return svg

def main():
    app = QtGui.QGuiApplication.instance() or QtGui.QGuiApplication([])
    logo_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Save master SVG
    svg_content = generate_palm_icon_svg(512)
    svg_path = os.path.join(logo_dir, "liteoffice-logo.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg_content)
    print(f"[+] Saved master logo SVG: {svg_path}")
    
    # Render PNG icons
    sizes = [16, 24, 32, 48, 64, 128, 256, 512]
    for s in sizes:
        out_png = os.path.join(logo_dir, f"liteoffice-icon-{s}.png")
        svg_s = generate_palm_icon_svg(s).encode('utf-8')
        renderer = QtSvg.QSvgRenderer(QtCore.QByteArray(svg_s))
        
        qim = QtGui.QImage(s, s, QtGui.QImage.Format.Format_ARGB32_Premultiplied)
        qim.fill(QtCore.Qt.GlobalColor.transparent)
        
        painter = QtGui.QPainter(qim)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)
        renderer.render(painter, QtCore.QRectF(0, 0, s, s))
        painter.end()
        
        qim.save(out_png, "PNG")
        print(f"[+] Rendered icon {s}x{s}: {out_png}")
        
    # Also copy 256x256 to liteoffice-logo.png
    qim_256 = QtGui.QImage(os.path.join(logo_dir, "liteoffice-icon-256.png"))
    qim_256.save(os.path.join(logo_dir, "liteoffice-logo.png"), "PNG")
    print("[+] Updated liteoffice-logo.png")

if __name__ == "__main__":
    main()
