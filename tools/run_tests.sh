#!/usr/bin/env bash
# Lance tous les tests automatisés en mode headless (sans fenêtre).
#   ./tools/run_tests.sh              tous les tests
#   ./tools/run_tests.sh audio        seulement les fichiers dont le nom contient « audio »
# Code de sortie : 0 si tout passe, 1 sinon.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT:-godot}"

# 1) Import : (ré)génère les ressources importées (sons, images) si besoin.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

# 2) Tests. --fixed-fps 60 : chaque image avance d'exactement 1/60 s, aussi vite
#    que possible (simulation reproductible et rapide, indépendante de la machine).
if [[ $# -gt 0 ]]; then
	exec "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- "$@"
else
	exec "$GODOT" --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
fi
