class_name Companion
extends CharacterBody2D
## Le compagnon (J7, PLAN §5.6) : un vieil homme évadé avec Élias. Comme pour
## Élias et les Sentinelles, ce script ne DÉCIDE rien : ses états
## (scripts/companion/states/) le font. Ici : ses gestes, sa voix, et les ordres
## qu'il reçoit.
##
## Ordres (touche « Ordre », lus par Élias) :
##   - appui COURT : bascule Suivre / Attendre ;
##   - appui LONG près d'un mécanisme marqué d'une spirale : « Active ça ». Il
##     s'y rend, l'actionne, puis attend sur place (utile sur une plaque de
##     pression, ou près d'un levier qu'il faudra actionner encore).
## Il répond par un geste et quelques mots d'une langue inconnue : l'intonation
## dit « d'accord », « je te suis », « j'attends », ou « rien à faire ici ».
##
## Pendant une cinématique, il passe dans l'état Scripted : la cinématique le
## déplace et l'anime elle-même.
## Repère : l'origine du nœud est à ses pieds.

## Réglages.
@export var config: CompanionConfig = preload("res://resources/characters/companion.tres")
## Sens du regard au départ.
@export_enum("Gauche:-1", "Droite:1") var start_facing: int = -1
## Mode au départ : &"Wait" (il attend) ou &"Follow" (il suit).
@export var start_mode: StringName = &"Wait"

## Sens du regard : 1 = droite, -1 = gauche.
var facing: int = -1:
	set(value):
		facing = 1 if value >= 0 else -1
		if visual:
			visual.set_facing(facing)
## Élias (groupe « player »).
var target: Player
## Mode choisi par les ordres : &"Follow" ou &"Wait" (Activate revient à Wait).
var mode: StringName = &"Wait"

@onready var visual: CharacterVisual = $Visual
@onready var machine: StateMachine = $StateMachine

const VOICES: Dictionary = {
	&"ok": &"companion_ok", &"follow": &"companion_follow", &"wait": &"companion_wait",
	&"no": &"companion_no", &"surprise": &"companion_surprise",
}


func _ready() -> void:
	add_to_group(&"companion")
	add_to_group(RewindManager.GROUP)
	collision_layer = PhysicsLayers.COMPANION
	collision_mask = PhysicsLayers.WORLD
	floor_snap_length = 6.0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(config.body_width, config.body_height)
	var shape_node: CollisionShape2D = $CollisionShape2D
	shape_node.shape = shape
	shape_node.position = Vector2(0.0, -config.body_height * 0.5)
	facing = start_facing
	mode = start_mode
	visual.anim_event.connect(_on_anim_event)
	machine.initial_state = start_mode
	machine.setup(self)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player
	machine.physics_update(delta)


# --------------------------------------------------------------------------
# Ordres (donnés par Élias)
# --------------------------------------------------------------------------

## Appui court : suivre <-> attendre.
func order_toggle() -> void:
	if machine.current_name == &"Scripted":
		return
	mode = &"Wait" if mode == &"Follow" else &"Follow"
	if mode == &"Follow":
		say(&"follow")
		gesture(&"beckon")
	else:
		say(&"wait")
		gesture(&"halt")
	machine.transition_to(mode)


## Appui long : « Active ça ». null = rien à actionner près d'Élias : refus.
func order_activate(item: Interactable) -> void:
	if machine.current_name == &"Scripted":
		return
	if item == null or not item.companion_can_use:
		refuse()
		return
	say(&"ok")
	machine.transition_to(&"Activate", {"target": item})


## « Rien à faire ici » : un petit geste de dénégation.
func refuse() -> void:
	say(&"no")
	gesture(&"halt")


## Cinématique : il ne bouge plus de lui-même (vrai), ou reprend son mode (faux).
func set_scripted(scripted: bool) -> void:
	if scripted:
		machine.transition_to(&"Scripted")
	elif machine.current_name == &"Scripted":
		machine.transition_to(mode)


# --------------------------------------------------------------------------
# Gestes
# --------------------------------------------------------------------------

func say(mood: StringName) -> void:
	if VOICES.has(mood):
		AudioManager.play_sfx(VOICES[mood], global_position + Vector2(0, -80), self)


## Un geste (animation), puis retour à l'animation de repos.
func gesture(animation: StringName) -> void:
	visual.play(animation, config.gesture_time)


func apply_gravity(delta: float) -> void:
	velocity.y = minf(velocity.y + config.gravity * delta, config.max_fall_speed)


## Rapproche la vitesse horizontale de « target_speed », applique la gravité et
## déplace le corps. Il s'arrête devant un mur ou un vide.
func move_at(target_speed: float, delta: float) -> void:
	if target_speed != 0.0 and not can_walk_toward(1 if target_speed > 0.0 else -1):
		target_speed = 0.0
	velocity.x = move_toward(velocity.x, target_speed, config.acceleration * delta)
	apply_gravity(delta)
	move_and_slide()


## Vrai s'il peut avancer dans la direction « dir » : pas de mur devant, pas de vide.
func can_walk_toward(dir: int) -> bool:
	var ahead: float = config.body_width * 0.5 + 6.0
	var feet: Vector2 = global_position
	var mid: float = -config.body_height * 0.5
	if not _ray(feet + Vector2(0.0, mid), feet + Vector2(dir * ahead, mid)).is_empty():
		return false
	var max_drop: float = config.max_step_down_blocks * GameUnits.BLOCK
	var probe_x: float = feet.x + dir * ahead
	return not _ray(Vector2(probe_x, feet.y - 4.0), Vector2(probe_x, feet.y + max_drop + 2.0)).is_empty()


func face_toward(point: Vector2) -> void:
	if absf(point.x - global_position.x) > 4.0:
		facing = 1 if point.x > global_position.x else -1


## Idle, marche ou course (sans relancer une animation déjà en cours, ni
## interrompre un geste).
func play_locomotion(speed: float) -> void:
	var anim: StringName = &"idle"
	var duration: float = -1.0
	if absf(speed) > config.walk_speed + 10.0:
		anim = &"run"
		duration = config.run_cycle_duration
	elif absf(speed) > 5.0:
		anim = &"walk"
		duration = config.walk_cycle_duration
	if anim == &"idle" and visual.current in [&"beckon", &"halt", &"interact", &"touch_pendant"]:
		return  # on laisse finir le geste
	if visual.current != anim:
		visual.play(anim, duration)


## L'ascenseur dont la plate-forme est à son niveau (pour rejoindre Élias à un
## autre étage), ou null.
func elevator_at_my_level() -> Elevator:
	for node in get_tree().get_nodes_in_group(&"elevators"):
		var elevator: Elevator = node as Elevator
		if elevator and absf(elevator.top_y() - global_position.y) < 8.0 \
				and (elevator.is_at_top() or elevator.is_at_bottom()):
			return elevator
	return null


## Appelé par un projectile : le compagnon n'est pas une cible (les tirs le traversent).
func take_hit(_projectile: Node) -> bool:
	return false


# --------------------------------------------------------------------------
# Rembobinage : voir RewindManager
# --------------------------------------------------------------------------

func capture_state() -> Dictionary:
	return {
		"position": global_position, "velocity": velocity, "facing": facing, "mode": mode,
		"state": machine.current_name, "state_data": machine.current.snapshot() if machine.current else {},
		"pose": visual.capture_pose(),
	}


func apply_state(state: Dictionary) -> void:
	global_position = state["position"]
	velocity = state["velocity"]
	facing = state["facing"]
	mode = state["mode"]
	visual.restore_pose(state["pose"])


func resume_state(state: Dictionary) -> void:
	var data: Dictionary = (state["state_data"] as Dictionary).duplicate()
	data["resumed"] = true
	# Un geste « Activate » en cours ne se reprend pas à moitié : il attend.
	var resume_as: StringName = state["state"] if state["state"] in [&"Follow", &"Wait", &"Scripted"] else mode
	machine.transition_to(resume_as, data)


func _on_anim_event(event_name: StringName) -> void:
	if event_name in [&"footstep", &"footstep_run"]:
		# Pas discrets, qui ne portent pas (il sait se faire oublier).
		AudioManager.play_sfx(&"foley_step_stone", global_position, self, -10.0, 0.0)


func _ray(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, PhysicsLayers.WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query)
