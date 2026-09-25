class_name Level
extends Node2D
## Script d'un niveau : relie Élias, la caméra et les salles, et gère la mort.
##
## J2 : à la mort, Élias réapparaît au point de départ de la dernière salle
## visitée (les vrais checkpoints arrivent en J3). « Pause » ramène à l'écran
## titre (le menu pause arrive en J9).

## Délai entre la mort et la réapparition (secondes).
@export var respawn_delay: float = 1.4
## Marge sous la salle la plus basse au-delà de laquelle on meurt (vide sans fond).
@export var kill_margin: float = 400.0

@onready var player: Player = $Elias
@onready var camera: CameraDirector = $CameraDirector

var _respawn_room: Room


func _ready() -> void:
	camera.target = player
	camera.room_changed.connect(_on_room_changed)
	player.died.connect(_on_player_died)
	player.kill_y = _lowest_room_bottom() + kill_margin
	camera.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		SceneTransition.change_scene("res://scenes/ui/title_screen.tscn")


func _on_room_changed(room: Room) -> void:
	if not player.is_dead:
		_respawn_room = room


func _on_player_died(_cause: StringName) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	await SceneTransition.fade_out(0.25)
	var room: Room = _respawn_room if _respawn_room else camera.current_room
	if room:
		player.respawn(room.spawn_point(), 1)
	camera.snap_to_target()
	await SceneTransition.fade_in(0.35)


func _lowest_room_bottom() -> float:
	var bottom: float = -INF
	for node in get_tree().get_nodes_in_group(&"rooms"):
		bottom = maxf(bottom, (node as Room).world_rect().end.y)
	return bottom if bottom > -INF else 1000.0
