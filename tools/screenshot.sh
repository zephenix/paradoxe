#!/usr/bin/env bash
# Capture d'écran d'une scène avec le vrai moteur de rendu, sans écran (Xvfb).
#   ./tools/screenshot.sh res://scenes/ui/title_screen.tscn build/shots/titre.png [images] [appui_à_l_image]
# Voir tools/godot/screenshot.gd pour le détail des arguments.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT:-godot}"
mkdir -p build && touch build/.gdignore
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 \
	-s res://tools/godot/screenshot.gd -- "$@" 2>&1 | grep -vE "^ALSA|audio_driver_alsa|All audio drivers failed|servers/audio/audio_server|^\s*at: " || true
