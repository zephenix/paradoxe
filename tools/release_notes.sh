#!/usr/bin/env bash
# Produit le texte d'une GitHub Release à partir de docs/JOURNAL.md.
#   ./tools/release_notes.sh v0.1
# Reprend la section du journal dont le titre contient « (v0.1) », puis ajoute
# les instructions de téléchargement communes à toutes les versions.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tag="${1:?Usage : release_notes.sh <tag>}"

# Section du journal : du titre « ## … (tag) » jusqu'au titre « ## » suivant.
awk -v tag="($tag)" '
	/^## / { inside = index($0, tag) > 0 }
	inside { print }
' docs/JOURNAL.md

cat <<'EOF'

---

### Télécharger et lancer

| Système | Fichier | Lancement |
|---|---|---|
| **Windows** | `Paradoxe-…-windows.exe` | Double-clic. Au premier lancement, Windows SmartScreen peut afficher « Windows a protégé votre ordinateur » (l'exécutable n'est pas signé) : cliquer sur **Informations complémentaires** puis **Exécuter quand même**. |
| **Linux** | `Paradoxe-…-linux.zip` | Décompresser, puis `./Paradoxe.x86_64` (ou `chmod +x Paradoxe.x86_64` si besoin). |
| **Navigateur** | Version en ligne sur GitHub Pages (voir le README) | Cliquer une fois dans la page pour activer le son. |

L'archive `…-web.zip` contient la version Web à héberger soi-même (serveur HTTP requis).
EOF
