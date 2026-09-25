extends TestCase
## Tests de la bibliothèque de sons (J5) : resources/audio/sound_library.tres.


## Liste récursive des scripts .gd d'un dossier.
func _scripts_in(dir: String) -> PackedStringArray:
	var found := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			found.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_scripts_in(dir.path_join(sub)))
	return found


func test_every_entry_has_sounds_and_a_known_bus() -> void:
	var library: SoundLibrary = AudioManager.library
	assert_true(library.entries.size() > 40, "bibliothèque remplie")
	for entry: SoundEntry in library.entries:
		assert_false(entry.streams.is_empty(), "%s a au moins un fichier" % entry.id)
		assert_true(AudioServer.get_bus_index(entry.bus) >= 0, "%s : bus « %s » existe" % [entry.id, entry.bus])


func test_every_sound_id_used_in_the_code_exists() -> void:
	# Cherche play_sfx(&"id"…) et play_loop_sfx(…, &"id"…) dans tous les scripts.
	var regex := RegEx.create_from_string("play_(?:loop_)?sfx\\((?:[^,()]*,\\s*)?&\"([a-z0-9_]+)\"")
	var count: int = 0
	for path: String in _scripts_in("res://scripts"):
		var text: String = FileAccess.get_file_as_string(path)
		for found_match: RegExMatch in regex.search_all(text):
			count += 1
			assert_true(AudioManager.library.has(StringName(found_match.get_string(1))),
					"%s : son « %s » dans la bibliothèque" % [path.get_file(), found_match.get_string(1)])
	assert_true(count > 15, "%d appels trouvés" % count)


func test_weapon_shot_ids_exist() -> void:
	for path: String in ["res://resources/weapons/pistol.tres", "res://resources/weapons/sentinel_gun.tres"]:
		if ResourceLoader.exists(path):
			var cfg: WeaponConfig = load(path)
			assert_true(AudioManager.library.has(cfg.shot_sound_id), "%s : %s" % [path, cfg.shot_sound_id])


func test_play_sfx_emits_signal_and_noise() -> void:
	var played: Array[StringName] = []
	var on_played := func(id: StringName) -> void: played.append(id)
	var heard: Array[float] = []
	var on_noise := func(_at: Vector2, radius: float, _source: Node) -> void: heard.append(radius)
	AudioManager.sfx_played.connect(on_played)
	AudioManager.noise_emitted.connect(on_noise)
	AudioManager.play_sfx(&"foley_land_heavy", Vector2(100, 100))
	AudioManager.play_sfx(&"foley_land_heavy", Vector2(100, 100), null, 0.0, 0.5)
	AudioManager.play_sfx(&"ui_confirm")
	AudioManager.sfx_played.disconnect(on_played)
	AudioManager.noise_emitted.disconnect(on_noise)
	assert_eq(played, [&"foley_land_heavy", &"foley_land_heavy", &"ui_confirm"] as Array[StringName])
	var r: float = AudioManager.library.get_entry(&"foley_land_heavy").noise_radius
	assert_eq(heard, [r, r * 0.5] as Array[float], "rayon de la bibliothèque, réductible")


func test_unknown_id_warns_and_plays_nothing() -> void:
	expect_warning("inconnu")
	assert_null(AudioManager.play_sfx(&"n_existe_pas"))
