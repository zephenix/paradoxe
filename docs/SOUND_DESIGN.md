# PARADOXE — Conception sonore

> Document vivant. La philosophie et le plan sont décrits dans `docs/PLAN.md` §6. Ici :
> **comment c'est construit**, **la liste des sons** (rôle, déclencheur, rayon de bruit)
> et **comment les remplacer** par des sons définitifs.
>
> État : **J1**. La chaîne technique est en place (bus, effets, gestionnaire, Web) avec 3
> sons de test. La bibliothèque complète arrive en J5.

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
| `set_reverb(wet, taille, amortissement)` | Réverbération de salle (préréglages de zone en J5) | J1 ✔ |
| `emit_noise(position, rayon, source)` | Signale un bruit aux ennemis | J1 ✔ (utilisé en J6) |
| `play_stream_2d(son, position, bus, volume_db, hauteur, rayon, source)` | Son **positionné** dans le monde ; si `rayon` > 0, les ennemis l'entendent (signal `noise_emitted`) | J3 ✔ |
| `play_sfx(id, position, source)` | Son de la bibliothèque : variations aléatoires, position, rayon de bruit | J5 |
| `set_zone(zone)` | Ambiance et acoustique d'une zone, en fondu | J5 |
| `set_tension(0..1)`, `play_stinger(id)` | Musique adaptative | J8 |
| `set_rewind_effect(actif)` | Effet complet de rembobinage (étouffement, aspiration, sons inversés) | J4/J5 |

### Particularités du Web

- Les navigateurs **interdisent le son avant une interaction**. L'écran titre attend un
  clic ou une touche, puis appelle `AudioManager.unlock()`. Aucune ambiance ne démarre avant.
- Sur le Web, Godot utilise par défaut le mode de lecture « Sample », **sans effets de
  bus**. Le projet force le mode « **Stream** » (`audio/general/default_playback_type.web=0`),
  si bien que réverbération, filtres et silences fonctionnent comme sur ordinateur.
- L'export Web est multithread : latence audio mesurée d'environ 90 ms dans Chromium.
  En monothread, elle serait nettement plus élevée.

---

## 4. Catalogue des sons

Colonnes : **rayon** = distance (pixels) à laquelle les ennemis entendent le son
(— = inaudible pour eux) ; **boucle** = le son se répète sans couture.

### Sons de test (J1)

| Fichier | Rôle | Déclencheur | Bus | Rayon | Boucle |
|---|---|---|---|---|---|
| `ui/ui_confirm.wav` | Validation de menu : deux notes brèves (quinte montante) | Premier clic sur l'écran titre | UI | — | non |
| `sfx/test_impact.wav` | Choc métallique : attaque sèche + résonances. Sert à entendre la réverbération | Bouton « Choc métallique » du banc de test | SFX | — | non |
| `ambience/portal_hum_loop.wav` | Bourdonnement du portail : drone grave (La 55 Hz), battements lents, crépitements | Démarre au premier clic ; interrupteur du banc de test | Ambiance | — | oui (8 s) |

### Foley provisoire du déplacement (J2)

Ces sons sont déclenchés par des **évènements** d'Élias, de deux sources :
- les **animations**, pour ce qui doit tomber à l'image près : le pied qui touche le sol,
  le corps qui s'effondre ;
- les **états**, pour les actions : saut, réception, roulade, glissade, prise, hissage.

Le script `scripts/player/player_foley.gd` fait la correspondance entre évènement et son.
Un évènement sans son déclenche un avertissement, sauf s'il est déclaré volontairement
muet : c'est le cas de `death_<cause>` (le cri et la musique de mort viendront plus
tard). Un test vérifie la correspondance dans les deux sens. Chaque lecture passe par un `AudioStreamRandomizer`,
qui tire une variante au hasard et fait varier hauteur et volume. **Provisoires** : J5 les
remplacera par des sons selon la surface, avec respiration et rayons de bruit.

| Fichier (`foley/`) | Rôle | Déclencheur (évènement d'animation) | Bus | Rayon |
|---|---|---|---|---|
| `foley_step_stone_01` à `04` | Pas sur pierre (4 variantes) | `footstep` (marche, -12 dB), `footstep_run` (course, -6 dB), `footstep_soft` (accroupi, -24 dB), `climb_knee` | SFX | — (J6) |
| `foley_jump` | Frottement de tissu à l'impulsion | Décollage d'un saut | SFX | — |
| `foley_land` | Double impact des pieds | Réception légère | SFX | — |
| `foley_land_heavy` | Impact grave + souffle | Réception lourde (2 à 3 blocs) | SFX | — |
| `foley_roll` | Tissu et épaule au sol | Roulade (esquive ou réception) | SFX | — |
| `foley_slide` | Raclement qui s'éteint | Glissade | SFX | — |
| `foley_skid` | Semelles qui frottent | Dérapage en fin de course | SFX | — |
| `foley_grab` | Mains qui agrippent | Prise d'un rebord | SFX | — |
| `foley_climb` | Effort, tissu | Se hisser | SFX | — |
| `foley_body_fall` | Corps qui s'effondre | Mort (à la fin de l'animation) | SFX | — |

### Combat provisoire (J3)

Tous les sons du combat passent par `AudioManager.play_stream_2d` : ils sont
**positionnés** (plus faibles et décalés à gauche ou à droite selon leur place par
rapport à la caméra). Un **tir** porte un **rayon de bruit** : les Sentinelles qui se
trouvent dans ce rayon l'entendent et viennent voir (J6 ajoutera l'atténuation par les
murs). Les chemins sont regroupés dans `scripts/combat/combat_sounds.gd`. L'arme, le
bouclier et les impacts sont les **mêmes** pour Élias et les Sentinelles (PLAN §5.2),
sauf le tir normal, plus grave et bourdonnant chez les Sentinelles.

| Fichier | Rôle | Déclencheur | Bus | Rayon |
|---|---|---|---|---|
| `combat/weapon_shot` | Tir d'Élias : décharge brève dont la fréquence plonge (« piou ») | Chaque tir normal | SFX | 700 px (`pistol.tres`) |
| `combat/weapon_shot_sentinel` | Tir des Sentinelles : plus grave, grain « organique » (vibrato rapide) | Tir d'une Sentinelle | SFX | 650 px (`sentinel_gun.tres`) |
| `combat/weapon_shot_charged` | Tir chargé : décharge lourde et crépitante | Relâcher la détente, charge complète | SFX | 900 px |
| `combat/weapon_charge` | Tension qui monte pendant 0,8 s | Début de la charge (s'arrête si on relâche) | SFX | — |
| `combat/weapon_charge_ready` | Tintement bref | Charge complète | SFX | — |
| `combat/weapon_empty` | Double clic sec | Tir ou bouclier sans assez d'énergie | SFX | — |
| `combat/weapon_draw` | Tissu + déclic | Dégainer | SFX | — |
| `combat/shield_up` / `shield_down` | Montée / descente brève | Lever / baisser le bouclier | SFX | — |
| `combat/shield_loop` | Grésillement continu (boucle de 2 s) | Tant que le bouclier est levé | SFX | — |
| `combat/shield_hit` | Claquement électrique + résonance | Tir arrêté par un bouclier | SFX | — |
| `combat/shield_break` | Éclatement, chute de fréquence | Bouclier brisé par un tir chargé | SFX | — |
| `combat/impact_wall` | Choc + grésillement | Tir qui frappe le décor | SFX | — |
| `combat/impact_body` | Coup sourd | Tir qui touche un corps | SFX | — |
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

*Les ambiances de zones et la musique seront ajoutées en J5 et J8 (voir PLAN §6.4 à
§6.8).*

---

## 5. Remplacer un son par un son définitif

1. **Même nom, même dossier** : il suffit d'écraser le fichier WAV dans
   `assets/audio/generated/…` (ou de le placer dans `assets/audio/final/…` et de modifier
   le chemin dans la bibliothèque de sons, à partir de J5). Godot le réimporte
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
   plus loin (réglage dans la bibliothèque de sons, J5).
6. Noter la source et la licence dans `CREDITS.md`.

---

## 6. Écouter et régler

- **J1** : l'écran titre contient un banc de test (choc, bourdonnement, réverbération,
  étouffement, silence, volume). Chaque bouton explique ce qu'il fait dans
  `docs/JOURNAL.md`, section J1.
- **J5** : le « sound board » (menu principal) permettra d'écouter **tous** les sons, avec
  leurs variations, dans chaque acoustique de zone, et d'en régler les paramètres.
