# Crédits

PARADOXE n'utilise **aucun élément** (nom, image, son, musique) issu d'autres jeux. Les
références aux jeux de plateforme cinématiques des années 1990 se limitent à des
allusions : situations, ambiance, mécaniques.

Ce fichier recense l'origine de **chaque** élément du jeu. Toute nouvelle ressource
extérieure doit y être ajoutée avant d'être versionnée : source, auteur, licence et lien.

## Moteur et bibliothèques

| Élément | Auteur | Licence | Remarque |
|---|---|---|---|
| [Godot Engine](https://godotengine.org) 4.7.2 | Juan Linietsky, Ariel Manzur et les contributeurs de Godot | MIT | Intégré aux exécutables. La licence doit accompagner le jeu : un écran de crédits l'affichera (J9, via `Engine.get_license_text()`). |
| Police par défaut de Godot (Open Sans SemiBold) | The Open Sans Project Authors (dessin : Steve Matteson) | SIL Open Font License 1.1 | Utilisée par l'interface tant qu'aucune police dédiée n'est choisie. |
| numpy, scipy | Communautés NumPy et SciPy | BSD | Servent uniquement à **générer** les sons (outil de développement, non distribué avec le jeu). |
| playwright-core | Microsoft | Apache 2.0 | Sert uniquement à **vérifier** la version Web (outil de développement). |

## Images

| Élément | Origine |
|---|---|
| `icon.svg` (icône du jeu) | Original, dessiné à la main en SVG (anneau polygonal et spirale calculée). |
| Anneau du portail (écran titre) | Original, dessiné par code (`scripts/fx/portal_ring.gd`). |
| Silhouette d'Élias et ses animations | Original, polygones et poses définis par code (`scripts/player/visual/`). |
| Décors de la salle de test, silhouettes de ville | Originaux, générés par code (`scripts/world/solid_block.gd`, `scripts/fx/skyline.gd`). |

## Sons

Tous les sons sont **synthétisés** par `tools/audio/generate_sounds.py` (voir
[`docs/SOUND_DESIGN.md`](docs/SOUND_DESIGN.md)). Aucun enregistrement extérieur n'est
utilisé pour l'instant.

| Fichier | Origine |
|---|---|
| `assets/audio/generated/ui/ui_confirm.wav` | Synthèse procédurale (original) |
| `assets/audio/generated/sfx/test_impact.wav` | Synthèse procédurale (original) |
| `assets/audio/generated/ambience/portal_hum_loop.wav` | Synthèse procédurale (original) |
| `assets/audio/generated/foley/*.wav` (13 fichiers : pas, sauts, réceptions, roulade…) | Synthèse procédurale (original) |

## Sons CC0 extérieurs

*Aucun pour le moment.* Si la synthèse ne suffit pas pour certains sons, des
enregistrements sous licence CC0 (domaine public) pourront être ajoutés, avec pour chacun
le site, l'auteur, le lien exact et la date de téléchargement.
