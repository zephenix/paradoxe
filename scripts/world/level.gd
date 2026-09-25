class_name Level
extends Node2D
## Script d'un niveau : relie Élias, la caméra et les salles, et gère la mort.
##
## Mort et réapparition (J3) : après un court délai (on voit Élias tomber), un
## fondu au noir ; pendant le noir, les tirs en vol sont effacés et Élias
## réapparaît au DERNIER CHECKPOINT atteint (ou à son point de départ s'il n'en
## a touché aucun), jauge d'énergie pleine. Sa réapparition prévient les
## ennemis (Events.player_respawned), qui reprennent leur poste. Le tout prend
## moins de 2 secondes (PLAN §5.7 ; réglages dans resources/world/respawn.tres).
## J4 ajoutera le choix « rembobiner » avant ce retour au checkpoint.
##
## « Pause » ramène à l'écran titre (le menu pause arrive en J9).

## Réglages de la réapparition (délai, fondus, vide sans fond).
@export var respawn: RespawnConfig = preload("res://resources/world/respawn.tres")
## Commencer une nouvelle partie en chargeant ce niveau (oublie les checkpoints
## d'une partie précédente, gardés par l'autoload GameState).
@export var new_game_on_start: bool = true

@onready var player: Player = $Elias
@onready var camera: CameraDirector = $CameraDirector

## Point de départ d'Élias (réapparition tant qu'aucun checkpoint n'est atteint).
var _start_position: Vector2
var _start_facing: int = 1


func _ready() -> void:
	if new_game_on_start:
		GameState.new_game()
	_start_position = player.global_position
	_start_facing = player.facing
	camera.target = player
	player.died.connect(_on_player_died)
	player.kill_y = _lowest_room_bottom() + respawn.kill_margin
	camera.snap_to_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		SceneTransition.change_scene("res://scenes/ui/title_screen.tscn")


## Où Élias réapparaîtra s'il meurt maintenant : [position des pieds, sens du regard].
func respawn_point() -> Array:
	if GameState.has_checkpoint():
		return [GameState.checkpoint_position, GameState.checkpoint_facing]
	return [_start_position, _start_facing]


func _on_player_died(_cause: StringName) -> void:
	await get_tree().create_timer(respawn.delay).timeout
	# Si le joueur a quitté le niveau entre-temps (Échap), on n'insiste pas.
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	await SceneTransition.fade_out(respawn.fade_out)
	if SceneTransition.is_changing_scene or not is_inside_tree():
		return
	clear_projectiles()
	var point: Array = respawn_point()
	player.respawn(point[0], point[1])
	camera.snap_to_target()
	await SceneTransition.fade_in(respawn.fade_in)


## Efface tous les tirs en vol (réapparition ; le rembobinage de J4 aussi).
func clear_projectiles() -> void:
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		node.queue_free()


func _lowest_room_bottom() -> float:
	var bottom: float = -INF
	for node in get_tree().get_nodes_in_group(&"rooms"):
		bottom = maxf(bottom, (node as Room).world_rect().end.y)
	return bottom if bottom > -INF else 1000.0
