#!/bin/sh
# Laeuft in kitty (Desktop-Test im CI): schreibt etwas Sichtbares und meldet sich mit einer
# Markendatei im Laufzeitverzeichnis.
printf '\033[1;36mVeyra OS 0.6 - Desktop-Grundlage\033[0m\n\n'
printf 'Compositor: cage (wlroots, pixman)   Terminal: kitty (Mesa softpipe)   Wayland: %s\n\n' "$WAYLAND_DISPLAY"
veyra-hwinfo 2>&1 | head -30
: > "$XDG_RUNTIME_DIR/terminal-laeuft"
exec sleep infinity
