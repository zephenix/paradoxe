extends TestCase
## Tests du banc d'écoute (J5) et des réglages de sons enregistrés.

const BOARD: PackedScene = preload("res://scenes/ui/sound_board.tscn")
const TEST_TUNING: String = "user://test_sound_tuning.json"

var _saved_path: String


func before_each() -> void:
	_saved_path = AudioManager.tuning_path
	AudioManager.tuning_path = TEST_TUNING  # ne pas toucher aux vrais réglages


func after_each() -> void:
	for entry: SoundEntry in AudioManager.library.entries:
		AudioManager.reset_tuning(entry.id)
	AudioManager.tuning_path = _saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_TUNING))
	AudioManager.set_zone(&"", 0.0)


func _board() -> Control:
	var board: Control = add_node(BOARD.instantiate())
	await wait_frames(2)
	return board


func test_board_lists_every_sound() -> void:
	var board: Control = await _board()
	var total: int = 0
	for i: int in board._categories.size():
		board._category_select.select(i)
		board._on_category_selected(i)
		total += board._list_ids.size()
	assert_eq(total, AudioManager.library.entries.size(), "chaque son est dans une catégorie")


func test_sliders_tune_the_sound_live_and_reset_restores() -> void:
	var board: Control = await _board()
	board.select_sound(&"foley_jump")
	var entry: SoundEntry = AudioManager.library.get_entry(&"foley_jump")
	var before: float = entry.volume_db
	(board._sliders["volume_db"] as HSlider).value = before - 6.0
	assert_almost_eq(entry.volume_db, before - 6.0, 0.001, "le curseur règle le son")
	assert_true(AudioManager.is_tuned(&"foley_jump"))
	assert_true(AudioManager.tuning_report().contains("foley_jump"), "présent dans le texte à copier")
	board._on_reset_pressed()
	assert_almost_eq(entry.volume_db, before, 0.001, "réglage d'origine")
	assert_false(AudioManager.is_tuned(&"foley_jump"))


func test_selecting_a_sound_does_not_tune_it() -> void:
	var board: Control = await _board()
	for id: StringName in [&"foley_jump", &"weapon_shot", &"amb_wind_loop"]:
		board.select_sound(id)
	for entry: SoundEntry in AudioManager.library.entries:
		assert_false(AudioManager.is_tuned(entry.id), "%s inchangé" % entry.id)


func test_saved_tuning_is_applied_at_next_start() -> void:
	var entry: SoundEntry = AudioManager.library.get_entry(&"weapon_shot")
	var before: float = entry.noise_radius
	entry.noise_radius = before + 100.0
	assert_eq(AudioManager.save_tuning(), OK)
	AudioManager.reset_tuning(&"weapon_shot")
	assert_almost_eq(entry.noise_radius, before, 0.001)
	assert_eq(AudioManager.load_tuning(), 1, "un son réglé")
	assert_almost_eq(entry.noise_radius, before + 100.0, 0.001, "réglage retrouvé")


func test_zone_selection_and_exit_restore_silence() -> void:
	var board: Control = await _board()
	var index: int = board._zone_ids.find(&"shaft")
	assert_true(index > 0)
	board._on_zone_selected(index)
	assert_eq(AudioManager.ambience.zone_id, &"shaft")
	assert_ne(AudioManager.ambience.play_random_event(), &"", "un évènement du puits")
	board._on_rewind_toggled(true)
	assert_true(AudioManager.muffle > 0.0 or AudioManager.is_loop_playing(&"sound_board_rewind"))
	board.free()
	assert_eq(AudioManager.ambience.zone_id, &"", "on quitte le banc : silence")
	assert_almost_eq(AudioManager.muffle, 0.0, 0.001, "effet de rembobinage retiré")
	assert_false(AudioManager.is_loop_playing(&"sound_board_rewind"))
