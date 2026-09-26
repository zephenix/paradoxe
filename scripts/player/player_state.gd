class_name PlayerState
extends State
## Base commune des états d'Élias : donne un accès typé au joueur et
## regroupe les réactions partagées par plusieurs états au sol.

## Le joueur (même objet que « actor », mais typé pour l'autocomplétion).
var player: Player:
	get:
		return actor as Player


## Réactions communes aux états « debout au sol » (arrêt, marche).
## Renvoie vrai si une transition a eu lieu.
func handle_ground_actions() -> bool:
	var p: Player = player
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return true
	# Pendant la tolérance d'une image sans sol, le mode classique n'accepte
	# aucune action (pas de « temps du coyote » en classique).
	if not p.is_on_floor() and not p.modern():
		return false
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
		if not edge.is_empty() and p.input.move == 0 and p.can_descend(edge["edge_x"]):
			machine.transition_to(&"LedgeDescend", edge)
		else:
			machine.transition_to(&"Crouch")
		return true
	return false


## Réactions de combat communes aux états au sol (arrêt, marche, course,
## accroupi) : un appui sur « tir » ou « bouclier » fait dégainer (état Aim),
## qui exécutera ensuite le tir ou lèvera le bouclier. Renvoie vrai si une
## transition a eu lieu.
func handle_combat_actions() -> bool:
	var p: Player = player
	if not p.is_on_floor() or not p.can_stand():
		return false
	if p.wants(&"shield") or p.input.shield:
		machine.transition_to(&"Aim", {"then": &"shield"})
		return true
	if p.wants(&"fire"):
		machine.transition_to(&"Aim", {"then": &"fire"})
		return true
	return false


## Lancer une pierre (J6), debout ou accroupi, s'il en a une. Renvoie vrai si
## une transition a eu lieu.
func handle_throw_action() -> bool:
	var p: Player = player
	if not p.is_on_floor() or not p.wants(&"throw"):
		return false
	if p.stones <= 0:
		return false
	machine.transition_to(&"Throw", {"crouched": p.is_crouched})
	return true


## Garde-bord : en marchant, Élias s'arrête devant un vide dangereux (plus
## profond qu'une chute sans conséquence). Désactivé en mode classique.
func edge_guard_stops() -> bool:
	var p: Player = player
	if not (p.modern() and p.config.edge_guard):
		return false
	var danger: float = p.config.blocks(p.config.safe_fall_blocks)
	var lookahead: float = p.config.body_width * 0.5 + p.config.edge_guard_lookahead
	return p.drop_depth_ahead(lookahead, danger + 4.0) > danger
