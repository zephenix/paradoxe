#!/usr/bin/env bash
# Vérifie dans Chromium qu'une nouvelle version publiée remplace l'ancienne, sans
# fermer d'onglet (le service worker de Godot garde sinon l'ancienne en cache).
#   ./tools/web/check_update.sh
# Exporte deux versions de test (9.0.1 puis 9.0.2) dans build/ (quelques minutes).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
if [[ ! -d tools/web/node_modules/playwright-core ]]; then
	(cd tools/web && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --silent --no-audit --no-fund)
fi
for v in 1 2; do
	GAME_VERSION="9.0.$v" ./tools/export.sh web >/dev/null
	rm -rf "build/web_update_v$v"
	cp -r build/web "build/web_update_v$v"
done
serve_root="$(mktemp -d)"
port=$((20000 + RANDOM % 20000))
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$serve_root" >/dev/null 2>&1 &
server_pid=$!
trap 'kill $server_pid 2>/dev/null; rm -rf "$serve_root"' EXIT
sleep 1
node tools/web/check_update.js "http://127.0.0.1:${port}/paradoxe/" "$serve_root/paradoxe" \
	"$PWD/build/web_update_v1" "$PWD/build/web_update_v2"
