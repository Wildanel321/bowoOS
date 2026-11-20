#!/usr/bin/env python3
"""
render_shutdown_and_boot_assets.py — Generates:
1. liteoffice-shutdown.png (1920x1080) & liteoffice-shutdown-1024x768.png (1024x768)
2. Plymouth boot splash watermark (watermark.png, 440x220)
"""

import os
import sys
import math

root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

from PIL import Image
from PySide6 import QtCore, QtGui, QtSvg

def generate_shutdown_svg(width, height):
    cx = width / 2
    scale = height / 1080.0
    cy = 420.0 * scale
    r_badge = 125.0 * scale
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">
  <defs>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="{4 * scale}" stdDeviation="{8 * scale}" flood-color="#020408" flood-opacity="0.95"/>
    </filter>

    <radialGradient id="badgeGrad" cx="50%" cy="35%" r="68%">
      <stop offset="0%" stop-color="#14213d" stop-opacity="0.94"/>
      <stop offset="60%" stop-color="#0c1527" stop-opacity="0.96"/>
      <stop offset="100%" stop-color="#040812" stop-opacity="0.98"/>
    </radialGradient>

    <linearGradient id="rimGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#f43f5e"/>
      <stop offset="40%" stop-color="#fbbf24"/>
      <stop offset="100%" stop-color="#f97316"/>
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

    <linearGradient id="pillGrad" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#b91c1c" stop-opacity="0.85"/>
      <stop offset="50%" stop-color="#dc2626" stop-opacity="0.92"/>
      <stop offset="100%" stop-color="#991b1b" stop-opacity="0.85"/>
    </linearGradient>
  </defs>

  <!-- Central Emblem with Drop Shadow -->
  <g filter="url(#shadow)">
    <!-- Amber/Red Pulsing Orbit Ring for Shutdown -->
    <circle cx="{cx}" cy="{cy}" r="{r_badge + 14 * scale}" fill="none" stroke="url(#rimGrad)" stroke-width="{2 * scale}" opacity="0.85" stroke-dasharray="{8 * scale} {5 * scale}"/>
    <circle cx="{cx}" cy="{cy}" r="{r_badge + 5 * scale}" fill="none" stroke="#f43f5e" stroke-width="{1 * scale}" opacity="0.45"/>

    <!-- Medallion Background Disc -->
    <circle cx="{cx}" cy="{cy}" r="{r_badge}" fill="url(#badgeGrad)" stroke="#ffffff" stroke-width="{1.8 * scale}" stroke-opacity="0.35"/>

    <!-- Palm Tree -->
    <g transform="translate({cx}, {cy})">
      <path d="M {-70 * scale} {84 * scale} Q 0 {74 * scale} {70 * scale} {84 * scale} Z" fill="#080e1a" opacity="0.9"/>
      
      <!-- Trunk -->
      <path d="M {-13 * scale} {8 * scale} L {13 * scale} {8 * scale} L {20 * scale} {82 * scale} L {-20 * scale} {82 * scale} Z" 
            fill="url(#trunkGrad)" stroke="#cbd5e1" stroke-width="{0.8 * scale}"/>
'''
    for row in range(6):
        y_pos = (16.0 + row * 11.5) * scale
        half_w = (13.5 + row * 1.0) * scale
        svg += f'''      <polygon points="0,{y_pos - 4.5 * scale} {half_w * 0.82},{y_pos} 0,{y_pos + 4.5 * scale} {-half_w * 0.82},{y_pos}" fill="#0f172a" stroke="#cbd5e1" stroke-width="{0.8 * scale}" opacity="0.75"/>\n'''

    svg += f'''
      <!-- Fruit Bunches -->
      <g>
        <g transform="translate({-17 * scale}, {12 * scale}) rotate(-14)">
          <ellipse cx="0" cy="0" rx="{9.5 * scale}" ry="{13.5 * scale}" fill="url(#fruitGrad)"/>
          <circle cx="{-3.5 * scale}" cy="{-6 * scale}" r="{2.7 * scale}" fill="#fef08a"/>
          <circle cx="{2.5 * scale}" cy="{-6.5 * scale}" r="{2.5 * scale}" fill="#fbbf24"/>
          <circle cx="{-1 * scale}" cy="{7 * scale}" r="{2.5 * scale}" fill="#92400e"/>
        </g>
        <g transform="translate({17 * scale}, {12 * scale}) rotate(14)">
          <ellipse cx="0" cy="0" rx="{9.5 * scale}" ry="{13.5 * scale}" fill="url(#fruitGrad)"/>
          <circle cx="{3.5 * scale}" cy="{-6 * scale}" r="{2.7 * scale}" fill="#fef08a"/>
          <circle cx="{-2.5 * scale}" cy="{-6.5 * scale}" r="{2.5 * scale}" fill="#fbbf24"/>
          <circle cx="{1 * scale}" cy="{7 * scale}" r="{2.5 * scale}" fill="#92400e"/>
        </g>
      </g>
'''

    left_fronds = [
        {"ang": -18, "flen": 98 * scale, "curv": -12 * scale, "n": 11, "grad": "leftFrondGrad"},
        {"ang": -40, "flen": 102 * scale, "curv": -22 * scale, "n": 12, "grad": "leftFrondGrad"},
        {"ang": -65, "flen": 104 * scale, "curv": -32 * scale, "n": 12, "grad": "leftFrondGrad"},
        {"ang": -88, "flen": 94 * scale, "curv": -38 * scale, "n": 11, "grad": "leftFrondGrad"},
    ]
    right_fronds = [
        {"ang": 18, "flen": 98 * scale, "curv": 12 * scale, "n": 11, "grad": "rightFrondGrad"},
        {"ang": 40, "flen": 102 * scale, "curv": 22 * scale, "n": 12, "grad": "rightFrondGrad"},
        {"ang": 65, "flen": 104 * scale, "curv": 32 * scale, "n": 12, "grad": "rightFrondGrad"},
        {"ang": 88, "flen": 94 * scale, "curv": 38 * scale, "n": 11, "grad": "rightFrondGrad"},
    ]

    svg += '''      <!-- Crown Fronds -->
      <g transform="translate(0, 0)">
'''
    for i in range(1, 12):
        t = i / 12.0
        ly = 4.0 * scale - (102.0 * scale) * t
        lw = (27.0 * math.sin(t * math.pi)) * scale
        svg += f'''        <path d="M 0 {ly} C {-lw * 0.5} {ly - 4 * scale} {-lw * 0.85} {ly - 1 * scale} {-lw} {ly + 5 * scale} C {-lw * 0.7} {ly + 1 * scale} {-lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)"/>\n'''
        svg += f'''        <path d="M 0 {ly} C {lw * 0.5} {ly - 4 * scale} {lw * 0.85} {ly - 1 * scale} {lw} {ly + 5 * scale} C {lw * 0.7} {ly + 1 * scale} {lw * 0.3} {ly} 0 {ly}" fill="url(#centerFrondGrad)"/>\n'''
    svg += f'''        <path d="M 0 4 Q 0 -50 0 -100" fill="none" stroke="#ffffff" stroke-width="{2.2 * scale}" stroke-linecap="round"/>
      </g>\n'''

    for f in left_fronds + right_fronds:
        ang = f["ang"]
        flen = f["flen"]
        curv = f["curv"]
        n_leaf = f["n"]
        grad = f["grad"]
        sgn = -1 if ang < 0 else 1
        svg += f'''      <g transform="translate(0, 2) rotate({ang})">\n'''
        for i in range(1, n_leaf + 1):
            t = i / (n_leaf + 1)
            lx = 2 * (1 - t) * t * (curv * 0.4) + (t ** 2) * curv
            ly = -flen * t
            lw = (27.0 * math.sin(t * math.pi)) * scale
            lw = max(lw, 7.0 * scale)
            svg += f'''        <path d="M {lx} {ly} C {lx - sgn * lw * 0.5} {ly - 5 * scale} {lx - sgn * lw * 0.85} {ly} {lx - sgn * lw} {ly + 7 * scale} C {lx - sgn * lw * 0.7} {ly + 2 * scale} {lx - sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})"/>\n'''
            svg += f'''        <path d="M {lx} {ly} C {lx + sgn * lw * 0.5} {ly - 5 * scale} {lx + sgn * lw * 0.85} {ly} {lx + sgn * lw} {ly + 7 * scale} C {lx + sgn * lw * 0.7} {ly + 2 * scale} {lx + sgn * lw * 0.3} {ly} {lx} {ly}" fill="url(#{grad})"/>\n'''
        svg += f'''        <path d="M 0 0 Q {curv * 0.4} {-flen * 0.5} {curv} {-flen}" fill="none" stroke="#ffffff" stroke-width="{2.2 * scale}" stroke-linecap="round"/>
      </g>\n'''

    svg += f'''      <circle cx="0" cy="2" r="{6 * scale}" fill="#fbbf24" stroke="#ffffff" stroke-width="{1.5 * scale}"/>
    </g>
  </g>
'''

    # Typography & Shutdown Status Pill
    text_y = cy + r_badge + (65.0 * scale)
    pill_y = text_y + (30.0 * scale)
    
    font_size_main = int(46 * scale)
    font_size_sub = int(17 * scale)
    pill_w = 340.0 * scale
    pill_h = 36.0 * scale

    svg += f'''
  <!-- Typography & Shutdown Badge -->
  <g filter="url(#shadow)" text-anchor="middle">
    <!-- Main Title: office lite -->
    <text x="{cx}" y="{text_y}" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="{font_size_main}" font-weight="800" fill="#030712" stroke="#030712" stroke-width="{11 * scale}" stroke-linejoin="round" letter-spacing="{6 * scale}">office lite</text>
    <text x="{cx}" y="{text_y}" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="{font_size_main}" font-weight="800" fill="#ffffff" letter-spacing="{6 * scale}">office lite</text>
    
    <!-- Shutdown Pill Badge -->
    <rect x="{cx - pill_w/2}" y="{pill_y}" width="{pill_w}" height="{pill_h}" rx="{pill_h/2}" fill="url(#pillGrad)" stroke="#fecaca" stroke-width="{1.2 * scale}"/>
    <circle cx="{cx - pill_w/2 + 20 * scale}" cy="{pill_y + pill_h/2}" r="{5 * scale}" fill="#fef08a"/>
    <text x="{cx + 8 * scale}" y="{pill_y + pill_h*0.68}" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="{font_size_sub}" font-weight="700" fill="#ffffff" letter-spacing="{1.5 * scale}">SHUTTING DOWN SYSTEM...</text>
  </g>
</svg>
'''
    return svg

def generate_plymouth_watermark_svg():
    # 440 x 240 canvas for Plymouth boot splash
    # Embed the authentic palm tree icon and crisp typography
    from branding.logo.render_sawit_icons import generate_palm_icon_svg
    icon_inner = generate_palm_icon_svg(140)
    # Strip <svg> and </svg> tags to embed inside watermark
    start_tag = icon_inner.find('>') + 1
    end_tag = icon_inner.rfind('</svg>')
    embedded_icon = icon_inner[start_tag:end_tag]

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 440 240" width="440" height="240">
  <!-- Embedded Authentic Palm Icon -->
  <g transform="translate(150, 10)">
    {embedded_icon}
  </g>

  <!-- Typography below: office lite -->
  <g text-anchor="middle">
    <text x="220" y="186" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="28" font-weight="800" fill="#ffffff" letter-spacing="4">office lite</text>
    <text x="220" y="210" font-family="'DejaVu Sans', 'Inter', 'Segoe UI', system-ui, sans-serif" font-size="11" font-weight="600" fill="#38bdf8" letter-spacing="2">LIGHTWEIGHT DESKTOP OS</text>
  </g>
</svg>
'''
    return svg

def render_shutdown_image(app, source_jpg_path, out_png_path, target_width, target_height):
    print(f"[*] Rendering Shutdown Wallpaper {target_width}x{target_height} to {out_png_path}...")
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
    
    svg_data = generate_shutdown_svg(target_width, target_height).encode('utf-8')
    svg_renderer = QtSvg.QSvgRenderer(QtCore.QByteArray(svg_data))
    
    target_qim = QtGui.QImage(target_width, target_height, QtGui.QImage.Format.Format_ARGB32_Premultiplied)
    painter = QtGui.QPainter(target_qim)
    painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
    painter.setRenderHint(QtGui.QPainter.RenderHint.SmoothPixmapTransform)
    painter.setRenderHint(QtGui.QPainter.RenderHint.TextAntialiasing)
    
    painter.drawImage(0, 0, qim)
    svg_renderer.render(painter, QtCore.QRectF(0, 0, target_width, target_height))
    painter.end()
    
    os.makedirs(os.path.dirname(os.path.abspath(out_png_path)), exist_ok=True)
    target_qim.save(out_png_path, "PNG")
    print(f"[+] Saved: {out_png_path}")

def render_plymouth_watermark(app, out_png_path):
    print(f"[*] Rendering Plymouth Watermark to {out_png_path}...")
    svg_data = generate_plymouth_watermark_svg().encode('utf-8')
    renderer = QtSvg.QSvgRenderer(QtCore.QByteArray(svg_data))
    
    w, h = 440, 240
    qim = QtGui.QImage(w, h, QtGui.QImage.Format.Format_ARGB32_Premultiplied)
    qim.fill(QtCore.Qt.GlobalColor.transparent)
    
    painter = QtGui.QPainter(qim)
    painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing)
    painter.setRenderHint(QtGui.QPainter.RenderHint.TextAntialiasing)
    renderer.render(painter, QtCore.QRectF(0, 0, w, h))
    painter.end()
    
    os.makedirs(os.path.dirname(os.path.abspath(out_png_path)), exist_ok=True)
    qim.save(out_png_path, "PNG")
    print(f"[+] Saved Plymouth Watermark: {out_png_path}")

def main():
    app = QtGui.QGuiApplication.instance() or QtGui.QGuiApplication([])
    root_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    source_jpg = os.path.join(root_dir, "example-wallpaper.jpg")
    
    # Render shutdown wallpapers
    out_shutdown_1080 = os.path.join(root_dir, "branding", "wallpapers", "liteoffice-shutdown.png")
    out_shutdown_768 = os.path.join(root_dir, "branding", "wallpapers", "liteoffice-shutdown-1024x768.png")
    render_shutdown_image(app, source_jpg, out_shutdown_1080, 1920, 1080)
    render_shutdown_image(app, source_jpg, out_shutdown_768, 1024, 768)
    
    # Render Plymouth watermark
    out_plymouth_wm = os.path.join(root_dir, "branding", "plymouth", "liteoffice", "watermark.png")
    render_plymouth_watermark(app, out_plymouth_wm)
    
    print("[V] All boot and shutdown branding assets generated successfully!")

if __name__ == "__main__":
    main()
