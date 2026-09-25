#!/usr/bin/env bash
# =============================================================================
# Exporte le jeu (Web, Windows, Linux) avec les presets de export_presets.cfg.
#
#   ./tools/export.sh web              -> build/web/index.html (+ .wasm, .pck…)
#   ./tools/export.sh windows          -> build/windows/Paradoxe.exe (fichier unique)
#   ./tools/export.sh linux            -> build/linux/Paradoxe.x86_64 (fichier unique)
#   ./tools/export.sh all              -> les trois
#
# Variables facultatives :
#   GAME_VERSION=0.2.0   numéro de version inscrit dans le jeu pour cet export
#                        (project.godot est restauré ensuite)
#   EXPORT_MODE=debug    export « debug » (messages d'erreur détaillés) au lieu de « release »
# =============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT:-godot}"
MODE="${EXPORT_MODE:-release}"

if [[ $# -eq 0 ]]; then
	sed -n '2,15p' "$0"
	exit 2
fi

targets=()
for arg in "$@"; do
	case "$arg" in
		web) targets+=("Web|build/web/index.html") ;;
		windows) targets+=("Windows Desktop|build/windows/Paradoxe.exe") ;;
		linux) targets+=("Linux|build/linux/Paradoxe.x86_64") ;;
		all) targets+=("Web|build/web/index.html" "Windows Desktop|build/windows/Paradoxe.exe" "Linux|build/linux/Paradoxe.x86_64") ;;
		*) echo "Cible inconnue : $arg (web, windows, linux, all)" >&2; exit 2 ;;
	esac
done

# Le dossier build/ ne doit pas être importé par Godot : un fichier .gdignore
# lui dit d'ignorer ce dossier.
mkdir -p build
touch build/.gdignore

# Numéro de version temporaire (restauré à la fin, même en cas d'erreur).
if [[ -n "${GAME_VERSION:-}" ]]; then
	cp project.godot build/project.godot.bak
	trap 'mv build/project.godot.bak project.godot' EXIT
	sed -i "s/^config\/version=.*/config\/version=\"${GAME_VERSION}\"/" project.godot
	echo "Version inscrite dans cet export : ${GAME_VERSION}"
fi

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

for target in "${targets[@]}"; do
	preset="${target%%|*}"
	output="${target##*|}"
	rm -rf "$(dirname "$output")"
	mkdir -p "$(dirname "$output")"
	echo "=== Export « $preset » ($MODE) -> $output"
	log="build/export-$(echo "$preset" | tr ' ' '_').log"
	if ! "$GODOT" --headless --path . "--export-$MODE" "$preset" "$output" >"$log" 2>&1; then
		cat "$log"
		echo "ÉCHEC de l'export « $preset »" >&2
		exit 1
	fi
	# Godot peut renvoyer 0 malgré une erreur : on vérifie le journal et le fichier produit.
	if grep -E "^(ERROR|SCRIPT ERROR)" "$log" >/dev/null || [[ ! -s "$output" ]]; then
		cat "$log"
		echo "ÉCHEC de l'export « $preset » (voir ci-dessus)" >&2
		exit 1
	fi
	ls -la "$(dirname "$output")"
done
