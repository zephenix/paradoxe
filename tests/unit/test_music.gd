extends TestCase
## Tests de la musique (J8) : thèmes (un seul à la fois), couches de tension
## qui suivent le niveau d'alerte, silence sous un thème, arrêt au calme.

var music: MusicPlayer
var cfg: MusicConfig


func before_each() -> void:
	music = AudioManager.music
	cfg = music.config
	music.silence()


func after_each() -> void:
	music.silence()


func test_every_music_track_is_in_the_library_on_the_music_bus() -> void:
	var ids: Array[StringName] = cfg.tension_layers.duplicate()
	ids.append_array([&"mus_theme_intro", &"mus_theme_arrival", &"mus_theme_meeting", &"mus_chase_loop",
			&"mus_sting_death", &"mus_theme_end"])
	for id in ids:
		var entry: SoundEntry = AudioManager.library.get_entry(id)
		assert_not_null(entry, "%s dans la bibliothèque" % id)
		if entry:
			assert_eq(entry.bus, AudioBuses.MUSIC, "%s sur le bus Musique" % id)
			assert_eq(entry.pitch_random, 0.0, "%s : jamais de variation de hauteur" % id)


func test_tension_layers_have_exactly_the_same_length() -> void:
	var first: AudioStreamWAV = AudioManager.stream_of(cfg.tension_layers[0]) as AudioStreamWAV
	for id in cfg.tension_layers:
		var stream: AudioStreamWAV = AudioManager.stream_of(id) as AudioStreamWAV
		assert_eq(stream.get_length(), first.get_length(), "%s : même durée (couches calées)" % id)
		assert_ne(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s tourne en boucle" % id)


func test_one_theme_at_a_time() -> void:
	var started: Array[StringName] = []
	var listener := func(id: StringName) -> void: started.append(id)
	music.theme_started.connect(listener)
	AudioManager.play_music(&"mus_theme_arrival")
	await wait_frames(2)
	assert_true(music.is_theme_playing())
	assert_eq(music.theme_id, &"mus_theme_arrival")
	AudioManager.play_music(&"mus_theme_arrival")
	assert_eq(started.size(), 1, "rejouer le thème en cours ne le relance pas")
	AudioManager.play_music(&"mus_chase_loop", 0.5)
	await wait_frames(2)
	assert_eq(music.theme_id, &"mus_chase_loop", "le nouveau thème remplace l'ancien")
	var themes: int = music.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Theme_")).size()
	await wait_seconds(0.8)
	var after: int = music.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Theme_")).size()
	assert_eq(themes, 2, "pendant le fondu, les deux thèmes coexistent")
	assert_eq(after, 1, "puis l'ancien disparaît")
	AudioManager.stop_music(0.0)
	assert_false(music.is_theme_playing())
	music.theme_started.disconnect(listener)


func test_tension_layers_follow_the_alert_level() -> void:
	assert_false(music.is_tension_running(), "au calme : silence, aucune couche")
	Events.alert_level_changed.emit(cfg.layer_ranges[0].y)
	assert_almost_eq(music.tension, cfg.layer_ranges[0].y, 0.001, "le signal global règle la tension")
	await wait_seconds(cfg.rise_time + 0.2)
	assert_true(music.is_tension_running())
	assert_almost_eq(music.layer_gain(0), 1.0, 0.01, "inquiétude : la nappe")
	assert_eq(music.layer_gain(1), 0.0, "pas encore la pulsation")
	assert_eq(music.layer_gain(2), 0.0, "ni les percussions")
	Events.alert_level_changed.emit(1.0)
	await wait_seconds(cfg.rise_time + 0.2)
	for i in 3:
		assert_almost_eq(music.layer_gain(i), 1.0, 0.01, "combat : couche %d à plein" % i)
	Events.alert_level_changed.emit(0.0)
	await wait_seconds(cfg.rise_time)
	assert_true(music.layer_gain(2) > 0.0, "la tension retombe lentement")
	await wait_seconds(cfg.fall_time + cfg.stop_after + 0.3)
	assert_false(music.is_tension_running(), "puis les couches s'arrêtent")


func test_tension_is_silent_under_a_theme() -> void:
	music.set_tension(1.0)
	await wait_seconds(cfg.rise_time + 0.2)
	assert_almost_eq(music.layer_gain(0), 1.0, 0.01)
	AudioManager.play_music(&"mus_chase_loop")
	assert_eq(music.target_gain(0), 0.0, "sous un thème, la tension se tait")
	AudioManager.stop_music(0.0)
	assert_eq(music.target_gain(0), 1.0, "et revient après")


func test_leaving_a_level_silences_the_music() -> void:
	var level: Level = load("res://scenes/levels/test_level.tscn").instantiate()
	level.get_node("Elias/Foley").free()
	add_node(level)
	await wait_physics(3)
	music.set_tension(0.8)
	AudioManager.play_music(&"mus_theme_arrival")
	level.free()
	assert_eq(music.tension, 0.0, "tension remise à zéro")
	assert_false(music.is_theme_playing(), "thème arrêté")
	AudioManager.set_zone(&"", 0.0)
