extends Control
## Écran des crédits (J9) : qui a fait quoi, et la licence du moteur Godot (la
## licence MIT demande qu'elle accompagne le jeu : Engine.get_license_text()).
## Échap, Entrée ou le bouton : retour à l'écran titre.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"

const CREDITS_TEXT: String = """PARADOXE - prototype

Un jeu de plateforme cinématique, dans l'esprit des jeux de 1991-1992.

Conception et direction : le propriétaire du projet
Programmation, dessin par code, sons et musique générés : Claude (Anthropic),
sous sa direction.

Aucun élément (nom, image, son, musique) ne vient d'un autre jeu.
Images, textures, sons et musiques sont tous calculés par le code du projet.

Moteur : Godot Engine %s - Juan Linietsky, Ariel Manzur et les contributeurs de Godot.
Police : Open Sans (SIL Open Font License 1.1).

---- Licence de Godot Engine ----

"""


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("05090b")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var text := RichTextLabel.new()
	text.name = "Text"
	text.position = Vector2(140, 50)
	text.size = Vector2(1000, 560)
	text.scroll_following = false
	text.text = CREDITS_TEXT % Engine.get_version_info().string + Engine.get_license_text()
	add_child(text)
	var back := Button.new()
	back.name = "Back"
	back.text = "Retour"
	back.position = Vector2(580, 640)
	back.pressed.connect(_leave)
	add_child(back)
	back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	AudioManager.play_sfx(&"ui_confirm")
	SceneTransition.change_scene(TITLE_SCENE)
