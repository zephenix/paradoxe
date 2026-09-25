class_name Level
extends Node2D
## Script d'un niveau : relie Élias, la caméra et les salles, et gère la mort.
##
## J2 : à la mort, Élias réapparaît au point de départ de la dernière salle où
## il s'est tenu debout (les vrais checkpoints arrivent en J3). « Pause » ramène
## à l'écran titre (le menu pause arrive en J9).

## Réglages de la réapparition (délai, fondus, vide sans fond).
@export var respawn: RespawnConfig = preload("res://resources/world/respawn.tres")

@onready var player: Player = $Elias
@onready var camera: CameraDirector = $CameraDirector

## Salle où Élias réapparaîtra. On ne la retient que lorsqu'il a les pieds sur
## un sol sûr : traverser une salle en tombant (le puits) ne compte pas.
var _respawn_room: Room


func _ready() -> void:
	camera.target = player
	player.died.connect(_on_player_died)
	player.kill_y = _lowest_room_bottom() + respawn.kill_margin
	camera.snap_to_target()
	_respawn_room = camera.current_room


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		SceneTransition.change_scene("res://scenes/ui/title_screen.tscn")


## Salle dont la réapparition est la plus récente (pour les tests).
func respawn_room() -> Room:
	return _respawn_room


func _physics_process(_delta: float) -> void:
	# À chaque image où Élias a les pieds au sol (vivant), la salle qui le
	# contient devient la salle de réapparition. Traverser une salle en tombant
	# (le puits) ne la change donc pas.
	if player.is_on_floor() and not player.is_dead:
		var room: Room = camera.room_at(player.global_position + Vector2(0, -camera.target_height))
		if room:
			_respawn_room = room


func _on_player_died(_cause: StringName) -> void:
	await get_tree().create_timer(respawn.delay).timeout
	# Si le joueur a quitté le niveau entre-temps (Échap), on n'insiste pas.
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	await SceneTransition.fade_out(respawn.fade_out)
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	var room: Room = _respawn_room if _respawn_room else camera.current_room
	if room:
		player.respawn(room.spawn_point(), 1)
	camera.snap_to_target()
	await SceneTransition.fade_in(respawn.fade_in)


func _lowest_room_bottom() -> float:
	var bottom: float = -INF
	for node in get_tree().get_nodes_in_group(&"rooms"):
		bottom = maxf(bottom, (node as Room).world_rect().end.y)
	return bottom if bottom > -INF else 1000.0
