@tool
class_name RubblePile
extends Interactable
## Un tas de gravats (J6) : Élias y ramasse des pierres, jusqu'au maximum qu'il
## peut porter (resources/player/throw.tres). Le tas ne s'épuise pas. L'origine
## du nœud est au sol, au centre du tas.
##
## J9 (retour de jeu de la v0.8) : on ne ramasse plus en passant dessus, mais
## avec « Interagir », comme les autres objets. Élias s'accroupit et prend les
## pierres une à une (état PickUp) : chaque pierre fait un bruit bien audible et
## l'hologramme du bracelet montre le compteur. Il peut aussi ramasser en restant
## accroupi, pour rester discret.

## Largeur du tas (pixels).
@export var width: float = 72.0:
	set(value):
		width = value
		reach_margin = width * 0.5
		queue_redraw()


func _init() -> void:
	gesture = &"PickUp"  # l'état d'Élias : s'accroupir et ramasser
	reach_margin = width * 0.5  # on l'atteint aussi debout sur le tas


## Une pierre de plus dans la poche de « by » (appelé par l'état PickUp, une fois
## par pierre). Renvoie faux si ses poches sont déjà pleines.
func _on_interact(by: Node) -> bool:
	var player: Player = by as Player
	if player == null or player.is_dead or player.stones >= player.throw_config.max_stones:
		return false
	player.stones += 1
	AudioManager.play_sfx(&"stone_take", global_position, player)
	return true


func _draw() -> void:
	var half: float = width * 0.5
	var color := Color(0.42, 0.42, 0.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-half, 0), Vector2(-half * 0.6, -14), Vector2(-half * 0.1, -20),
			Vector2(half * 0.4, -16), Vector2(half, 0)]), color)
	for i in 5:
		var x: float = -half * 0.7 + i * half * 0.35
		draw_circle(Vector2(x, -4.0 - (i % 2) * 7.0), 5.0, color.lightened(0.1 + 0.05 * i))
