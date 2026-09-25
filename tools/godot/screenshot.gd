extends SceneTree
## Capture d'écran d'une scène, pour vérifier le rendu sur une machine sans écran.
##
## Il faut un vrai moteur de rendu (pas --headless) : sous Linux sans écran,
## on utilise un écran virtuel Xvfb. Voir tools/screenshot.sh qui fait tout ça.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/godot/screenshot.gd -- <scène.tscn> <sortie.png> [images] [appui_à_l_image]
##
## - images : nombre d'images à attendre avant la capture (défaut 60, soit 1 s) ;
## - appui_à_l_image : si fourni, simule un appui sur Espace à cette image
##   (utile pour passer l'écran « Appuyez sur une touche »).

var _out_path: String
var _frames_to_wait: int = 60
var _press_at: int = -1
var _frame: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("Usage : -- <scène.tscn> <sortie.png> [images] [appui_à_l_image]")
		quit(2)
		return
	var scene: PackedScene = load(args[0])
	if scene == null:
		printerr("Scène introuvable : %s" % args[0])
		quit(1)
		return
	_out_path = args[1]
	if args.size() > 2:
		_frames_to_wait = int(args[2])
	if args.size() > 3:
		_press_at = int(args[3])
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == _press_at:
		_tap_key(KEY_SPACE)
	if _frame < _frames_to_wait:
		return false
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out_path.get_base_dir())
	var err: Error = image.save_png(_out_path)
	print("Capture %s (%dx%d) : %s" % [_out_path, image.get_width(), image.get_height(), error_string(err)])
	_silence_audio()
	return true  # « true » demande à Godot de quitter


## Arrête les sons et laisse au moteur le temps de les libérer (sinon « fuite »
## affichée à la sortie ; même raison que dans tests/run_tests.gd).
func _silence_audio() -> void:
	for node in root.find_children("*", "AudioStreamPlayer", true, false):
		(node as AudioStreamPlayer).stop()
	for node in root.find_children("*", "AudioStreamPlayer2D", true, false):
		(node as AudioStreamPlayer2D).stop()
	OS.delay_msec(250)


func _tap_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
