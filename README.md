# PARADOXE

*Prototype de jeu de plateforme cinématique 2D, réalisé avec Godot 4.*

2140. Élias Varenne, chercheur, teste seul un portail temporel dans un laboratoire
souterrain, une nuit d'orage. L'expérience dérape : il se retrouve projeté sur une
Terre future méconnaissable, envahie par une végétation extraterrestre luminescente…

PARADOXE s'inspire des grands jeux de plateforme cinématiques du début des années 1990 :
mouvements « engagés », mort en un coup, narration sans texte, ambiance sonore au premier
plan. Le tout est modernisé avec du parkour, un rembobinage temporel limité, un compagnon,
de l'infiltration par la lumière et le son, et une interface intégrée au personnage.
Tous les éléments du jeu (images, sons, musique) sont originaux ou générés par du code.

> **État actuel : jalon J2 (v0.2), les déplacements.** Depuis l'écran titre, une **salle de
> test** de cinq écrans permet d'essayer tous les mouvements d'Élias : marche, course,
> sauts, rebords, roulade, glissade, chutes. Elle montre aussi les transitions de caméra
> d'une salle à l'autre. Le combat arrive en J3. Feuille de route : [`docs/PLAN.md`](docs/PLAN.md) ;
> avancement : [`docs/JOURNAL.md`](docs/JOURNAL.md).

---

## Jouer

### Dans le navigateur

**https://zephenix.github.io/paradoxe/**

- Il faut un navigateur récent (Chrome, Edge, Firefox, Safari 15.2 ou plus).
- **Au premier chargement, la page se recharge automatiquement une fois.** C'est normal :
  cela active le mode multithread, qui assure un son de qualité.
- **Après une mise à jour du jeu, la page se recharge aussi une fois toute seule**, une ou
  deux secondes après l'ouverture. Le navigateur garde une copie du jeu pour démarrer plus
  vite ; ce rechargement la remplace par la nouvelle version. Le numéro de version est
  affiché en bas de l'écran titre.
- **Cliquez une fois dans la page ou appuyez sur une touche pour activer le son.** Les
  navigateurs interdisent le son avant une interaction.
- La navigation privée de Firefox n'est pas prise en charge : elle bloque les « service
  workers », dont le jeu a besoin. Utilisez une fenêtre normale.

### Sur ordinateur (Windows, Linux)

Téléchargez la dernière version dans les
[**Releases**](https://github.com/zephenix/paradoxe/releases). Godot n'a pas besoin
d'être installé.

**Windows** : téléchargez `Paradoxe-vX.Y-windows.exe`. C'est un fichier unique, il suffit
de double-cliquer dessus.

> **Avertissement SmartScreen.** L'exécutable n'est pas signé numériquement (une
> signature est payante), si bien que Windows peut afficher « Windows a protégé votre
> ordinateur ». Pour lancer le jeu quand même :
> 1. cliquez sur **Informations complémentaires** ;
> 2. puis sur **Exécuter quand même**.
>
> Windows ne pose la question qu'une fois par fichier téléchargé. Si l'antivirus bloque le
> fichier, vous pouvez le débloquer dans *Propriétés → Général → Débloquer*.

**Linux** : téléchargez `Paradoxe-vX.Y-linux.zip`, puis :

```bash
unzip Paradoxe-vX.Y-linux.zip
chmod +x Paradoxe.x86_64   # seulement si le fichier n'est pas exécutable
./Paradoxe.x86_64
```

### Contrôles

Les touches ci-dessous sont celles par défaut. Elles pourront être modifiées dans les
options (jalon J9). Pour les lettres, c'est la **position** de la touche qui compte : les
touches notées « WASD » (clavier QWERTY) correspondent à **ZQSD** sur un clavier AZERTY.

| Action | Clavier | Manette (disposition Xbox) | Disponible |
|---|---|---|---|
| Se déplacer | Flèches ou WASD / ZQSD | Stick gauche ou croix | J2 |
| Sauter | Espace | A | J2 |
| Courir (maintenir) | Maj | RB | J2 |
| Roulade / esquive | C | B | J2 |
| Tirer (maintenir pour charger) | X ou J | RT | J3 |
| Bouclier (maintenir) | Z (QWERTY) / W (AZERTY) ou K | LT | J3 |
| Interagir | E ou Entrée | X | J3 |
| Lancer un objet | F | LB | J6 |
| Donner un ordre au compagnon | Q (QWERTY) / A (AZERTY) | Y | J7 |
| Rembobiner (après une mort) | R ou Retour arrière | Y | J4 |
| Bracelet holographique | Tab | Back / View | J9 |
| Pause | Échap ou P | Start / Menu | J9 |
| Passer une cinématique (maintenir) | Échap ou Espace | Start ou A | J7 |

Dans la version actuelle (J2), n'importe quelle touche ou un clic active le son. On choisit
ensuite « Salle de test : déplacements » au clavier (flèches, Entrée), à la souris ou à la
manette. Dans la salle de test, **Haut** (ou Espace à l'arrêt) sert aussi à sauter sur place
et à se hisser, et **Échap** ramène à l'écran titre.

---

## Travailler sur le projet

### Prérequis

- **Godot 4.7.2** (version exacte ; la CI utilise la même). Sous Windows, téléchargez
  l'éditeur « Standard » sur <https://godotengine.org/download/archive/4.7.2-stable/>.
  N'utilisez pas la version « .NET », inutile ici.
- **Python 3.10 ou plus**, avec numpy et scipy, uniquement pour régénérer les sons.

### Ouvrir le projet dans l'éditeur

1. Clonez le dépôt : `git clone https://github.com/zephenix/paradoxe.git`
2. Lancez Godot 4.7.2, cliquez sur **Importer**, puis choisissez le fichier `project.godot`
   du dépôt.
3. Touche **F5** : lance le jeu. Touche **F6** : lance la scène ouverte.

### Linux, ou session cloud (ligne de commande)

```bash
./setup.sh                 # installe Godot 4.7.2 (headless) + modèles d'export, importe le projet
./setup.sh --python        # idem + numpy/scipy pour le générateur de sons
./tools/run_tests.sh       # lance tous les tests automatisés (headless)
./tools/export.sh web      # exporte la version Web dans build/web/
./tools/export.sh all      # exporte Web + Windows + Linux dans build/
python3 tools/audio/generate_sounds.py   # régénère les sons procéduraux
```

Autres outils : [`CLAUDE.md`](CLAUDE.md) (commandes, conventions, création d'une release).

### Organisation du dépôt

```
scenes/      scènes Godot (.tscn) : écrans, personnages, objets, salles
scripts/     code GDScript : autoload/ (systèmes globaux), core/ (machine à états, unités),
             player/ (Élias : états, visuel, réglages), world/ (salles, caméra, niveau),
             audio/, input/, ui/, fx/
assets/      sons générés, polices, textures
resources/   réglages de gameplay (fichiers .tres modifiables sans toucher au code)
tests/       lanceur de tests maison et tests automatisés
tools/       générateur de sons (Python), export, captures d'écran, vérification Web
docs/        PLAN.md (feuille de route), JOURNAL.md (avancement), SOUND_DESIGN.md
```

### Publication automatique

- Chaque **Pull Request** lance les tests.
- Chaque **push sur `main`** publie la version Web sur GitHub Pages.
- Chaque **tag de version** (`v0.1`, `v0.2`…) produit une Release avec les exécutables
  Windows et Linux. On peut aussi lancer le workflow à la main depuis l'onglet
  *Actions → Build → Run workflow* (branche `main`) en indiquant le tag voulu dans
  `release_tag` : la CI crée alors le tag elle-même.

Le détail est dans [`.github/workflows/build.yml`](.github/workflows/build.yml).

---

## Documentation

| Document | Contenu |
|---|---|
| [`docs/PLAN.md`](docs/PLAN.md) | Architecture, écrans, systèmes de jeu, plan audio, jalons, risques |
| [`docs/JOURNAL.md`](docs/JOURNAL.md) | Ce qui a été fait à chaque jalon, comment le tester, concepts Godot expliqués |
| [`docs/SOUND_DESIGN.md`](docs/SOUND_DESIGN.md) | Liste des sons, rôle, déclencheur, remplacement par des sons définitifs |
| [`tools/audio/README.md`](tools/audio/README.md) | Mode d'emploi du générateur de sons |
| [`CREDITS.md`](CREDITS.md) | Origine de chaque élément (tout est original ou libre de droits) |
| [`CLAUDE.md`](CLAUDE.md) | Conventions et commandes, pour les sessions de développement assistées |
