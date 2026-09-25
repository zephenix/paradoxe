class_name DeathController
extends Node
## Séquence de mort d'Élias (J4, PLAN §5.5 et §5.7), créée par le niveau.
##
##   1. RALENTI : le jeu tourne au quart de sa vitesse un court instant (on voit
##      Élias tomber) ;
##   2. TEMPS FIGÉ : le jeu se met en pause et un choix apparaît :
##        - MAINTENIR « Rembobiner » (R) : le temps remonte (jusqu'à 5 s) ; en
##          relâchant, on reprend à cet instant (une utilisation décomptée) ;
##        - « Interagir » ou « Sauter » (Entrée, Espace) : retour au checkpoint.
##   3. Le niveau fait le reste (fondu et réapparition, ou simple reprise).
##
## Sans rembobinage possible (mode classique, plus d'utilisations, historique
## trop court), il n'y a ni ralenti ni choix : retour direct au checkpoint.
##
## Ce nœud continue de fonctionner quand le jeu est en pause
## (PROCESS_MODE_ALWAYS). L'affichage du choix est PROVISOIRE : en J9, c'est
## l'hologramme du bracelet qui l'affichera.
##
## Pour les tests : input_from_devices = false, puis rewind_held = true/false
## et request_checkpoint().

## Émis quand le joueur a choisi. result : &"rewound" ou &"checkpoint".
signal decided(result: StringName)
## Émis à chaque image du défilement arrière (le niveau recadre la caméra).
signal scrubbed

const SHADER: Shader = preload("res://assets/shaders/rewind.gdshader")
## Intensité de l'effet d'image : temps figé, puis rembobinage.
const FROZEN_EFFECT: float = 0.5
const REWIND_EFFECT: float = 1.0

## Si faux, les touches ne sont pas lues (tests) : utiliser rewind_held et request_checkpoint().
var input_from_devices: bool = true
## « Rembobiner » est maintenu (rempli par les touches ou par les tests).
var rewind_held: bool = false
## Étape en cours : &"" (rien), &"slowmo", &"choice".
var phase: StringName = &""

var _checkpoint_requested: bool = false
var _layer: CanvasLayer
var _effect: ColorRect
var _prompt: Label
var _paused_by_me: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _exit_tree() -> void:
	# Quitter le niveau pendant la séquence (Échap, fin de test) : on rend au
	# jeu sa vitesse et on lève la pause.
	_restore_time()
	RewindManager.cancel_rewind()


## Joue la séquence. Renvoie &"rewound" (Élias a remonté le temps et le jeu
## reprend) ou &"checkpoint" (le niveau doit le faire réapparaître).
func play() -> StringName:
	if not RewindManager.can_rewind():
		return &"checkpoint"
	var cfg: RewindConfig = RewindManager.config
	# 1) Ralenti, mesuré en temps réel (le dernier « true » : le minuteur ignore
	#    le ralenti qu'il est chargé de mesurer).
	phase = &"slowmo"
	Engine.time_scale = cfg.slowmo_scale
	await get_tree().create_timer(cfg.slowmo_duration, true, false, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return &"checkpoint"
	# 2) Temps figé et choix.
	get_tree().paused = true
	_paused_by_me = true
	_checkpoint_requested = false
	rewind_held = false
	phase = &"choice"
	_show(FROZEN_EFFECT)
	var result: StringName = await decided
	phase = &""
	_hide()
	_restore_time()
	return result


## Demande le retour au checkpoint (touche, ou test).
func request_checkpoint() -> void:
	_checkpoint_requested = true


func _process(delta: float) -> void:
	if phase != &"choice":
		return
	if input_from_devices:
		rewind_held = Input.is_action_pressed(&"rewind")
		if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"jump"):
			_checkpoint_requested = true
	if rewind_held:
		if not RewindManager.is_rewinding:
			RewindManager.begin_rewind()
			_set_effect(REWIND_EFFECT)
		RewindManager.scrub(delta)
		scrubbed.emit()
		_update_prompt()
		return
	if RewindManager.is_rewinding:
		# Touche relâchée : on reprend là… si on a remonté assez loin.
		if RewindManager.finish_rewind():
			decided.emit(&"rewound")
			return
		_update_prompt()
	if _checkpoint_requested:
		RewindManager.cancel_rewind()
		decided.emit(&"checkpoint")


func _restore_time() -> void:
	Engine.time_scale = 1.0
	if _paused_by_me and is_inside_tree():
		get_tree().paused = false
	_paused_by_me = false


# --------------------------------------------------------------------------
# Affichage (provisoire)
# --------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_effect = ColorRect.new()
	_effect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	_effect.material = material
	_layer.add_child(_effect)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt.offset_bottom = -60.0
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color("b8fff0"))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_prompt)
	_hide()


func _show(effect: float) -> void:
	_layer.visible = true
	_set_effect(effect)
	_update_prompt()


func _hide() -> void:
	_layer.visible = false
	_set_effect(0.0)


func _set_effect(strength: float) -> void:
	(_effect.material as ShaderMaterial).set_shader_parameter(&"strength", strength)


func _update_prompt() -> void:
	var cfg: RewindConfig = RewindManager.config
	if RewindManager.is_rewinding:
		var text: String = "<<  %.1f s" % RewindManager.rewound()
		if RewindManager.at_oldest():
			text += "  (pas plus loin)"
		elif not rewind_held and RewindManager.rewound() < cfg.min_rewind:
			text += "  (remonter un peu plus)"
		_prompt.text = text + "\nRelâcher R : reprendre ici     Entrée : checkpoint"
	else:
		_prompt.text = "Maintenir R : remonter le temps (%d restant%s)\nEntrée ou Espace : reprendre au checkpoint" % [
			GameState.rewinds_left, "s" if GameState.rewinds_left > 1 else ""]
