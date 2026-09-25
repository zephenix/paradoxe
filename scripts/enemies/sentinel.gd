class_name Sentinel
extends CharacterBody2D
## Une Sentinelle : humanoïde armé qui patrouille, s'alerte, cherche, combat et
## poursuit (PLAN §5.3). Comme pour Élias, ce script ne DÉCIDE rien : ce sont ses
## états (dossier scripts/enemies/states/) qui décident. Ici se trouvent ses sens
## (voir, entendre, sentir un tir arriver), ses gestes (marcher, parler) et sa
## vie (touchée, morte, remise en place quand Élias réapparaît).
##
## J3 : perception simple. Elle VOIT Élias s'il est devant elle, assez près, à
## peu près à sa hauteur, et qu'aucun décor ne cache sa tête ou son buste. Elle
## ENTEND les bruits diffusés par l'AudioManager (tirs…) dans leur rayon.
## J6 remplacera la vue par la lumière et une jauge de suspicion.
##
## Repère : l'origine du nœud est à ses pieds, comme pour Élias.

## Émis quand la Sentinelle meurt.
signal died

## Réglages (vitesses, vue, combat…).
@export var config: SentinelConfig = preload("res://resources/enemies/sentinel.tres")
## Sens du regard au départ : -1 = gauche, 1 = droite.
@export_enum("Gauche:-1", "Droite:1") var start_facing: int = -1
## Trajet de patrouille : distance (en blocs) à gauche et à droite du point de
## départ. 0 et 0 : elle monte la garde sur place.
@export var patrol_left_blocks: float = 3.0
@export var patrol_right_blocks: float = 3.0
## Graine du hasard (bouclier levé ou non) : deux parties identiques se jouent
## pareil, ce qui rend les tests reproductibles.
@export var rng_seed: int = 1

## Sens du regard : 1 = droite, -1 = gauche.
var facing: int = -1:
	set(value):
		facing = 1 if value >= 0 else -1
		if visual:
			visual.set_facing(facing)
		if weapon:
			weapon.facing = facing
## Vrai une fois morte.
var is_dead: bool = false
## Élias (trouvé par le groupe « player »), ou null.
var target: Player
## Vrai si elle voit Élias en ce moment (mis à jour à chaque pas de physique).
var sees_target: bool = false
## Dernier endroit où elle a vu Élias, et depuis combien de temps.
var last_seen_position: Vector2 = Vector2.ZERO
var time_since_seen: float = INF
## Point de départ (centre de la patrouille, réapparition).
var home: Vector2 = Vector2.ZERO
## Hasard propre à cette Sentinelle.
var rng := RandomNumberGenerator.new()

@onready var visual: CharacterVisual = $Visual
@onready var machine: StateMachine = $StateMachine
@onready var energy: EnergyPool = $Energy
@onready var weapon: Weapon = $Weapon

## Morte AVANT le dernier checkpoint atteint par Élias : elle ne revient plus.
var _stays_dead: bool = false
## Hauteur de voix propre à chaque Sentinelle.
var _voice_pitch: float = 1.0

const STEP_SOUND: AudioStream = preload("res://assets/audio/generated/foley/foley_step_stone_02.wav")
const BODY_FALL_SOUND: AudioStream = preload("res://assets/audio/generated/foley/foley_body_fall.wav")
const VOICES: Dictionary = {
	&"calm": preload("res://assets/audio/generated/creature/creature_calm.wav"),
	&"curious": preload("res://assets/audio/generated/creature/creature_curious.wav"),
	&"alert": preload("res://assets/audio/generated/creature/creature_alert.wav"),
	&"search": preload("res://assets/audio/generated/creature/creature_search.wav"),
	&"death": preload("res://assets/audio/generated/creature/creature_death.wav"),
}


func _ready() -> void:
	add_to_group(&"enemies")
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 6.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(config.body_width, config.body_height)
	var shape_node: CollisionShape2D = $CollisionShape2D
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, -config.body_height * 0.5)
	home = global_position
	rng.seed = rng_seed
	_voice_pitch = 0.9 + 0.2 * rng.randf()
	weapon.energy = energy
	weapon.team = Projectile.TEAM_ENEMY
	facing = start_facing
	visual.anim_event.connect(_on_anim_event)
	AudioManager.noise_emitted.connect(_on_noise)
	Events.player_respawned.connect(reset_to_start)
	Events.checkpoint_reached.connect(_on_checkpoint_reached)
	machine.setup(self)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player
	if not is_dead:
		sees_target = can_see(target)
		if sees_target:
			last_seen_position = target.global_position
			time_since_seen = 0.0
		else:
			time_since_seen += delta
	machine.physics_update(delta)


# --------------------------------------------------------------------------
# Sens
# --------------------------------------------------------------------------

## Vrai si elle voit « who » : devant elle, pas trop loin, à peu près à sa
## hauteur, et au moins la tête ou le buste non cachés par le décor.
func can_see(who: Player) -> bool:
	if who == null or not is_instance_valid(who) or who.is_dead:
		return false
	var to: Vector2 = who.global_position - global_position
	if absf(to.x) > config.view_distance or absf(to.y) > config.view_height:
		return false
	if absf(to.x) > 8.0 and signf(to.x) != facing:
		return false  # derrière elle
	var eye: Vector2 = global_position + Vector2(0.0, -config.eye_height)
	var height: float = who.config.crouch_height if who.is_crouched else who.config.stand_height
	for part: float in [0.85, 0.5]:  # tête, puis buste
		var point: Vector2 = who.global_position + Vector2(0.0, -height * part)
		if _ray(eye, point).is_empty():
			return true
	return false


## Un tir d'Élias qui arrive droit sur elle (assez près pour réagir, sans
## décor entre eux) : renvoie ce projectile, ou null.
func incoming_projectile() -> Projectile:
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		var p: Projectile = node as Projectile
		if p == null or p.team == Projectile.TEAM_ENEMY or p.is_queued_for_deletion():
			continue
		var dx: float = global_position.x - p.global_position.x
		if signf(dx) != p.direction or absf(dx) > config.threat_distance:
			continue  # il s'éloigne, ou il est trop loin
		var dy: float = global_position.y - p.global_position.y
		if dy < 0.0 or dy > config.body_height:
			continue  # il passe au-dessus ou en dessous
		if _ray(p.global_position, Vector2(global_position.x, p.global_position.y)).is_empty():
			return p  # rien entre le tir et elle : il va la toucher
	return null


## Bruit entendu (signal de l'AudioManager) : l'état courant décide quoi en faire.
func _on_noise(at: Vector2, radius: float, source: Node) -> void:
	if is_dead or source == self:
		return
	if global_position.distance_to(at) <= radius * config.hearing_factor:
		var state: SentinelState = machine.current as SentinelState
		if state:
			state.on_noise(at)


# --------------------------------------------------------------------------
# Gestes
# --------------------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)


## Rapproche la vitesse horizontale de « target_speed », applique la gravité et
## déplace le corps. Elle s'arrête d'elle-même devant un mur ou un vide.
func move_at(target_speed: float, delta: float) -> void:
	if target_speed != 0.0 and not can_walk_toward(1 if target_speed > 0.0 else -1):
		target_speed = 0.0
	velocity.x = move_toward(velocity.x, target_speed, config.acceleration * delta)
	apply_gravity(delta)
	move_and_slide()


## Vrai si elle peut avancer dans la direction « dir » : pas de mur juste
## devant, et un sol pas trop bas (elle ne saute pas des plates-formes).
func can_walk_toward(dir: int) -> bool:
	var half: float = config.body_width * 0.5
	var ahead: float = half + 6.0
	var feet: Vector2 = global_position
	# Mur : un rayon horizontal à mi-hauteur.
	if not _ray(feet + Vector2(0.0, -config.body_height * 0.5), feet + Vector2(dir * ahead, -config.body_height * 0.5)).is_empty():
		return false
	# Vide : un rayon vertical juste devant les pieds.
	var max_drop: float = config.max_step_down_blocks * GameUnits.BLOCK
	var probe_x: float = feet.x + dir * ahead
	return not _ray(Vector2(probe_x, feet.y - 4.0), Vector2(probe_x, feet.y + max_drop + 2.0)).is_empty()


## Se tourne vers une position.
func face_toward(point: Vector2) -> void:
	if absf(point.x - global_position.x) > 4.0:
		facing = 1 if point.x > global_position.x else -1


## Parle (voix des créatures : l'intonation dit son état, sans aucun mot).
func say(mood: StringName) -> void:
	if VOICES.has(mood):
		AudioManager.play_stream_2d(VOICES[mood], global_position + Vector2(0, -80), AudioBuses.VOICE,
				-4.0, _voice_pitch)


## Joue une animation de marche ou de course au bon rythme.
func play_move_animation(running: bool) -> void:
	var anim: StringName = &"run" if running else &"walk"
	if visual.current != anim:
		visual.play(anim, config.run_cycle_duration if running else config.walk_cycle_duration)


# --------------------------------------------------------------------------
# Vie et mort
# --------------------------------------------------------------------------

## Appelé par un projectile d'Élias qui la touche. Un tir suffit.
func take_hit(_projectile: Projectile) -> bool:
	if is_dead:
		return false
	die()
	return true


func die() -> void:
	if is_dead:
		return
	is_dead = true
	sees_target = false
	# Le corps ne bloque plus les tirs ni les regards.
	collision_layer = 0
	weapon.reset()
	say(&"death")
	machine.transition_to(&"Dead")
	died.emit()
	Events.enemy_died.emit(self)


## Remise en place quand Élias réapparaît au checkpoint : les Sentinelles
## tuées depuis ce checkpoint reviennent à leur poste (comme dans les jeux
## d'origine) ; celles tuées AVANT restent au sol.
func reset_to_start() -> void:
	if _stays_dead:
		return
	global_position = home
	velocity = Vector2.ZERO
	is_dead = false
	sees_target = false
	time_since_seen = INF
	collision_layer = PhysicsLayers.ENEMIES
	facing = start_facing
	energy.refill()
	weapon.reset()
	machine.transition_to(&"Patrol")


func _on_checkpoint_reached(_checkpoint_id: StringName) -> void:
	if is_dead:
		_stays_dead = true


func _on_anim_event(event_name: StringName) -> void:
	match event_name:
		&"footstep", &"footstep_run":
			AudioManager.play_stream_2d(STEP_SOUND, global_position, AudioBuses.SFX, -18.0, 0.8)
		&"body_fall":
			AudioManager.play_stream_2d(BODY_FALL_SOUND, global_position, AudioBuses.SFX, -4.0, 0.9)


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)
