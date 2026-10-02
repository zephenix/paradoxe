extends PlayerState
## Ramasser des pierres (J9) sur un tas de gravats (RubblePile). Geste engagé :
##   1. Élias se baisse (pickup_reach secondes) ;
##   2. il prend les pierres UNE À UNE, autant qu'il lui en manque : une
##      pierre toutes les pickup_interval secondes, chacune avec son bruit, et
##      l'hologramme du bracelet compte ;
##   3. il se relève (pickup_rise secondes), ou reste accroupi s'il l'était.
## Poches déjà pleines : il tâte sa poche (les pierres s'entrechoquent) et
## l'hologramme montre le compteur plein.
## Réglages : resources/player/throw.tres. data["target"] : le tas (Interactable).

var _target: Interactable
var _crouched: bool = false
## Pierres à prendre (au moins 1 : le geste de tâter sa poche dure autant).
var _count: int = 1
## Pierres déjà prises, et phase du geste (&"down", &"take", &"rise").
var _taken: int = 0
var _phase: StringName = &"down"


func enter(_previous: StringName, data: Dictionary) -> void:
	var p: Player = player
	_target = data.get("target") as Interactable
	_crouched = p.is_crouched
	_count = maxi(p.throw_config.max_stones - p.stones, 1)
	_taken = 0
	_phase = &"down"
	p.visual.play(&"pick_down", p.throw_config.pickup_reach)


func is_committed() -> bool:
	return true


## Durée totale du geste (secondes).
func duration() -> float:
	var cfg: ThrowConfig = player.throw_config
	return cfg.pickup_reach + _count * cfg.pickup_interval + cfg.pickup_rise


func physics_update(delta: float) -> void:
	var p: Player = player
	var cfg: ThrowConfig = p.throw_config
	p.move_on_ground(0.0, delta)
	if p.lost_ground():
		machine.transition_to(&"Fall")
		return
	if _phase == &"down" and time_in_state >= cfg.pickup_reach:
		_phase = &"take"
		p.visual.play(&"pick_take", cfg.pickup_interval)
	# Une pierre au début de chaque boucle « prendre » (la main touche le sol).
	if _phase == &"take" and _taken < _count and time_in_state >= cfg.pickup_reach + _taken * cfg.pickup_interval:
		_taken += 1
		_take_one()
	if _phase == &"take" and time_in_state >= cfg.pickup_reach + _count * cfg.pickup_interval:
		_phase = &"rise"
		p.visual.play(&"pick_rise_crouch" if _crouched else &"pick_rise", cfg.pickup_rise)
	if time_in_state >= duration():
		if _crouched:
			machine.transition_to(&"Crouch")
		elif p.can_stand():
			machine.transition_to(&"Idle")
		else:
			machine.transition_to(&"Crouch")  # un plafond est descendu ? on reste accroupi


func _take_one() -> void:
	var p: Player = player
	var got: bool = is_instance_valid(_target) and _target.interact(p)
	if not got:
		AudioManager.play_sfx(&"stone_pickup", p.global_position, p)  # poches pleines : elles cliquettent
	p.show_stones()
