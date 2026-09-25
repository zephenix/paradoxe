#!/usr/bin/env bash
# Vérifie la version Web exportée (build/web) dans Chromium headless.
#   ./tools/export.sh web && ./tools/web/check_web.sh
# Nécessite Node.js et un Chromium (préinstallé dans les sessions cloud Claude Code ;
# sinon : npx playwright install chromium).
# Captures d'écran écrites dans build/shots/.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
[[ -f build/web/index.html ]] || { echo "Pas d'export Web : lancer ./tools/export.sh web" >&2; exit 1; }

# Dépendance Node (playwright-core seul, sans téléchargement de navigateur).
if [[ ! -d tools/web/node_modules/playwright-core ]]; then
	(cd tools/web && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --silent --no-audit --no-fund)
fi

# Serveur local qui imite GitHub Pages : le jeu est servi sous /paradoxe/.
serve_root="$(mktemp -d)"
ln -s "$PWD/build/web" "$serve_root/paradoxe"
port=$((20000 + RANDOM % 20000))
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$serve_root" >/dev/null 2>&1 &
server_pid=$!
trap 'kill $server_pid 2>/dev/null; rm -rf "$serve_root"' EXIT
sleep 1

mkdir -p build/shots
node tools/web/check_web.js "http://127.0.0.1:${port}/paradoxe/" build/shots
