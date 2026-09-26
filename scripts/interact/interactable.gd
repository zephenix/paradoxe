@tool
class_name Interactable
extends Node2D
## Base des objets avec lesquels on interagit (J7, PLAN §5.7) : leviers,
## terminaux, objets à ramasser…
##
## Une seule touche « Interagir » : l'objet interactif le plus proche, DEVANT
## Élias et à portée de main, réagit (voir find_for). Le compagnon peut aussi
## actionner les objets marqués « companion_can_use » (ordre « Active ça ») :
## une petite spirale verte les signale.
##
## Chaque objet redéfinit _on_interact(by) : ce qui se passe quand on
## l'actionne. Il renvoie vrai si l'action a eu lieu.
##
## L'origine du nœud est au sol, là où se tient celui qui l'actionne.

## Émis quand l'objet est actionné (by : Élias ou le compagnon).
signal activated(by: Node)

## Groupe Godot de tous les objets interactifs.
const GROUP: StringName = &"interactables"

## Le compagnon sait-il l'actionner (ordre « Active ça ») ?
@export var companion_can_use: bool = false:
	set(value):
		companion_can_use = value
		queue_redraw()
## Actionnable en ce moment ?
@export var enabled: bool = true


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## Actionne l'objet. Renvoie vrai si quelque chose s'est passé.
func interact(by: Node) -> bool:
	if not enabled:
		return false
	var done: bool = _on_interact(by)
	if done:
		activated.emit(by)
	return done


## À redéfinir : l'effet de l'objet.
func _on_interact(_by: Node) -> bool:
	return false


## L'objet interactif le plus proche devant « who » (regard « facing »), à
## moins de « reach » pixels devant ses pieds et à peu près à sa hauteur.
## Renvoie null s'il n'y en a pas.
static func find_for(who: Node2D, facing: int, reach: float) -> Interactable:
	var best: Interactable = null
	var best_distance: float = INF
	for node in who.get_tree().get_nodes_in_group(GROUP):
		var item: Interactable = node as Interactable
		if item == null or not item.enabled or not item.is_visible_in_tree():
			continue
		var offset: Vector2 = item.global_position - who.global_position
		if absf(offset.y) > 48.0:
			continue  # pas au même niveau
		var ahead: float = offset.x * facing
		if ahead < -16.0 or ahead > reach:
			continue  # derrière lui, ou trop loin
		if absf(offset.x) < best_distance:
			best_distance = absf(offset.x)
			best = item
	return best


## Le plus proche objet que le compagnon sait actionner, à moins de « radius »
## pixels de « point » (dans n'importe quelle direction).
static func nearest_for_companion(context: Node, point: Vector2, radius: float) -> Interactable:
	var best: Interactable = null
	var best_distance: float = radius
	for node in context.get_tree().get_nodes_in_group(GROUP):
		var item: Interactable = node as Interactable
		if item == null or not item.enabled or not item.companion_can_use:
			continue
		var distance: float = item.global_position.distance_to(point)
		if distance <= best_distance:
			best_distance = distance
			best = item
	return best


## Petite spirale verte au-dessus des objets que le compagnon sait actionner.
func draw_companion_mark(at: Vector2) -> void:
	if not companion_can_use:
		return
	var points := PackedVector2Array()
	for i in 21:
		var k: float = float(i) / 20.0
		var angle: float = k * 2.0 * TAU
		points.append(at + Vector2(cos(angle), sin(angle)) * 6.0 * k)
	draw_polyline(points, Color(0.43, 1.0, 0.69, 0.9), 1.5)
