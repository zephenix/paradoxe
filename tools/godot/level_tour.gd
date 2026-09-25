extends SceneTree
## Visite guidée de la salle de test avec captures d'écran (vérification du
## rendu sans écran). Élias est piloté par ses intentions, comme dans les tests.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       -s res://tools/godot/level_tour.gd -- build/shots

var _out: String = "build/shots"
var _level: Node
## Non typé exprès : un script lancé avec -s est compilé AVANT les autoloads ;
## typer « Player » forcerait la compilation de player.gd, qui a besoin d'eux.
var _player: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_level = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(_level)
	_tour.call_deferred()


func _tour() -> void:
	_player = _level.get_node("Elias")
	_player.input.from_devices = false
	await _frames(20)
	# 1) Salle A : accroupi dans le tunnel.
	_teleport(Vector2(19 * 48, 13 * 48))
	_player.input.down = true
	await _frames(30)
	await _shot("tour_1_tunnel")
	_player.input.down = false
	# 2) Salle B : saut avec élan au-dessus du grand trou.
	_teleport(Vector2(1280 + 8.5 * 48, 11 * 48))
	_player.input.move = 1
	_player.input.run = true
	await _frames(40)
	_player.input.press(&"jump")
	await _frames(14)
	await _shot("tour_2_leap")
	_player.input.move = 0
	_player.input.run = false
	await _frames(60)
	# 3) Salle C : suspendu au mur de 3 blocs.
	_teleport(Vector2(2560 + 9 * 48 - 13, 11 * 48))
	_player.input.press(&"move_up")
	await _frames(45)
	await _shot("tour_3_hang")
	_player.input.press(&"move_up")
	await _frames(18)
	await _shot("tour_4_climb")
	await _frames(40)
	# 4) Passage de C vers E : glissement de caméra (capture à mi-chemin).
	_teleport(Vector2(2560 + 25.5 * 48, 11 * 48))
	await _frames(10)
	_player.input.move = 1
	_player.input.run = true
	await _frames(22)
	await _shot("tour_5_transition")
	await _frames(40)
	await _shot("tour_6_hall")
	quit()


func _teleport(feet: Vector2) -> void:
	_player.respawn(feet, 1)
	_level.get_node("CameraDirector").snap_to_target()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(shot_name: String) -> void:
	await process_frame
	var path: String = _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("Capture %s (état %s)" % [path, _player.machine.current_name])
