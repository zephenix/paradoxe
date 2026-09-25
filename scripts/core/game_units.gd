class_name GameUnits
extends RefCounted
## Unités de mesure du monde, partagées par tout le projet.
##
## Le BLOC est la grille du décor : les salles, les obstacles et les réglages de
## déplacement (sauts, chutes) sont tous exprimés en blocs. Il n'est défini
## qu'ici, pour que le décor et le personnage parlent toujours la même unité.

## Taille d'un bloc, en pixels. Élias mesure 2 blocs.
const BLOCK: float = 48.0
