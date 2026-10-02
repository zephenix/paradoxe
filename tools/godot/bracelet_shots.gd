extends SceneTree
## Captures de l'hologramme du bracelet et du ramassage des pierres (J9), dans
## l'écran 6 (ruines, de nuit : l'hologramme ne doit pas s'y assombrir) :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --fixed-fps 60 -s res://tools/godot/bracelet_shots.gd -- build/shots/bracelet
## Images : wrist.png (bracelet ouvert, Élias regarde son poignet), pick.png
## (accroupi sur les gravats), pockets.png (compteur après ramassage),
## running.png (ouvert en courant, écran 7). (Non typé : un script -s est compilé
## avant les autoloads.)

var _out: String = "build/shots/bracelet"
var _level: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://scenes/levels/prototype.tscn") as PackedScene).instantiate()
	_level.set(&"play_opening", false)
	root.add_child(_level)
	_tour.call_deferred()


func _tour() -> void:
	for i in 5:
		await process_frame
	var player: Node = _level.get_node("Elias")
	var input: Object = player.get(&"input")
	input.set(&"from_devices", false)
	# Écran 6 : à gauche du tas de gravats (x = 1900 dans la salle, posée en 0, 2400).
	await _place(player, Vector2(1840.0, 3072.0))
	input.call(&"press", &"bracelet")
	await _frames(40)
	_shot("wrist")
	player.get(&"bracelet").call(&"hide_now")
	await _frames(10)
	input.call(&"press", &"interact")
	await _frames(22)
	_shot("pick")
	await _frames(50)
	_shot("pockets")
	# Écran 7 (hall éclairé) : en courant.
	player.get(&"bracelet").call(&"hide_now")
	await _place(player, Vector2(2700.0, 3072.0))
	input.set(&"move", 1)
	input.set(&"run", true)
	await _frames(30)
	input.call(&"press", &"bracelet")
	await _frames(14)
	_shot("running")
	quit()


func _place(player: Node, at: Vector2) -> void:
	player.set(&"global_position", at)
	player.set(&"air_top_y", at.y)
	_level.get_node("CameraDirector").call(&"snap_to_target")
	await _frames(40)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(shot_name: String) -> void:
	var path: String = _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("Capture ", path)
