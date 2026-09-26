extends SceneTree
## Captures d'écran de la cinématique d'ouverture (J8) à des instants choisis,
## pour vérifier les plans sans écran :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --fixed-fps 60 -s res://tools/godot/intro_frames.gd -- build/shots 7.3 36 59.5
## Sans instants : une image au milieu de chaque plan. Les fichiers s'appellent
## intro_<instant>.png. (Non typé : un script -s est compilé avant les autoloads.)

var _out: String = "build/shots"
var _times: Array[float] = []
var _scene: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for i in range(1, args.size()):
		_times.append(float(args[i]))
	DirAccess.make_dir_recursive_absolute(_out)
	if _out.begins_with("build") and not FileAccess.file_exists("build/.gdignore"):
		FileAccess.open("build/.gdignore", FileAccess.WRITE).close()
	_scene = (load("res://scenes/cutscenes/intro.tscn") as PackedScene).instantiate()
	_scene.set(&"auto_leave", false)
	root.add_child(_scene)
	_capture.call_deferred()


func _capture() -> void:
	for i in 40:  # les bandes noires finissent d'apparaître
		await process_frame
	var intro: Node = _scene.get_node("Intro")
	if _times.is_empty():
		for row: Array in intro.get(&"SHOTS"):
			_times.append(float(row[1]) + float(row[2]) * 0.5)
	var montage: AnimationPlayer = _scene.get_node("Montage")
	for t in _times:
		montage.seek(t, true)
		for i in 3:
			await process_frame
		var path: String = _out.path_join("intro_%05.1f.png" % t)
		root.get_texture().get_image().save_png(path)
		print("Capture ", path)
	quit()
