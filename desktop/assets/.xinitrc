#!/bin/sh
# ==============================================================================
# Lite Office OS — X11 Session Startup (.xinitrc)
# ==============================================================================

if [ -f "$HOME/.Xresources" ]; then
    xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
fi

# Ensure user session bus is active
if which dbus-launch >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session openbox-session
elif which dbus-daemon >/dev/null 2>&1 && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval $(dbus-daemon --session --fork --print-address --print-pid 2>/dev/null) || true
    exec openbox-session
else
    exec openbox-session
fi
