extends PlayerState
## Suspendu à un rebord. Haut (ou saut) : se hisser. Un NOUVEL appui sur Bas,
## ou la direction opposée au mur pressée après l'arrivée : lâcher prise.
##
## Pourquoi « nouvel appui » : on arrive souvent ici en maintenant Bas (descente
## d'un rebord) ou une direction ; sans cette précaution, Élias lâcherait prise
## dans la même image qu'il s'accroche.

var _ledge: Dictionary = {}
## Vrai une fois que la direction « vers le vide » a été relâchée depuis l'arrivée.
var _away_armed: bool = false


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	_ledge = data.get("ledge", {})
	_away_armed = false
	p.set_crouched(false)
	p.velocity = Vector2.ZERO
	# Oublie un appui sur Bas antérieur à la prise (celui qui a lancé la descente).
	p.input.consume(&"move_down", INF)
	p.visual.play(&"hang")
	if not data.get("resumed", false):
		p.anim_event.emit(&"grab")  # pas de bruit de prise en reprenant après un rembobinage


func snapshot() -> Dictionary:
	return {"ledge": _ledge}


func physics_update(_delta: float) -> void:
	var p: Player = player
	p.air_top_y = p.global_position.y
	if p.input.move != -p.facing:
		_away_armed = true
	var climb: bool = p.wants(&"move_up") or p.wants(&"jump") \
			or (p.input.up and time_in_state > p.config.hang_hold_to_climb)
	if climb and _ledge.get("can_climb", false):
		machine.transition_to(&"LedgeClimb", {"ledge": _ledge})
		return
	if p.wants(&"move_down") or (_away_armed and p.input.move == -p.facing):
		p.grab_cooldown = p.config.regrab_cooldown
		machine.transition_to(&"Fall")
