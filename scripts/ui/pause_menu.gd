class_name PauseMenu
extends CanvasLayer
## Menu pause (J9) : Échap (ou Start) en jeu. Le jeu s'arrête derrière (l'arbre
## de scène est mis « en pause » : seuls les nœuds réglés sur « toujours »
## continuent, comme ce menu et la musique).
##   - Reprendre ;
##   - Recommencer au checkpoint ;
##   - Options (le même menu qu'à l'écran titre) ;
##   - Retour au titre.
## Créé par le Level ; il ne s'ouvre ni pendant une cinématique, ni pendant la
## séquence de mort (qui a son propre choix).

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

## Émis quand le joueur demande à repartir du checkpoint (le Level s'en charge).
signal restart_requested

var is_open: bool = false
var _root: Control
var _first: Button
var _options: OptionsMenu


func _ready() -> void:
	layer = 30  # au-dessus du jeu, des textes et des bandes de cinématique
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.03, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(500, 220)
	box.custom_minimum_size = Vector2(280, 0)
	box.add_theme_constant_override(&"separation", 10)
	_root.add_child(box)
	var heading := Label.new()
	heading.text = "PAUSE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override(&"font_size", 34)
	box.add_child(heading)
	_first = _button(box, "Reprendre", close)
	_button(box, "Recommencer au checkpoint", func() -> void:
		close()
		restart_requested.emit())
	_button(box, "Options", open_options)
	_button(box, "Retour au titre", func() -> void:
		close()
		SceneTransition.change_scene(TITLE_SCENE))


func _button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	box.add_child(button)
	return button


func open() -> void:
	if is_open:
		return
	is_open = true
	_root.visible = true
	get_tree().paused = true
	AudioManager.play_sfx(&"ui_confirm")
	_first.grab_focus()


func close() -> void:
	if not is_open:
		return
	if _options:
		_options.queue_free()
		_options = null
	is_open = false
	_root.visible = false
	get_tree().paused = false


func open_options() -> void:
	_options = OptionsMenu.new()
	_options.closed.connect(func() -> void:
		_options = null
		_first.grab_focus())
	_root.add_child(_options)


## Échap referme le menu (le menu d'options gère lui-même son Échap).
func _unhandled_input(event: InputEvent) -> void:
	if is_open and _options == null and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		close()
