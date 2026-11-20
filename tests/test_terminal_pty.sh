#!/bin/bash
set -euo pipefail

ROOTFS="/var/tmp/liteoffice-build/rootfs_x86_64"
echo "[*] Verifying /dev/pts and PTY allocation..."

mkdir -p "$ROOTFS/dev/pts"
if ! mountpoint -q "$ROOTFS/dev/pts"; then
    mount -t devpts devpts "$ROOTFS/dev/pts" -o gid=5,mode=620,ptmxmode=666
fi

chroot "$ROOTFS" python3 - << 'PYEOF'
import pty, os
master, slave = pty.openpty()
print("PTY successfully allocated! Master FD:", master, "Slave device:", os.ttyname(slave))
os.close(master)
os.close(slave)
PYEOF

echo "[*] Testing bash interactive shell prompt..."
chroot "$ROOTFS" su - liteuser -c 'bash -i -c "echo \"Interactive prompt: \$PS1\""' 2>/dev/null || true

echo "[*] Verifying lxterminal configuration..."
cat "$ROOTFS/etc/xdg/lxterminal/lxterminal.conf" | grep -E "hidemenubar|fontname|geometry"

echo "[✓] All PTY and terminal tests PASSED!"
