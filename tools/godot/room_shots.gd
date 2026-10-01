extends SceneTree
## Captures d'écran rapides d'un endroit du prototype, pour régler un décor :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --fixed-fps 60 -s res://tools/godot/room_shots.gd -- build/shots/x nom:x:y [nom:x:y…]
## x, y : pieds d'Élias (monde). Chaque capture s'appelle <nom>.png. Plus complet :
## prototype_tour.gd. (Non typé : un script -s est compilé avant les autoloads.)

var _out: String = "build/shots"
var _stops: Array = []
var _level: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for i in range(1, args.size()):
		var parts: PackedStringArray = args[i].split(":")
		_stops.append([parts[0], float(parts[1]), float(parts[2])])
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load("res://scenes/levels/prototype.tscn") as PackedScene).instantiate()
	_level.set(&"play_opening", false)
	root.add_child(_level)
	_tour.call_deferred()


func _tour() -> void:
	for i in 5:
		await process_frame
	var player: Node = _level.get_node("Elias")
	player.get(&"input").set(&"from_devices", false)
	for stop: Array in _stops:
		player.set(&"global_position", Vector2(stop[1], stop[2]))
		player.set(&"air_top_y", float(stop[2]))
		_level.get_node("CameraDirector").call(&"snap_to_target")
		for i in 40:
			await process_frame
		var path: String = _out.path_join(String(stop[0]) + ".png")
		root.get_texture().get_image().save_png(path)
		print("Capture ", path)
	quit()
