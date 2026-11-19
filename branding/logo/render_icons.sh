#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

for s in 16 24 32 48 64 128 256 512; do
    rsvg-convert -w "$s" -h "$s" liteoffice-logo.svg -o "liteoffice-icon-${s}.png"
done

cp liteoffice-icon-256.png liteoffice-logo.png
echo "All icons rendered successfully."
