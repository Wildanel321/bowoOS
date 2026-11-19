#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

rsvg-convert -w 1920 -h 1080 liteoffice-default.svg -o liteoffice-default.png
rsvg-convert -w 1920 -h 1080 liteoffice-minimal.svg -o liteoffice-minimal.png

# Also render 1024x768 for low-resolution displays / GRUB
rsvg-convert -w 1024 -h 768 liteoffice-default.svg -o liteoffice-1024x768.png

echo "Wallpapers rendered successfully."
