extends TestCase
## Tests de la table des commandes (clavier + manette).


func test_all_actions_are_installed() -> void:
	for action in InputActions.all_actions():
		assert_true(InputMap.has_action(action), "action manquante : %s" % action)


func test_every_action_works_on_keyboard_and_gamepad() -> void:
	for action in InputActions.all_actions():
		var has_key: bool = false
		var has_pad: bool = false
		for event in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_key, "%s : aucune touche clavier" % action)
		assert_true(has_pad, "%s : aucune commande manette" % action)


func test_keyboard_uses_physical_positions() -> void:
	# Touches physiques : « WASD » en QWERTY = « ZQSD » en AZERTY, sans rien changer.
	for action in InputActions.all_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_ne(event.physical_keycode, KEY_NONE, "%s : touche non physique" % action)


func test_reinstalling_defaults_is_idempotent() -> void:
	var before: int = InputMap.action_get_events(&"jump").size()
	InputActions.install_defaults()
	assert_eq(InputMap.action_get_events(&"jump").size(), before)


func test_simulated_key_triggers_action() -> void:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	assert_true(press.is_action_pressed(&"jump"), "Espace déclenche « jump »")
	var right := InputEventKey.new()
	right.physical_keycode = KEY_D
	right.pressed = true
	assert_true(right.is_action_pressed(&"move_right"), "D (QWERTY) / D (AZERTY) : à droite")
