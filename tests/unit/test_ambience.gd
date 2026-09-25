extends TestCase
## Tests des ambiances et de l'acoustique par zone (J5) : AmbiencePlayer,
## AudioManager.set_zone, zones de resources/audio/zones/.

## Écho maximal d'une zone (0 à 1). Au-delà, les sons « résonnent » trop : les
## ambiances contiennent déjà leur propre espace, et l'écho s'y ajoute.
const MAX_REVERB_WET: float = 0.3


func after_each() -> void:
	AudioManager.set_zone(&"", 0.0)


func test_every_zone_is_valid() -> void:
	var ids: Array[StringName] = AudioManager.ambience.zone_ids()
	for expected: StringName in [&"lab", &"ruins", &"shaft", &"hall"]:
		assert_true(ids.has(expected), "zone %s" % expected)
	for id in ids:
		var zone: AcousticZone = AudioManager.ambience.load_zone(id)
		assert_eq(zone.id, id, "l'identifiant suit le nom du fichier")
		assert_false(zone.layers.is_empty(), "%s a au moins une couche" % id)
		assert_false(zone.events.is_empty(), "%s a des évènements ponctuels" % id)
		assert_true(zone.event_interval_min <= zone.event_interval_max, "%s : intervalle" % id)
		assert_true(zone.reverb_wet <= MAX_REVERB_WET, "%s : écho %.2f (max %.2f)" % [id, zone.reverb_wet, MAX_REVERB_WET])
		for sound_id: StringName in zone.layers + zone.events:
			assert_true(AudioManager.library.has(sound_id), "%s : son %s" % [id, sound_id])
		for sound_id: StringName in zone.layers:
			var stream: AudioStreamWAV = AudioManager.stream_of(sound_id) as AudioStreamWAV
			assert_true(stream != null and stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s boucle" % sound_id)


func test_every_room_of_the_test_level_has_a_known_zone() -> void:
	var level: Node = load("res://scenes/levels/test_level.tscn").instantiate()
	var ids: Array[StringName] = AudioManager.ambience.zone_ids()
	var used: Array[StringName] = []
	for child in level.get_children():
		if child is Room:
			assert_true(ids.has((child as Room).acoustic_zone), "%s : zone %s" % [child.name, (child as Room).acoustic_zone])
			if not used.has((child as Room).acoustic_zone):
				used.append((child as Room).acoustic_zone)
	assert_true(used.size() >= 3, "au moins trois ambiances différentes : %s" % [used])
	level.free()


func test_set_zone_starts_layers_and_acoustics() -> void:
	AudioManager.set_zone(&"shaft", 0.0)
	var zone: AcousticZone = AudioManager.ambience.zone
	assert_eq(AudioManager.ambience.zone_id, &"shaft")
	for sound_id: StringName in zone.layers:
		assert_true(AudioManager.ambience.has_layer(sound_id), "couche %s" % sound_id)
	var reverb: AudioEffectReverb = AudioManager.world_reverb()
	assert_almost_eq(reverb.wet, zone.reverb_wet, 0.001, "écho du puits")
	assert_almost_eq(reverb.room_size, zone.reverb_room_size, 0.001)
	assert_almost_eq(AudioManager.world_lowpass_hz(), zone.lowpass_hz, 1.0, "filtre du puits")


func test_zone_change_crossfades_and_keeps_shared_layers() -> void:
	AudioManager.set_zone(&"ruins", 0.0)
	var shared: StringName = &"amb_wind_loop"  # commun aux ruines et au puits
	var wind: Node = AudioManager.ambience.get_node("Layer_%s" % shared)
	AudioManager.set_zone(&"shaft", 0.5)
	assert_true(AudioManager.ambience.has_layer(&"amb_shaft_loop"))
	assert_false(AudioManager.ambience.has_layer(&"amb_city_loop"), "la ville s'éteint")
	assert_eq(AudioManager.ambience.get_node("Layer_%s" % shared), wind, "le vent continue sans reprendre")
	await wait_seconds(0.8)
	assert_eq(AudioManager.ambience.layer_count(), 2, "l'ancienne couche est partie")
	var reverb: AudioEffectReverb = AudioManager.world_reverb()
	assert_almost_eq(reverb.wet, AudioManager.ambience.zone.reverb_wet, 0.001, "réverbération arrivée")


func test_silence_zone_stops_everything() -> void:
	AudioManager.set_zone(&"hall", 0.0)
	AudioManager.set_zone(&"", 0.0)
	assert_eq(AudioManager.ambience.layer_count(), 0)
	assert_almost_eq(AudioManager.world_reverb().wet, 0.0, 0.001, "réverbération coupée")
	assert_almost_eq(AudioManager.world_lowpass_hz(), AudioBuses.LOWPASS_OPEN_HZ, 1.0)


func test_random_events_play_and_do_not_alert_enemies() -> void:
	var played: Array[StringName] = []
	var on_played := func(id: StringName) -> void: played.append(id)
	var noises: Array[float] = []
	var on_noise := func(_at: Vector2, radius: float, _source: Node) -> void: noises.append(radius)
	AudioManager.sfx_played.connect(on_played)
	AudioManager.noise_emitted.connect(on_noise)
	AudioManager.set_zone(&"ruins", 0.0)
	await wait_seconds(AudioManager.ambience.zone.event_interval_max * 2.0 + 0.5)
	AudioManager.sfx_played.disconnect(on_played)
	AudioManager.noise_emitted.disconnect(on_noise)
	assert_true(played.size() >= 2, "des évènements ponctuels : %s" % [played])
	for id in played:
		assert_true(AudioManager.ambience.zone.events.has(id), "%s appartient à la zone" % id)
	assert_true(noises.is_empty(), "les ennemis n'y réagissent pas")


func test_unknown_zone_is_ignored_with_a_warning() -> void:
	AudioManager.set_zone(&"lab", 0.0)
	expect_warning("zone inconnue")
	AudioManager.set_zone(&"nulle_part", 0.0)
	assert_eq(AudioManager.ambience.zone_id, &"lab", "on garde la zone courante")


func test_level_switches_zone_with_the_room() -> void:
	var level: Level = load("res://scenes/levels/test_level.tscn").instantiate()
	level.get_node("Elias/Foley").free()
	add_node(level)
	await wait_physics(3)
	assert_eq(AudioManager.ambience.zone_id, (level.camera.current_room as Room).acoustic_zone, "zone de la première salle")
	var shaft: Room = level.get_node("RoomD")
	level.player.global_position = shaft.spawn_point()
	await wait_physics(10)
	assert_eq(AudioManager.ambience.zone_id, &"shaft", "le puits")
	level.free()
	assert_eq(AudioManager.ambience.zone_id, &"", "on quitte le niveau : silence")
