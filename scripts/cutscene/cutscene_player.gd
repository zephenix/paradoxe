class_name CutscenePlayer
extends CanvasLayer
## Lecteur de cinématiques (J7), créé par le niveau (Level.cutscenes).
##
## Pendant une cinématique :
##   - deux BANDES NOIRES descendent en haut et en bas de l'écran (format cinéma) ;
##   - le joueur ne pilote plus Élias (ses intentions sont vidées), et le
##     compagnon ne décide plus rien (état Scripted) ;
##   - MAINTENIR « Passer » (Échap, Espace ; Start ou A) pendant une seconde la
##     passe : une petite jauge se remplit en bas à droite. La cinématique saute
##     alors directement à son état final (Cutscene.finish).
## Puis la main revient au joueur.
##
## Pour les tests : input_from_devices = false, puis skip_held = vrai / faux.

signal started(cutscene: Cutscene)
signal ended(cutscene: Cutscene)

## Hauteur des bandes noires (pixels). Le sol des salles est à 48 px du bas de
## l'écran : des bandes plus hautes couperaient les pieds des personnages.
const BAR_HEIGHT: float = 46.0
## Durée d'apparition des bandes.
const BAR_TIME: float = 0.4
## Durée d'appui pour passer (secondes).
const SKIP_HOLD: float = 1.0

## Vrai pendant une cinématique.
var playing: bool = false
## Vrai quand le joueur a demandé à passer : les attentes se terminent aussitôt.
var skipping: bool = false
## Si faux, les touches ne sont pas lues (tests) : utiliser skip_held.
var input_from_devices: bool = true
var skip_held: bool = false
## Durée d'appui en cours sur « Passer ».
var skip_time: float = 0.0

var _top: ColorRect
var _bottom: ColorRect
var _gauge: ColorRect
var _bar_tween: Tween


func _ready() -> void:
	layer = 25
	_top = _bar()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bottom = _bar()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_gauge = ColorRect.new()
	_gauge.color = Color(0.43, 1.0, 0.69, 0.8)
	_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_set_gauge(0.0)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gauge)
	_set_bars(0.0)


## Joue une cinématique (et celles qui s'enchaînent après elle), puis rend la main.
func play(cutscene: Cutscene) -> void:
	if playing or cutscene == null or (cutscene.play_once and cutscene.played):
		return
	playing = true
	_lock(true)
	_show_bars(true)
	var current: Cutscene = cutscene
	while current != null:
		current.played = true
		skipping = false
		skip_time = 0.0
		started.emit(current)
		await current.run(self)
		current.finish(self)
		ended.emit(current)
		current = current.next_cutscene()
	skipping = false
	skip_time = 0.0
	_set_gauge(0.0)
	_show_bars(false)
	_lock(false)
	playing = false


func _process(delta: float) -> void:
	if not playing:
		return
	var held: bool = Input.is_action_pressed(&"skip") if input_from_devices else skip_held
	skip_time = skip_time + delta if held else 0.0
	if skip_time >= SKIP_HOLD:
		skipping = true
	_set_gauge(0.0 if skipping else clampf(skip_time / SKIP_HOLD, 0.0, 1.0))


# --------------------------------------------------------------------------
# Étapes utilisables par les cinématiques (toutes écourtées si on passe)
# --------------------------------------------------------------------------

## Attend « seconds » secondes.
func wait(seconds: float) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds and not skipping and is_inside_tree():
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()


## Fait marcher un personnage (Élias, le compagnon, un figurant) jusqu'à
## l'abscisse « x » du monde, à « speed » pixels par seconde.
func walk(actor: Node2D, x: float, speed: float = 110.0) -> void:
	var visual: CharacterVisual = actor.get_node_or_null(^"Visual") as CharacterVisual
	var dir: int = 1 if x > actor.global_position.x else -1
	_face(actor, dir)
	if visual:
		visual.play(&"walk", 1.0)
	while (x - actor.global_position.x) * dir > 1.0 and not skipping and is_inside_tree():
		await get_tree().physics_frame
		var step: float = speed * get_physics_process_delta_time()
		actor.global_position.x += dir * minf(step, absf(x - actor.global_position.x))
	actor.global_position.x = x
	if visual:
		visual.play(&"idle")


## Fondu au noir, puis retour de l'image (écourtés si on passe).
func fade_out(duration: float) -> void:
	await SceneTransition.fade_out(0.0 if skipping else duration)


func fade_in(duration: float) -> void:
	await SceneTransition.fade_in(0.0 if skipping else duration)


# --------------------------------------------------------------------------
# Interne
# --------------------------------------------------------------------------

## Pendant la cinématique, personne ne pilote les personnages.
func _lock(locked: bool) -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		var player: Player = node as Player
		if player:
			player.input.clear()
			player.input.from_devices = not locked and input_from_devices
			player.velocity.x = 0.0
	for node in get_tree().get_nodes_in_group(&"companion"):
		(node as Companion).set_scripted(locked)
	# Les textes d'aide des salles se taisent pendant la cinématique.
	var labels: CanvasLayer = get_parent().get_node_or_null(^"LabelsLayer") as CanvasLayer
	if labels:
		labels.visible = not locked


func _face(actor: Node2D, dir: int) -> void:
	if &"facing" in actor:
		actor.set(&"facing", dir)


func _bar() -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	return bar


func _show_bars(visible_now: bool) -> void:
	if _bar_tween:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_method(_set_bars, _top.offset_bottom / BAR_HEIGHT, 1.0 if visible_now else 0.0, BAR_TIME)


## Hauteur des bandes (0 = rentrées, 1 = sorties). On règle les « offsets » (les
## marges par rapport aux ancres) plutôt que la taille : les ancres décident.
func _set_bars(k: float) -> void:
	var height: float = BAR_HEIGHT * k
	for bar: ColorRect in [_top, _bottom]:
		bar.offset_left = 0.0  # toute la largeur de l'écran (ancres 0 et 1)
		bar.offset_right = 0.0
	_top.offset_top = 0.0
	_top.offset_bottom = height
	_bottom.offset_top = -height
	_bottom.offset_bottom = 0.0


## Jauge de passage (0 à 1), en bas à droite.
func _set_gauge(k: float) -> void:
	_gauge.offset_left = -80.0
	_gauge.offset_right = -80.0 + 64.0 * k
	_gauge.offset_top = -40.0
	_gauge.offset_bottom = -36.0
