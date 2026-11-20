#!/usr/bin/env python3
"""
generate_sawit_wallpaper.py — Renders the official LiteOffice OS wallpaper
incorporating example-wallpaper.jpg (starry galaxy background),
an iconic, majestic oil palm tree logo (pohon kelapa sawit) in the center,
and "office lite" typography below with balanced breathing space.
"""

import os
import sys
import math
from PIL import Image
from PySide6 import QtCore, QtGui, QtSvg

def generate_svg_overlay(width, height):
    cx = width / 2
    scale = height / 1080.0
    cy = 425.0 * scale
    
    # Palm tree emblem parameters
    r_badge = 128.0 * scale
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">
  <defs>
    <!-- Heavy drop shadow filter for maximum legibility against stars -->
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="{4 * scale}" stdDeviation="{8 * scale}" flood-color="#020408" flood-opacity="0.95"/>
    </filter>

    <radialGradient id="badgeGrad" cx="50%" cy="35%" r="68%">
      <stop offset="0%" stop-color="#14213d" stop-opacity="0.94"/>
      <stop offset="60%" stop-color="#0c1527" stop-opacity="0.96"/>
      <stop offset="100%" stop-color="#040812" stop-opacity="0.98"/>
    </radialGradient>

    <linearGradient id="rimGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#38bdf8"/>
      <stop offset="35%" stop-color="#34d399"/>
      <stop offset="70%" stop-color="#fbbf24"/>
      <stop offset="100%" stop-color="#10b981"/>
    </linearGradient>

    <!-- Gradients for Stylized Solid Palm Fronds -->
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

    <linearGradient id="spineGrad" x1="0%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#10b981"/>
      <stop offset="60%" stop-color="#a7f3d0"/>
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

  <!-- Central Emblem with Drop Shadow -->
  <g filter="url(#shadow)">
    <!-- Outer Decorative Orbit Ring with Dashes -->
    <circle cx="{cx}" cy="{cy}" r="{r_badge + 14 * scale}" fill="none" stroke="url(#rimGrad)" stroke-width="{2 * scale}" opacity="0.8" stroke-dasharray="{8 * scale} {5 * scale}"/>
    <circle cx="{cx}" cy="{cy}" r="{r_badge + 5 * scale}" fill="none" stroke="#38bdf8" stroke-width="{1 * scale}" opacity="0.4"/>

    <!-- Medallion Background Disc -->
    <circle cx="{cx}" cy="{cy}" r="{r_badge}" fill="url(#badgeGrad)" stroke="#ffffff" stroke-width="{1.8 * scale}" stroke-opacity="0.35"/>
    <circle cx="{cx}" cy="{cy}" r="{r_badge - 8 * scale}" fill="none" stroke="#1e293b" stroke-width="{1 * scale}" opacity="0.5"/>

    <!-- ==================== POHON KELAPA SAWIT (AUTHENTIC, STYLIZED OIL PALM TREE) ==================== -->
    <g transform="translate({cx}, {cy})">
      
      <!-- Ground base mound -->
      <path d="M {-70 * scale} {86 * scale} Q 0 {75 * scale} {70 * scale} {86 * scale} Z" fill="#080e1a" opacity="0.9"/>
      
      <!-- STURDY PALM TRUNK (Batang Sawit Bertekstur Bekas Pelepah) -->
      <!-- Solid Trunk Pillar -->
      <path d="M {-13 * scale} {8 * scale} 
               L {13 * scale} {8 * scale} 
               L {20 * scale} {84 * scale} 
               L {-20 * scale} {84 * scale} Z" 
            fill="url(#trunkGrad)" stroke="#cbd5e1" stroke-width="{0.8 * scale}"/>

      <!-- Distinctive Rhomboid / Diamond Scars of Pruned Oil Palm Fronds -->
'''
    for row in range(6):
        y_pos = (16.0 + row * 11.5) * scale
        half_w = (13.5 + row * 1.0) * scale
        svg += f'''      <polygon points="0,{y_pos - 4.5 * scale} {half_w * 0.82},{y_pos} 0,{y_pos + 4.5 * scale} {-half_w * 0.82},{y_pos}" fill="#0f172a" stroke="#cbd5e1" stroke-width="{0.8 * scale}" opacity="0.75"/>\n'''

    # Tandan Buah Kelapa Sawit (Ripe Palm Oil Fruit Bunches)
    svg += f'''
      <!-- Tandan Buah Sawit (Left & Right Clustered Oil Palm Fruit Bunches) -->
      <g>
        <!-- Left Fruit Bunch -->
        <g transform="translate({-17 * scale}, {12 * scale}) rotate(-14)">
          <ellipse cx="0" cy="0" rx="{9.5 * scale}" ry="{13.5 * scale}" fill="url(#fruitGrad)"/>
          <circle cx="{-3.5 * scale}" cy="{-6 * scale}" r="{2.7 * scale}" fill="#fef08a"/>
          <circle cx="{2.5 * scale}" cy="{-6.5 * scale}" r="{2.5 * scale}" fill="#fbbf24"/>
          <circle cx="{-2 * scale}" cy="{0}" r="{2.8 * scale}" fill="#f59e0b"/>
          <circle cx="{3.5 * scale}" cy="{1.5 * scale}" r="{2.6 * scale}" fill="#d97706"/>
          <circle cx="{-1 * scale}" cy="{7 * scale}" r="{2.5 * scale}" fill="#92400e"/>
        </g>

        <!-- Right Fruit Bunch -->
        <g transform="translate({17 * scale}, {12 * scale}) rotate(14)">
          <ellipse cx="0" cy="0" rx="{9.5 * scale}" ry="{13.5 * scale}" fill="url(#fruitGrad)"/>
          <circle cx="{3.5 * scale}" cy="{-6 * scale}" r="{2.7 * scale}" fill="#fef08a"/>
          <circle cx="{-2.5 * scale}" cy="{-6.5 * scale}" r="{2.5 * scale}" fill="#fbbf24"/>
          <circle cx="{2 * scale}" cy="{0}" r="{2.8 * scale}" fill="#f59e0b"/>
          <circle cx="{-3.5 * scale}" cy="{1.5 * scale}" r="{2.6 * scale}" fill="#d97706"/>
          <circle cx="{1 * scale}" cy="{7 * scale}" r="{2.5 * scale}" fill="#92400e"/>
        </g>
      </g>
'''

    # PALM FRONDS (Pelepah Daun Sawit):
    # Left and Right Fronds
    left_fronds = [
        {"ang": -18, "flen": 100 * scale, "curv": -12 * scale, "n": 12, "grad": "leftFrondGrad"},
        {"ang": -40, "flen": 104 * scale, "curv": -22 * scale, "n": 13, "grad": "leftFrondGrad"},
        {"ang": -65, "flen": 106 * scale, "curv": -32 * scale, "n": 13, "grad": "leftFrondGrad"},
        {"ang": -88, "flen": 96 * scale, "curv": -38 * scale, "n": 12, "grad": "leftFrondGrad"},
    ]

    right_fronds = [
        {"ang": 18, "flen": 100 * scale, "curv": 12 * scale, "n": 12, "grad": "rightFrondGrad"},
        {"ang": 40, "flen": 104 * scale, "curv": 22 * scale, "n": 13, "grad": "rightFrondGrad"},
        {"ang": 65, "flen": 106 * scale, "curv": 32 * scale, "n": 13, "grad": "rightFrondGrad"},
        {"ang": 88, "flen": 96 * scale, "curv": 38 * scale, "n": 12, "grad": "rightFrondGrad"},
    ]

    svg += '''      <!-- Crown Center & Fronds -->
      <!-- Center Upright Frond -->
      <g transform="translate(0, 0)">
'''
    # Center frond leaflets
    for i in range(1, 13):
        t = i / 13.0
        ly = 4.0 * scale - (105.0 * scale) * t
        lw = (28.0 * math.sin(t * math.pi)) * scale
        svg += f'''        <path d="M 0 {ly} C {-lw * 0.5} {ly - 4 * scale} {-lw * 0.85} {ly - 1 * scale} {-lw} {ly + 5 * scale} C {-lw * 0.7} {ly + 1 * scale} {-lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)" opacity="0.95"/>\n'''
        svg += f'''        <path d="M 0 {ly} C {lw * 0.5} {ly - 4 * scale} {lw * 0.85} {ly - 1 * scale} {lw} {ly + 5 * scale} C {lw * 0.7} {ly + 1 * scale} {lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)" opacity="0.95"/>\n'''
        
    svg += f'''        <path d="M 0 4 Q 0 -50 0 -102" fill="none" stroke="url(#spineGrad)" stroke-width="{2.2 * scale}" stroke-linecap="round"/>
      </g>\n'''

    # Render Left and Right Fronds
    for f in left_fronds + right_fronds:
        ang = f["ang"]
        flen = f["flen"]
        curv = f["curv"]
        n_leaf = f["n"]
        grad = f["grad"]
        sgn = -1 if ang < 0 else 1

        svg += f'''      <!-- Frond {ang} deg -->
      <g transform="translate(0, 2) rotate({ang})">\n'''

        for i in range(1, n_leaf + 1):
            t = i / (n_leaf + 1)
            lx = 2 * (1 - t) * t * (curv * 0.4) + (t ** 2) * curv
            ly = -flen * t
            
            lw = (28.0 * math.sin(t * math.pi)) * scale
            lw = max(lw, 8.0 * scale)

            svg += f'''        <path d="M {lx} {ly} C {lx - sgn * lw * 0.5} {ly - 5 * scale} {lx - sgn * lw * 0.85} {ly} {lx - sgn * lw} {ly + 7 * scale} C {lx - sgn * lw * 0.7} {ly + 2 * scale} {lx - sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})" opacity="0.94"/>\n'''
            svg += f'''        <path d="M {lx} {ly} C {lx + sgn * lw * 0.5} {ly - 5 * scale} {lx + sgn * lw * 0.85} {ly} {lx + sgn * lw} {ly + 7 * scale} C {lx + sgn * lw * 0.7} {ly + 2 * scale} {lx + sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})" opacity="0.94"/>\n'''

        # Frond spine
        svg += f'''        <path d="M 0 0 Q {curv * 0.4} {-flen * 0.5} {curv} {-flen}" fill="none" stroke="url(#spineGrad)" stroke-width="{2.2 * scale}" stroke-linecap="round"/>
      </g>\n'''

    # Golden Crown Junction Jewel
    svg += f'''
      <!-- Golden Crown Jewel -->
      <circle cx="0" cy="2" r="{6 * scale}" fill="#fbbf24" stroke="#ffffff" stroke-width="{1.5 * scale}"/>
    </g>
  </g>
'''

    # Typography: "office lite"
    # Space between bottom of medallion disc (cy + r_badge + 14) and baseline of text
    text_y = cy + r_badge + (68.0 * scale)
    
    font_size_main = int(46 * scale)
    letter_spacing_main = 6 * scale

    svg += f'''
  <!-- Typography with dark glow backing for maximum contrast against galaxy stars -->
  <g filter="url(#shadow)" text-anchor="middle">
    <!-- Main Title: office lite -->
    <!-- Soft dark aura behind text for legibility -->
    <text x="{cx}" y="{text_y}" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="{font_size_main}" font-weight="800" fill="#030712" stroke="#030712" stroke-width="{11 * scale}" stroke-linejoin="round" letter-spacing="{letter_spacing_main}">office lite</text>
    
    <!-- Crisp Foreground Text: office lite -->
    <text x="{cx}" y="{text_y}" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="{font_size_main}" font-weight="800" fill="#ffffff" letter-spacing="{letter_spacing_main}">office lite</text>
  </g>
</svg>
'''
    return svg

def render_wallpaper(app, source_jpg_path, out_png_path, target_width, target_height):
    print(f"[*] Rendering {target_width}x{target_height} to {out_png_path}...")
    
    im = Image.open(source_jpg_path).convert('RGB')
    orig_w, orig_h = im.size
    
    target_aspect = target_width / target_height
    orig_aspect = orig_w / orig_h
    
    if orig_aspect > target_aspect:
        crop_w = int(orig_h * target_aspect)
        offset_x = (orig_w - crop_w) // 2
        im_cropped = im.crop((offset_x, 0, offset_x + crop_w, orig_h))
    else:
        crop_h = int(orig_w / target_aspect)
        offset_y = (orig_h - crop_h) // 2
        im_cropped = im.crop((0, offset_y, orig_w, offset_y + crop_h))
        
    im_resized = im_cropped.resize((target_width, target_height), Image.Resampling.LANCZOS)
    
    im_resized_rgba = im_resized.convert('RGBA')
    raw_bytes = im_resized_rgba.tobytes('raw', 'RGBA')
    
    qim = QtGui.QImage(raw_bytes, target_width, target_height, QtGui.QImage.Format.Format_RGBA8888)
    
    svg_data = generate_svg_overlay(target_width, target_height).encode('utf-8')
    svg_renderer = QtSvg.QSvgRenderer(QtCore.QByteArray(svg_data))
    
    target_qim = QtGui.QImage(target_width, target_height, QtGui.QImage.Format.Format_ARGB32_Premultiplied)
    painter = QtGui.QPainter(target_qim)
    painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
    painter.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)
    painter.setRenderHint(QtGui.QPainter.RenderHint.TextAntialiasing)
    
    # Draw background
    painter.drawImage(0, 0, qim)
    
    # Draw SVG
    svg_renderer.render(painter, QtCore.QRectF(0, 0, target_width, target_height))
    painter.end()
    
    os.makedirs(os.path.dirname(os.path.abspath(out_png_path)), exist_ok=True)
    target_qim.save(out_png_path, "PNG")
    print(f"[+] Saved: {out_png_path} ({os.path.getsize(out_png_path)} bytes)")

def main():
    app = QtGui.QGuiApplication.instance() or QtGui.QGuiApplication([])
    
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    source_jpg = os.path.join(root_dir, "example-wallpaper.jpg")
    
    if not os.path.exists(source_jpg):
        print(f"Error: {source_jpg} not found!")
        sys.exit(1)
        
    out_1080p = os.path.join(root_dir, "branding", "wallpapers", "liteoffice-default.png")
    out_768p = os.path.join(root_dir, "branding", "wallpapers", "liteoffice-1024x768.png")
    out_grub = os.path.join(root_dir, "branding", "grub", "liteoffice", "background.png")
    
    svg_path = os.path.join(root_dir, "branding", "wallpapers", "liteoffice-default.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(generate_svg_overlay(1920, 1080))
    print(f"[+] Saved SVG source: {svg_path}")
    
    render_wallpaper(app, source_jpg, out_1080p, 1920, 1080)
    render_wallpaper(app, source_jpg, out_768p, 1024, 768)
    render_wallpaper(app, source_jpg, out_grub, 1024, 768)
    
    print("[V] All wallpapers rendered successfully!")

if __name__ == "__main__":
    main()
