extends TestCase
## J9 : noms des touches (clavier, manette), remappage sauvegardé, assistances
## (vitesse, rebords, bascules, flashs), menu pause, textes des salles.

const PROTOTYPE: PackedScene = preload("res://scenes/levels/prototype.tscn")
const TEST_FILE: String = "user://test_menus_settings.cfg"

var _saved_path: String


func before_each() -> void:
	_saved_path = Settings.file_path
	Settings.file_path = TEST_FILE
	Settings.reset_to_defaults()


func after_each() -> void:
	Settings.reset_to_defaults()
	Settings.using_gamepad = false
	Settings.file_path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	Engine.time_scale = 1.0
	tree.paused = false
	SceneTransition.fade_in(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.music.silence()


func test_key_and_button_names() -> void:
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	assert_eq(InputPrompt.event_label(space), "Espace")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	assert_eq(InputPrompt.event_label(a), "A")
	assert_eq(InputPrompt.action_label(&"jump", false), "Espace")
	assert_eq(InputPrompt.action_label(&"jump", true), "A")
	assert_eq(InputPrompt.action_label(&"fire", false), "X ou J", "deux touches au clavier")
	assert_eq(InputPrompt.fill("{jump} : sauter, {move} : marcher", false), "Espace : sauter, Flèches : marcher")
	assert_eq(InputPrompt.fill("{jump} : sauter", true), "A : sauter")


func test_rebinding_is_saved_and_restored() -> void:
	var b := InputEventKey.new()
	b.physical_keycode = KEY_B
	InputActions.rebind(&"jump", b)
	assert_eq(InputPrompt.action_label(&"jump", false), "B", "nouvelle touche")
	assert_eq(InputPrompt.action_label(&"jump", true), "A", "la manette n'a pas changé")
	assert_eq(Settings.save_settings(), OK)
	InputActions.install_defaults()
	assert_eq(InputPrompt.action_label(&"jump", false), "Espace", "touches par défaut")
	Settings.load_settings()
	assert_eq(InputPrompt.action_label(&"jump", false), "B", "relue depuis le fichier")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_X
	InputActions.rebind(&"jump", pad)
	assert_eq(InputPrompt.action_label(&"jump", true), "X", "bouton de manette changé")
	assert_eq(InputPrompt.action_label(&"jump", false), "B", "et le clavier garde le sien")


func test_options_menu_rebinds_a_key() -> void:
	var menu := OptionsMenu.new()
	add_node(menu)
	await wait_frames(2)
	menu.call(&"_start_rebind", &"throw", false)
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	menu.finish_rebind(g)
	assert_eq(InputPrompt.action_label(&"throw", false), "G")
	var saved := ConfigFile.new()
	assert_eq(saved.load(TEST_FILE), OK, "sauvegardé aussitôt")
	assert_true(saved.has_section_key("input", "throw"))


func test_assists_are_saved() -> void:
	Settings.slow_game = true
	Settings.ledge_assist = true
	Settings.toggle_crouch = true
	Settings.reduce_flashes = true
	assert_eq(Settings.save_settings(), OK)
	Settings.reset_to_defaults()
	assert_false(Settings.slow_game)
	Settings.load_settings()
	assert_true(Settings.slow_game and Settings.ledge_assist and Settings.toggle_crouch and Settings.reduce_flashes)
	assert_almost_eq(Settings.game_speed(), Settings.assists.slow_speed, 0.001)
	assert_almost_eq(Settings.ledge_factor(), Settings.assists.ledge_factor, 0.001)
	assert_almost_eq(Settings.flash_factor(), Settings.assists.flash_factor, 0.001)


func test_crouch_toggle_latches() -> void:
	Settings.toggle_crouch = true
	var input := PlayerInput.new()
	Input.action_press(&"move_down")
	input.update(0.016)
	assert_true(input.down, "un appui : accroupi")
	Input.action_release(&"move_down")
	await wait_frames(2)
	input.update(0.016)
	assert_true(input.down, "touche relâchée : toujours accroupi")
	Input.action_press(&"move_down")
	input.update(0.016)
	Input.action_release(&"move_down")
	assert_false(input.down, "un second appui : debout")


func _level() -> Level:
	GameState.new_game()
	var level: Level = PROTOTYPE.instantiate()
	level.play_opening = false
	level.get_node("Elias/Foley").free()
	add_node(level)
	level.player.input.from_devices = false
	return level


func test_slow_game_sets_the_game_speed() -> void:
	Settings.slow_game = true
	var level: Level = _level()
	await wait_frames(2)
	assert_almost_eq(Engine.time_scale, Settings.assists.slow_speed, 0.001, "jeu ralenti")
	Settings.slow_game = false
	Events.settings_changed.emit()
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "vitesse normale dès que l'aide est coupée")
	level.queue_free()
	await wait_frames(2)
	assert_almost_eq(Engine.time_scale, 1.0, 0.001)


func test_pause_menu_stops_the_game() -> void:
	var level: Level = _level()
	await wait_physics(3)
	var start: Vector2 = level.player.global_position
	level.player.global_position = start + Vector2(300, 0)
	var escape := InputEventAction.new()
	escape.action = &"pause"
	escape.pressed = true
	level._unhandled_input(escape)
	assert_true(level.pause_menu.is_open, "menu ouvert")
	assert_true(tree.paused, "jeu arrêté")
	level.pause_menu.close()
	assert_false(tree.paused, "jeu reparti")
	level.restart_from_checkpoint()
	assert_almost_eq(level.player.global_position.x, start.x, 1.0, "recommencer : retour au point de départ")


func test_room_hints_show_the_players_keys() -> void:
	var level: Level = _level()
	await wait_frames(2)
	var hint: Label = null
	for node in level.find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("ÉCRAN 2"):
			hint = node
	assert_not_null(hint)
	assert_false(hint.text.contains("{"), "plus de jetons")
	assert_true(hint.text.contains("Espace : sauter"), "touche du clavier")
	Settings.using_gamepad = true
	Events.input_device_changed.emit(true)
	assert_true(hint.text.contains("A : sauter"), "bouton de manette")
