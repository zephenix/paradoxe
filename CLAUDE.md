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
./tools/web/check_update.sh     # vérifie qu'une nouvelle version Web remplace l'ancienne (~2 min)
./tools/screenshot.sh res://tools/godot/pose_sheet.tscn build/shots/poses.png 10   # planche de toutes les poses d'Élias
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/godot/level_tour.gd -- build/shots   # visite guidée (captures)
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

- Lanceur maison : `tests/run_tests.gd`, lancé avec `--fixed-fps 60` (simulation image par
  image, rapide et reproductible). Chaque fichier `tests/unit/**/test_*.gd` hérite de
  `TestCase`, et chaque fonction `test_*` est un test.
- Fonctions de `TestCase` : `assert_true`, `assert_false`, `assert_eq`, `assert_ne`,
  `assert_almost_eq`, `assert_null`, `assert_not_null`, `fail`, `add_node`,
  `await wait_frames(n)`, `await wait_physics(n)`, `await wait_physics_seconds(s)`,
  `await wait_seconds(s)`, `expect_warning(fragment)`, `engine_errors()`,
  `clear_engine_errors()`.
- **Un test échoue** s'il a une vérification fausse, si le moteur signale une erreur
  (`push_error`, erreur de script, ressource manquante) ou un avertissement non annoncé par
  `expect_warning`, s'il ne vérifie rien, ou s'il dépasse le délai maximum (2 min simulées).
- Les déclarations non typées sont des **erreurs** (`untyped_declaration=2`) :
  `test_every_script_compiles` impose la règle.
- Déplacement d'Élias : piloter ses intentions (`player.input.from_devices = false`, puis
  `input.move`, `input.press(&"jump")`…) et retirer son nœud `Foley` dans les tests.
- Après un changement de gameplay, réintroduire une erreur dans le code et vérifier qu'un
  test la détecte : c'est le contrôle par mutation de l'audit J2.
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
- **Mise à jour Web** : le service worker de Godot sert le jeu depuis son cache (« cache
  d'abord »), et une nouvelle version attendrait la fermeture de tous les onglets. Le script
  de `html/head_include` la fait prendre au chargement (message `'update'` au nouveau service
  worker, puis rechargement). Après toute modification de ce script ou de la version de
  Godot : `./tools/web/check_update.sh`. Juste après la toute première installation du
  service worker, Chromium met les recherches de mise à jour en attente environ 60 s.
- Les fichiers `*.uid` (scripts) et `*.import` (sons, images) **se versionnent**. Le
  dossier `.godot/` ne se versionne pas.
- `build/` contient un `.gdignore` (créé par `tools/export.sh`), et `tools/web/` et
  `tools/audio/` aussi : Godot ne doit pas importer ces dossiers.
- Police par défaut (Open Sans) : certains symboles (→, ▸…) sont absents sur le Web. Rester
  en ASCII ou choisir une police dédiée.
- `project.godot` : l'éditeur peut réécrire le fichier et supprimer les commentaires `;`.
- Un script lancé avec `-s` (outils de `tools/godot/`, lanceur de tests) est compilé **avant**
  les autoloads : il ne doit pas typer statiquement une classe qui utilise un autoload
  (`Player`, `CameraDirector`…), sous peine d'« Identifier not found: GameState ». Utiliser
  `Node` et des appels dynamiques ; les fichiers de test, chargés plus tard, n'ont pas ce souci.
- Vérifier le **site publié** (`node tools/web/check_web.js https://zephenix.github.io/paradoxe/ build/shots`)
  dans une session cloud : Chromium doit faire confiance à l'autorité du proxy HTTPS. Si
  `ERR_CERT_AUTHORITY_INVALID`, ajouter les certificats « Anthropic » de
  `/root/.ccr/ca-bundle.crt` au magasin NSS (`certutil -d sql:$HOME/.pki/nssdb -A -t "C,," …`,
  paquet `libnss3-tools`). Ne jamais désactiver la vérification TLS.

## Méthode de travail par jalon (J1 → J9, voir PLAN §9)

1. Partir de `main` à jour, sur la branche de travail désignée pour la session.
2. Développer en commits clairs (en français). Lancer `./tools/run_tests.sh` avant chaque
   push et faire des captures d'écran pour tout changement visuel.
3. Mettre à jour `docs/JOURNAL.md` : une section `## Jx — Titre (vX.Y)` avec ce qui a été
   fait, comment le tester, ce qu'il faut écouter, ce qui reste à faire, et 1 ou 2 concepts
   Godot expliqués simplement. Le titre doit contenir `(vX.Y)` : `tools/release_notes.sh`
   s'en sert pour le texte de la Release.
4. Mettre à jour `config/version` dans `project.godot` (X.Y.0).
5. Ouvrir une Pull Request vers `main` et attendre la CI verte, puis **fusionner la PR
   soi-même**, sans attendre de relecture (autorisation donnée par le propriétaire le
   25/09/2026). Il relit les PR après coup.
6. **Créer la release** après la fusion. Deux méthodes, qui donnent la même Release
   (Windows `.exe` unique, Linux `.zip`, Web `.zip`) :
   - **session cloud** (le proxy git y refuse l'envoi de tags, erreur 403) : lancer le
     workflow « Build » sur `main` avec l'entrée `release_tag=vX.Y` (outil GitHub
     `actions_run_trigger`, méthode `run_workflow`, fichier `build.yml`, ref `main`). La
     CI crée le tag sur le commit de `main` ;
   - **poste local** : `git tag -a vX.Y -m "PARADOXE vX.Y — Jx" && git push origin vX.Y`.
7. Vérifier la Release et la version Web (`https://zephenix.github.io/paradoxe/`).

## Règle : conseil de niveau d'effort

Claude ne peut pas changer lui-même le niveau d'effort de la session : c'est le propriétaire
qui le fait. Le rôle de Claude est de lui dire précisément quand le changer.

1. Au début de chaque jalon, et avant chaque tâche importante hors jalon, écrire un bloc
   d'une ou deux lignes au format :
   > ⚙️ EFFORT RECOMMANDÉ : [low/medium/high/xhigh] — ULTRACODE : [non / mot-clé conseillé pour la sous-tâche X] — Raison : [une phrase]

   Si le niveau recommandé diffère de celui en cours, **s'arrêter après ce bloc** et attendre
   que le propriétaire confirme avoir changé de niveau avant de commencer.
2. Claude ne connaît pas toujours le niveau d'effort actif : en cas de doute, le demander
   plutôt que le supposer.
3. Référence par jalon (Opus 5.5, dont le défaut est medium) :
   - PLAN.md et révisions d'architecture : high
   - J1 setup, CI, export : medium
   - J2 déplacements, parkour, transitions : medium
   - J3 combat, énergie, ennemis, checkpoints : high
   - J4 rembobinage temporel : high (xhigh si un problème de synchronisation d'état résiste)
   - J5 sons procéduraux : medium, avec le mot-clé ultracode possible pour la génération en série
   - J6 infiltration lumière/son : high
   - J7 compagnon et interactions, J8 musique et scènes : medium (high si l'IA du compagnon pose problème)
   - J9 menus, options, polish : medium
4. Signaler aussi un changement en cours de jalon, avec le même bloc, dans ces cas :
   - deux échecs de suite sur le même bug ou le même test : recommander de monter d'un cran
     pour ce problème précis ;
   - problème résolu après une montée d'effort : recommander de redescendre au niveau du jalon ;
   - tâche répétitive et découpable en parties indépendantes (série d'assets, audit de tous
     les fichiers, boucle « tester et corriger jusqu'au succès ») : proposer le mot-clé
     ultracode avec la taille de workflow « small », et rédiger la ligne exacte à taper.
5. Ne jamais recommander le mode ultracode de session (`/effort ultracode`) : le projet a
   besoin des validations du propriétaire entre les étapes, ce que les workflows ne
   permettent pas. Le mot-clé ultracode est réservé aux sous-tâches autonomes, qui n'ont
   pas besoin de son avis en cours de route.
6. Avant chaque tag de version, proposer l'audit du code en ultracode (taille small) et
   rédiger la ligne à taper.
