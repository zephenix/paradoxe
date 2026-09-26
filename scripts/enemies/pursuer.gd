class_name Pursuer
extends CharacterBody2D
## Un poursuivant (J8) : le Traqueur, le prédateur qui surgit de la jungle à
## l'arrivée d'Élias (écran 2), ou les Sentinelles qui le poursuivent dans la
## ville (écran 8). Une poursuite SCÉNARISÉE, pas une IA complète :
##   1. il attend, caché (invisible), jusqu'à ce qu'Élias dépasse « trigger_offset » ;
##   2. il surgit en criant (le cri du Traqueur, on le reconnaîtra) ;
##   3. il court vers Élias, franchit d'un bond les petits obstacles, et le tue
##      s'il l'attrape : il faut courir ;
##   4. il ne grimpe pas et ne dépasse pas sa limite (« limit_offset ») : il s'y
##      arrête, gronde et abandonne.
## Réglages (vitesse, apparence, sons) : un PursuerConfig. Rembobinable (J4). À la
## réapparition d'Élias, il retourne se cacher.

## Émis quand il attrape Élias.
signal caught

enum Mode { DORMANT, EMERGE, CHASE, BLOCKED, FED }


@export var config: PursuerConfig = preload("res://resources/enemies/tracker.tres")
## Élias déclenche la poursuite en passant à cette distance à droite du point de départ.
@export var trigger_offset: float = 550.0
## Le Traqueur ne va jamais plus loin que cette distance à droite de son départ.
@export var limit_offset: float = 1600.0

var mode: Mode = Mode.DORMANT
var facing: int = 1
## Le dessin : un TrackerVisual ou un SentinelVisual (ils ont les mêmes fonctions
## play() et set_facing()).
var visual: Node2D

var _start: Vector2
var _timer: float = 0.0
var _step_timer: float = 0.0


func _ready() -> void:
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = config.body_size
	shape.shape = rect
	shape.position = Vector2(0.0, -config.body_size.y * 0.5)
	add_child(shape)
	visual = (SentinelVisual.new() if config.skin == &"sentinel" else TrackerVisual.new()) as Node2D
	visual.name = "Visual"
	visual.scale = Vector2(config.visual_scale, config.visual_scale)
	add_child(visual)
	_start = global_position
	add_to_group(&"pursuers")
	add_to_group(RewindManager.GROUP)
	Events.player_respawned.connect(reset_to_start)
	_set_mode(Mode.DORMANT)


func _physics_process(delta: float) -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	match mode:
		Mode.DORMANT:
			velocity = Vector2.ZERO
			if player and not player.is_dead and _in_hunting_ground(player.global_position.x) \
					and player.global_position.x > _start.x + trigger_offset:
				_set_mode(Mode.EMERGE)
			return
		Mode.EMERGE:
			_timer -= delta
			if _timer <= 0.0:
				_set_mode(Mode.CHASE)
		Mode.CHASE:
			_chase(player, delta)
		Mode.BLOCKED:
			velocity.x = move_toward(velocity.x, 0.0, config.acceleration * delta)
			if player:
				_face(signf(player.global_position.x - global_position.x))
				# Élias redescend à sa portée : la poursuite reprend.
				if _reachable(player) and player.global_position.x < limit_x() - 40.0:
					_set_mode(Mode.CHASE)
			_timer -= delta
			if _timer <= 0.0:
				_timer = 4.0
				AudioManager.play_sfx(config.cry_sound, global_position, self, -4.0)
		Mode.FED:
			velocity.x = move_toward(velocity.x, 0.0, config.acceleration * delta)
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)
	move_and_slide()


## Demi-longueur du corps (pixels) : du centre à l'avant.
func half_length() -> float:
	return config.body_size.x * 0.5


## Abscisse (monde) qu'il ne dépasse jamais.
func limit_x() -> float:
	return _start.x + limit_offset


func _chase(player: Player, delta: float) -> void:
	if player == null or player.is_dead:
		_set_mode(Mode.FED)
		return
	var dir: float = signf(player.global_position.x - global_position.x)
	_face(dir)
	var target_speed: float = config.run_speed * dir
	if dir > 0.0 and global_position.x >= limit_x():
		_set_mode(Mode.BLOCKED)
		return
	velocity.x = move_toward(velocity.x, target_speed, config.acceleration * delta)
	# Petit obstacle ou trou devant lui : il bondit.
	if is_on_floor() and (is_on_wall() or not _ground_ahead()):
		velocity.y = -sqrt(2.0 * config.gravity * config.hop_height_blocks * GameUnits.BLOCK)
	_step_timer -= delta
	if _step_timer <= 0.0 and is_on_floor():
		_step_timer = config.step_interval
		AudioManager.play_sfx(config.step_sound, global_position, self)
	# Attrapé ?
	if _reachable(player) and absf(player.global_position.x - global_position.x) < half_length() + config.catch_distance:
		player.kill(&"tracker")
		_set_mode(Mode.FED)
		caught.emit()


## Élias est-il à sa portée (pas perché au-dessus de lui) ?
func _reachable(player: Player) -> bool:
	return global_position.y - player.global_position.y < config.reach_height_blocks * GameUnits.BLOCK


func _in_hunting_ground(x: float) -> bool:
	return x < limit_x() + 200.0


## Y a-t-il du sol juste devant ses pattes avant ?
func _ground_ahead() -> bool:
	var front := Vector2(global_position.x + facing * half_length() * 1.1, global_position.y - 8.0)
	var query := PhysicsRayQueryParameters2D.create(front, front + Vector2(0.0, 40.0), PhysicsLayers.WORLD)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _face(dir: float) -> void:
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		visual.call(&"set_facing", facing)


## Change de mode. « quiet » : sans le rugissement (rembobinage).
func _set_mode(new_mode: Mode, quiet: bool = false) -> void:
	mode = new_mode
	visible = mode != Mode.DORMANT
	match mode:
		Mode.DORMANT:
			visual.call(&"play", &"idle")
		Mode.EMERGE:
			_timer = config.emerge_time
			visual.call(&"play", config.emerge_animation)
			if not quiet:
				AudioManager.play_sfx(config.cry_sound, global_position, self)
		Mode.CHASE:
			visual.call(&"play", &"run")
			if not quiet and config.chase_theme != &"":
				AudioManager.play_music(config.chase_theme, 0.3)
		Mode.BLOCKED:
			_timer = 0.6
			visual.call(&"play", config.emerge_animation)
		Mode.FED:
			visual.call(&"play", &"idle")


## Réapparition d'Élias : le Traqueur retourne se cacher à son point de départ.
func reset_to_start() -> void:
	if config.chase_theme != &"" and AudioManager.music.theme_id == config.chase_theme:
		AudioManager.stop_music(1.0)
	global_position = _start
	velocity = Vector2.ZERO
	_face(1.0)
	_set_mode(Mode.DORMANT)


# --------------------------------------------------------------------------
# Rembobinage (J4)
# --------------------------------------------------------------------------

func capture_state() -> Dictionary:
	return {"position": global_position, "velocity": velocity, "mode": mode, "timer": _timer, "facing": facing}


func apply_state(state: Dictionary) -> void:
	global_position = state["position"]
	velocity = state["velocity"]
	_face(float(state["facing"]))
	if mode != state["mode"]:
		_set_mode(state["mode"], true)
	_timer = state["timer"]


func resume_state(state: Dictionary) -> void:
	apply_state(state)
