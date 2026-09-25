@tool
class_name Room
extends Node2D
## Une salle (un « écran » au sens des jeux d'origine).
##
## La salle est un rectangle : l'origine du nœud est son coin haut-gauche et
## room_size sa taille. Quand Élias y entre, le CameraDirector cadre la salle
## et l'AudioManager passera à son ambiance (J5). Une salle plus grande que
## l'écran fait défiler la caméra (et peut la faire reculer avec camera_zoom).

enum Transition { SLIDE, CUT }

## Taille de la salle en pixels (1280×720 = un écran).
@export var room_size: Vector2 = Vector2(1280, 720):
	set(value):
		room_size = value
		queue_redraw()
## Zoom de la caméra : 1 = normal, < 1 = la caméra recule (scènes spectaculaires).
@export_range(0.4, 1.5, 0.05) var camera_zoom: float = 1.0
## Façon d'arriver dans cette salle : glissement de caméra ou coupure franche.
@export var transition: Transition = Transition.SLIDE
## Nom affiché dans l'éditeur et les journaux de débogage.
@export var title: String = ""
## Zone acoustique (J5) et éclairage ambiant (J6).
@export var acoustic_zone: StringName = &"lab"
@export var ambient_light: float = 0.5


func _ready() -> void:
	add_to_group(&"rooms")


## Rectangle de la salle en coordonnées du monde.
func world_rect() -> Rect2:
	return Rect2(global_position, room_size)


## Point de réapparition : le nœud enfant « Spawn » s'il existe, sinon le bas-gauche.
func spawn_point() -> Vector2:
	var marker: Node2D = get_node_or_null(^"Spawn")
	return marker.global_position if marker else global_position + Vector2(96, room_size.y - 96)


func _draw() -> void:
	# Contour visible uniquement dans l'éditeur, pour placer les salles.
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, room_size), Color(0.4, 1.0, 0.7, 0.8), false, 3.0)
