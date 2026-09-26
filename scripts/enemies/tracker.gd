class_name Tracker
extends CharacterBody2D
## Le Traqueur (J8, écran 2) : le prédateur qui surgit de la jungle à l'arrivée
## d'Élias. Une poursuite SCÉNARISÉE, pas une IA complète :
##   1. il dort, caché (invisible), jusqu'à ce qu'Élias dépasse « trigger_offset » ;
##   2. il surgit en rugissant (le cri qu'on reconnaîtra) ;
##   3. il court vers Élias, franchit d'un bond les petits obstacles, et le tue
##      s'il l'attrape. Il court moins vite qu'Élias qui court : il faut courir ;
##   4. il ne grimpe pas : arrivé à sa limite (« limit_offset », au pied du mur
##      qu'Élias escalade), il s'arrête, gronde et abandonne.
## Rembobinable (J4). À la réapparition d'Élias, il retourne se cacher.

## Émis quand il attrape Élias.
signal caught

enum Mode { DORMANT, EMERGE, CHASE, BLOCKED, FED }

## Demi-longueur du corps (pixels) : du centre au museau.
const HALF_LENGTH: float = 98.0
## Taille du dessin (le corps est dessiné à l'échelle 1 puis agrandi).
const SCALE: float = 1.3

@export var config: TrackerConfig = preload("res://resources/enemies/tracker.tres")
## Élias déclenche la poursuite en passant à cette distance à droite du point de départ.
@export var trigger_offset: float = 550.0
## Le Traqueur ne va jamais plus loin que cette distance à droite de son départ.
@export var limit_offset: float = 1600.0

var mode: Mode = Mode.DORMANT
var facing: int = 1
var visual: TrackerVisual

var _start: Vector2
var _timer: float = 0.0
var _step_timer: float = 0.0


func _ready() -> void:
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150.0, 84.0) * SCALE
	shape.shape = rect
	shape.position = Vector2(0.0, -42.0 * SCALE)
	add_child(shape)
	visual = TrackerVisual.new()
	visual.name = "Visual"
	visual.scale = Vector2(SCALE, SCALE)
	add_child(visual)
	_start = global_position
	add_to_group(&"trackers")
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
				AudioManager.play_sfx(&"creature_tracker_roar", global_position, self, -4.0)
		Mode.FED:
			velocity.x = move_toward(velocity.x, 0.0, config.acceleration * delta)
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)
	move_and_slide()


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
		AudioManager.play_sfx(&"creature_tracker_step", global_position, self)
	# Attrapé ?
	if _reachable(player) and absf(player.global_position.x - global_position.x) < HALF_LENGTH + config.catch_distance:
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
	var front := Vector2(global_position.x + facing * HALF_LENGTH * 1.1, global_position.y - 8.0)
	var query := PhysicsRayQueryParameters2D.create(front, front + Vector2(0.0, 40.0), PhysicsLayers.WORLD)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _face(dir: float) -> void:
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		visual.set_facing(facing)


## Change de mode. « quiet » : sans le rugissement (rembobinage).
func _set_mode(new_mode: Mode, quiet: bool = false) -> void:
	mode = new_mode
	visible = mode != Mode.DORMANT
	match mode:
		Mode.DORMANT:
			visual.play(&"idle")
		Mode.EMERGE:
			_timer = config.emerge_time
			visual.play(&"roar")
			if not quiet:
				AudioManager.play_sfx(&"creature_tracker_roar", global_position, self)
		Mode.CHASE:
			visual.play(&"run")
		Mode.BLOCKED:
			_timer = 0.6
			visual.play(&"roar")
		Mode.FED:
			visual.play(&"idle")


## Réapparition d'Élias : le Traqueur retourne se cacher à son point de départ.
func reset_to_start() -> void:
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
