extends TestCase
## Tests de la cinématique d'ouverture (J8) : la table de montage est cohérente,
## chaque plan apparaît à son heure, les sons existent et partent, le silence du
## plan 10 est total, et on peut passer l'intro sans laisser de son derrière soi.

const INTRO: PackedScene = preload("res://scenes/cutscenes/intro.tscn")

var scene: IntroScene
var montage: AnimationPlayer


func before_each() -> void:
	scene = INTRO.instantiate()
	scene.auto_leave = false
	scene.input_from_devices = false
	add_node(scene)
	montage = scene.get_node("Montage")
	await wait_frames(3)


func after_each() -> void:
	AudioManager.music.silence()
	AudioManager.restore_from_silence(0.0)
	await wait_frames(2)


func _visible_shots() -> Array[String]:
	var names: Array[String] = []
	for shot in scene.get_node("Shots").get_children():
		if (shot as CanvasItem).visible:
			names.append(shot.name)
	return names


func test_montage_table_is_consistent() -> void:
	assert_eq(IntroCutscene.SHOTS.size(), 11, "11 plans (PLAN §5.12)")
	var t: float = 0.0
	for row: Array in IntroCutscene.SHOTS:
		assert_almost_eq(row[1], t, 0.001, "le plan %s commence quand le précédent finit" % row[0])
		assert_not_null(scene.get_node_or_null("Shots/" + String(row[0])), "le plan %s existe" % row[0])
		t += float(row[2])
	assert_almost_eq(t, IntroCutscene.LENGTH, 0.001, "75 s au total")
	for row: Array in IntroCutscene.CUES:
		if row[1] in ["sfx", "loop", "music"]:
			assert_not_null(AudioManager.library.get_entry(row[2]), "son %s dans la bibliothèque" % row[2])


func test_each_shot_shows_at_its_time() -> void:
	assert_true(montage.is_playing(), "l'intro démarre toute seule")
	for row: Array in IntroCutscene.SHOTS:
		montage.seek(float(row[1]) + float(row[2]) * 0.5, true)
		await wait_frames(1)
		assert_eq(_visible_shots(), [String(row[0])], "au milieu du plan %s, lui seul est visible" % row[0])
	scene.cutscenes.skip_held = true
	await wait_seconds(1.3)


func test_full_intro_plays_its_sounds_then_finishes() -> void:
	var played: Array[StringName] = []
	var on_sfx := func(id: StringName) -> void: played.append(id)
	var themes: Array[StringName] = []
	var on_theme := func(id: StringName) -> void: themes.append(id)
	AudioManager.sfx_played.connect(on_sfx)
	AudioManager.music.theme_started.connect(on_theme)
	var done: Array[bool] = [false]
	scene.finished.connect(func() -> void: done[0] = true)
	montage.speed_scale = 10.0  # 75 s en 7,5 s
	for i in 900:
		if done[0]:
			break
		await wait_frames(1)
	AudioManager.sfx_played.disconnect(on_sfx)
	AudioManager.music.theme_started.disconnect(on_theme)
	assert_true(done[0], "l'intro se termine")
	for id: StringName in [&"sfx_thunder", &"sfx_glider_pass", &"sfx_bio_scan", &"sfx_lightning_strike", &"sfx_flash_breath"]:
		assert_true(played.has(id), "%s entendu" % id)
	assert_true(played.find(&"sfx_bio_scan") < played.find(&"sfx_lightning_strike"), "dans l'ordre du montage")
	assert_eq(themes, [&"mus_theme_intro"], "le thème de l'intro")
	assert_false(AudioManager.is_loop_playing(&"intro_amb_rain_loop"), "plus de pluie après l'intro")


func test_shot_ten_cuts_everything_to_silence() -> void:
	montage.seek(57.5, true)
	await wait_frames(1)
	var intro: IntroCutscene = scene.intro
	intro.cue("music", &"mus_theme_intro", 0.0)
	assert_true(AudioManager.music.is_theme_playing())
	await wait_seconds(0.7)  # la lecture continue et passe l'instant de la coupure (58 s)
	assert_false(AudioManager.music.is_theme_playing(), "coupure : plus de musique")
	assert_eq(AudioManager.drama_gain_db, AudioManager.SILENT_DB, "silence total")
	assert_false(AudioManager.is_loop_playing(&"intro_amb_rain_loop"), "plus de pluie")
	scene.cutscenes.skip_held = true
	await wait_seconds(1.3)


func test_skipping_the_intro_leaves_no_sound_behind() -> void:
	var done: Array[bool] = [false]
	scene.finished.connect(func() -> void: done[0] = true)
	montage.seek(57.8, true)
	await wait_seconds(0.4)  # pendant le silence du plan 10 : le pire moment pour passer
	assert_eq(AudioManager.drama_gain_db, AudioManager.SILENT_DB, "on est bien dans le silence")
	scene.cutscenes.skip_held = true
	await wait_seconds(1.3)
	assert_true(done[0], "maintenir « Passer » termine l'intro")
	assert_false(montage.is_playing(), "le montage s'arrête")
	await wait_seconds(0.5)
	assert_almost_eq(AudioManager.drama_gain_db, 0.0, 0.5, "le son est revenu")
	assert_false(AudioManager.is_loop_playing(&"intro_amb_rain_loop"))
