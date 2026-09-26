extends CompanionState
## Attendre : il reste où il est (sur une plaque de pression, près d'un levier…)
## et garde un œil sur Élias.


func enter(_previous: StringName, _data: Dictionary) -> void:
	companion.mode = &"Wait"


func physics_update(delta: float) -> void:
	var c: Companion = companion
	if c.target and c.visual.current in [&"idle", &"walk", &"run"]:
		c.face_toward(c.target.global_position)
	c.move_at(0.0, delta)
	c.play_locomotion(c.velocity.x)
