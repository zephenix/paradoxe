extends TestCase
## Tests du mode chrono et du fantôme (J9, PLAN §5.8).
##
## Le meilleur passage est écrit dans un fichier de test (TEST_PATH), jamais
## dans celui du joueur : on change le chemin des réglages (resources/time_trial.tres,
## une ressource partagée) le temps du test.

const LEVEL: PackedScene = preload("res://scenes/levels/prototype.tscn")
const TITLE: PackedScene = preload("res://scenes/ui/title_screen.tscn")
const TEST_PATH: String = "user://test_ghost_best.res"

var config: TimeTrialConfig = preload("res://resources/time_trial.tres")
var level: Level
var _saved_path: String


func before_each() -> void:
	_saved_path = config.best_path
	config.best_path = TEST_PATH
	_remove_test_file()
	GameState.new_game()


func after_each() -> void:
	GameState.time_trial = false
	config.best_path = _saved_path
	_remove_test_file()
	Engine.time_scale = 1.0
	tree.paused = false
	SceneTransition.fade_in(0.0)
	AudioManager.restore_from_silence(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.music.silence()


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## Lance le prototype en mode chrono.
func start_level(opening: bool = true) -> void:
	GameState.time_trial = true
	level = LEVEL.instantiate()
	level.play_opening = opening
	level.get_node("Elias/Foley").free()
	add_node(level)
	level.player.input.from_devices = false
	level.death.input_from_devices = false
	level.cutscenes.input_from_devices = false
	await wait_physics(3)


## Un passage fictif : on va de x = 0 vers la droite, 100 px par seconde.
func fake_run(duration: float) -> GhostRun:
	var run := GhostRun.new()
	for i in roundi(duration * run.sample_rate) + 1:
		run.add_sample(Vector2(i * 100.0 / run.sample_rate, 0.0), 1, {"anim": &"walk", "time": 0.0, "speed": 1.0})
	run.time = duration
	return run


func wait_for(condition: Callable, max_frames: int = 600) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


# --- Le passage enregistré -------------------------------------------------------

func test_time_is_shown_as_minutes_seconds_hundredths() -> void:
	assert_eq(TimeTrial.format_time(0.0), "0:00.00")
	assert_eq(TimeTrial.format_time(83.456), "1:23.46")
	assert_eq(TimeTrial.format_time(600.0), "10:00.00")


func test_a_run_is_interpolated_and_survives_saving() -> void:
	var run: GhostRun = fake_run(1.0)
	assert_eq(run.sample_count(), 21, "20 photos par seconde")
	assert_almost_eq(run.position_at(0.025).x, 2.5, 0.01, "entre deux photos, on interpole")
	run.positions[5] = Vector2(900.0, 0.0)  # un saut (réapparition) : pas de glissade
	assert_eq(run.position_at(0.22), Vector2(20.0, 0.0), "juste avant le saut, il reste sur place")
	assert_eq(run.position_at(0.25), Vector2(900.0, 0.0), "puis il y est d'un coup")
	assert_true(run.save_to(TEST_PATH))
	var loaded: GhostRun = GhostRun.load_from(TEST_PATH)
	assert_not_null(loaded)
	assert_eq(loaded.sample_count(), run.sample_count())
	assert_almost_eq(loaded.time, 1.0)
	assert_eq(loaded.pose_at(0.5)["anim"], &"walk")
	assert_null(GhostRun.load_from("user://nulle_part.res"), "pas de fichier : pas de fantôme")
	var broken := GhostRun.new()
	broken.save_to(TEST_PATH)
	assert_null(GhostRun.load_from(TEST_PATH), "un passage vide est ignoré")


# --- La course ----------------------------------------------------------------------

func test_cutscenes_are_skipped_and_the_clock_runs() -> void:
	await start_level(true)  # avec la cinématique d'arrivée
	assert_not_null(level.time_trial, "le niveau a créé le chrono")
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 30), "l'arrivée est passée d'office")
	await wait_physics_seconds(0.5)
	assert_true(level.time_trial.elapsed > 0.4, "le chrono tourne : %.2f" % level.time_trial.elapsed)
	tree.paused = true
	var frozen: float = level.time_trial.elapsed
	await wait_frames(10)
	assert_eq(level.time_trial.elapsed, frozen, "en pause, le chrono s'arrête")
	tree.paused = false


func test_no_time_trial_in_a_normal_game() -> void:
	GameState.time_trial = false
	level = LEVEL.instantiate()
	level.play_opening = false
	level.get_node("Elias/Foley").free()
	(level.get_node("Story/Finale") as FinaleCutscene).return_to_title = false
	add_node(level)
	await wait_physics(2)
	assert_null(level.time_trial)


func test_arrival_saves_the_first_record_and_shows_the_results() -> void:
	await start_level(false)
	level.player.input.move = 1
	await wait_physics_seconds(1.0)
	level.player.input.move = 0
	level.cutscenes.play(level.get_node("Story/Finale"))
	assert_true(await wait_for(func() -> bool: return level.time_trial.is_finished, 30), "la fin arrête le chrono")
	var time: float = level.time_trial.elapsed
	assert_not_null(level.time_trial.results, "l'écran d'arrivée")
	var saved: GhostRun = GhostRun.load_from(TEST_PATH)
	assert_not_null(saved, "premier record : enregistré")
	assert_almost_eq(saved.time, time, 0.001)
	assert_true(absi(saved.sample_count() - roundi(time * 20.0)) <= 2, "20 photos par seconde : %d" % saved.sample_count())
	assert_true(saved.position_at(time).x > saved.position_at(0.0).x, "la trace suit Élias")
	await wait_physics(30)
	assert_true(level.is_inside_tree(), "la fin ne ramène pas au titre : l'écran d'arrivée s'en charge")
	assert_false(level.can_pause(), "pas de menu pause sur l'écran d'arrivée")


func test_a_slower_run_keeps_the_record() -> void:
	fake_run(1.0).save_to(TEST_PATH)
	await start_level(false)
	await wait_physics_seconds(1.2)
	assert_false(level.time_trial.finish(), "plus lent : pas de record")
	assert_almost_eq(GhostRun.load_from(TEST_PATH).time, 1.0, 0.001, "l'ancien record reste")
	var texts: Array[String] = []
	for label in level.time_trial.results.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.any(func(t: String) -> bool: return t.contains("Record : 0:01.00 (+")), "écart affiché : %s" % [texts])


func test_the_ghost_replays_the_best_run() -> void:
	fake_run(1.0).save_to(TEST_PATH)
	await start_level(false)
	var ghost: GhostRunner = level.time_trial.ghost
	assert_not_null(ghost, "un record : un fantôme")
	await wait_physics_seconds(0.5)
	var expected: Vector2 = level.time_trial.best.position_at(level.time_trial.elapsed)
	assert_almost_eq(ghost.global_position.x, expected.x, 0.5, "il suit le passage enregistré")
	assert_true(ghost.visible)
	assert_true(ghost.modulate.a < 1.0, "translucide")
	await wait_physics_seconds(0.7)
	assert_false(ghost.visible, "son passage fini, il disparaît")


func test_title_offers_the_time_trial_with_the_record() -> void:
	var title: Control = add_node(TITLE.instantiate())
	await wait_frames(2)
	var button: Button = title.get_node("%TimeTrialButton")
	assert_eq(button.text, "Contre la montre", "pas encore de record")
	title.free()
	fake_run(83.456).save_to(TEST_PATH)
	title = add_node(TITLE.instantiate())
	await wait_frames(2)
	assert_eq((title.get_node("%TimeTrialButton") as Button).text, "Contre la montre (record 1:23.46)")


func test_pause_menu_offers_to_restart_the_run() -> void:
	await start_level(false)
	var texts: Array[String] = []
	for button in level.pause_menu.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	assert_true(texts.has("Recommencer la course"), "en mode chrono : %s" % [texts])


# --- Finitions -------------------------------------------------------------------

func test_entering_a_room_shows_its_objective_on_the_bracelet() -> void:
	GameState.time_trial = false
	level = LEVEL.instantiate()
	level.play_opening = false
	level.get_node("Elias/Foley").free()
	add_node(level)
	level.player.input.from_devices = false
	await wait_physics(3)
	var texts: Array[String] = []
	for button in level.pause_menu.find_children("*", "Button", true, false):
		texts.append((button as Button).text)
	assert_false(texts.has("Recommencer la course"), "hors chrono, pas de course à recommencer")
	level.player.bracelet.hide_now()
	var room6: Room = level.get_node("Room6")
	level.player.global_position = (room6.get_node("Entry") as Node2D).global_position
	level.player.air_top_y = level.player.global_position.y
	assert_true(await wait_for(func() -> bool: return level.player.bracelet.is_showing(), 120), "le bracelet s'allume")
	assert_eq(level.player.bracelet.visible_rows(), [&"objective"] as Array[StringName], "avec l'objectif seul")
	assert_eq(level.player.bracelet.objective_text(), room6.objective)
