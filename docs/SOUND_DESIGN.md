# PARADOXE — Conception sonore

> Document vivant. La philosophie et le plan sont décrits dans `docs/PLAN.md` §6. Ici :
> **comment c'est construit**, **la liste des sons** (rôle, déclencheur, rayon de bruit)
> et **comment les remplacer** par des sons définitifs.
>
> État : **J5**. Tous les sons du jeu passent par une **bibliothèque** (identifiants,
> volumes, variations, rayons de bruit). Élias a des pas selon le sol et une respiration ;
> chaque salle a son ambiance et son acoustique ; un **banc d'écoute** permet de tout
> entendre et régler, y compris sur le Web. La musique arrive en J8.

---

## 1. Principes

- **Le silence et l'ambiance d'abord.** La musique est rare, déclenchée par des événements.
- **Un seul système** pour ce que le joueur entend et ce que les ennemis entendent : un son
  joué avec un *rayon de bruit* émet le signal `AudioManager.noise_emitted`.
- **Tout est remplaçable** : un son procédural n'est qu'un fichier WAV rangé au bon endroit,
  qu'on peut échanger contre un enregistrement définitif sans toucher au code.

---

## 2. Table de mixage (bus audio)

```
    SFX ──┐
    Voix ─┼──► Monde ───┐
 Ambiance ┘             ├──► Master ──► haut-parleurs
          Musique ──────┤
          UI ───────────┘
```

| Bus | Reçoit | Effets (dans l'ordre) | Réglable par le joueur |
|---|---|---|---|
| **Master** | tout | 0 `Etouffement` (passe-bas, coupé au repos) · 1 `GainDramatique` (amplification, 0 dB au repos) · 2 `Limiteur` (plafond -0,5 dB) | oui (« Général ») |
| **Musique** | thèmes, couches de tension | — | oui |
| **UI** | sons de menus | — | oui (« Interface ») |
| **Monde** | SFX + Voix + Ambiance | 0 `ReverbSalle` (réverbération, coupée au repos) · 1 `FiltreSalle` (passe-bas, coupé au repos) | non (interne) |
| **Ambiance** | couches d'ambiance, événements aléatoires | — | oui |
| **SFX** | bruitages (Foley, arme, objets) | — | oui (« Effets sonores ») |
| **Voix** | créatures, compagnon, respiration | — | oui |

**Pourquoi un bus « Monde » ?** Il regroupe les sons qui existent *dans* le monde du jeu :
c'est lui qui reçoit l'acoustique de la salle (écho du hall, étouffement de la jungle). La
musique et l'interface n'ont pas à résonner dans une grotte.

**Pourquoi un « gain dramatique » séparé du volume ?** Le volume du Master appartient au
joueur (options). Les silences de mise en scène passent donc par un effet distinct, et ne
modifient jamais le réglage du joueur.

La description de référence est dans `scripts/audio/audio_buses.gd`. Le fichier
`default_bus_layout.tres` en est **généré** :

```bash
godot --headless --path . -s res://tools/godot/generate_bus_layout.gd
```

On peut ensuite ajuster les réglages fins (taille de pièce, amortissement…) dans l'onglet
**Audio** de l'éditeur. Relancer le générateur fait revenir aux valeurs du script.

---

## 3. Le gestionnaire audio (`AudioManager`)

| Fonction | Rôle | Jalon |
|---|---|---|
| `unlock()` | Débloque le son au premier clic ou à la première touche (obligatoire sur le Web) | J1 ✔ |
| `play_stream(son, bus, volume_db, hauteur)` | Joue un son court, non positionné | J1 ✔ |
| `play_loop(id, son, bus, volume_db, fondu)` / `stop_loop(id, fondu)` | Boucles nommées (ambiances), avec fondus | J1 ✔ |
| `set_muffle(0..1, durée)` | Étouffement global (rembobinage, choc) | J1 ✔ |
| `cut_to_silence(maintien, retour)` / `restore_from_silence()` | Coupure dramatique | J1 ✔ |
| `set_reverb(wet, taille, amortissement)` / `set_world_lowpass(Hz)` | Réverbération et filtre de la salle (réglés par les zones) | J1 ✔ / J5 ✔ |
| `emit_noise(position, rayon, source)` | Signale un bruit aux ennemis | J1 ✔ (utilisé en J6) |
| `play_stream_2d(son, position, bus, volume_db, hauteur, rayon, source)` | Son **positionné** dans le monde ; si `rayon` > 0, les ennemis l'entendent (signal `noise_emitted`) | J3 ✔ |
| `play_sfx(id, position, source, volume, part_du_rayon)` | Son de la **bibliothèque** : variante au hasard, variations, position, rayon de bruit. **À utiliser pour tout son du jeu.** Émet `sfx_played(id)` | J5 ✔ |
| `play_loop_sfx(id_boucle, id_son, fondu)` | Boucle nommée, jouée depuis la bibliothèque | J5 ✔ |
| `set_zone(zone, fondu)` | Ambiance et acoustique d'une zone, en fondu enchaîné (`&""` = silence) | J5 ✔ |
| `save_tuning()` / `load_tuning()` / `reset_tuning(id)` / `tuning_report()` | Réglages faits au banc d'écoute (`user://sound_tuning.json`) | J5 ✔ |
| `set_tension(0..1)`, `play_stinger(id)` | Musique adaptative | J8 |
| `set_rewind_effect(actif)` | Effet complet de rembobinage | J4 : fait par `RewindManager` (étouffement + boucle) |

### Particularités du Web

- Les navigateurs **interdisent le son avant une interaction**. L'écran titre attend un
  clic ou une touche, puis appelle `AudioManager.unlock()`. Aucune ambiance ne démarre avant.
- Sur le Web, Godot utilise par défaut le mode de lecture « Sample », **sans effets de
  bus**. Le projet force le mode « **Stream** » (`audio/general/default_playback_type.web=0`),
  si bien que réverbération, filtres et silences fonctionnent comme sur ordinateur.
- L'export Web est multithread : latence audio mesurée d'environ 90 ms dans Chromium.
  En monothread, elle serait nettement plus élevée.

---

## 4. La bibliothèque de sons (J5)

Le code ne manipule jamais un fichier : il demande un **identifiant**.

```gdscript
AudioManager.play_sfx(&"foley_land", global_position, self)   # son positionné, bruit pour les ennemis
AudioManager.play_sfx(&"ui_confirm")                           # son d'interface, non positionné
```

La bibliothèque est une ressource, `resources/audio/sound_library.tres` (classe
`SoundLibrary`), faite d'entrées (`SoundEntry`) : identifiant, catégorie, **variantes**
(plusieurs fichiers, une tirée au hasard), bus, volume, variation de hauteur, variation de
volume, **rayon de bruit** et description. On la règle dans l'inspecteur de Godot, ou au
banc d'écoute.

*Analogie Excel : un tableau dont chaque ligne est un son ; `play_sfx` fait une RECHERCHEV
sur l'identifiant, puis lit les colonnes « volume », « rayon »…*

### Ajouter ou régénérer des sons

```bash
python3 tools/audio/generate_sounds.py                                   # 1) fichiers WAV + catalog.json
godot --headless --path . --import                                        # 2) import par Godot
godot --headless --path . -s res://tools/godot/build_sound_library.gd    # 3) bibliothèque
```

L'outil de l'étape 3 regroupe les variantes (`foley_step_metal_01` à `_04` deviennent
l'entrée `foley_step_metal`) et **ajoute** les nouveaux sons ; une entrée existante garde
ses réglages (seule sa liste de fichiers est mise à jour). Les réglages de départ d'un
nouveau son viennent des tables `CATEGORY_DEFAULTS` et `OVERRIDES` de l'outil.

Un test vérifie que chaque identifiant cité dans le code (`play_sfx(&"…")`) existe dans
la bibliothèque.

---

## 5. Catalogue des sons

Colonnes : **rayon** = distance (pixels) à laquelle les ennemis entendent le son
(— = inaudible pour eux) ; **boucle** = le son se répète sans couture.

### Sons de test (J1)

| Fichier | Rôle | Déclencheur | Bus | Rayon | Boucle |
|---|---|---|---|---|---|
| `ui/ui_confirm.wav` | Validation de menu : deux notes brèves (quinte montante) | Premier clic sur l'écran titre | UI | — | non |
| `sfx/test_impact.wav` | Choc métallique : attaque sèche + résonances. Sert à entendre la réverbération | Bouton « Choc métallique » du banc de test | SFX | — | non |
| `ambience/portal_hum_loop.wav` | Bourdonnement du portail : drone grave (La 55 Hz), battements lents, crépitements | Démarre au premier clic ; interrupteur du banc de test | Ambiance | — | oui (8 s) |

### Foley d'Élias (J2, refait en J5)

Ces sons sont déclenchés par des **évènements** d'Élias, de deux sources :
- les **animations**, pour ce qui doit tomber à l'image près : le pied qui touche le sol,
  le corps qui s'effondre ;
- les **états**, pour les actions : saut, réception, roulade, demi-tour, s'accroupir…

Le script `scripts/player/player_foley.gd` fait la correspondance entre évènement et son
(table `EVENTS`). Un évènement sans son déclenche un avertissement, sauf s'il est déclaré
volontairement muet (`death_<cause>`). Un test vérifie la correspondance dans les deux
sens, et un autre qu'**une action du joueur a toujours un son**.

**Pas selon le sol.** À chaque pas, un rayon part sous les pieds d'Élias et trouve le bloc
foulé ; sa propriété `surface` (`SolidBlock.surface`) choisit le son :
`foley_step_stone`, `foley_step_metal`, `foley_step_plant` ou `foley_step_water`.

**Allure.** Le volume et la portée d'un pas dépendent de l'allure (réglages dans
`resources/audio/foley.tres`) :

| Allure | Évènement | Volume | Rayon de bruit |
|---|---|---|---|
| Course | `footstep_run` | celui de la bibliothèque | 100 % |
| Marche | `footstep` | -6 dB | 60 % |
| Accroupi | `footstep_soft` | -18 dB | 0 : les ennemis ne l'entendent pas |
| Genou (se hisser) | `climb_knee` | -8 dB | 30 % |

**Respiration.** Un « effort » (de 0 à 1) monte en courant et à chaque geste fatigant
(saut, hissage, roulade, réception lourde), et redescend au repos. Trois paliers :
`breath_calm` (toutes les 4,5 s, à peine audible), `breath_effort` (au-dessus de 0,35) et
`breath_exhausted` (au-dessus de 0,7, toutes les 1,2 s). Environ 10 s de course essoufflent
Élias.

| Son | Rôle | Déclencheur | Bus | Rayon |
|---|---|---|---|---|
| `foley_step_stone` (4 variantes) | Pas sur pierre | Pas sur un bloc « stone » (défaut) | SFX | 300 px |
| `foley_step_metal` (4) | Pas sur métal | Pas sur « metal » (puits de la salle de test) | SFX | 420 px |
| `foley_step_plant` (4) | Pas sur végétation | Pas sur « plant » (salle C) | SFX | 240 px |
| `foley_step_water` (4) | Pas sur eau | Pas sur « water » | SFX | 360 px |
| `foley_jump` | Frottement de tissu à l'impulsion | Décollage d'un saut | SFX | 120 px |
| `foley_land` | Double impact des pieds | Réception légère | SFX | 300 px |
| `foley_land_heavy` | Impact grave + souffle | Réception lourde (2 à 3 blocs) | SFX | 450 px |
| `foley_roll` | Tissu et épaule au sol | Roulade | SFX | 200 px |
| `foley_slide` | Raclement qui s'éteint | Glissade | SFX | 280 px |
| `foley_skid` | Semelles qui frottent | Dérapage en fin de course | SFX | 220 px |
| `foley_grab` | Mains qui agrippent | Prise d'un rebord | SFX | 120 px |
| `foley_climb` | Effort, tissu | Se hisser | SFX | 100 px |
| `foley_turn` | Bref froissement de la blouse | Demi-tour | SFX | — |
| `foley_crouch` | Tissu et genou qui se plie | S'accroupir | SFX | — |
| `foley_body_fall` | Corps qui s'effondre | Mort (Élias et Sentinelles) | SFX | 400 px |
| `breath_calm` / `breath_effort` / `breath_exhausted` (2 chacun) | Respiration | Selon l'effort (voir plus haut) | Voix | — |

### Combat provisoire (J3)

Tous les sons du combat sont **positionnés** (plus faibles et décalés à gauche ou à
droite selon leur place par rapport à la caméra). Un **tir** ou un **impact** porte un
**rayon de bruit** : les Sentinelles qui se trouvent dans ce rayon l'entendent et viennent
voir (J6 ajoutera l'atténuation par les murs). Depuis J5, ils passent tous par la
bibliothèque ; l'arme d'un combattant désigne son tir par `WeaponConfig.shot_sound_id`. L'arme, le
bouclier et les impacts sont les **mêmes** pour Élias et les Sentinelles (PLAN §5.2),
sauf le tir normal, plus grave et bourdonnant chez les Sentinelles.

| Fichier | Rôle | Déclencheur | Bus | Rayon |
|---|---|---|---|---|
| `combat/weapon_shot` | Tir d'Élias : décharge brève dont la fréquence plonge (« piou ») | Chaque tir normal | SFX | 700 px |
| `combat/weapon_shot_sentinel` | Tir des Sentinelles : plus grave, grain « organique » (vibrato rapide) | Tir d'une Sentinelle | SFX | 650 px |
| `combat/weapon_shot_charged` | Tir chargé : décharge lourde et crépitante | Relâcher la détente, charge complète | SFX | 900 px |
| `combat/weapon_charge` | Tension qui monte pendant 0,8 s | Début de la charge (s'arrête si on relâche) | SFX | — |
| `combat/weapon_charge_ready` | Tintement bref | Charge complète | SFX | — |
| `combat/weapon_empty` | Double clic sec | Tir ou bouclier sans assez d'énergie | SFX | 80 px |
| `combat/weapon_draw` | Tissu + déclic | Dégainer | SFX | — |
| `combat/weapon_holster` | Déclic puis frottement | Rengainer (quitter la visée) | SFX | — |
| `combat/shield_up` / `shield_down` | Montée / descente brève | Lever / baisser le bouclier | SFX | — |
| `combat/shield_loop` | Grésillement continu (boucle de 2 s) | Tant que le bouclier est levé | SFX | — |
| `combat/shield_hit` | Claquement électrique + résonance | Tir arrêté par un bouclier | SFX | 250 px |
| `combat/shield_break` | Éclatement, chute de fréquence | Bouclier brisé par un tir chargé | SFX | 500 px |
| `combat/impact_wall` | Choc + grésillement | Tir qui frappe le décor | SFX | 250 px |
| `combat/impact_body` | Coup sourd | Tir qui touche un corps | SFX | 150 px |
| `sfx/checkpoint_on` | Trois notes douces qui montent (do, mi, sol) | Nouveau checkpoint atteint | SFX | — |

### Voix des Sentinelles (J3)

Aucune langue réelle : une « glotte » (dent de scie dont la hauteur varie) passe dans
trois résonateurs placés sur les formants d'une voyelle. **L'intonation porte l'émotion**
(PLAN §6.6). Chaque Sentinelle a sa propre hauteur de voix (±10 %).

| Fichier (`creature/`) | Intonation | Déclencheur | Bus |
|---|---|---|---|
| `creature_curious` | Montante, deux syllabes | Alerte : un bruit l'intrigue | Voix |
| `creature_search` | Grave, interrogative | Elle part chercher | Voix |
| `creature_alert` | Aiguë, hachée | Elle voit Élias (combat) | Voix |
| `creature_death` | Cri qui retombe | Touchée | Voix |
| `creature_calm` | Descendante | Retour au calme : la recherche n'a rien donné | Voix |

Leurs pas reprennent un son de pas d'Élias, plus grave et plus discret.

### Rembobinage (J4)

Pendant le défilement arrière, tout le son passe dans le filtre passe-bas du Master
(étouffement à 75 %, en 0,25 s), et une boucle joue par-dessus. Au relâchement, le filtre
s'ouvre en 0,2 s et un « relâchement » marque la reprise. C'est `RewindManager` qui pilote
ces effets.

| Fichier (`sfx/`) | Rôle | Déclencheur | Bus |
|---|---|---|---|
| `rewind_loop` | Souffles joués à l'envers (des « aspirations ») et sifflement de bande qui ondule (boucle de 2 s) | Tant que « Rembobiner » est maintenu | UI |
| `rewind_release` | Souffle vers l'avant, fréquence qui plonge, coup sourd | Reprise après un rembobinage | UI |

### Ambiances et acoustique par zone (J5)

Chaque salle (`Room`) appartient à une **zone acoustique** (`acoustic_zone`). En entrant
dans une salle, le niveau appelle `AudioManager.set_zone(zone)` : l'ambiance passe en
**fondu enchaîné** (2,5 s) à celle de la zone, et l'acoustique (réverbération et filtre du
bus Monde) glisse vers ses réglages. Une couche commune à deux zones (le vent) continue sans
coupure. En quittant le niveau, tout s'éteint.

Une zone (`resources/audio/zones/<id>.tres`, classe `AcousticZone`) contient :
- des **couches** : boucles longues (11 à 17 s, pour que la répétition ne s'entende pas),
  qui « respirent » (houle lente de quelques dB) ;
- des **évènements ponctuels** : petits sons tirés au hasard, à gauche ou à droite de
  l'écran, toutes les quelques secondes. Ils n'alertent **pas** les ennemis ;
- l'**acoustique** : écho, taille de la pièce, amortissement, filtre.

| Zone | Salles de test | Couches | Évènements | Acoustique |
|---|---|---|---|---|
| `lab` (Laboratoire) | A, B | `amb_lab_loop` (ventilation), `amb_electric_loop` (grésillement, -6 dB) | `amb_buzz`, `amb_drip` | petite pièce, écho 7 % |
| `ruins` (Ruines) | C, F | `amb_wind_loop` (vent), `amb_city_loop` (ville lointaine, -3 dB) | `amb_debris`, `amb_creak`, `amb_cry` | plein air, écho 4 % |
| `shaft` (Puits) | D | `amb_shaft_loop` (grondement), `amb_wind_loop` (-10 dB) | `amb_drip`, `amb_creak`, `amb_debris` | grande cavité sombre, écho 20 %, filtre 9 kHz |
| `hall` (Grand hall) | E | `amb_hall_loop` (présence, machinerie), `amb_electric_loop` (-12 dB) | `amb_creak`, `amb_cry`, `amb_buzz` | immense, écho 24 % |

| Son (`ambience/`) | Rôle |
|---|---|
| `amb_wind_loop` (17 s) | Vent : souffle grave qui enfle et retombe |
| `amb_city_loop` (13 s) | Ville morte au loin : rumeur sourde, tintements métalliques rares |
| `amb_lab_loop` (13 s) | Laboratoire : ventilation et bourdonnement électrique à 50 Hz |
| `amb_electric_loop` (11 s) | Grésillement électrique irrégulier |
| `amb_shaft_loop` (13 s) | Puits : grondement très grave, air qui circule |
| `amb_hall_loop` (17 s) | Grand hall : présence de la pièce, machinerie lointaine |
| `amb_drip` (3 variantes) | Goutte d'eau qui tombe |
| `amb_creak` (2) | Craquement de structure |
| `amb_debris` (2) | Petits gravats qui roulent |
| `amb_buzz` (2) | Grésillement de lampe |
| `amb_cry` (2) | Cri de faune lointain |

### Interface (J5)

| Son (`ui/`) | Rôle | Bus |
|---|---|---|
| `ui_confirm` | Valider | UI |
| `ui_move` | Tic bref : déplacer la sélection (menus de J9) | UI |
| `ui_back` | Deux notes descendantes : revenir en arrière | UI |

*La musique sera ajoutée en J8 (voir PLAN §6.7 et §6.8).*

---

## 6. Remplacer un son par un son définitif

1. **Même nom, même dossier** : il suffit d'écraser le fichier WAV dans
   `assets/audio/generated/…` (ou le placer dans `assets/audio/final/…` et changer le
   fichier de l'entrée dans `resources/audio/sound_library.tres`). Godot le réimporte
   automatiquement.
2. **Format conseillé** : WAV 44,1 kHz ou 48 kHz, 16 ou 24 bits. Mono pour les bruitages
   positionnés, stéréo possible pour les ambiances et la musique. Godot compresse en QOA à
   l'import (réglage par défaut du projet).
3. **Niveau** : crête vers -1 dBFS pour les sons courts ; ambiances plus basses (le mixage
   se règle ensuite par les volumes de la bibliothèque et des bus).
4. **Boucles** : soit inscrire des points de boucle dans le WAV (la plupart des éditeurs
   audio le font, bloc « smpl »), soit régler **Loop Mode = Forward** dans l'onglet *Import*
   de Godot. Soigner le raccord : fondu enchaîné, pas de clic.
5. **Garder le rayon de bruit** cohérent avec le nouveau son : un pas plus fort doit porter
   plus loin (réglage dans la bibliothèque de sons, ou au banc d'écoute).
6. Noter la source et la licence dans `CREDITS.md`.

---

## 7. Écouter et régler

### Mesurer l'équilibre (v0.5.1)

```bash
python3 tools/audio/measure_levels.py          # vérifie les familles de sons
python3 tools/audio/measure_levels.py --all    # et affiche les autres sons
```

L'outil mesure le **niveau effectif** de chaque son (niveau du fichier + volume de la
bibliothèque) et le compare à la cible de sa **famille** : tous les pas au même niveau,
tous les tirs, toutes les voix de Sentinelles… (table `FAMILIES` en tête du script). Il
signale aussi une crête au-dessus de 0 dB. La CI le lance à chaque Pull Request : un son
ajouté ou réglé trop fort ou trop faible fait échouer la vérification.

| Famille | Cible (dB) | Tolérance |
|---|---|---|
| Tirs | -21 | ± 1,5 |
| Voix des Sentinelles | -21 | ± 1,5 |
| Réceptions et chutes | -21,5 | ± 1,5 |
| Pas (course) | -22 | ± 2 |
| Impacts | -24 | ± 1,5 |
| Gestes (saut, roulade, prise…) | -27,5 | ± 2 |
| Bouclier levé / baissé | -28 | ± 2 |
| Signaux de l'arme | -31,5 | ± 2 |
| Couches d'ambiance | -32 | ± 2,5 |
| Évènements d'ambiance | -32,5 | ± 2 |
| Petits gestes (demi-tour, accroupi, dégainer, rengainer) | -35 | ± 2,5 |
| Interface | -20 | ± 1,5 |

Un niveau égal n'est pas une sonie parfaitement égale (l'oreille entend mieux les
médiums) : c'est un premier réglage objectif, que l'oreille affine au banc d'écoute.

L'**écho** des zones est plafonné à 30 % par un test (`test_ambience.gd`) : les ambiances
contiennent déjà leur propre espace, et la réverbération du bus Monde s'y ajoute.

### Au banc d'écoute

- **Banc d'écoute** (J5) : bouton « Banc d'écoute » de l'écran titre. Il fonctionne aussi
  sur le Web.
  - À gauche : les sons par catégorie. Un double-clic ou Entrée joue le son.
  - Au centre : le son choisi. « Jouer » tire une variante au hasard, avec ses variations ;
    « Rafale x5 » en joue cinq de suite pour juger de la variété ; « Boucle » pour les
    ambiances. Les curseurs (bus, volume, variations, rayon de bruit) règlent le son **en
    direct**.
  - À droite : les ambiances de zone (avec « Évènement ponctuel »), l'effet de rembobinage,
    le silence dramatique et le volume général.
  - « **Enregistrer** » garde les réglages sur cet appareil (`user://sound_tuning.json`) :
    ils s'appliquent aussi en jeu. « **Copier les valeurs** » met le texte des sons
    modifiés dans le presse-papiers : il suffit de le coller dans la conversation pour que
    Claude les reporte dans la bibliothèque. « Rétablir ce son » revient à l'origine.
- **Banc de test des bus** (J1) : sur l'écran titre (choc, bourdonnement, réverbération,
  étouffement, silence, volume).
