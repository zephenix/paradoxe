extends "res://scripts/player/states/idle.gd"
## Regarder le bracelet (J9) : à l'arrêt, Élias lève le poignet gauche et
## regarde l'hologramme. Ce n'est PAS un geste engagé : comme à l'arrêt (Idle,
## dont cet état hérite), la moindre commande (marcher, sauter, tirer…) l'en
## fait sortir aussitôt. Quand l'hologramme se referme, il baisse le bras.


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.set_crouched(false)
	player.visual.play(&"wrist")


func physics_update(delta: float) -> void:
	var p: Player = player
	if not p.bracelet.is_open:
		machine.transition_to(&"Idle")
		return
	super.physics_update(delta)
