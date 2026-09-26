extends SceneTree
## Visite guidée du PROTOTYPE (J8) avec captures d'écran : Élias est déposé à des
## endroits choisis de chaque écran, sans cinématique d'ouverture.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --fixed-fps 60 -s res://tools/godot/prototype_tour.gd -- build/shots
## Les téléportations ne vérifient PAS que le niveau se parcourt : c'est le rôle
## de tests/unit/test_prototype_*.gd. (Non typé : script -s compilé avant les autoloads.)

## [nom de la capture, x, y (pieds d'Élias, monde), images d'attente]
const STOPS: Array = [
	["proto_2a_arrivee", -4950.0, 672.0, 30],
	["proto_2b_enseigne", -4380.0, 672.0, 30],
	["proto_2c_corniche", -3380.0, 672.0, 30],
	["proto_3a_toits", -2300.0, 576.0, 30],
	["proto_3b_poutre", -1180.0, 384.0, 30],
	["proto_3c_balcon", -800.0, 480.0, 30],
	["proto_3d_descente", -300.0, 480.0, 30],
	["proto_4_clairiere", 300.0, 672.0, 30],
	["proto_5_cellules", 600.0, 1872.0, 30],
	["proto_6a_ruines", 400.0, 3072.0, 30],
	["proto_6b_passerelle", 1100.0, 2928.0, 30],
	["proto_7_hall", 3200.0, 3072.0, 30],
	["proto_8a_poursuite", 5100.0, 2880.0, 30],
	["proto_8b_porte", 6900.0, 2880.0, 30],
]

var _out: String = "build/shots"
var _level: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	if _out.begins_with("build") and not FileAccess.file_exists("build/.gdignore"):
		FileAccess.open("build/.gdignore", FileAccess.WRITE).close()
	_level = (load("res://scenes/levels/prototype.tscn") as PackedScene).instantiate()
	_level.set(&"play_opening", false)
	root.add_child(_level)
	_tour.call_deferred()


func _tour() -> void:
	var player: Node = _level.get_node("Elias")
	player.get(&"input").set(&"from_devices", false)
	for stop: Array in STOPS:
		player.set(&"global_position", Vector2(stop[1], stop[2]))
		player.set(&"air_top_y", float(stop[2]))
		_level.get_node("CameraDirector").call(&"snap_to_target")
		for i in int(stop[3]):
			await process_frame
		var path: String = _out.path_join(String(stop[0]) + ".png")
		root.get_texture().get_image().save_png(path)
		print("Capture ", path)
	quit()
