extends TestCase
## Tests des options du joueur (autoload Settings) : volumes et sauvegarde.

const TEST_PATH: String = "user://test_settings.cfg"

var _original_path: String


func before_each() -> void:
	_original_path = Settings.file_path
	Settings.file_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	Settings.reset_to_defaults()


func after_each() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	Settings.file_path = _original_path
	Settings.load_settings()
	Settings.apply_all()


func test_volume_is_applied_to_the_bus() -> void:
	Settings.set_volume(AudioBuses.MUSIC, 0.5)
	var idx: int = AudioBuses.index(AudioBuses.MUSIC)
	assert_almost_eq(AudioServer.get_bus_volume_linear(idx), 0.5, 0.001)
	assert_false(AudioServer.is_bus_mute(idx))


func test_zero_volume_mutes_the_bus() -> void:
	Settings.set_volume(AudioBuses.SFX, 0.0)
	assert_true(AudioServer.is_bus_mute(AudioBuses.index(AudioBuses.SFX)))


func test_volume_is_clamped() -> void:
	Settings.set_volume(AudioBuses.VOICE, 3.0)
	assert_almost_eq(Settings.get_volume(AudioBuses.VOICE), 1.0)
	Settings.set_volume(AudioBuses.VOICE, -1.0)
	assert_almost_eq(Settings.get_volume(AudioBuses.VOICE), 0.0)


func test_unknown_bus_is_ignored() -> void:
	Settings.set_volume(&"BusQuiNExistePas", 0.3)
	assert_false(Settings.volumes.has(&"BusQuiNExistePas"))


func test_save_then_load_restores_values() -> void:
	Settings.set_volume(AudioBuses.AMBIENCE, 0.25)
	Settings.classic_mode = true
	assert_eq(Settings.save_settings(), OK, "sauvegarde")
	Settings.reset_to_defaults()
	assert_false(Settings.classic_mode)
	Settings.load_settings()
	assert_almost_eq(Settings.get_volume(AudioBuses.AMBIENCE), 0.25)
	assert_true(Settings.classic_mode, "mode classique relu")


func test_missing_file_keeps_defaults() -> void:
	Settings.load_settings()
	for bus: StringName in Settings.DEFAULT_VOLUMES:
		assert_almost_eq(Settings.get_volume(bus), Settings.DEFAULT_VOLUMES[bus], 0.0001, String(bus))


func test_settings_changed_signal() -> void:
	var count: Array[int] = [0]
	var on_changed := func() -> void: count[0] += 1
	Events.settings_changed.connect(on_changed)
	Settings.set_volume(AudioBuses.UI, 0.4)
	Events.settings_changed.disconnect(on_changed)
	assert_eq(count[0], 1)
