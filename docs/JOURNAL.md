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
    à l'autre (ou coupe net, comme à l'entrée du puits), recule dans les grandes salles et
    suit Élias sans montrer l'extérieur ;
  - fonds de ville en **parallaxe** (`Parallax2D`), dessinés par code.
- **Salle de test** (`scenes/levels/test_level.tscn`) : 5 salles avec panneaux d'aide.
  Elle est accessible depuis l'écran titre. À la mort, Élias réapparaît au début de la
  dernière salle où il avait les pieds au sol, en attendant les vrais checkpoints de J3.
- **Bruitages provisoires** : 13 sons générés (pas, saut, réceptions, roulade, glissade,
  prise de rebord…). Les pas et la chute du corps sont déclenchés par les animations ; les
  actions (saut, réception, prise…) par les états.
- **Tests** : 115 au total après l'audit (voir plus bas), dont 43 sur le déplacement, joués
  dans des décors construits par les tests eux-mêmes. S'y ajoutent des tests sur la
  caméra, les salles, la machine à états, les bruitages et le parcours réel de la salle de
  test. La simulation avance image par image (`--fixed-fps 60`) : les tests sont
  reproductibles et rapides (moins de 2 secondes pour tout).

### Comment tester

1. Écran titre : cliquer ou appuyer sur une touche, puis **« Salle de test : déplacements
   (J2) »**.
2. Suivre les panneaux, de gauche à droite :

| Salle | À essayer |
|---|---|
| **A - Les bases** | Marcher, courir (Maj), demi-tour, **Haut** devant la marche et devant le mur (se hisser), **Bas** puis avancer dans le tunnel, **C** pour la roulade |
| **B - Sauts** | Espace **en marchant** (saut de 2 blocs, trou de 1,5), Espace **en courant, après avoir pris de l'élan** (saut de 4 blocs, trou de 3,5), **Bas en courant** pour glisser sous le bloc suspendu. Tomber dans un trou (3 blocs) puis en ressortir (Haut contre la paroi) |
| **C - Rebords et chutes** | Haut contre le mur de 3 blocs (saut, prise, puis Haut pour se hisser), deuxième mur, puis **se laisser tomber** de la tour (4 blocs : roulade) ; un saut avec élan depuis la tour est mortel (plus de 5 blocs). Au bord d'un vide : **Bas** (maintenu ou non) pour descendre et s'accrocher, un nouvel appui sur Bas pour lâcher |
| **D - Le puits** | Tomber dans le puits de la salle C : coupure franche vers le puits, chute mortelle, réapparition au début de la salle C |
| **E - Grand hall** | La caméra recule (zoom) et suit Élias. Terrain libre |

3. **Échap** ramène à l'écran titre. Le **mode classique** n'a pas encore d'option dans
   l'interface (J9) : ses six différences (glissade, rattrapage des rebords, invulnérabilité
   de l'esquive, tampon d'entrée, temps du coyote, garde-bord) sont vérifiées par les tests
   automatisés.

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

- 115 tests automatisés au vert, dont les distances de saut mesurées (à ±0,25 bloc du
  réglage) : saut sans élan ≈ 2 blocs, saut avec élan ≈ 4 blocs, roulade ≈ 2,5 blocs.
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

### Correctif après l'audit (avant le tag v0.2)

Avant de publier v0.2, un audit du code en trois volets parallèles a été mené, en lecture
seule : joueur ; monde et outils ; tests et documentation. Tout ce qu'il a trouvé a été
corrigé, sauf ses simples suggestions.

**Blocages de la salle de test (critiques)**
- La sortie du tunnel de la salle A butait sur le mur suivant : impossible de se relever,
  donc d'atteindre la salle B. Le tunnel fait maintenant 5 blocs. La visite guidée ne
  l'avait pas vu, car elle téléportait Élias. Un test parcourt désormais la salle A
  jusqu'à la salle B, avec un pilote automatique.
- Mourir dans le puits faisait réapparaître Élias dans le puits lui-même, une poche fermée.
  La salle de réapparition est maintenant la dernière salle où il avait les pieds au sol.

**Défauts de comportement (majeurs)**
- **Descente de rebord** : Élias lâchait prise aussitôt si Bas restait maintenu. Il faut
  maintenant un nouvel appui pour lâcher.
- **Élan** : le saut avec élan, la glissade et le dérapage étaient possibles dès le premier
  instant d'une course. Il faut maintenant avoir atteint 75 % de la vitesse de course
  (réglage `momentum_threshold`).
- **Hauteurs de chute** : elles pouvaient se cumuler d'un étage à l'autre. La référence
  suit maintenant le sol à chaque image.
- **Accroupi au bord d'un vide** : l'état changeait à chaque image, et la silhouette
  tremblait.
- **Échap pendant une réapparition** était ignoré : un fondu interrompu laissait une
  attente bloquée. `SceneTransition` refuse maintenant les demandes concurrentes.
- **Réglage sans effet** : `step_climb_max_blocks` n'était pas utilisé. Il vaut 2,6 blocs :
  au-delà, Haut fait un saut sur place.

**Défauts mineurs**
- Retour en arrière visible en fin de roulade.
- Faux atterrissage à la réapparition.
- Hissage à travers un surplomb.
- Saut « coyote » qui rejouait l'impulsion en l'air.
- Roulade à 80 % de sa distance réglée.
- Glissade d'environ 1 bloc à la réception d'un saut avec élan.
- Trous de la salle de test sans marge (ils font maintenant 1,5 et 3,5 blocs).
- Tour de la salle C mortelle en saut avec élan : c'est désormais signalé sur le panneau.

**Code et documentation**
- Toutes les valeurs de réglage passent dans les Resources (`player_movement.tres`, nouveau
  `respawn.tres`), et la taille du bloc n'est définie qu'à un endroit (`GameUnits.BLOCK`).
- Une transition demandée pendant une autre est mise en file : les signaux restent dans
  l'ordre.
- Les couches de collision ont des noms dans l'éditeur.
- Commentaires trompeurs corrigés, notamment celui du `.tres` (voir le concept 2 ci-dessous).

**Tests renforcés**
- Le lanceur impose un délai maximum par test. Un avertissement imprévu ou un test sans
  vérification font maintenant échouer.
- Les déclarations non typées sont désormais des **erreurs** (règle « GDScript typé »).
- 41 tests ajoutés.
- **Contrôle par mutation** : j'ai réintroduit une à une 20 erreurs dans le code du joueur
  (marche immobile, gravité à 80 %, coyote supprimé…), et **les 20 sont détectées**. Avant
  l'audit, 16 d'entre elles passaient inaperçues.

**Point ouvert** : un `AudioStreamRandomizer` joué par l'`AudioManager` provoque des
messages de fuite mémoire à la sortie du lanceur de tests. Je ne le reproduis dans aucun
autre contexte, et ces messages sont sans effet sur le jeu. Les tests de déplacement
coupent donc le Foley. La cause sera examinée en J5, avec la bibliothèque de sons.

### Correctif Web après la v0.2 : la version en ligne restait l'ancienne

**Symptôme** : après la publication de la v0.2, la page en ligne affichait encore la v0.1
(l'écran de démonstration des sons).

**Cause** : l'export Web de Godot installe un *service worker*, un petit programme que le
navigateur exécute en arrière-plan pour ce site. Il ajoute les en-têtes qui permettent le
multithread, et il garde une copie du jeu en cache pour démarrer plus vite. Il fonctionne
en « cache d'abord » : il sert la copie gardée sans regarder le réseau. Le navigateur finit
par voir qu'une nouvelle version existe, mais la règle des service workers veut que la
nouvelle version **attende la fermeture de tous les onglets du site** avant de prendre la
main. Recharger la page ne suffit donc pas.

**Correction** (dans le script `html/head_include` de `export_presets.cfg`) :
- à l'ouverture de la page, on demande au navigateur de chercher une mise à jour ;
- s'il en trouve une, on dit au nouveau service worker de prendre la main tout de suite
  (message `'update'`, prévu par Godot), puis on recharge la page : la nouvelle version
  démarre, une ou deux secondes après l'ouverture ;
- si la nouvelle version n'est prête que plus de 20 s après l'ouverture, on ne recharge pas
  en pleine partie : elle sera prise à la visite suivante.

Le jeu écrit aussi sa version dans la console du navigateur (`PARADOXE v0.2.0`, touche F12).

**Vérification** : `./tools/web/check_update.sh` exporte deux versions de test, ouvre la
première dans Chromium, remplace le site par la seconde et revient sur la page, sans fermer
l'onglet : la seconde s'affiche 2,8 s après le retour. En cherchant, j'ai découvert que
Chromium met en attente les recherches de mise à jour pendant environ 60 s après la toute
première installation du service worker. Un joueur qui revient plus tard n'est pas
concerné, et le test attend donc la fin de cette période.

**Pour toi** : cette correction ne s'applique qu'à partir de la version qui la contient.
Si ton navigateur affiche encore l'ancienne version, ferme **tous** les onglets du site
puis rouvre-le : c'est la dernière fois que tu auras à le faire.

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
saut, seuils de chute…) et leurs **valeurs par défaut**. Le fichier
`resources/player/player_movement.tres` est une « instance » de ces réglages. Double-clique
dessus dans l'éditeur : l'inspecteur affiche tous les réglages, groupés et commentés, comme
une feuille de paramètres Excel. Attention, Godot n'enregistre dans le `.tres` que les
valeurs **modifiées** : tant qu'on n'a rien changé, le fichier est presque vide, ce qui veut
dire « tout aux valeurs par défaut ». Il faut donc régler dans l'inspecteur, pas en ouvrant
le `.tres` dans un éditeur de texte. Change « Running Jump Distance
Blocks » de 4 à 5 : le saut avec élan ira plus loin. Le code, lui, recalcule seul la vitesse
nécessaire (`jump_velocity()`, avec les formules de la chute libre). Les ennemis, l'énergie
et la perception auront chacun leur fichier de réglages.

---

## J3 — Combat, énergie, Sentinelles et checkpoints (v0.3)

### Ce qui a été fait

- **Une jauge d'énergie unique** (`EnergyPool`, réglages `resources/player/energy.tres`) :
  10 unités, un tir coûte 1, un tir chargé 4, le bouclier 3 par seconde. Elle se recharge
  toute seule après une seconde sans rien consommer. Sans énergie, rien ne part : l'arme
  fait un « clic » à vide.
- **L'arme d'Élias** (`Weapon`, réglages `resources/weapons/pistol.tres`) et quatre nouveaux
  états :
  - **Aim** : arme levée. Un appui sur Tirer dégaine puis tire ; la direction opposée fait
    se retourner Élias en gardant l'arme levée ; la direction du regard le fait rengainer
    et marcher ; il rengaine seul au bout de 3 s ;
  - **Shoot** : le tir et le recul (0,28 s, c'est la cadence de tir) ;
  - **Charge** : en gardant la touche enfoncée après un tir, la tension monte pendant
    0,8 s ; en relâchant, le **tir chargé** part. Il brise un bouclier ;
  - **Shield** : un mur d'énergie devant Élias, tant que la touche est maintenue.
- **Un tir tue** (Élias comme les Sentinelles), sauf pendant la roulade d'esquive. Les
  **hauteurs de tir** comptent : accroupi, Élias passe sous un tir debout ; un tir « à
  genou » le touche, sauf s'il est derrière un **muret de 1,5 bloc**.
- **Projectiles et boucliers** (`scripts/combat/`) : le même code et les mêmes sons pour
  Élias et les Sentinelles. Les tirs lancent un « rayon » à chaque image (voir le
  concept 1 ci-dessous) : aucun ne traverse un mur, même fin.
- **Les Sentinelles** (`scenes/enemies/sentinel.tscn`, réglages
  `resources/enemies/sentinel.tres`), avec six états (PLAN §5.3) :
  - **Patrol** : elles vont et viennent, et s'arrêtent au bord des plates-formes ;
  - **Suspicious** : un bruit (un tir) les intrigue, elles se tournent vers lui ;
  - **Search** : elles vont voir et regardent autour d'elles ;
  - **Combat** : réaction, **visée visible** (l'avertissement pour toi), tir, recul, pause.
    Elles lèvent leur bouclier face à un tir (7 fois sur 10), tirent à genou sur un Élias
    accroupi, s'approchent s'il est loin ;
  - **Chase** : elles l'ont perdu de vue, elles courent vers le dernier endroit connu ;
  - **Dead**.

  Elles **voient** devant elles (620 px, le décor cache) et **entendent** les tirs par le
  même système que le son (`AudioManager`, rayon de bruit : PLAN §6.3). Leur silhouette
  reprend le squelette et les gestes d'Élias, avec une autre peau et des marques
  lumineuses en spirale (les indices du twist, PLAN §4.3). Leurs voix sont des syllabes
  synthétisées, sans aucune langue : l'intonation dit leur état.
- **Checkpoints** (`scenes/props/checkpoint.tscn`) : une balise s'allume en vert quand Élias
  la touche. À la mort, il réapparaît au dernier checkpoint en moins de 2 s, jauge pleine ;
  les tirs en vol sont effacés et les Sentinelles reprennent leur poste, sauf celles tuées
  **avant** ce checkpoint. La réapparition « au début de la salle » de J2 disparaît.
- **Salle de test** : checkpoints à l'entrée des salles B, C, E et F ; nouvelle **salle F**,
  avec deux Sentinelles et deux murets.
- **Interface provisoire** : le bracelet d'Élias (poignet de l'arme) brille selon
  l'énergie, et une petite jauge apparaît au-dessus de sa tête quand l'énergie change.
  L'hologramme du bracelet la remplacera en J9 (PLAN §5.10).
- **20 sons provisoires** générés : tirs, charge, clic à vide, bouclier, impacts, voix des
  Sentinelles, checkpoint (détail dans `docs/SOUND_DESIGN.md`). Nouvelle fonction
  `AudioManager.play_stream_2d` : son positionné, avec rayon de bruit pour les ennemis.
- **Tests** : 190 au total (75 nouveaux), dont un test de bout en bout : un « pilote
  automatique » joue la salle F comme un joueur prudent et doit vaincre les deux
  Sentinelles.
- **Point ouvert de J2 résolu** : les « fuites mémoire » affichées à la sortie du lanceur
  de tests venaient des sons encore en cours au moment de quitter. Le lanceur les arrête
  maintenant et laisse au moteur le temps de les libérer.

### Comment tester

1. Écran titre : cliquer, puis **« Salle de test : mouvement et combat (J3) »**.
2. Traverser les salles A à E (ou aller directement au bout du grand hall E) : une porte
   mène à la **salle F**. En passant, tu vois les balises des checkpoints s'allumer.
3. Dans la salle F :

| À essayer | Comment |
|---|---|
| Tirer | **J** (ou X). La jauge apparaît au-dessus d'Élias |
| Tir chargé | Tirer, puis **garder J enfoncé** : la tension monte, un tintement, relâcher |
| Bouclier | **K** (ou W sur AZERTY) maintenu. Regarder la jauge baisser |
| Se mettre à couvert | **Bas** derrière un muret : les tirs de la Sentinelle s'y écrasent |
| Esquiver | **C** au moment où un tir arrive |
| Se faire toucher | Rester debout à découvert : réapparition au checkpoint de la salle F |
| Clic à vide | Vider la jauge en tirant vite, puis tirer encore |

4. Tactiques qui marchent : attendre qu'une Sentinelle tire (elle ne peut pas lever son
   bouclier pendant son recul) ; briser son bouclier d'un tir chargé puis tirer ; tirer
   sur une Sentinelle de dos (elle n'a pas le temps de réagir).

### Ce qu'il faut écouter

| Action | Ce que tu dois entendre |
|---|---|
| Tir d'Élias | Un « piou » clair et bref, puis l'impact (choc + grésillement) |
| Tir d'une Sentinelle | Plus grave et « bourdonnant » : on sait qui tire sans regarder |
| Charge | Une tension qui monte pendant 0,8 s, puis un tintement : c'est prêt |
| Tir chargé | Une décharge lourde et crépitante |
| Bouclier | Montée brève, grésillement tant qu'il est levé, claquement quand un tir le frappe, éclatement s'il est brisé |
| Jauge vide | Double clic sec, rien ne part |
| Voix des Sentinelles | Montante (intriguée), grave et interrogative (elle cherche), aiguë et hachée (elle t'a vu), descendante (retour au calme), cri qui retombe (touchée). Chacune a sa propre hauteur de voix |
| Checkpoint | Trois notes douces qui montent |

Tous ces sons sont **positionnés** : une Sentinelle à droite de l'écran s'entend à droite.

### Décisions prises (et pourquoi)

- **Tir chargé = maintenir après un tir** (et non « appuyer longtemps avant de tirer ») :
  le premier tir part tout de suite, sans latence, et la charge est un choix délibéré.
  Pendant la charge, la jauge ne se recharge pas, sinon garder la touche enfoncée serait
  une recharge gratuite.
- **Un tir tue**, dans les deux camps : c'est l'esprit des jeux d'origine, et ce qui donne
  son poids au bouclier et aux couverts.
- **Hauteurs de tir** : se baisser esquive les tirs debout. Pour que ce ne soit pas une
  protection absolue, les Sentinelles tirent à genou sur un Élias accroupi ; seul un muret
  protège alors.
- **Les Sentinelles réagissent à un tir vu de face**, pas dans le dos. Sans cela, on
  pouvait les tuer de loin avant qu'elles ne réagissent (le premier essai du pilote
  automatique gagnait en 3 s). Pour la même raison, la **portée d'un tir** est d'environ
  un écran (1000 px).
- **Même squelette pour les Sentinelles et Élias** : leurs gestes sont humains, ce qui sert
  le twist (PLAN §4.3), et chaque nouvelle pose profite aux deux.
- **Perception simple** en J3 (distance, sens du regard, décor qui cache) : la lumière,
  la suspicion progressive et l'atténuation du bruit par les murs arrivent en J6.
- **Checkpoints plutôt que salles** pour la réapparition : un seul système, placé à la main
  dans le niveau.

### Vérifications effectuées

- **190 tests** automatisés au vert (4 s). Nouveaux fichiers : `test_energy_pool.gd` (8),
  `test_projectiles_and_shields.gd` (16), `test_player_combat.gd` (19),
  `test_sentinel.gd` (21), `test_checkpoints.gd` (8), et 3 tests de plus dans
  `test_test_level.gd`, dont le pilote automatique de la salle F (il gagne en 7 s de jeu
  simulé, sans mourir).
- **Contrôle par mutation** : 14 erreurs réintroduites une à une (roulade qui ne protège
  plus, bouclier transparent, jauge sans limite, Sentinelle qui voit dans son dos, tir à
  genou supprimé, réapparition qui ignore le checkpoint…). Les 14 sont détectées. Les deux
  qui passaient au premier essai ont fait renforcer les tests.
- **Captures** : planche de poses (tir, recul, charge, bouclier, tir à genou) et visite
  guidée de la salle F (`tools/godot/level_tour.gd`, captures 7 à 10). En les regardant,
  j'ai corrigé un recul trop marqué et une Sentinelle trop sombre, qui se fondait dans le
  décor.
- **Web** : export vérifié dans Chromium. `tools/web/check_web.sh` entre maintenant dans la
  salle de test et fait tirer Élias, en échouant à la moindre erreur du moteur.

### Reste à faire / points d'attention

- **L'équilibrage est à juger manette en main** : vitesse des tirs ennemis, temps de visée
  (l'avertissement), probabilité de bouclier, coûts en énergie. Tout est dans
  `resources/enemies/sentinel.tres`, `resources/weapons/*.tres` et `resources/*/energy*.tres`.
- Le bruit d'un tir traverse les murs (atténuation en J6) ; la vue ne dépend pas encore de
  la lumière (J6).
- La mort n'a pas encore son court ralenti ni le choix « rembobiner » : c'est J4.
- La touche « Interagir » attendra les premiers objets interactifs (J7).
- Jalon suivant : **J4, le rembobinage temporel** (effort recommandé : high).

### Concepts Godot expliqués

**1. Les rayons : demander au moteur « qu'y a-t-il sur cette ligne ? »**

Un *rayon* (`PhysicsRayQueryParameters2D`) est une question posée au moteur physique :
« en allant du point A au point B, quel est le premier objet rencontré ? ». La réponse
donne l'objet, le point touché et l'orientation de la surface. C'est l'équivalent d'une
fonction RECHERCHEV lancée dans le monde du jeu : on ne crée rien, on interroge.

PARADOXE s'en sert partout :
- **les projectiles** : à chaque image, un rayon va de la position actuelle à la position
  suivante. Même à 2400 px/s (40 px par image), un tir ne peut donc pas « sauter »
  par-dessus un mur de 2 px (un test le vérifie) ;
- **la vue des Sentinelles** : un rayon de leurs yeux vers la tête d'Élias, un autre vers
  son buste ; si les deux touchent le décor, elles ne le voient pas ;
- **les rebords** (J2) et le **bord des plates-formes** : un rayon vers le bas, juste
  devant les pieds, mesure la profondeur du vide.

Le « masque de collision » dit quelles couches le rayon peut toucher : un tir d'Élias voit
le décor, les boucliers et les ennemis, mais pas Élias lui-même.

**2. L'héritage : une Sentinelle « est un » visuel d'Élias, avec une autre peau**

`class_name SentinelVisual extends EliasVisual` veut dire : « une SentinelVisual est une
EliasVisual, sauf ce que je redéfinis ». Elle hérite de tout le squelette, des
animations et de la fonction `play()`, et ne réécrit que trois choses : ses couleurs (dans
`_init`), sa tête (`_build_head`) et ses décorations (`_decorate`, les spirales au lieu du
bracelet).

VBA n'a pas vraiment d'héritage (seulement `Implements`, qui impose une liste de
procédures sans en fournir le code). L'image la plus proche est un classeur modèle : on
repart de toutes ses feuilles et formules, et on ne change que ce qui diffère. Avec une
différence de taille : ici, le lien reste vivant. Une correction dans `EliasVisual`, ou une
nouvelle pose ajoutée pour Élias, sert aussitôt aux Sentinelles.

---

## J4 — Remonter le temps (v0.4)

### Ce qui a été fait

- **Enregistrement du temps** (`RewindManager`, réglages `resources/rewind.tres`) :
  30 fois par seconde, une « photo » d'Élias et de chaque Sentinelle est prise (position,
  vitesse, énergie, pose, état de la machine à états…). Seules les 5 dernières secondes sont
  gardées : la plus vieille photo est jetée à chaque nouvelle.
- **Séquence de mort** (`DeathController`, créé par le niveau) :
  1. **ralenti** : le jeu tourne au quart de sa vitesse pendant 0,6 s, on voit Élias tomber ;
  2. **temps figé** : le jeu se met en pause, l'image se désature, et le choix s'affiche ;
  3. **maintenir R** : le temps remonte à l'écran (image froide, lignes qui défilent, son
     étouffé, souffles à l'envers) ; **relâcher** : on reprend à cet instant ;
  4. ou **Entrée / Espace** : retour au checkpoint, comme en J3.
- **Reprise propre** : on ne reprend jamais au milieu d'un geste engagé (hissage, roulade,
  tir…). Le jeu recule jusqu'à la dernière photo où Élias était dans une posture simple
  (arrêt, marche, course, accroupi, en chute, suspendu, arme levée).
- **Le monde remonte aussi le temps** : une Sentinelle tuée pendant les secondes remontées
  se relève, et son « hasard » repart du même point. Les tirs en vol disparaissent.
- **3 rembobinages par checkpoint** : rendus à chaque nouveau checkpoint et à chaque retour
  au checkpoint. Quand il n'en reste plus, la mort ramène directement au checkpoint.
- **Mode classique** : un interrupteur sur l'écran titre (sauvegardé). Pas de rembobinage
  (retour direct au checkpoint), et aucune des six aides du parkour de J2. Le diagnostic en
  bas de l'écran titre l'indique.
- **2 sons** générés : la boucle du rembobinage et le « relâchement » à la reprise.
- **Tests** : 206 au total (16 nouveaux). `test_rewind.gd` vérifie entre autres qu'après
  un rembobinage, Élias est **exactement** à une position qu'il a occupée (au millième de
  pixel).

### Comment tester

1. Écran titre : cliquer, laisser le mode classique **désactivé**, puis « Salle de test ».
2. Mourir, par exemple dans le puits de la salle C, ou sous les tirs dans la salle F.
3. Pendant le choix :

| À essayer | Ce qui doit se passer |
|---|---|
| **Maintenir R** | Le temps remonte, l'image devient froide et tremblante, le compteur « << 1,2 s » grandit |
| **Relâcher R** | Reprise à cet instant, couleurs normales ; « 2 restants » à la mort suivante |
| Relâcher R tout de suite | « remonter un peu plus » : rien n'est consommé |
| Maintenir R longtemps | Arrêt au bout des 5 s (« pas plus loin ») |
| Tuer une Sentinelle, se faire tuer, remonter | La Sentinelle se relève |
| **Entrée** | Retour au checkpoint |
| 4 morts de suite | À la 4e, plus de choix : retour direct au checkpoint (et 3 rembobinages rendus) |

4. Puis, sur l'écran titre, activer le **mode classique** : la mort ramène directement au
   checkpoint, et le parkour perd ses aides (pas de glissade, il faut maintenir Haut pour
   s'accrocher, etc.).

### Ce qu'il faut écouter

| Moment | Ce que tu dois entendre |
|---|---|
| Mort | Le corps qui tombe, au ralenti avec l'image |
| Temps qui remonte | Tout le son s'étouffe, comme sous l'eau ; des souffles « à l'envers » et un sifflement de bande qui ondule |
| Reprise | Le son se rouvre d'un coup, avec un souffle vers l'avant et un coup sourd |

L'étouffement agit sur **tout** le son (filtre du bus Master) : c'est l'effet qui ne
marcherait pas sur le Web en mode « Sample », d'où le choix du mode « Stream » en J1.

### Décisions prises (et pourquoi)

- **Photos d'états explicites plutôt qu'enregistrement de la physique** : chaque objet dit
  lui-même ce qu'il faut retenir de lui. C'est plus de code, mais c'est la seule façon de
  restaurer **exactement** (PLAN §10, risque « rembobinage et physique »).
- **Reprise à la dernière photo stable** : reprendre au milieu d'un hissage ou d'une
  roulade demanderait de sauvegarder tous les détails internes de ces gestes. En reculant
  de quelques centièmes de seconde jusqu'à une posture simple, la reprise est toujours
  cohérente, et le joueur ne voit pas la différence.
- **Élias reste « mort » pendant le défilement** : il ne revit qu'à la reprise. Si le
  joueur choisit finalement le checkpoint, le monde est d'abord remis dans son état au
  moment de la mort.
- **Le temps de ralenti est mesuré en temps réel** (minuteur qui ignore le ralenti) : sinon
  un ralenti de 0,6 s au quart de la vitesse durerait 2,4 s.
- **Checkpoints non rembobinés** : un checkpoint atteint le reste, même si l'on remonte
  avant le moment où on l'a touché.
- **Affichage du choix provisoire** : un texte à l'écran, en attendant l'hologramme du
  bracelet (J9).

### Vérifications effectuées

- **206 tests** au vert. `test_rewind.gd` (15 tests) couvre la mémoire circulaire, la
  restauration exacte de la position, la Sentinelle relevée, l'énergie, les tirs effacés,
  le rembobinage trop court, la limite des 5 s, la reprise en l'air, la reprise avant une
  roulade, la limite de 3, le checkpoint qui les rend, le mode classique, le ralenti, et la
  sortie du niveau pendant le choix (pause levée, vitesse normale). S'y ajoute
  `test_title_screen.gd` (interrupteur du mode classique, sauvegardé).
- **Contrôle par mutation** : 13 erreurs réintroduites, 13 détectées. Au premier essai,
  l'erreur « reprendre au milieu d'une roulade » passait : le test a été corrigé pour que
  le curseur tombe vraiment au milieu du geste.
- **Captures** (`level_tour.gd`, captures 11 à 13) : le choix sur l'image figée, le
  rembobinage en cours (Élias revenu 1 s en arrière, compteur « << 1.0 s »), la reprise.
  J'y ai vu que la caméra ne suivait pas Élias pendant le défilement : corrigé.
- **Web** : export vérifié dans Chromium (démarrage, son, salle de test, tir). L'effet
  d'image utilise le moteur de rendu « Compatibility », le même sur ordinateur et sur le
  Web ; je n'ai pas pu déclencher une mort dans le navigateur de test (aucun moyen de tuer
  Élias depuis la page sans ajouter une triche au jeu). **À vérifier de ton côté** : l'effet
  du rembobinage sur la version en ligne.

### Reste à faire / points d'attention

- À juger en jouant : durée du ralenti, vitesse du défilement (1,5 s par seconde), nombre
  de rembobinages. Tout est dans `resources/rewind.tres`.
- Le compteur de rembobinages et le choix passeront sur le bracelet en J9.
- L'ambiance « inversée » pendant le rembobinage viendra avec les ambiances de zone (J5).
- Proposé avant le tag v0.4 : l'**audit du code** de J3 et J4 (voir la fin de ce jalon
  dans la conversation).
- Jalon suivant : **J5, le son** (générateur, bibliothèque, ambiances, banc d'écoute).

### Concepts Godot expliqués

**1. La pause, et les nœuds qui continuent quand même**

`get_tree().paused = true` fige le jeu : les nœuds cessent d'appeler leurs fonctions
`_process` et `_physics_process`. Chaque nœud a un réglage `process_mode` qui dit comment
il réagit :
- **Inherit** (par défaut) : comme son parent ;
- **Pausable** : s'arrête pendant la pause ;
- **Always** : continue toujours.

Le rembobinage s'appuie là-dessus. Le niveau, Élias et les Sentinelles sont figés.
`RewindManager`, `AudioManager` et `DeathController` sont en **Always** : ils continuent
de tourner, remontent le temps et replacent les objets figés, photo après photo. C'est
comme figer le recalcul d'Excel (mode manuel) : les cellules ne bougent plus toutes
seules, mais une macro peut encore y écrire des valeurs.

**2. Un shader d'écran : retoucher l'image entière**

Un *shader* est un petit programme exécuté par la carte graphique **pour chaque pixel**.
Celui du rembobinage (`assets/shaders/rewind.gdshader`) est posé sur un rectangle qui
couvre l'écran. Il lit l'image déjà dessinée (`hint_screen_texture`), puis :
- la désature (moyenne pondérée des couleurs) et la refroidit ;
- la décale un peu à l'horizontale selon une sinusoïde : c'est le tremblement ;
- l'assombrit une ligne sur deux : ce sont les lignes qui défilent.

Un seul paramètre, `strength`, règle tout : 0 = image normale, 0,5 = temps figé, 1 =
rembobinage. C'est l'équivalent d'une mise en forme conditionnelle appliquée à toute la
feuille d'un coup, mais calculée 60 fois par seconde pour chaque pixel.
