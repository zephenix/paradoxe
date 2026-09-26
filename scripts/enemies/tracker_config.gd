class_name TrackerConfig
extends Resource
## Réglages du Traqueur, le prédateur de l'écran 2 (fichier resources/enemies/tracker.tres).
## Distances en pixels (1 bloc = 48 px), durées en secondes.

@export_group("Poursuite")
## Vitesse de course. Élias court à 285 px/s et marche à 125. Le Traqueur est un
## peu plus rapide qu'Élias qui court : il ne le rattrape pas grâce à son avance,
## et arrive au pied du mur juste après qu'Élias l'a escaladé. Qui hésite est pris.
@export var run_speed: float = 310.0
## Accélération (pixels par seconde²).
@export var acceleration: float = 700.0
## Durée de l'apparition (il surgit de la jungle en rugissant) avant la course.
@export var emerge_time: float = 1.0
## Distance entre son museau et Élias à laquelle il l'attrape.
@export var catch_distance: float = 20.0
## Hauteur au-dessus de laquelle Élias est hors d'atteinte (il ne grimpe pas) (blocs).
@export var reach_height_blocks: float = 1.6

@export_group("Obstacles")
## Il franchit d'un bond les marches et les trous jusqu'à cette hauteur (blocs).
@export var hop_height_blocks: float = 1.4
## Gravité et chute maximale.
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0

@export_group("Son")
## Intervalle entre deux pas pendant la course.
@export var step_interval: float = 0.28
