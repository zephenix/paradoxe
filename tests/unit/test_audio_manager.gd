extends TestCase
## Tests du gestionnaire audio central (AudioManager).

const AUDIO_MANAGER_SCRIPT: GDScript = preload("res://scripts/autoload/audio_manager.gd")
const IMPACT: AudioStream = preload("res://assets/audio/generated/sfx/test_impact.wav")
const HUM: AudioStream = preload("res://assets/audio/generated/ambience/portal_hum_loop.wav")

var _noise_events: Array = []


func after_each() -> void:
	# On remet l'autoload dans son état normal pour les tests suivants.
	AudioManager.muffle = 0.0
	AudioManager.drama_gain_db = 0.0
	AudioManager.set_reverb(0.0)
	AudioManager.stop_loop(&"test_loop", 0.0)
	_noise_events.clear()


func test_unlock_emits_signal_only_once() -> void:
	var manager: Node = add_node(AUDIO_MANAGER_SCRIPT.new())
	var count: Array[int] = [0]
	var on_unlock := func() -> void: count[0] += 1
	Events.audio_unlocked.connect(on_unlock)
	assert_false(manager.is_unlocked, "verrouillé au départ")
	manager.unlock()
	manager.unlock()
	Events.audio_unlocked.disconnect(on_unlock)
	assert_true(manager.is_unlocked, "déverrouillé après unlock()")
	assert_eq(count[0], 1, "le signal ne doit partir qu'une fois")


func test_muffle_drives_master_lowpass() -> void:
	var master: int = AudioBuses.index(AudioBuses.MASTER)
	var lowpass: AudioEffectLowPassFilter = AudioServer.get_bus_effect(master, AudioBuses.MASTER_FX_LOWPASS)
	AudioManager.muffle = 0.0
	assert_false(AudioServer.is_bus_effect_enabled(master, AudioBuses.MASTER_FX_LOWPASS), "filtre coupé au repos")
	AudioManager.muffle = 1.0
	assert_true(AudioServer.is_bus_effect_enabled(master, AudioBuses.MASTER_FX_LOWPASS), "filtre actif")
	assert_almost_eq(lowpass.cutoff_hz, AudioManager.MUFFLE_MIN_HZ, 1.0, "coupure maximale")
	AudioManager.muffle = 0.5
	assert_true(lowpass.cutoff_hz > 1000.0 and lowpass.cutoff_hz < 5000.0, "mi-chemin (échelle en octaves)")


func test_set_muffle_is_progressive() -> void:
	AudioManager.set_muffle(1.0, 0.2)
	await wait_frames(2)
	assert_true(AudioManager.muffle > 0.0 and AudioManager.muffle < 1.0, "en cours de transition")
	await wait_seconds(0.3)
	assert_almost_eq(AudioManager.muffle, 1.0, 0.001, "transition terminée")


func test_cut_to_silence_and_restore() -> void:
	var gain: AudioEffectAmplify = AudioServer.get_bus_effect(AudioBuses.index(AudioBuses.MASTER), AudioBuses.MASTER_FX_GAIN)
	AudioManager.cut_to_silence(-1.0)
	assert_almost_eq(gain.volume_db, AudioManager.SILENT_DB, 0.01, "silence immédiat")
	AudioManager.restore_from_silence(0.05)
	await wait_seconds(0.15)
	assert_almost_eq(gain.volume_db, 0.0, 0.01, "son revenu")


func test_silence_does_not_touch_player_volume() -> void:
	var before: float = AudioServer.get_bus_volume_linear(AudioBuses.index(AudioBuses.MASTER))
	AudioManager.cut_to_silence(-1.0)
	assert_almost_eq(AudioServer.get_bus_volume_linear(AudioBuses.index(AudioBuses.MASTER)), before, 0.0001,
			"le volume choisi par le joueur est indépendant des effets de mise en scène")


func test_reverb_settings() -> void:
	var world: int = AudioBuses.index(AudioBuses.WORLD)
	var reverb: AudioEffectReverb = AudioServer.get_bus_effect(world, AudioBuses.WORLD_FX_REVERB)
	AudioManager.set_reverb(0.4, 0.9, 0.2)
	assert_true(AudioServer.is_bus_effect_enabled(world, AudioBuses.WORLD_FX_REVERB), "réverb active")
	assert_almost_eq(reverb.wet, 0.4)
	assert_almost_eq(reverb.room_size, 0.9)
	AudioManager.set_reverb(0.0)
	assert_false(AudioServer.is_bus_effect_enabled(world, AudioBuses.WORLD_FX_REVERB), "réverb coupée")


func test_play_stream_uses_requested_bus() -> void:
	var player: AudioStreamPlayer = AudioManager.play_stream(IMPACT, AudioBuses.SFX, -3.0, 1.1)
	assert_not_null(player)
	assert_eq(player.bus, AudioBuses.SFX)
	assert_almost_eq(player.volume_db, -3.0)
	assert_almost_eq(player.pitch_scale, 1.1)
	assert_true(player.playing, "le son joue")
	player.stop()


func test_pool_grows_when_all_players_busy() -> void:
	var players: Array[AudioStreamPlayer] = []
	for i in AudioManager.POOL_SIZE + 3:
		players.append(AudioManager.play_stream(IMPACT, AudioBuses.SFX))
	var unique: Dictionary = {}
	for p in players:
		unique[p] = true
	assert_eq(unique.size(), players.size(), "chaque son a son propre lecteur")
	for p in players:
		p.stop()


func test_loops_start_and_stop() -> void:
	AudioManager.play_loop(&"test_loop", HUM, AudioBuses.AMBIENCE, -6.0, 0.0)
	assert_true(AudioManager.is_loop_playing(&"test_loop"))
	AudioManager.play_loop(&"test_loop", HUM, AudioBuses.AMBIENCE, -6.0, 0.0)  # sans effet
	AudioManager.stop_loop(&"test_loop", 0.0)
	assert_false(AudioManager.is_loop_playing(&"test_loop"))


func test_noise_signal_carries_position_and_radius() -> void:
	AudioManager.noise_emitted.connect(_on_noise)
	AudioManager.emit_noise(Vector2(100, 50), 320.0, null)
	AudioManager.emit_noise(Vector2(0, 0), 0.0, null)  # rayon nul : aucun bruit perçu
	AudioManager.noise_emitted.disconnect(_on_noise)
	assert_eq(_noise_events.size(), 1, "un seul bruit perçu")
	if _noise_events.size() == 1:
		assert_eq(_noise_events[0][0], Vector2(100, 50))
		assert_almost_eq(_noise_events[0][1], 320.0)


func test_generated_ambience_is_imported_as_loop() -> void:
	# Vérifie toute la chaîne : Python écrit les points de boucle dans le WAV,
	# Godot les détecte à l'import.
	var wav: AudioStreamWAV = HUM as AudioStreamWAV
	assert_not_null(wav)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "mode boucle")
	assert_true(wav.loop_end > wav.loop_begin, "points de boucle valides")


func test_one_shot_sound_is_not_looping() -> void:
	assert_eq((IMPACT as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_DISABLED)


func test_describe_mentions_playback_mode() -> void:
	assert_true(AudioManager.describe().contains(AudioManager.get_playback_mode_name()))


func _on_noise(noise_position: Vector2, radius: float, _source: Node) -> void:
	_noise_events.append([noise_position, radius])
