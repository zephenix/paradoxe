#!/usr/bin/env bash
# =============================================================================
# setup.sh — Installe Godot (version headless utilisable en ligne de commande)
# et les modèles d'export correspondant EXACTEMENT à la même version.
#
# Utilisé à l'identique en local, dans une session cloud et par la CI GitHub.
# Le script est « idempotent » : le relancer ne retélécharge rien si tout est
# déjà en place.
#
# Usage :
#   ./setup.sh                 installe Godot + modèles d'export + importe le projet
#   ./setup.sh --no-templates  Godot seul (suffit pour lancer les tests)
#   ./setup.sh --python        installe aussi numpy/scipy (générateur de sons)
#   ./setup.sh --no-import     n'importe pas le projet à la fin
#
# Après installation, Godot est accessible par la commande `godot`
# (lien dans ~/.local/bin) ou par le chemin affiché à la fin.
# =============================================================================
set -euo pipefail

# --- Version de Godot : LA source de vérité pour tout le projet -------------
GODOT_VERSION="4.7.2"
GODOT_STATUS="stable"
# -----------------------------------------------------------------------------

GODOT_TAG="${GODOT_VERSION}-${GODOT_STATUS}"                       # 4.7.2-stable
TEMPLATES_DIR_NAME="${GODOT_VERSION}.${GODOT_STATUS}"              # 4.7.2.stable
RELEASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"
BIN_NAME="Godot_v${GODOT_TAG}_linux.x86_64"
BIN_ZIP="${BIN_NAME}.zip"
TPZ="Godot_v${GODOT_TAG}_export_templates.tpz"

GODOT_HOME="${GODOT_HOME:-$HOME/.local/share/godot}"               # dossier standard de Godot sous Linux
BIN_DIR="$GODOT_HOME/bin"
TEMPLATES_DIR="$GODOT_HOME/export_templates/$TEMPLATES_DIR_NAME"
CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/paradoxe-setup}"        # archives téléchargées
LINK_DIR="$HOME/.local/bin"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WANT_TEMPLATES=1
WANT_PYTHON=0
WANT_IMPORT=1
for arg in "$@"; do
	case "$arg" in
		--no-templates) WANT_TEMPLATES=0 ;;
		--python) WANT_PYTHON=1 ;;
		--no-import) WANT_IMPORT=0 ;;
		--version) echo "$GODOT_VERSION"; exit 0 ;;
		-h|--help) sed -n '2,20p' "$0"; exit 0 ;;
		*) echo "Option inconnue : $arg" >&2; exit 2 ;;
	esac
done

log() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }

# Téléchargement avec quelques nouvelles tentatives (réseau capricieux).
download() {
	local url="$1" dest="$2" attempt
	for attempt in 1 2 3 4; do
		if curl -fL --retry 3 --connect-timeout 30 -o "$dest.part" "$url"; then
			mv "$dest.part" "$dest"
			return 0
		fi
		log "Échec du téléchargement (tentative $attempt), nouvel essai…"
		sleep $((attempt * 2))
	done
	echo "Impossible de télécharger $url" >&2
	return 1
}

# Vérifie la somme SHA-512 d'une archive avec le fichier officiel de la release.
verify() {
	local file="$1"
	local expected
	expected="$(awk -v f="$file" '$2 == f { print $1 }' "$CACHE_DIR/SHA512-SUMS-${GODOT_TAG}.txt")"
	if [[ -z "$expected" ]]; then
		echo "Somme de contrôle introuvable pour $file" >&2
		return 1
	fi
	echo "$expected  $CACHE_DIR/$file" | sha512sum -c --quiet -
}

fetch_and_verify() {
	local file="$1"
	if [[ -f "$CACHE_DIR/$file" ]] && verify "$file" 2>/dev/null; then
		log "$file déjà téléchargé et vérifié."
		return 0
	fi
	log "Téléchargement de $file…"
	download "$RELEASE_URL/$file" "$CACHE_DIR/$file"
	verify "$file"
	log "$file vérifié (SHA-512)."
}

mkdir -p "$CACHE_DIR" "$BIN_DIR" "$LINK_DIR"

# 1) Sommes de contrôle officielles ------------------------------------------
if [[ ! -s "$CACHE_DIR/SHA512-SUMS-${GODOT_TAG}.txt" ]]; then
	download "$RELEASE_URL/SHA512-SUMS.txt" "$CACHE_DIR/SHA512-SUMS-${GODOT_TAG}.txt"
fi

# 2) Binaire de l'éditeur (sert aussi en headless : option --headless) -------
if [[ -x "$BIN_DIR/$BIN_NAME" ]]; then
	log "Godot $GODOT_TAG déjà installé."
else
	fetch_and_verify "$BIN_ZIP"
	unzip -o -q "$CACHE_DIR/$BIN_ZIP" -d "$BIN_DIR"
	chmod +x "$BIN_DIR/$BIN_NAME"
fi
ln -sf "$BIN_DIR/$BIN_NAME" "$LINK_DIR/godot"

# 3) Modèles d'export (même version exacte) ----------------------------------
# L'archive complète pèse ~1,3 Go : on n'extrait que ce dont le projet a besoin
# (Web, Windows x86_64, Linux x86_64), soit ~450 Mo.
if [[ "$WANT_TEMPLATES" == 1 ]]; then
	if [[ -f "$TEMPLATES_DIR/version.txt" && -f "$TEMPLATES_DIR/web_release.zip" \
		&& -f "$TEMPLATES_DIR/windows_release_x86_64.exe" && -f "$TEMPLATES_DIR/linux_release.x86_64" ]]; then
		log "Modèles d'export $TEMPLATES_DIR_NAME déjà installés."
	else
		fetch_and_verify "$TPZ"
		mkdir -p "$TEMPLATES_DIR"
		unzip -o -q -j "$CACHE_DIR/$TPZ" \
			'templates/version.txt' \
			'templates/icudt_godot.dat' \
			'templates/web_debug.zip' 'templates/web_release.zip' \
			'templates/web_nothreads_debug.zip' 'templates/web_nothreads_release.zip' \
			'templates/windows_debug_x86_64.exe' 'templates/windows_release_x86_64.exe' \
			'templates/windows_debug_x86_64_console.exe' 'templates/windows_release_x86_64_console.exe' \
			'templates/linux_debug.x86_64' 'templates/linux_release.x86_64' \
			-d "$TEMPLATES_DIR"
		log "Modèles d'export installés dans $TEMPLATES_DIR"
		if [[ "${SETUP_KEEP_TPZ:-0}" != 1 ]]; then
			rm -f "$CACHE_DIR/$TPZ"   # libère 1,3 Go ; mettre SETUP_KEEP_TPZ=1 pour le garder
		fi
	fi
	installed_version="$(cat "$TEMPLATES_DIR/version.txt")"
	if [[ "$installed_version" != "$TEMPLATES_DIR_NAME" ]]; then
		echo "Version des modèles ($installed_version) ≠ version de Godot ($TEMPLATES_DIR_NAME)" >&2
		exit 1
	fi
fi

# 4) Python (facultatif) pour le générateur de sons ---------------------------
if [[ "$WANT_PYTHON" == 1 ]]; then
	log "Installation de numpy/scipy pour tools/audio…"
	python3 -m pip install --quiet --user -r "$PROJECT_DIR/tools/audio/requirements.txt" \
		|| python3 -m pip install --quiet --user --break-system-packages -r "$PROJECT_DIR/tools/audio/requirements.txt"
fi

# 5) Import du projet (génère le dossier .godot/ et les ressources importées) --
GODOT="$BIN_DIR/$BIN_NAME"
reported="$("$GODOT" --headless --version 2>/dev/null | head -n1)"
log "Godot opérationnel : $reported"
if [[ "$WANT_IMPORT" == 1 && -f "$PROJECT_DIR/project.godot" ]]; then
	log "Import du projet (première fois : peut prendre une minute)…"
	"$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true
	# --import renvoie parfois un code non nul pour de simples avertissements ;
	# les vraies erreurs seront détectées par les tests (tools/run_tests.sh).
fi

log "Terminé. Commande : godot (ou $GODOT)"
if [[ ":$PATH:" != *":$LINK_DIR:"* ]]; then
	log "Astuce : ajoute $LINK_DIR à ton PATH pour taper simplement « godot »."
fi
