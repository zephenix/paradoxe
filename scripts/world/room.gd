@tool
class_name Room
extends Node2D
## Une salle (un « écran » au sens des jeux d'origine).
##
## La salle est un rectangle : l'origine du nœud est son coin haut-gauche et
## room_size sa taille. Quand Élias y entre, le CameraDirector cadre la salle
## et l'AudioManager passe à son ambiance (zone acoustique). Une salle plus grande que
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
## Zone acoustique (J5) : resources/audio/zones/<zone>.tres.
@export var acoustic_zone: StringName = &"lab"
## Lumière ambiante (J6) : 1 = plein jour (tout est visible), 0,2 = pénombre.
## Elle teinte l'écran et compte dans ce que voient les Sentinelles (Lighting).
@export_range(0.0, 1.0, 0.05) var ambient_light: float = 1.0
## Ambiance visuelle (essai graphique) : lumière principale, brume, poussières,
## grain. Vide : rien de tout cela. Sans effet sur le gameplay.
@export var atmosphere: RoomAtmosphere
## Objectif affiché par l'hologramme du bracelet (J9) : une phrase courte.
## Vide : pas de ligne « objectif ».
@export var objective: String = ""
## Vers quoi pointe la flèche de l'objectif (une sortie, un mécanisme…). Vide :
## pas de flèche, seulement la phrase.
@export var objective_target: NodePath

const FOG_SHADER: Shader = preload("res://assets/shaders/fog.gdshader")


func _ready() -> void:
	add_to_group(&"rooms")
	if atmosphere and not Engine.is_editor_hint():
		_create_fog()
		_create_dust()


## Position (dans le monde) de la cible de l'objectif ; Vector2.INF s'il n'y en a pas.
func objective_point() -> Vector2:
	var target: Node2D = get_node_or_null(objective_target) as Node2D if not objective_target.is_empty() else null
	return target.global_position if target else Vector2.INF


## La salle qui contient le point « at » (dans le monde), ou null.
static func find_at(context: Node, at: Vector2) -> Room:
	for node in context.get_tree().get_nodes_in_group(&"rooms"):
		var room: Room = node as Room
		if room and room.world_rect().has_point(at):
			return room
	return null


## Brume : un rectangle au bas de la salle, dessiné par un shader (volutes qui
## dérivent), devant les personnages (leurs pieds s'y perdent un peu).
func _create_fog() -> void:
	if atmosphere.fog_color.a <= 0.0:
		return
	var fog := ColorRect.new()
	fog.name = "Fog"
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.position = Vector2(0.0, room_size.y - atmosphere.fog_height)
	fog.size = Vector2(room_size.x, atmosphere.fog_height)
	fog.z_index = 6
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter(&"fog_color", atmosphere.fog_color)
	material.set_shader_parameter(&"world_size", fog.size)
	fog.material = material
	add_child(fog)


## Poussières : de petits points qui flottent dans toute la salle et brillent
## quand ils passent dans la lumière d'une lampe.
func _create_dust() -> void:
	if atmosphere.dust_amount <= 0:
		return
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = atmosphere.dust_amount
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.position = room_size * 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = room_size * 0.5
	dust.direction = Vector2(1.0, -0.3)
	dust.spread = 60.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 12.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	var fade := Gradient.new()
	fade.set_color(0, Color(atmosphere.dust_color, 0.0))
	fade.set_color(1, Color(atmosphere.dust_color, 0.0))
	fade.add_point(0.5, atmosphere.dust_color)
	dust.color_ramp = fade
	dust.z_index = 5
	add_child(dust)


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
