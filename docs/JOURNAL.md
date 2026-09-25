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

---

## J2 — Déplacements, parkour et salles (v0.2)

### Ce qui a été fait

- **Élias** (`scenes/player/elias.tscn`) : un corps physique (`CharacterBody2D`) piloté
  par une **machine à états** de 16 états, chacun dans son propre script
  (`scripts/player/states/`) :
  - au sol : arrêt, marche, course, dérapage, demi-tour, accroupi, marche accroupie ;
  - en l'air : saut (sur place, sans élan, avec élan), chute ;
  - réceptions : réception (légère ou lourde), roulade ;
  - parkour : glissade, suspension, hissage, descente d'un rebord ;
  - mort.
- **Mouvements engagés** : un saut, une roulade, un hissage vont à leur terme, et la
  trajectoire d'un saut ne se corrige pas en l'air. Les commandes données pendant ce temps
  sont **mémorisées** (tampon de 0,2 s) et s'enchaînent dès que possible.
- **Parkour moderne**, désactivé en mode classique :
  - glissade sous les obstacles ;
  - rattrapage automatique des rebords (en classique, il faut maintenir Haut) ;
  - roulade d'esquive brièvement invulnérable ;
  - « temps du coyote » : on peut sauter un instant après avoir quitté un bord ;
  - garde-bord : en marchant, Élias s'arrête devant un vide dangereux.
- **Chutes** : sans conséquence jusqu'à 3 blocs, réception lourde au-delà de 2 blocs,
  roulade obligatoire entre 3 et 5 blocs, mortelle au-delà.
- **Réglages** dans `resources/player/player_movement.tres`. Les sauts sont exprimés
  **en blocs** (« le saut avec élan franchit 4 blocs ») et le code en déduit les vitesses.
- **Silhouette polygonale animée** : un squelette de polygones construit par code et
  19 animations générées à partir de **tables de poses**
  (`scripts/player/visual/elias_poses.gd`). Les états ne connaissent que l'interface
  `CharacterVisual` : une version rotoscopée pourra remplacer ce dessin sans toucher aux
  états.
- **Monde** :
  - blocs de décor dessinés et dimensionnés dans l'éditeur (`SolidBlock`, script `@tool`) ;
  - salles (`Room`) et caméra « écran par écran » (`CameraDirector`), qui glisse d'une salle
    à l'autre (ou coupe net), recule dans les grandes salles et suit Élias sans montrer
    l'extérieur ;
  - fonds de ville en **parallaxe** (`Parallax2D`), dessinés par code.
- **Salle de test** (`scenes/levels/test_level.tscn`) : 5 salles avec panneaux d'aide.
  Elle est accessible depuis l'écran titre. À la mort, Élias réapparaît au début de la
  salle, en attendant les vrais checkpoints de J3.
- **Bruitages provisoires** : 13 sons générés (pas, saut, réceptions, roulade, glissade,
  prise de rebord…), déclenchés par les évènements d'animation.
- **Tests** : 74 au total, dont 21 sur le déplacement, joués dans des décors construits par
  les tests eux-mêmes. S'y ajoutent des tests sur la caméra, les salles et la machine à
  états. La simulation avance image par image (`--fixed-fps 60`) : les tests sont
  reproductibles et rapides (moins d'une seconde pour tout).

### Comment tester

1. Écran titre : cliquer ou appuyer sur une touche, puis **« Salle de test : déplacements
   (J2) »**.
2. Suivre les panneaux, de gauche à droite :

| Salle | À essayer |
|---|---|
| **A - Les bases** | Marcher, courir (Maj), demi-tour, **Haut** devant la marche et devant le mur (se hisser), **Bas** puis avancer dans le tunnel, **C** pour la roulade |
| **B - Sauts** | Espace **en marchant** (2 blocs), Espace **en courant** (4 blocs, pour le grand trou), **Bas en courant** pour glisser sous le bloc suspendu. Tomber dans un trou (3 blocs) puis en ressortir (Haut contre la paroi) |
| **C - Rebords et chutes** | Haut contre le mur de 3 blocs (saut, prise, puis Haut pour se hisser), deuxième mur, puis sauter de la tour (4 blocs : roulade). Au bord d'un vide : **Bas** pour descendre et s'accrocher |
| **D - Le puits** | Tomber dans le puits de la salle C : caméra qui descend, chute mortelle, réapparition |
| **E - Grand hall** | La caméra recule (zoom) et suit Élias. Terrain libre |

3. **Échap** ramène à l'écran titre. Le **mode classique** n'a pas encore d'option dans
   l'interface (J9) : il est vérifié par les tests automatisés.

### Ce qu'il faut écouter

| Action | Ce que tu dois entendre |
|---|---|
| Marcher | Pas sourds et réguliers, calés sur le moment où le pied touche le sol. Deux pas successifs ne sont jamais identiques (4 variantes, hauteur et volume légèrement aléatoires). |
| Courir | Mêmes pas, plus forts et plus rapprochés. |
| Avancer accroupi | Pas presque inaudibles : c'est la base de l'infiltration (J6). |
| Sauter / retomber | Frottement de tissu au décollage, double impact à la réception. |
| Chute de 2 à 3 blocs | Impact plus grave et un souffle (réception lourde). |
| Roulade, glissade, dérapage | Frottements de tissu, raclement qui s'éteint, crissement de semelles. |
| Prise de rebord, hissage | Claquement des mains, puis effort. |
| Chute mortelle | Corps qui s'effondre, puis fondu au noir. |

Ces sons sont volontairement simples : ils vérifient la synchronisation entre animation et
son. Les vrais bruitages (selon la surface, avec la respiration) arrivent en J5.

### Décisions prises (et pourquoi)

- **Haut = saut sur place**, comme dans les jeux d'origine. Contre un mur, ce saut attrape
  le rebord : c'est la façon naturelle de grimper. Un rebord à hauteur de mains se franchit
  directement, sans sauter.
- **Garde-bord** : en marchant, Élias s'arrête devant un vide de plus de 3 blocs. En
  courant, il ne s'arrête pas (on assume son élan). Cette assistance limite les morts
  bêtes sans retirer le danger ; elle est désactivée en mode classique.
- **Hauteur accroupie** : 1,2 bloc (58 px), pour coller au dessin. Les passages bas font
  donc 1,5 bloc.
- **Tout le niveau dans une seule scène** : les salles sont posées côte à côte, et la caméra
  passe de l'une à l'autre sans temps de chargement (voir PLAN §3.3).
- **Squelette et animations construits par code** à partir de tables de poses : les poses
  se retouchent en changeant des nombres. La planche de poses
  (`./tools/screenshot.sh res://tools/godot/pose_sheet.tscn build/shots/poses.png 10`)
  les montre toutes d'un coup.
- **Réapparition au début de la salle** : c'est provisoire, les checkpoints arrivent en J3.
- **Pièges techniques rencontrés** :
  - à la première image, le moteur n'a pas encore détecté le sol : une tolérance de
    0,05 s évite un faux départ en chute ;
  - un script d'outil lancé avec `-s` est compilé avant les autoloads : il ne doit pas
    utiliser la classe `Player` (voir CLAUDE.md).

### Vérifications effectuées

- 74 tests automatisés au vert, dont les distances de saut mesurées :
  - saut sans élan : entre 1,7 et 2,9 blocs ;
  - saut avec élan : entre 3,7 et 5 blocs.
- Planche de poses (19 animations) et « visite guidée » de la salle de test
  (`tools/godot/level_tour.gd`). J'ai regardé les captures : accroupi dans le tunnel, saut,
  suspension, hissage, glissement de caméra entre deux salles, recul de caméra dans le
  grand hall.

### Reste à faire / points d'attention

- Les distances de saut et les vitesses sont à juger **manette en main** : dis-moi si c'est
  trop lent, trop flottant ou trop sec. Tout se règle dans
  `resources/player/player_movement.tres`.
- Pas encore de sons selon la surface ni de respiration (J5), pas de rayon de bruit (J6).
- Jalon suivant : **J3, arme, énergie, ennemis, mort et checkpoints**.

### Concepts Godot expliqués

**1. La machine à états (un script par état)**

Un personnage de jeu d'action est toujours « dans un état » : à l'arrêt, en course, en l'air,
suspendu… La tentation est d'écrire une seule grosse fonction :

```
Select Case etat          ' (en VBA)
    Case "course" : ...   ' 30 lignes
    Case "saut"   : ...   ' 40 lignes
    ...                   ' 16 cas, 600 lignes
End Select
```

Ici, chaque `Case` devient un **fichier** (`run.gd`, `jump.gd`…) avec trois procédures :
`enter` (ce qu'on fait en arrivant), `physics_update` (60 fois par seconde) et `exit` (en
partant). Un état décide lui-même quand passer à un autre :
`machine.transition_to(&"Jump", {"kind": &"running"})`. Ajouter un mouvement revient à
ajouter un fichier, sans toucher aux autres. La même machine (`scripts/core/`) servira
aux ennemis (J3) et au compagnon (J7).

**2. Les Resources (`.tres`) : régler le jeu sans toucher au code**

Une *Resource* est un objet de données enregistré dans un fichier. Le script
`player_movement_config.gd` déclare les réglages avec `@export` (vitesses, hauteurs de
saut, seuils de chute…), et `resources/player/player_movement.tres` en contient les valeurs.
Double-clique sur ce fichier dans l'éditeur : l'inspecteur affiche tous les réglages,
groupés et commentés, comme une feuille de paramètres Excel. Change « Running Jump Distance
Blocks » de 4 à 5 : le saut avec élan ira plus loin. Le code, lui, recalcule seul la vitesse
nécessaire (`jump_velocity()`, avec les formules de la chute libre). Les ennemis, l'énergie
et la perception auront chacun leur fichier de réglages.
