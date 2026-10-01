extends SceneTree
## Planche du Traqueur (dessin par code) : repos, course à plusieurs instants,
## rugissement. Pour juger le dessin sans lancer le niveau :
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/godot/creature_sheet.gd -- build/shots/creature.png
## (Non typé : un script -s est compilé avant les autoloads.)

const STOPS: Array = [["idle", 0.4], ["run", 0.0], ["run", 0.09], ["run", 0.18], ["run", 0.27], ["roar", 0.5]]

var _out: String = "build/shots/creature.png"
var _visuals: Array = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var bg := ColorRect.new()
	bg.color = Color("3a434c")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	for i in STOPS.size():
		var v: Node2D = (load("res://scripts/enemies/tracker_visual.gd") as GDScript).new()
		v.position = Vector2(220 + (i % 3) * 420, 300 + (i / 3) * 330)
		v.scale = Vector2(1.4, 1.4)
		root.add_child(v)
		v.call(&"play", StringName(STOPS[i][0]))
		v.set_process(false)
		_visuals.append(v)
	_shoot.call_deferred()


func _shoot() -> void:
	for i in _visuals.size():
		var v: Node2D = _visuals[i]
		v.call(&"_process", float(STOPS[i][1]))  # avance l'animation jusqu'à l'instant voulu
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png(_out)
	quit()
