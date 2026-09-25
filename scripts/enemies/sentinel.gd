class_name Sentinel
extends CharacterBody2D
## Une Sentinelle : humanoïde armé qui patrouille, s'alerte, cherche, combat et
## poursuit (PLAN §5.3). Comme pour Élias, ce script ne DÉCIDE rien : ce sont ses
## états (dossier scripts/enemies/states/) qui décident. Ici se trouvent ses sens
## (voir, entendre, sentir un tir arriver), ses gestes (marcher, parler) et sa
## vie (touchée, morte, remise en place quand Élias réapparaît).
##
## Perception (J6, PLAN §5.4) :
##   - VUE : Élias doit être dans son cône de vision, assez près, à peu près à
##     sa hauteur, et sa tête ou son buste ne doit pas être caché par le décor.
##     Ce qu'elle en perçoit (sa « visibilité », de 0 à 1) dépend de la LUMIÈRE
##     sur Élias (Lighting), de la distance, et de sa posture (accroupi : moins
##     visible). Voir visibility_of().
##   - OUÏE : chaque son joué par l'AudioManager a un rayon de bruit ; chaque mur
##     entre le bruit et elle réduit ce rayon (wall_attenuation).
##   - Les indices remplissent une JAUGE DE SUSPICION (0 à 1). Ses seuils
##     décident des états : alerte (0,25), recherche (0,5), combat (1, s'il est
##     en vue). Une silhouette nette (visibilité ≥ clear_sight) la remplit d'un
##     coup ; une silhouette dans la pénombre, peu à peu.
##   - Mode classique : ni lumière ni jauge. Elle voit Élias dès qu'il est dans
##     son champ de vision, comme dans les jeux d'origine.
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
## Vrai si elle perçoit Élias en ce moment (visibilité ≥ track_visibility).
var sees_target: bool = false
## Ce qu'elle perçoit d'Élias en ce moment, de 0 (rien) à 1 (parfaitement).
var visibility: float = 0.0
## Jauge de suspicion : 0 = calme, 1 = certaine qu'un intrus est là.
var suspicion: float = 0.0
## Dernier indice (bruit entendu, silhouette entrevue) : où regarder, où chercher.
var last_clue: Vector2 = Vector2.ZERO
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

## Humeurs connues : chacune a son son « creature_<humeur> » dans la bibliothèque.
const MOODS: Array[StringName] = [&"calm", &"curious", &"alert", &"search", &"death"]
## Pas des Sentinelles : plus discrets que ceux d'Élias, et sans rayon de bruit
## (elles ne s'alertent pas entre elles au bruit de leurs pas).
const STEP_VOLUME_OFFSET_DB: float = -12.0


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(RewindManager.GROUP)  # enregistrée pour le rembobinage (J4)
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
		visibility = visibility_of(target)
		sees_target = visibility >= config.track_visibility
		if sees_target:
			last_seen_position = target.global_position
			last_clue = target.global_position
			time_since_seen = 0.0
		else:
			time_since_seen += delta
		_update_suspicion(delta)
	machine.physics_update(delta)


## La jauge de suspicion suit ce qu'elle voit : une silhouette nette la remplit
## d'un coup, une silhouette dans la pénombre peu à peu. En patrouille, elle
## retombe aussi d'elle-même (suspicion_decay) : une silhouette trop vague ne
## l'inquiète jamais. En alerte ou en recherche, elle garde ses soupçons.
func _update_suspicion(delta: float) -> void:
	if visibility >= config.clear_sight:
		suspicion = 1.0
		return
	var change: float = visibility * config.sight_gain
	if machine.current_name == &"Patrol":
		change -= config.suspicion_decay
	suspicion = clampf(suspicion + change * delta, 0.0, 1.0)


# --------------------------------------------------------------------------
# Sens
# --------------------------------------------------------------------------

## Vrai si elle voit « who » en ce moment (même faiblement).
func can_see(who: Player) -> bool:
	return visibility_of(who) >= config.track_visibility


## Ce qu'elle perçoit de « who », de 0 (rien) à 1 (parfaitement) :
##   1. il doit être dans son champ de vision : devant elle, pas trop loin, à peu
##      près à sa hauteur, dans son cône de vision (sauf tout près), et sa tête
##      ou son buste ne doit pas être caché par le décor ;
##   2. tout près (close_distance), elle le remarque même dans le noir : 1 ;
##   3. sinon : lumière perçue (lumière ^ light_exponent) × (crouch_visibility
##      s'il est accroupi) × (1 - (distance / view_distance)²).
## En mode classique, l'étape 3 disparaît : dans son champ de vision = 1.
func visibility_of(who: Player) -> float:
	if who == null or not is_instance_valid(who) or who.is_dead:
		return 0.0
	var to: Vector2 = who.global_position - global_position
	if absf(to.x) > config.view_distance or absf(to.y) > config.view_height:
		return 0.0
	var distance: float = to.length()
	var eye: Vector2 = global_position + Vector2(0.0, -config.eye_height)
	var height: float = who.config.crouch_height if who.is_crouched else who.config.stand_height
	var seen_point: Variant = null
	for part: float in [0.85, 0.5]:  # tête, puis buste
		var point: Vector2 = who.global_position + Vector2(0.0, -height * part)
		var dir: Vector2 = point - eye
		if absf(dir.x) > 8.0:
			if signf(dir.x) != facing:
				continue  # derrière elle
			if distance > config.close_distance and absf(atan2(dir.y, absf(dir.x))) > deg_to_rad(config.view_half_angle):
				continue  # hors du cône de vision
		if _ray(eye, point).is_empty():
			seen_point = point
			break
	if seen_point == null:
		return 0.0
	if GameState.is_classic_mode() or distance <= config.close_distance:
		return 1.0
	var light: float = pow(Lighting.level_at(self, seen_point), config.light_exponent)
	var posture: float = config.crouch_visibility if who.is_crouched else 1.0
	var ratio: float = distance / config.view_distance
	return clampf(light * posture * (1.0 - ratio * ratio), 0.0, 1.0)


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


## Bruit diffusé par l'AudioManager. Chaque mur entre le bruit et elle réduit
## le rayon (wall_attenuation) ; si elle est dans le rayon qui reste, elle
## l'entend : sa suspicion monte, d'autant plus que le bruit est proche.
func _on_noise(at: Vector2, radius: float, source: Node) -> void:
	if is_dead or source == self:
		return
	var heard_radius: float = heard_radius_of(at, radius)
	var distance: float = global_position.distance_to(at)
	if heard_radius <= 0.0 or distance > heard_radius:
		return
	var closeness: float = 1.0 - distance / heard_radius
	hear(at, lerpf(config.noise_suspicion_far, config.noise_suspicion_near, closeness))


## Rayon auquel elle entend un bruit de rayon « radius » émis en « at » : réduit
## de moitié (wall_attenuation) par chaque mur traversé.
func heard_radius_of(at: Vector2, radius: float) -> float:
	var ear: Vector2 = global_position + Vector2(0.0, -config.eye_height)
	# La source est un peu relevée : un bruit de pas naît au ras du sol.
	var walls: int = walls_between(at + Vector2(0.0, -24.0), ear)
	return radius * config.hearing_factor * pow(config.wall_attenuation, walls)


## Nombre de blocs de décor traversés par le segment « from » -> « to » (au plus 4).
func walls_between(from: Vector2, to: Vector2) -> int:
	var exclude: Array[RID] = [get_rid()]
	var count: int = 0
	while count < 4:
		var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD, exclude)
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit["rid"])
		count += 1
	return count


## Un indice entendu (ou fourni par un test) : la suspicion monte de « amount »,
## puis l'état courant décide quoi en faire (se tourner, aller voir…).
func hear(at: Vector2, amount: float) -> void:
	suspicion = minf(suspicion + amount, 1.0)
	last_clue = at
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
	if MOODS.has(mood):
		var player: Node = AudioManager.play_sfx(StringName("creature_" + String(mood)), global_position + Vector2(0, -80), self)
		if player:
			player.set(&"pitch_scale", _voice_pitch)


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
	visibility = 0.0
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
	visibility = 0.0
	suspicion = 0.0
	time_since_seen = INF
	collision_layer = PhysicsLayers.ENEMIES
	facing = start_facing
	energy.refill()
	weapon.reset()
	machine.transition_to(&"Patrol")


# --------------------------------------------------------------------------
# Rembobinage (J4) : voir RewindManager
# --------------------------------------------------------------------------

func capture_state() -> Dictionary:
	return {
		"position": global_position, "velocity": velocity, "facing": facing, "dead": is_dead,
		"sees": sees_target, "last_seen": last_seen_position, "since_seen": time_since_seen,
		"visibility": visibility, "suspicion": suspicion, "clue": last_clue,
		"rng": rng.state, "state": machine.current_name,
		"state_data": machine.current.snapshot() if machine.current else {},
		"energy": energy.capture_state(), "shield_broken": weapon.shield.broken_timer,
		"pose": visual.capture_pose(),
	}


## Replace la Sentinelle (une Sentinelle tuée pendant les secondes remontées
## se relève : sa mort « n'a pas encore eu lieu »).
func apply_state(state: Dictionary) -> void:
	global_position = state["position"]
	velocity = state["velocity"]
	facing = state["facing"]
	is_dead = state["dead"]
	collision_layer = 0 if is_dead else PhysicsLayers.ENEMIES
	sees_target = state["sees"]
	visibility = state["visibility"]
	suspicion = state["suspicion"]
	last_clue = state["clue"]
	last_seen_position = state["last_seen"]
	time_since_seen = state["since_seen"]
	rng.state = state["rng"]  # le hasard repart du même point : même décision de bouclier
	energy.apply_state(state["energy"])
	weapon.reset()
	weapon.shield.broken_timer = state["shield_broken"]
	visual.restore_pose(state["pose"])


func resume_state(state: Dictionary) -> void:
	var data: Dictionary = (state["state_data"] as Dictionary).duplicate()
	data["resumed"] = true
	machine.transition_to(state["state"], data)


func _on_checkpoint_reached(_checkpoint_id: StringName) -> void:
	if is_dead:
		_stays_dead = true


func _on_anim_event(event_name: StringName) -> void:
	match event_name:
		&"footstep", &"footstep_run":
			AudioManager.play_sfx(&"foley_step_stone", global_position, self, STEP_VOLUME_OFFSET_DB, 0.0)
		&"body_fall":
			AudioManager.play_sfx(&"foley_body_fall", global_position, self)


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)
