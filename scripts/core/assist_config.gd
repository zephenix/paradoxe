class_name AssistConfig
extends Resource
## Réglages des ASSISTANCES (J9, PLAN §5.11) : les valeurs de jeu qu'une aide
## modifie. Le joueur choisit dans le menu d'options QUELLES aides il active
## (Settings) ; ce fichier dit DE COMBIEN elles aident (resources/settings/assists.tres).

## Vitesse du jeu avec l'aide « jeu ralenti » (1 = normale).
@export_range(0.5, 1.0, 0.05) var slow_speed: float = 0.8
## Avec l'aide « rebords tolérants » : la zone où les mains attrapent un rebord
## est multipliée par ce facteur (en hauteur et en portée).
@export_range(1.0, 3.0, 0.1) var ledge_factor: float = 2.0
## Avec « moins de flashs » : les éclairs et éclats lumineux sont multipliés par
## ce facteur (0 = supprimés).
@export_range(0.0, 1.0, 0.05) var flash_factor: float = 0.3
## Avec « moins de secousses » : les tremblements de l'image sont multipliés par ce facteur.
@export_range(0.0, 1.0, 0.05) var shake_factor: float = 0.0
