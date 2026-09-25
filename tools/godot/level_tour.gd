extends SceneTree
## Visite guidée de la salle de test avec captures d'écran (vérification du
## rendu sans écran). Élias est piloté par ses intentions, comme dans les tests.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##       --fixed-fps 60 -s res://tools/godot/level_tour.gd -- build/shots
## (--fixed-fps 60 : les captures tombent toujours au même instant du jeu.)
## Les téléportations d'une salle à l'autre ne vérifient PAS que le niveau se
## parcourt : c'est le rôle de tests/unit/test_test_level.gd.

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
	# build/ ne doit pas être importé par Godot (sinon les captures deviennent
	# des ressources du projet) : un fichier .gdignore l'en empêche.
	if _out.begins_with("build") and not FileAccess.file_exists("build/.gdignore"):
		FileAccess.open("build/.gdignore", FileAccess.WRITE).close()
	_level = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(_level)
	_tour.call_deferred()


func _tour() -> void:
	_player = _level.get_node("Elias")
	_player.input.from_devices = false
	await _frames(20)
	# 1) Salle A : accroupi dans le tunnel.
	await _teleport(Vector2(19 * 48, 13 * 48))
	_player.input.down = true
	await _frames(30)
	await _shot("tour_1_tunnel")
	_player.input.down = false
	# 2) Salle B : saut avec élan au-dessus du grand trou.
	await _teleport(Vector2(1280 + 8.5 * 48, 11 * 48))
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
	await _teleport(Vector2(2560 + 9 * 48 - 13, 11 * 48))
	_player.input.press(&"move_up")
	await _frames(45)
	await _shot("tour_3_hang")
	_player.input.press(&"move_up")
	await _frames(18)
	await _shot("tour_4_climb")
	await _frames(40)
	# 4) Passage de C vers E : glissement de caméra (capture à mi-chemin).
	await _teleport(Vector2(2560 + 25.5 * 48, 11 * 48))
	await _frames(10)
	_player.input.move = 1
	_player.input.run = true
	await _frames(22)
	await _shot("tour_5_transition")
	await _frames(40)
	await _shot("tour_6_hall")
	_player.input.move = 0
	_player.input.run = false
	# 5) Salle F : combat. Élias entre, se met à couvert, tire, se protège.
	await _teleport(Vector2(6400 + 96, 528))
	_player.input.move = 1
	await _frames(40)
	_player.input.move = 0
	await _frames(10)
	await _shot("tour_7_combat_room")
	_player.input.press(&"fire")
	await _frames(14)
	await _shot("tour_8_shot")
	await _frames(20)
	_player.input.shield = true
	await _frames(60)
	await _shot("tour_9_shield")
	_player.input.shield = false
	_player.input.down = true
	await _frames(50)
	await _shot("tour_10_cover")
	_player.input.down = false
	# 6) Mort et rembobinage (J4), dans la salle B : Élias court, meurt, remonte le temps.
	var death: Node = _level.get("death")
	death.input_from_devices = false
	await _teleport(Vector2(1280 + 1.5 * 48, 11 * 48))
	_player.input.move = 1
	_player.input.run = true
	await _frames(70)
	_player.kill(&"shot")
	_player.input.move = 0
	_player.input.run = false
	while death.phase != &"choice":
		await _frames(1)
	await _frames(5)
	await _shot("tour_11_choice")
	death.rewind_held = true
	await _frames(40)
	await _shot("tour_12_rewind")
	death.rewind_held = false
	await _frames(20)
	await _shot("tour_13_resumed")
	quit()


func _teleport(feet: Vector2) -> void:
	_player.respawn(feet, 1)
	_level.get_node("CameraDirector").snap_to_target()
	await _frames(5)  # laisse Élias se poser avant de lui donner des ordres


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(shot_name: String) -> void:
	await process_frame
	var path: String = _out.path_join(shot_name + ".png")
	root.get_texture().get_image().save_png(path)
	print("Capture %s (état %s)" % [path, _player.machine.current_name])
