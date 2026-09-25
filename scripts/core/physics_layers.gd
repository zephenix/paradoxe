class_name PhysicsLayers
extends RefCounted
## Couches de collision du projet.
##
## Godot range chaque objet physique sur une ou plusieurs « couches » (layer)
## et lui dit quelles couches il doit « voir » (mask). Les valeurs ci-dessous
## sont des masques de bits : couche 1 = 1, couche 2 = 2, couche 3 = 4…
## Les mêmes noms sont déclarés dans project.godot (section [layer_names]) :
## l'éditeur les affiche dans l'inspecteur (Paramètres du projet > Noms de
## couches > Physique 2D). Garder les deux listes identiques.

const WORLD: int = 1        # décor solide (sols, murs, plafonds)
const PLAYER: int = 2       # Élias
const ENEMIES: int = 4      # créatures (J3)
const COMPANION: int = 8    # compagnon (J7)
const PROJECTILES: int = 16 # tirs (J3)
const TRIGGERS: int = 32    # zones de déclenchement (salles, checkpoints…)
const SHIELDS: int = 64     # boucliers d'énergie (J3) : arrêtent les tirs
