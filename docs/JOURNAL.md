# PARADOXE — Journal de développement

Une section par jalon. On y trouve ce qui a été fait, comment le tester, **ce qu'il faut
écouter**, ce qui reste à faire, et l'explication de 1 ou 2 concepts Godot utilisés.
Les décisions de conception prises en cours de route y sont notées et justifiées.

---

## J0 — Plan (25/09/2026)

- Rédaction de `docs/PLAN.md` : architecture, 8 écrans, systèmes de jeu, plan audio,
  tests, CI/CD, jalons, risques.
- Plan **validé**. Ajout demandé : une **cinématique d'ouverture** dans l'esprit des jeux
  d'origine. Son découpage en 11 plans est dans PLAN §5.12. Le système de cinématiques
  arrive en J7, l'intro elle-même en J8.
- Branche `main` créée. GitHub Pages activé (source : GitHub Actions).

---

## J1 — Fondations (v0.1)

### Ce qui a été fait

- **Installation reproductible** : `setup.sh` installe Godot **4.7.2** (binaire officiel,
  somme SHA-512 vérifiée) et **les modèles d'export de la même version**. Seuls les
  modèles utiles sont extraits (Web, Windows, Linux) : 530 Mo au lieu de 1,3 Go.
- **Projet Godot** : rendu *Compatibility* (le seul possible sur le Web), 1280×720, six
  autoloads (`Events`, `Settings`, `GameState`, `AudioManager`, `RewindManager`,
  `SceneTransition`), commandes clavier et manette déclarées dans
  `scripts/input/input_actions.gd`.
- **Audio** : table de mixage à 7 bus (Master, Musique, UI, Monde, Ambiance, SFX, Voix)
  avec leurs effets (étouffement, gain dramatique, limiteur, réverbération et filtre de
  salle). Le gestionnaire `AudioManager` sait déjà jouer des sons, gérer des boucles en
  fondu, étouffer, couper au silence, régler la réverbération, et signaler un bruit aux
  futurs ennemis.
- **Générateur de sons** (Python) : `tools/audio/`, avec une boîte à outils de synthèse
  (`dsp.py`) et 3 sons de test. Les boucles sont inscrites dans le WAV, et Godot les
  détecte seul.
- **Écran titre / banc de test** : un anneau de portail animé, dessiné par code. L'écran
  attend un clic ou une touche, débloque le son, puis affiche un panneau pour tester chaque
  bus et chaque effet, avec une ligne de diagnostic (version, plateforme, mode audio,
  latence).
- **Tests automatisés** : un lanceur maison, 43 tests (bus, audio, réglages, commandes,
  transitions, configuration). Des tests de fumée instancient toutes les scènes et
  chargent tous les scripts. **Toute erreur du moteur fait échouer un test.**
- **Exports** : Web (multithread, PWA), Windows (`.exe` unique avec l'icône du jeu), Linux
  (fichier unique).
- **CI GitHub Actions** : tests à chaque Pull Request, publication Web sur GitHub Pages à
  chaque push sur `main`, Release Windows/Linux/Web à chaque tag `v*`.
- **Documentation** : README, CLAUDE.md, CREDITS.md, SOUND_DESIGN.md, mode d'emploi du
  générateur.

### Comment tester

1. **Navigateur** : <https://zephenix.github.io/paradoxe/>.
   - Au premier chargement, la page se recharge d'elle-même une fois. C'est normal.
   - Écran titre : un anneau vert tourne en silence. **Cliquez ou appuyez sur une touche.**
   - Le panneau « Banc de test audio (J1) » apparaît à droite. En bas, la ligne de
     diagnostic doit indiquer `Web (multithread)` et `Audio : Stream`.
2. **Windows / Linux** : téléchargez la Release **v0.1**
   (<https://github.com/zephenix/paradoxe/releases>). Mêmes écrans, avec en plus le bouton
   « Quitter ». Sous Windows, voir le README pour l'avertissement SmartScreen.
3. **Navigation** : souris, ou clavier (flèches + Entrée), ou manette (croix + A).
4. **Dans l'éditeur Godot 4.7.2** : ouvrir `project.godot`, touche F5.

### Ce qu'il faut écouter

| Action | Ce que tu dois entendre |
|---|---|
| Premier clic | Deux notes brèves et douces qui montent, puis un **bourdonnement grave** qui enfle sur 2,5 s, avec des battements lents (le son « respire ») et de petits crépitements aigus. |
| Laisser tourner 20 s | La boucle dure 8 s : **aucun clic ni saut** audible au raccord. |
| « Choc métallique » | Un « clang » sec qui résonne environ 1,5 s. Chaque appui a une hauteur légèrement différente (variation aléatoire de ±6 %). |
| « Réverbération grand hall » puis « Choc métallique » | Même choc, suivi d'une **longue traîne d'écho brillante**. Le bourdonnement devient lui aussi plus spacieux. |
| « Étouffement » | En 0,8 s, tout devient **sourd**, comme entendu à travers un mur. C'est la base de l'effet de rembobinage (J4). Le retirer rend la clarté. |
| « Coupure brutale au silence » | **Silence total** instantané pendant 1,2 s, puis le son revient progressivement en 1,5 s. |
| Curseur « Volume général » | Volume global. Le réglage est mémorisé pour le prochain lancement. |

Sur le Web, un léger décalage entre le clic et le son (environ 90 ms) est normal.

### Décisions prises (et pourquoi)

- **Tests maison plutôt que GUT** : pas de dépendance à maintenir. De plus, le lanceur
  intercepte **les erreurs du moteur** (classe `Logger`, apparue avec Godot 4.5) : un test
  échoue si une erreur de script survient, même sans vérification fausse. J'ai vérifié
  qu'il détecte bien une erreur d'exécution, un `push_error` et une erreur de syntaxe.
- **Web multithread + mode audio « Stream »** : c'est la seule combinaison qui garde les
  effets de bus (réverbération, filtres) avec une latence raisonnable. GitHub Pages
  n'envoie pas les en-têtes nécessaires au multithread : c'est le *service worker* de
  Godot qui les ajoute. Au premier chargement, Godot rechargeait parfois la page avant que
  ce service worker soit actif, et laissait alors un écran noir. J'ai ajouté un petit
  script qui attend son activation et recharge une seule fois. Testé dans Chromium avec un
  navigateur « neuf ».
- **Bus « Monde » intermédiaire** : l'acoustique de la salle s'applique aux sons du monde
  (SFX, Voix, Ambiance), pas à la musique ni à l'interface.
- **Gain dramatique séparé du volume du joueur** : les silences de mise en scène ne
  touchent jamais les réglages des options.
- **Commandes déclarées par code** (et non dans les paramètres du projet) : la liste reste
  lisible comme un tableau, et le retour aux touches par défaut sera trivial. Les touches
  sont **physiques** : WASD en QWERTY = ZQSD en AZERTY.
- **Icône Windows** : Godot 4.7 modifie l'exécutable lui-même, sans rcedit ni Wine.
  **L'icône personnalisée est donc incluse** (vérifié en extrayant les ressources du `.exe`).
- **Sons générés versionnés** (WAV) : la CI n'a pas besoin de Python. Elle vérifie
  seulement que le générateur fonctionne toujours.
- **Numéro de version** : la CI l'inscrit dans le jeu à l'export (`0.1.0` pour le tag
  `v0.1`, `0.1.0+<commit>` pour la version Web de `main`).
- **Création des Releases** : depuis la session cloud, l'envoi d'un tag git est refusé
  par le proxy (seules les branches passent). Le workflow peut donc aussi être lancé à
  la main sur `main` avec un champ `release_tag` (ex. `v0.1`) : la CI crée alors le tag
  elle-même et publie la Release. Pousser un tag depuis un poste local marche toujours
  et donne le même résultat.
- Symbole « → » retiré de l'interface : la police par défaut ne le contient pas sur le Web.

### Vérifications effectuées

- 43 tests automatisés au vert (headless).
- Captures d'écran de l'écran titre (avant et après le clic), avec le vrai moteur de rendu.
- Version Web dans Chromium headless, servie depuis un sous-dossier comme sur GitHub Pages :
  isolation active dès la première visite, moteur multithread, aucune erreur JavaScript.
  **Sortie audio mesurée** : silence avant le clic, son après le clic ; l'étouffement
  divise la part d'aigus par 5 ; la coupure ramène le volume à ~0 puis il revient.
- Exécutable Linux lancé avec succès (données intégrées). Ressources du `.exe` Windows
  inspectées : icône du jeu en 6 tailles, nom et description du produit.

- **Site publié vérifié** (<https://zephenix.github.io/paradoxe/>, version
  `0.1.0+50fba7b`) avec le même contrôle Chromium : isolation dès la première visite, son
  mesuré après le clic, aucune erreur.

### Reste à faire / points d'attention

- **Branche par défaut** : le dépôt étant vide au départ, GitHub a pris la branche de
  travail comme branche par défaut. À régler une fois : *Settings → General → Default
  branch → `main`*.
- Licence du projet (code, contenus) : à choisir.
- Police dédiée pour l'interface (J9).
- Jalon suivant : **J2 — déplacement complet, parkour, salles et transitions**.

### Concepts Godot expliqués

**1. Les autoloads (singletons)**

Un autoload est un script (ou une scène) que Godot charge **une seule fois au démarrage**,
avant tout le reste, et qu'il garde en vie jusqu'à la fermeture du jeu. On y accède
**partout par son nom** : `AudioManager.play_stream(...)`, `Settings.get_volume(...)`.

Analogie VBA : c'est un **module standard avec des variables publiques**. Il existe en un
seul exemplaire, et toutes les feuilles et tous les formulaires peuvent l'appeler. Ici,
chaque autoload a une responsabilité unique (le son, les réglages, l'état de la partie…).
Il survit aux changements de scène, ce qui permet par exemple de garder une ambiance
sonore pendant un fondu entre deux écrans.

On les déclare dans *Projet → Paramètres du projet → Globals → Autoload* (section
`[autoload]` de `project.godot`). **L'ordre compte** : `Settings` utilise `Events`, donc
`Events` est déclaré avant.

**2. Les bus audio et leurs effets**

Un **bus** est une tranche de table de mixage. Chaque lecteur de son (`AudioStreamPlayer`)
envoie son signal dans un bus (`player.bus = "SFX"`). Le bus a un volume, peut être coupé,
et porte une **chaîne d'effets** appliqués dans l'ordre (réverbération, filtre,
limiteur…). Sa sortie part ensuite vers un autre bus, jusqu'au **Master**, qui va aux
haut-parleurs.

L'intérêt : on règle **une catégorie entière** d'un seul geste. Le curseur « Musique » des
options change le volume du bus Musique. Entrer dans une grotte active la réverbération du
bus Monde, et tous les pas, voix et ambiances résonnent aussitôt, sans que chaque son ait
à s'en occuper. Côté code : `AudioServer.get_bus_effect(index_du_bus, index_de_l_effet)`
donne accès à un effet pour modifier ses réglages en direct (c'est ce que fait
`AudioManager.set_muffle`).
