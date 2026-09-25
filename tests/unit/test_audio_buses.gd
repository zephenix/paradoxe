extends TestCase
## Vérifie que la table de mixage chargée par le jeu correspond à la
## description de scripts/audio/audio_buses.gd (bus, ordre, envois, effets).


func test_all_buses_exist_in_expected_order() -> void:
	assert_eq(AudioServer.bus_count, AudioBuses.ORDER.size(), "nombre de bus")
	for i in AudioBuses.ORDER.size():
		assert_eq(AudioServer.get_bus_name(i), AudioBuses.ORDER[i], "bus n°%d" % i)


func test_player_adjustable_buses_are_the_six_requested() -> void:
	var expected: Array[StringName] = [&"Master", &"Musique", &"Ambiance", &"SFX", &"Voix", &"UI"]
	assert_eq(AudioBuses.PLAYER_ADJUSTABLE.size(), 6)
	for bus in expected:
		assert_true(AudioBuses.PLAYER_ADJUSTABLE.has(bus), "bus réglable manquant : %s" % bus)
		assert_true(AudioBuses.index(bus) >= 0, "bus absent du mixeur : %s" % bus)


func test_bus_routing() -> void:
	for bus: StringName in AudioBuses.SENDS:
		assert_eq(AudioServer.get_bus_send(AudioBuses.index(bus)), AudioBuses.SENDS[bus], "destination de %s" % bus)


func test_diegetic_sounds_go_through_world_bus() -> void:
	# Ce que le joueur entend « dans le monde » doit recevoir l'acoustique de la salle.
	for bus: StringName in [AudioBuses.SFX, AudioBuses.VOICE, AudioBuses.AMBIENCE]:
		assert_eq(AudioServer.get_bus_send(AudioBuses.index(bus)), AudioBuses.WORLD, bus)
	# La musique et l'interface n'y passent pas.
	for bus: StringName in [AudioBuses.MUSIC, AudioBuses.UI]:
		assert_eq(AudioServer.get_bus_send(AudioBuses.index(bus)), AudioBuses.MASTER, bus)


func test_master_effect_chain() -> void:
	var master: int = AudioBuses.index(AudioBuses.MASTER)
	assert_eq(AudioServer.get_bus_effect_count(master), 3)
	assert_true(AudioServer.get_bus_effect(master, AudioBuses.MASTER_FX_LOWPASS) is AudioEffectLowPassFilter, "étouffement")
	assert_true(AudioServer.get_bus_effect(master, AudioBuses.MASTER_FX_GAIN) is AudioEffectAmplify, "gain dramatique")
	assert_true(AudioServer.get_bus_effect(master, AudioBuses.MASTER_FX_LIMITER) is AudioEffectHardLimiter, "limiteur")


func test_world_effect_chain() -> void:
	var world: int = AudioBuses.index(AudioBuses.WORLD)
	assert_eq(AudioServer.get_bus_effect_count(world), 2)
	assert_true(AudioServer.get_bus_effect(world, AudioBuses.WORLD_FX_REVERB) is AudioEffectReverb, "réverbération")
	assert_true(AudioServer.get_bus_effect(world, AudioBuses.WORLD_FX_LOWPASS) is AudioEffectLowPassFilter, "filtre de salle")


func test_layout_file_is_the_project_default() -> void:
	var path: String = ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres")
	assert_true(ResourceLoader.exists(path), "fichier de table de mixage : %s" % path)
