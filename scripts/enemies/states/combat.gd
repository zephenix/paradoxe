extends SentinelState
## Combat : elle a vu Élias. Elle crie l'alerte, dégaine, puis enchaîne un cycle :
##
##   RÉACTION (reaction_time) -> VISÉE (aim_time) -> TIR -> RECUL -> PAUSE -> VISÉE…
##
## La VISÉE est l'avertissement pour le joueur : bras tendu pendant aim_time
## avant chaque tir. Si Élias est accroupi, elle vise à genou : son tir part bas
## (un couvert de 1,5 bloc l'arrête, un Élias accroupi à découvert non).
## Pendant la pause, elle s'approche si Élias est plus loin que preferred_distance.
##
## BOUCLIER : quand un tir d'Élias arrive sur elle, elle décide UNE fois par
## tir (au hasard, shield_chance) de lever le bouclier après shield_reaction_time
## et le garde shield_hold_time. Elle ne peut pas le faire pendant le recul de
## son propre tir : c'est la fenêtre du joueur. Un tir chargé brise le bouclier
## et la laisse un instant sans défense.
##
## Elle perd Élias de vue plus de lose_sight_time secondes -> Chase.

enum Phase { REACT, AIM, RECOIL, PAUSE, SHIELD }

var _phase: Phase = Phase.REACT
var _timer: float = 0.0
## Tir à genou (Élias accroupi) pour le cycle en cours.
var _low: bool = false
## Projectiles déjà « jugés » (bouclier ou pas), pour ne tirer au sort qu'une fois.
var _judged: Array[int] = []
## Bouclier décidé, à lever dans _shield_delay secondes.
var _shield_pending: bool = false
var _shield_delay: float = 0.0


func enter(previous: StringName, data: Dictionary) -> void:
	var s: Sentinel = sentinel
	_judged.clear()
	_shield_pending = false
	_phase = Phase.REACT
	_timer = s.config.reaction_time
	if previous != &"Chase" and not data.get("resumed", false):
		s.say(&"alert")
		s.weapon.play_draw_sound()
	s.visual.play(&"aim")


func exit() -> void:
	sentinel.weapon.lower_shield()


func physics_update(delta: float) -> void:
	var s: Sentinel = sentinel
	var target: Player = s.target
	if target == null or target.is_dead:
		# Élias est mort : elle baisse son arme et attend (le niveau la remettra
		# à son poste quand il réapparaîtra).
		s.weapon.lower_shield()
		if s.visual.current != &"idle":
			s.visual.play(&"idle")
		s.move_at(0.0, delta)
		return
	if s.time_since_seen > s.config.lose_sight_time and _phase != Phase.SHIELD:
		machine.transition_to(&"Chase")
		return
	if s.sees_target and _phase != Phase.RECOIL:
		s.face_toward(target.global_position)
	_update_shield_decision(delta)
	var moving: bool = false
	match _phase:
		Phase.REACT:
			_timer -= delta
			if _timer <= 0.0:
				_start_aim()
		Phase.AIM:
			_timer -= delta
			if _timer <= 0.0:
				_fire()
		Phase.RECOIL:
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.PAUSE
				_timer = s.config.fire_pause
				s.visual.play(&"aim")
		Phase.PAUSE:
			moving = _approach(target, delta)
			_timer -= delta
			if _timer <= 0.0:
				_start_aim()
		Phase.SHIELD:
			_timer -= delta
			if not s.weapon.sustain_shield(delta):
				# Jauge vide ou bouclier brisé par un tir chargé : sonnée un instant.
				_phase = Phase.PAUSE
				_timer = s.config.stagger_time
				s.visual.play(&"aim")
			elif _timer <= 0.0:
				s.weapon.lower_shield()
				_start_aim()
	if not moving:
		s.move_at(0.0, delta)


## Déjà au combat : un bruit n'y change rien.
func on_noise(_at: Vector2) -> void:
	pass


func _start_aim() -> void:
	var s: Sentinel = sentinel
	if not s.sees_target:
		_phase = Phase.PAUSE  # elle attend de le revoir (ou passe à la poursuite)
		_timer = 0.2
		return
	_low = s.target.is_crouched
	_phase = Phase.AIM
	_timer = s.config.aim_time
	s.visual.play(&"kneel_aim" if _low else &"aim")


func _fire() -> void:
	var s: Sentinel = sentinel
	s.weapon.fire(false, _low)
	s.visual.play(&"kneel_shoot" if _low else &"shoot", s.weapon.config.fire_cooldown)
	_phase = Phase.RECOIL
	_timer = s.weapon.config.fire_cooldown


## Pendant la pause, elle se rapproche d'Élias s'il est trop loin. Renvoie vrai
## si elle marche.
func _approach(target: Player, delta: float) -> bool:
	var s: Sentinel = sentinel
	var distance: float = absf(target.global_position.x - s.global_position.x)
	if distance <= s.config.preferred_distance or not s.can_walk_toward(s.facing):
		if s.visual.current != &"aim":
			s.visual.play(&"aim")
		return false
	s.play_move_animation(false)
	s.move_at(s.facing * s.config.walk_speed, delta)
	return true


## Un tir d'Élias arrive : lever le bouclier ou non (tiré au sort une fois par tir).
func _update_shield_decision(delta: float) -> void:
	var s: Sentinel = sentinel
	if _phase == Phase.RECOIL or _phase == Phase.SHIELD:
		return
	var incoming: Projectile = s.incoming_projectile()
	if incoming and not _judged.has(incoming.get_instance_id()):
		_judged.append(incoming.get_instance_id())
		if not _shield_pending and s.rng.randf() < s.config.shield_chance:
			_shield_pending = true
			_shield_delay = s.config.shield_reaction_time
	if not _shield_pending:
		return
	_shield_delay -= delta
	if _shield_delay > 0.0:
		return
	_shield_pending = false
	if s.weapon.raise_shield():
		_phase = Phase.SHIELD
		_timer = s.config.shield_hold_time
		s.visual.play(&"shield")
