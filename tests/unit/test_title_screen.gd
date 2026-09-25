extends TestCase
## Tests de l'écran titre (provisoire) : l'interrupteur du mode classique.

const TITLE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const TEST_FILE: String = "user://test_title_settings.cfg"

var _saved_path: String
var _saved_classic: bool


func before_each() -> void:
	_saved_path = Settings.file_path
	_saved_classic = Settings.classic_mode
	Settings.file_path = TEST_FILE  # ne pas toucher aux vrais réglages du joueur


func after_each() -> void:
	Settings.classic_mode = _saved_classic
	Settings.file_path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))


func test_classic_toggle_sets_and_saves_the_setting() -> void:
	Settings.classic_mode = false
	var title: Control = add_node(TITLE.instantiate())
	var toggle: CheckButton = title.get_node("%ClassicToggle")
	assert_false(toggle.button_pressed, "reflète le réglage au départ")
	toggle.button_pressed = true
	assert_true(Settings.classic_mode, "mode classique activé")
	var saved := ConfigFile.new()
	assert_eq(saved.load(TEST_FILE), OK, "réglage sauvegardé")
	assert_true(bool(saved.get_value("gameplay", "classic_mode", false)))
	assert_false(RewindManager.is_available(), "plus de rembobinage")
