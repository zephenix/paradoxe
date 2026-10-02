class_name TimeTrial
extends Node
## Le mode chrono (J9, PLAN §5.8), créé par le Level quand GameState.time_trial
## est vrai (bouton « Contre la montre » de l'écran titre).
##
##   - Le chrono part au début du niveau (écran 2) et s'arrête quand la
##     cinématique de fin commence. Les cinématiques sont passées automatiquement
##     (CutscenePlayer). Il compte le temps du JEU : il s'arrête pendant la pause
##     et le choix de la séquence de mort ; une mort coûte donc le temps rejoué.
##   - Pendant la course, la trace d'Élias est enregistrée (GhostRun, 20 photos par
##     seconde). Si le temps bat le record, elle est sauvegardée et devient le
##     nouveau fantôme.
##   - Le fantôme du meilleur passage (GhostRunner) court en même temps que le
##     joueur.
##   - À l'arrivée, un écran montre le temps et le record ; on recommence ou on
##     revient au titre.
## Réglages : resources/time_trial.tres.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const LEVEL_SCENE: String = "res://scenes/levels/prototype.tscn"

## Émis à l'arrivée : temps (secondes) et vrai si c'est un nouveau record.
signal finished(time: float, record: bool)

var config: TimeTrialConfig = preload("res://resources/time_trial.tres")
## Fichier du meilleur passage (les tests en utilisent un autre).
var best_path: String = ""
## Temps écoulé (secondes de jeu).
var elapsed: float = 0.0
var running: bool = false
var is_finished: bool = false
## Passage en cours d'enregistrement, et meilleur passage (null s'il n'y en a pas).
var current_run: GhostRun
var best: GhostRun
var ghost: GhostRunner
## Écran d'arrivée (null tant qu'on n'est pas arrivé).
var results: CanvasLayer

var _level: Level
var _since_sample: float = 0.0
var _clock_label: Label
var _record_label: Label


func _init(level: Level = null) -> void:
	_level = level


func _ready() -> void:
	if best_path == "":
		best_path = config.best_path
	best = GhostRun.load_from(best_path)
	current_run = GhostRun.new()
	current_run.sample_rate = config.sample_rate
	_create_clock()
	if _level:
		if best:
			ghost = GhostRunner.new(best, config.ghost_color)
			ghost.name = "Ghost"
			_level.add_child(ghost)
		if _level.cutscenes:
			_level.cutscenes.started.connect(_on_cutscene_started)
	running = true
	_sample()


func _physics_process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	if ghost:
		ghost.seek(elapsed)
	_since_sample += delta
	var interval: float = 1.0 / config.sample_rate
	while _since_sample >= interval:
		_since_sample -= interval
		_sample()
	_clock_label.text = format_time(elapsed)


## Une photo d'Élias pour le fantôme.
func _sample() -> void:
	var player: Player = _level.player if _level else null
	if player:
		current_run.add_sample(player.global_position, player.facing, player.visual.capture_pose())


## La fin : la cinématique finale ne ramène pas au titre (l'écran d'arrivée s'en charge).
func _on_cutscene_started(cutscene: Cutscene) -> void:
	var finale: FinaleCutscene = cutscene as FinaleCutscene
	if finale and running:
		finale.return_to_title = false
		finish()


## Arrêt du chrono. Sauvegarde le passage s'il bat le record. Renvoie vrai si
## c'est un nouveau record.
func finish() -> bool:
	if is_finished:
		return false
	running = false
	is_finished = true
	current_run.time = elapsed
	var previous: float = best.time if best else INF
	var record: bool = elapsed < previous
	if record and not current_run.save_to(best_path):
		push_warning("TimeTrial : impossible d'enregistrer le record dans %s" % best_path)
	_show_results(record, previous)
	finished.emit(elapsed, record)
	return record


## « 1:23.45 » (minutes, secondes, centièmes).
static func format_time(seconds: float) -> String:
	var hundredths: int = roundi(seconds * 100.0)
	return "%d:%02d.%02d" % [floori(hundredths / 6000.0), floori(hundredths / 100.0) % 60, hundredths % 100]


## Meilleur temps enregistré dans « path » (INF s'il n'y en a pas) : pour l'écran titre.
static func best_time(path: String = "") -> float:
	var config_path: String = path if path != "" else (load("res://resources/time_trial.tres") as TimeTrialConfig).best_path
	var run: GhostRun = GhostRun.load_from(config_path)
	return run.time if run else INF


# --------------------------------------------------------------------------
# Affichage
# --------------------------------------------------------------------------

## Le chrono, en haut à droite (un calque : la pénombre ne l'assombrit pas).
func _create_clock() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ClockLayer"
	layer.layer = 7
	add_child(layer)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -220.0
	box.offset_right = -24.0
	box.offset_top = 16.0
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	layer.add_child(box)
	_clock_label = _label(box, format_time(0.0), 30)
	_record_label = _label(box, ("Record : " + format_time(best.time)) if best else "Pas encore de record", 15)
	_record_label.modulate = Color(0.75, 0.9, 0.86)


func _label(parent: Control, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.05, 0.05))
	label.add_theme_constant_override(&"outline_size", 5)
	parent.add_child(label)
	return label


## L'écran d'arrivée : au-dessus du fondu au noir de la fin (calque 110).
func _show_results(record: bool, previous: float) -> void:
	if _level and _level.player:
		_level.player.input.from_devices = false  # Élias ne bouge plus derrière l'écran
	results = CanvasLayer.new()
	results.name = "Results"
	results.layer = 110
	results.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(results)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.03, 0.04, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	results.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -260.0
	box.offset_right = 260.0
	box.offset_top = -150.0
	box.offset_bottom = 150.0
	box.add_theme_constant_override(&"separation", 12)
	results.add_child(box)
	var title := _centered(box, "ARRIVÉE", 34)
	title.modulate = Color(0.55, 1.0, 0.85)
	_centered(box, "Temps : " + format_time(elapsed), 28)
	if record:
		_centered(box, "Nouveau record !" if previous < INF else "Premier record ! Votre fantôme vous attendra.", 18)
	else:
		_centered(box, "Record : %s (+%s)" % [format_time(previous), format_time(elapsed - previous)], 18)
	var again := Button.new()
	again.text = "Recommencer"
	again.pressed.connect(func() -> void: SceneTransition.change_scene(LEVEL_SCENE))
	box.add_child(again)
	var back := Button.new()
	back.text = "Retour au titre"
	back.pressed.connect(func() -> void:
		GameState.time_trial = false
		SceneTransition.change_scene(TITLE_SCENE))
	box.add_child(back)
	again.grab_focus()


func _centered(parent: Control, text: String, size: int) -> Label:
	var label := _label(parent, text, size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
