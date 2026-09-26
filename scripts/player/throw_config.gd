class_name ThrowConfig
extends Resource
## Réglages du lancer de pierre (J6) : resources/player/throw.tres.
##
## Une pierre lancée retombe plus loin et fait du bruit en touchant le sol : les
## Sentinelles qui l'entendent vont voir. C'est une DIVERSION : on attire une
## Sentinelle ailleurs pour passer derrière elle. Le rayon de bruit de l'impact
## est réglé dans la bibliothèque de sons (stone_impact).

## Vitesse de départ (pixels par seconde) et angle au-dessus de l'horizontale (degrés).
@export var speed: float = 700.0
@export_range(0.0, 80.0, 1.0) var angle: float = 40.0
## Gravité subie par la pierre (pixels par seconde²).
@export var gravity: float = 1400.0
## Durée du geste (engagé) et instant où la pierre quitte la main (secondes).
@export var duration: float = 0.4
@export var release_time: float = 0.18
## Nombre de pierres qu'Élias peut porter.
@export var max_stones: int = 3
## Durée pendant laquelle une pierre reste visible au sol avant de disparaître.
@export var linger_time: float = 4.0


## Vitesse de départ d'une pierre lancée vers « facing » (-1 ou 1).
func launch_velocity(facing: int) -> Vector2:
	var radians: float = deg_to_rad(angle)
	return Vector2(facing * speed * cos(radians), -speed * sin(radians))


## Distance horizontale parcourue avant de retomber à la hauteur de départ
## (formule de la portée d'un tir en cloche : v² × sin(2 × angle) / g).
func flat_range() -> float:
	return speed * speed * sin(2.0 * deg_to_rad(angle)) / gravity
