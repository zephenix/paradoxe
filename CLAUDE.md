# CLAUDE.md — mémo pour les sessions de développement

## Le projet

**PARADOXE** : prototype (« vertical slice ») d'un jeu de plateforme cinématique 2D en
**Godot 4.7.2 / GDScript**, dans l'esprit des jeux de plateforme cinématiques de 1991-1992.
Il est jouable sur le Web (GitHub Pages) et en exécutables Windows/Linux (GitHub Releases).

- Feuille de route et architecture : `docs/PLAN.md`. Toujours la relire avant un jalon.
- Avancement, décisions, explications pédagogiques : `docs/JOURNAL.md`.
- Sons : `docs/SOUND_DESIGN.md` et `tools/audio/`.
- Le propriétaire du projet est ingénieur (hors informatique) et autodidacte : bonnes
  bases en VBA/Excel, notions de Python et C++. Il veut **comprendre et modifier le code**.
  D'où des commentaires en français, abondants et pédagogiques, et des analogies VBA/Excel
  quand elles aident.
- Langue : documentation, commentaires et messages de commit **en français** ; identifiants
  (variables, fonctions, fichiers, nœuds) **en anglais**, en `snake_case` (API Godot).

## Règles impératives

- **Aucun élément issu des jeux originaux** : ni nom, ni sprite, ni son, ni musique. Les
  allusions sont permises (situations, mécaniques). Tout élément extérieur doit être CC0
  ou libre, et **noté dans `CREDITS.md`**.
- **Version de Godot unique** : `GODOT_VERSION` dans `setup.sh`. La CI et les modèles
  d'export en dépendent. Pour changer de version, modifier ce seul endroit (plus
  `config/features` dans `project.godot`).
- **GDScript uniquement**, typé (`var x: float = 0.0`, `func f(a: int) -> void:`).
- **Pas de valeur de gameplay en dur** : vitesses, hauteurs, énergie, perception… vont dans
  des Resources `.tres` sous `resources/`.
- **Audio : tout son passe par `AudioManager`** (autoload). Un son qui a un « rayon de
  bruit » prévient les ennemis via le signal `noise_emitted` : un seul système pour
  l'audition du joueur et celle des ennemis.
- **Bus audio** : décrits dans `scripts/audio/audio_buses.gd`. `default_bus_layout.tres` est
  **généré** par `tools/godot/generate_bus_layout.gd`. On ne l'édite pas à la main.
- Architecture : « les appels descendent, les signaux remontent ». Les signaux globaux
  passent par l'autoload `Events`.
- Une animation « engagée » va à son terme ; seule la mort interrompt tout (voir PLAN §3.4).

## Commandes utiles

```bash
./setup.sh                      # installe Godot 4.7.2 headless + modèles d'export (~530 Mo), importe le projet
./setup.sh --python             # + numpy/scipy (générateur de sons)
./tools/run_tests.sh            # tous les tests (headless) ; code de sortie ≠ 0 si échec
./tools/run_tests.sh audio      # seulement les fichiers de test dont le nom contient « audio »
./tools/export.sh web|windows|linux|all      # exports dans build/
GAME_VERSION=0.2.0 ./tools/export.sh all     # export avec un numéro de version
./tools/screenshot.sh res://scenes/ui/title_screen.tscn build/shots/x.png 90 [appui_à_l_image]
./tools/web/check_web.sh        # après un export Web : vérifie isolation, JS, son réel dans Chromium
python3 tools/audio/generate_sounds.py       # régénère les sons (puis réimport Godot)
godot --headless --path . -s res://tools/godot/generate_bus_layout.gd   # régénère la table de mixage
```

- `godot` = lien vers `~/.local/share/godot/bin/Godot_v4.7.2-stable_linux.x86_64` (créé par
  `setup.sh` dans `~/.local/bin`).
- Captures d'écran : Xvfb + `--rendering-driver opengl3`. **Toujours regarder les captures**
  après un changement visuel : c'est le seul moyen de vérifier le rendu.
- Chromium est préinstallé dans les sessions cloud (`/opt/pw-browsers`) : ne pas lancer
  `playwright install`.

## Tests

- Lanceur maison : `tests/run_tests.gd`. Chaque fichier `tests/unit/**/test_*.gd` hérite de
  `TestCase`, et chaque fonction `test_*` est un test. Fonctions disponibles : `assert_eq`,
  `assert_true`, `assert_almost_eq`, `add_node`, `await wait_frames(n)`,
  `await wait_seconds(s)`.
- **Toute erreur du moteur pendant un test le fait échouer** (un `Logger` intercepte
  `push_error`, les erreurs de script, les ressources manquantes).
- `test_scenes_smoke.gd` instancie **toutes** les scènes de `scenes/` et charge **tous** les
  scripts : une nouvelle scène est testée automatiquement.
- Les autoloads sont chargés pendant les tests ; si un test modifie leur état, il doit le
  restaurer dans `after_each()`.

## Pièges connus

- **Audio Web** : `audio/general/default_playback_type.web=0` (Stream). En mode « Sample »
  (valeur par défaut de Godot sur le Web), les effets de bus ne marchent pas. L'export Web
  est **multithread** et nécessite l'isolation cross-origin : c'est le service worker PWA
  de Godot qui ajoute les en-têtes, et un script maison dans `html/head_include`
  (`export_presets.cfg`) recharge la page quand le service worker s'active trop tard au
  premier chargement. Repli possible : `variant/thread_support=false` (latence audio plus
  élevée).
- Les fichiers `*.uid` (scripts) et `*.import` (sons, images) **se versionnent**. Le
  dossier `.godot/` ne se versionne pas.
- `build/` contient un `.gdignore` (créé par `tools/export.sh`), et `tools/web/` et
  `tools/audio/` aussi : Godot ne doit pas importer ces dossiers.
- Police par défaut (Open Sans) : certains symboles (→, ▸…) sont absents sur le Web. Rester
  en ASCII ou choisir une police dédiée.
- `project.godot` : l'éditeur peut réécrire le fichier et supprimer les commentaires `;`.

## Méthode de travail par jalon (J1 → J9, voir PLAN §9)

1. Partir de `main` à jour, sur la branche de travail désignée pour la session.
2. Développer en commits clairs (en français). Lancer `./tools/run_tests.sh` avant chaque
   push et faire des captures d'écran pour tout changement visuel.
3. Mettre à jour `docs/JOURNAL.md` : une section `## Jx — Titre (vX.Y)` avec ce qui a été
   fait, comment le tester, ce qu'il faut écouter, ce qui reste à faire, et 1 ou 2 concepts
   Godot expliqués simplement. Le titre doit contenir `(vX.Y)` : `tools/release_notes.sh`
   s'en sert pour le texte de la Release.
4. Mettre à jour `config/version` dans `project.godot` (X.Y.0).
5. Ouvrir une Pull Request vers `main`, attendre la CI verte, puis faire fusionner la PR.
6. **Créer la release** : après la fusion, depuis `main` à jour,
   `git tag -a vX.Y -m "PARADOXE vX.Y — Jx" && git push origin vX.Y`. La CI exporte et
   publie la Release (Windows `.exe` unique, Linux `.zip`, Web `.zip`).
7. Vérifier la Release et la version Web (`https://zephenix.github.io/paradoxe/`).
