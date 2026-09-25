extends PlayerState
## Charge d'un tir puissant : Élias garde la détente enfoncée après un tir.
## La tension monte (son qui grimpe) ; quand elle est complète (charge_time),
## un tintement le signale. En relâchant :
##   - charge complète   -> tir chargé (brise un bouclier), puis recul (Shoot) ;
##   - charge incomplète -> rien ne part, retour à Aim.
## Le tir chargé coûte cher : sans assez d'énergie, clic à vide.
## Bouclier ou roulade annulent la charge (réflexes de défense prioritaires).


func enter(_previous: StringName, _data: Dictionary) -> void:
	player.weapon.start_charge()
	player.visual.play(&"charge")


func exit() -> void:
	player.weapon.cancel_charge()  # sans effet si le tir vient de partir


func physics_update(delta: float) -> void:
	var p: Player = player
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if p.wants(&"roll"):
		machine.transition_to(&"Roll", {"landing": false})
		return
	if p.input.shield or p.wants(&"shield"):
		machine.transition_to(&"Shield")
		return
	p.weapon.update_charge(delta)
	if not p.input.fire:
		if p.weapon.is_charged():
			p.weapon.release_charge()
			machine.transition_to(&"Shoot", {"fired": true})
		else:
			machine.transition_to(&"Aim")
