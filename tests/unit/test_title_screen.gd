extends TestCase
## Tests de l'écran titre et du menu d'options (J9) : le mode classique se règle
## maintenant dans les options (onglet « Aides »).

const TITLE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const TEST_FILE: String = "user://test_title_settings.cfg"

var _saved_path: String


func before_each() -> void:
	_saved_path = Settings.file_path
	Settings.file_path = TEST_FILE  # ne pas toucher aux vrais réglages du joueur
	Settings.reset_to_defaults()


func after_each() -> void:
	Settings.reset_to_defaults()
	Settings.file_path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))


## Cherche l'interrupteur dont le texte commence par « start ».
func _toggle(menu: Node, start: String) -> CheckButton:
	for node in menu.find_children("*", "CheckButton", true, false):
		if (node as CheckButton).text.begins_with(start):
			return node
	return null


func test_classic_toggle_sets_and_saves_the_setting() -> void:
	var title: Control = add_node(TITLE.instantiate())
	var menu: OptionsMenu = title.call(&"open_options")
	await wait_frames(2)
	var toggle: CheckButton = _toggle(menu, "Mode classique")
	assert_not_null(toggle, "interrupteur du mode classique dans les options")
	assert_false(toggle.button_pressed, "reflète le réglage au départ")
	toggle.button_pressed = true
	assert_true(Settings.classic_mode, "mode classique activé")
	var saved := ConfigFile.new()
	assert_eq(saved.load(TEST_FILE), OK, "réglage sauvegardé")
	assert_true(bool(saved.get_value("gameplay", "classic_mode", false)))
	assert_false(RewindManager.is_available(), "plus de rembobinage")


func test_workshop_holds_the_test_tools() -> void:
	var title: Control = add_node(TITLE.instantiate())
	var workshop: Control = title.get_node("%Workshop")
	assert_false(workshop.visible, "l'atelier est fermé au départ")
	assert_true(workshop.is_ancestor_of(title.get_node("%LevelButton")), "salle de test dans l'atelier")
	assert_true(workshop.is_ancestor_of(title.get_node("%SoundBoardButton")), "banc d'écoute dans l'atelier")
	(title.get_node("%WorkshopButton") as Button).pressed.emit()
	assert_true(workshop.visible, "l'atelier s'ouvre")
	assert_false((title.get_node("%Items") as Control).visible, "à la place du menu")
