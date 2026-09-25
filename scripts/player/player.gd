class_name Player
extends CharacterBody2D
## Élias : corps physique, capteurs et outils communs à tous ses états.
##
## Ce script ne décide RIEN du comportement : ce sont les états (dossier
## scripts/player/states/) qui décident, via la machine à états. Ici on trouve
## seulement ce dont ils ont besoin : se déplacer, tomber, détecter un rebord,
## savoir si l'on tient debout sous un plafond, mourir, réapparaître.
##
## Repère : l'origine du nœud est AUX PIEDS d'Élias, au milieu. En 2D dans
## Godot, x va vers la droite et y vers le BAS (donc « monter » = y diminue).

## Émis quand Élias meurt (cause : &"fall", &"hazard"…).
signal died(cause: StringName)
## Émis à chaque atterrissage, avec la hauteur de chute en blocs.
signal landed(fall_blocks: float)
## Émis par les animations (pas, prise de rebord…) : sert aux sons.
signal anim_event(event_name: StringName)

## Réglages de déplacement (fichier .tres modifiable sans toucher au code).
@export var config: PlayerMovementConfig = preload("res://resources/player/player_movement.tres")
## Sens du regard au départ : 1 = droite, -1 = gauche.
@export_enum("Gauche:-1", "Droite:1") var start_facing: int = 1

## Sens du regard : 1 = droite, -1 = gauche.
var facing: int = 1:
	set(value):
		facing = 1 if value >= 0 else -1
		if visual:
			visual.set_facing(facing)
## Intentions du joueur (clavier, manette, ou tests).
var input := PlayerInput.new()
## Invulnérable (roulade d'esquive, J3).
var is_invulnerable: bool = false
## Plus haut point atteint depuis qu'Élias a quitté le sol (y le plus petit).
var air_top_y: float = 0.0
## Temps écoulé depuis le dernier contact avec le sol.
var time_since_grounded: float = 0.0
## Délai pendant lequel on ne peut pas se raccrocher (après avoir lâché un rebord).
var grab_cooldown: float = 0.0
## Hauteur (y) au-delà de laquelle Élias meurt de sa chute (vide sans fond).
var kill_y: float = INF
## Vrai une fois mort (jusqu'à la réapparition).
var is_dead: bool = false
var is_crouched: bool = false

@onready var visual: CharacterVisual = $Visual
@onready var machine: StateMachine = $StateMachine
@onready var _shape_node: CollisionShape2D = $CollisionShape2D

var _shape := RectangleShape2D.new()


func _ready() -> void:
	collision_layer = PhysicsLayers.PLAYER
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 6.0
	_shape_node.shape = _shape
	set_crouched(false)
	facing = start_facing
	visual.anim_event.connect(func(event_name: StringName) -> void: anim_event.emit(event_name))
	air_top_y = global_position.y
	machine.setup(self)


func _physics_process(delta: float) -> void:
	input.update(delta)
	grab_cooldown = maxf(grab_cooldown - delta, 0.0)
	if is_on_floor():
		time_since_grounded = 0.0
	else:
		time_since_grounded += delta
		air_top_y = minf(air_top_y, global_position.y)
	machine.physics_update(delta)
	if not is_dead and global_position.y > kill_y:
		kill(&"fall")


# --------------------------------------------------------------------------
# Règles générales
# --------------------------------------------------------------------------

## Vrai sauf en mode classique : active glissade, rattrapage automatique,
## esquive, tampon d'entrée et « temps du coyote » (évolution 1 du plan).
func modern() -> bool:
	return not GameState.is_classic_mode()


## Fenêtre du tampon d'entrée (quasi nulle en mode classique).
func buffer_window() -> float:
	return config.input_buffer_time if modern() else 0.02


## Vrai si « action » a été pressée récemment (et consomme l'appui).
func wants(action: StringName) -> bool:
	return input.consume(action, buffer_window())


# --------------------------------------------------------------------------
# Déplacement
# --------------------------------------------------------------------------

func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)


## Rapproche la vitesse horizontale de « target » (accélération ou freinage
## progressifs), applique la gravité et déplace le corps.
func move_on_ground(target_speed: float, delta: float) -> void:
	var rate: float = config.ground_acceleration if absf(target_speed) > absf(velocity.x) else config.ground_deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	apply_gravity(delta)
	move_and_slide()


## Déplacement en l'air : trajectoire balistique, sans contrôle (saut « engagé »).
func move_in_air(delta: float) -> void:
	apply_gravity(delta)
	move_and_slide()


## Le joueur vient de toucher le sol : choisit la réception selon la hauteur
## de chute (sans conséquence, lourde, roulade obligatoire, mortelle).
func land() -> void:
	var fall_blocks: float = (global_position.y - air_top_y) / config.block_size
	air_top_y = global_position.y
	landed.emit(fall_blocks)
	if fall_blocks > config.deadly_fall_blocks:
		kill(&"fall")
	elif fall_blocks > config.safe_fall_blocks:
		machine.transition_to(&"Roll", {"landing": true})
	elif fall_blocks > config.heavy_land_blocks:
		machine.transition_to(&"Land", {"heavy": true})
	else:
		machine.transition_to(&"Land", {"heavy": false})


## Démarre un saut. kind : &"vertical", &"standing" ou &"running".
func start_jump(kind: StringName) -> void:
	machine.transition_to(&"Jump", {"kind": kind})


## Appui sur « haut » : se hisser si un rebord est à portée de main, sinon
## sauter à la verticale (en se raccrochant au rebord s'il y en a un plus haut).
func climb_or_jump_up() -> void:
	var reach: float = config.hang_hand_height + config.grab_tolerance
	var ledge: Dictionary = find_ledge(8.0, reach)
	if not ledge.is_empty() and ledge["can_stand"]:
		machine.transition_to(&"LedgeClimb", {"ledge": ledge})
	else:
		start_jump(&"vertical")


## En l'air : se raccroche à un rebord si les mains passent à sa hauteur.
## En mode classique, il faut maintenir « haut » (pas de rattrapage automatique).
func try_grab() -> bool:
	if grab_cooldown > 0.0 or (not modern() and not input.up):
		return false
	var ledge: Dictionary = find_ledge(config.hang_hand_height - config.grab_tolerance,
			config.hang_hand_height + config.grab_tolerance)
	if ledge.is_empty():
		return false
	var point: Vector2 = ledge["point"]
	var hang_position := Vector2(point.x - facing * config.body_width * 0.5, point.y + config.hang_hand_height)
	if not is_space_free(hang_position, config.stand_height):
		return false
	global_position = hang_position
	velocity = Vector2.ZERO
	machine.transition_to(&"LedgeHang", {"ledge": ledge})
	return true


# --------------------------------------------------------------------------
# Posture
# --------------------------------------------------------------------------

## Change la boîte de collision (debout ou accroupi). L'origine reste aux pieds.
func set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	var height: float = config.crouch_height if crouched else config.stand_height
	_shape.size = Vector2(config.body_width, height)
	_shape_node.position = Vector2(0.0, -height * 0.5)


## Vrai s'il y a la place de se tenir debout ici (pas de plafond bas).
func can_stand() -> bool:
	return is_space_free(global_position, config.stand_height)


# --------------------------------------------------------------------------
# Capteurs (questions posées au moteur physique)
# --------------------------------------------------------------------------

## Cherche, devant Élias, un rebord dont le dessus est entre min_height et
## max_height pixels au-dessus des pieds.
## Renvoie {} si rien, sinon {"point": coin du rebord, "can_stand": bool}.
func find_ledge(min_height: float, max_height: float) -> Dictionary:
	var feet: Vector2 = global_position
	var half: float = config.body_width * 0.5
	var probe_x: float = feet.x + facing * (half + config.grab_reach)
	# 1) Un rayon vertical, juste devant, cherche le dessus d'un bloc.
	var top_hit: Dictionary = _ray(Vector2(probe_x, feet.y - max_height - 2.0), Vector2(probe_x, feet.y - min_height + 2.0))
	if top_hit.is_empty() or top_hit["normal"].y > -0.7:
		return {}
	var top_y: float = top_hit["position"].y
	# 2) Un rayon horizontal, juste sous ce dessus, trouve la face du mur.
	var wall_hit: Dictionary = _ray(Vector2(feet.x, top_y + 3.0), Vector2(probe_x + facing * 2.0, top_y + 3.0))
	if wall_hit.is_empty() or absf(wall_hit["normal"].x) < 0.7:
		return {}
	var wall_x: float = wall_hit["position"].x
	# 3) Juste au-dessus du rebord, il faut du vide (sinon ce n'est pas un rebord).
	if not _ray(Vector2(feet.x, top_y - 6.0), Vector2(wall_x + facing * 10.0, top_y - 6.0)).is_empty():
		return {}
	var stand_spot := Vector2(wall_x + facing * (half + 4.0), top_y)
	return {"point": Vector2(wall_x, top_y), "can_stand": is_space_free(stand_spot, config.stand_height)}


## Profondeur du vide à « offset » pixels devant les pieds (INF si pas de sol
## trouvé à moins de max_depth pixels).
func drop_depth_ahead(offset: float, max_depth: float = 2000.0) -> float:
	var x: float = global_position.x + facing * offset
	var hit: Dictionary = _ray(Vector2(x, global_position.y - 4.0), Vector2(x, global_position.y + max_depth))
	if hit.is_empty():
		return INF
	return hit["position"].y - global_position.y


## Si Élias se tient au bord d'un vide, renvoie {"edge_x": abscisse du bord},
## sinon {}. Sert à descendre d'un rebord.
func find_edge_ahead() -> Dictionary:
	var half: float = config.body_width * 0.5
	var step: float = 2.0
	var offset: float = -half
	while offset <= half + 12.0:
		if drop_depth_ahead(offset, config.block_size * 0.5 + 8.0) > config.block_size * 0.5:
			var edge_x: float = global_position.x + facing * (offset - step * 0.5)
			return {"edge_x": edge_x}
		offset += step
	return {}


## Vrai si une boîte de la taille d'Élias (pieds en « feet ») ne touche aucun décor.
func is_space_free(feet: Vector2, height: float) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(config.body_width - 2.0, height - 2.0)
	query.shape = box
	query.transform = Transform2D(0.0, feet + Vector2(0.0, -height * 0.5))
	query.collision_mask = PhysicsLayers.WORLD
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)


# --------------------------------------------------------------------------
# Vie et mort
# --------------------------------------------------------------------------

func kill(cause: StringName) -> void:
	if is_dead:
		return
	is_dead = true
	machine.transition_to(&"Dead", {"cause": cause})
	died.emit(cause)
	Events.player_died.emit(cause)


## Réapparition (au checkpoint en J3 ; au début de la salle en J2).
func respawn(at: Vector2, new_facing: int = 1) -> void:
	global_position = at
	velocity = Vector2.ZERO
	is_dead = false
	is_invulnerable = false
	grab_cooldown = 0.0
	air_top_y = at.y
	input.clear()
	set_crouched(false)
	facing = new_facing
	machine.transition_to(&"Idle")
	Events.player_respawned.emit()
