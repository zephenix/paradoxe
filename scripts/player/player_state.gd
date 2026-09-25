class_name PlayerState
extends State
## Base commune des états d'Élias : donne un accès typé au joueur et
## regroupe les réactions partagées par plusieurs états au sol.

## Le joueur (même objet que « actor », mais typé pour l'autocomplétion).
var player: Player:
	get:
		return actor as Player


## Temps sans sol au-delà duquel un état « au sol » passe en chute (secondes).
const AIR_TOLERANCE: float = 0.05


## Réactions communes aux états « debout au sol » (arrêt, marche, course).
## Renvoie vrai si une transition a eu lieu.
func handle_ground_actions() -> bool:
	var p: Player = player
	# Petite tolérance : on ne « tombe » qu'après quelques centièmes de seconde
	# sans sol (évite les faux départs, et laisse le temps d'un saut de coyote).
	if not p.is_on_floor() and p.time_since_grounded > AIR_TOLERANCE:
		machine.transition_to(&"Fall")
		return true
	if p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return true
	if p.wants(&"jump"):
		if p.input.move == 0:
			p.climb_or_jump_up()
		else:
			p.facing = p.input.move
			p.start_jump(&"standing")
		return true
	if p.wants(&"move_up"):
		p.climb_or_jump_up()
		return true
	if p.input.down:
		var edge: Dictionary = p.find_edge_ahead()
		if not edge.is_empty() and p.input.move == 0:
			machine.transition_to(&"LedgeDescend", edge)
		else:
			machine.transition_to(&"Crouch")
		return true
	return false


## Garde-bord : en marchant, Élias s'arrête devant un vide dangereux.
func edge_guard_stops() -> bool:
	var p: Player = player
	if not (p.modern() and p.config.edge_guard):
		return false
	var danger: float = p.config.blocks(p.config.safe_fall_blocks)
	return p.drop_depth_ahead(p.config.body_width * 0.5 + 6.0, danger + 4.0) > danger
