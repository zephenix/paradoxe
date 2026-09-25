extends PlayerState
## Bouclier levé : un mur d'énergie devant Élias arrête les tirs.
## Il reste levé tant que la touche est maintenue ET que la jauge n'est pas
## vide (il consomme en continu). Élias ne bouge pas et ne tire pas pendant ce
## temps ; une roulade reste possible pour s'échapper.
## Un tir chargé adverse brise le bouclier (voir EnergyShield).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.visual.play(&"shield")
	if not player.weapon.raise_shield():
		# Jauge presque vide ou bouclier brisé à l'instant : clic à vide, on reste
		# en garde. L'appui est « consommé » : il faudra relâcher et réappuyer.
		AudioManager.play_sfx(&"weapon_empty", player.global_position + Vector2(0, -70), player)
		player.input.consume(&"shield", INF)
		machine.transition_to(&"Aim", {"shield_locked": true})


func exit() -> void:
	player.weapon.lower_shield()


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return
	if not p.input.shield:
		machine.transition_to(&"Aim")
	elif not p.weapon.sustain_shield(delta):
		# Jauge vide ou bouclier brisé : il tombe, même touche enfoncée.
		machine.transition_to(&"Aim", {"shield_locked": true})
