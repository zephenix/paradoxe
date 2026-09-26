class_name PursuerConfig
extends Resource
## Réglages d'un poursuivant (J8) : le Traqueur de l'écran 2
## (resources/enemies/tracker.tres) ou les Sentinelles qui poursuivent Élias à
## l'écran 8 (resources/enemies/sentinel_pursuer.tres).
## Distances en pixels (1 bloc = 48 px), durées en secondes.

@export_group("Apparence et sons")
## &"tracker" (le prédateur) ou &"sentinel" (une créature humanoïde).
@export var skin: StringName = &"tracker"
## Taille de la boîte de collision (largeur, hauteur).
@export var body_size: Vector2 = Vector2(195.0, 110.0)
## Agrandissement du dessin.
@export var visual_scale: float = 1.3
## Animation jouée en surgissant, et cri (identifiant de la bibliothèque de sons).
@export var emerge_animation: StringName = &"roar"
@export var cry_sound: StringName = &"creature_tracker_roar"
## Bruit de pas pendant la course, et intervalle entre deux pas.
@export var step_sound: StringName = &"creature_tracker_step"
@export var step_interval: float = 0.28
## Musique lancée quand la poursuite commence (&"" : aucune ; les Sentinelles de
## l'écran 8 lancent le thème de poursuite).
@export var chase_theme: StringName = &""

@export_group("Poursuite")
## Vitesse de course. Élias court à 285 px/s et marche à 125. Le Traqueur est un
## peu plus rapide qu'Élias qui court : il ne le rattrape pas grâce à son avance,
## et arrive au pied du mur juste après qu'Élias l'a escaladé. Qui hésite est pris.
@export var run_speed: float = 310.0
## Accélération (pixels par seconde²).
@export var acceleration: float = 700.0
## Durée de l'apparition (il surgit en criant) avant la course.
@export var emerge_time: float = 1.0
## Distance entre son avant et Élias à laquelle il l'attrape.
@export var catch_distance: float = 20.0
## Hauteur au-dessus de laquelle Élias est hors d'atteinte (il ne grimpe pas) (blocs).
@export var reach_height_blocks: float = 1.6

@export_group("Obstacles")
## Il franchit d'un bond les marches et les trous jusqu'à cette hauteur (blocs).
@export var hop_height_blocks: float = 1.4
## Gravité et chute maximale.
@export var gravity: float = 2000.0
@export var max_fall_speed: float = 1200.0
