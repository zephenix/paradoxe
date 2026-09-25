class_name InputActions
extends RefCounted
## Table des commandes du jeu et de leurs touches par défaut.
##
## Godot sépare les « actions » (sauter, tirer…) des touches physiques :
## le code du jeu ne demande jamais « la barre d'espace est-elle enfoncée ? »
## mais « l'action jump est-elle enfoncée ? ». C'est ce qui rend le
## remappage des touches possible sans toucher au code du gameplay.
##
## Les actions sont créées ici par code (et non dans les paramètres du projet)
## pour que la liste reste lisible comme un tableau, et pour pouvoir revenir
## facilement aux touches par défaut depuis le menu d'options.
##
## Clavier : on utilise les touches PHYSIQUES (leur position sur le clavier),
## si bien que « WASD » en QWERTY correspond automatiquement à « ZQSD » en AZERTY.
## Manette : disposition Xbox (A en bas, B à droite, X à gauche, Y en haut).

## Zone morte des sticks analogiques (0 = très sensible, 1 = insensible).
const DEADZONE: float = 0.3

## Pour chaque action : liste de touches clavier (codes physiques), boutons de
## manette et axes de manette [axe, sens]. Les commentaires disent à partir de
## quel jalon l'action est réellement utilisée.
const DEFAULTS: Dictionary = {
	# --- Déplacements (J2) ---
	&"move_left": {
		"keys": [KEY_LEFT, KEY_A],
		"buttons": [JOY_BUTTON_DPAD_LEFT],
		"axes": [[JOY_AXIS_LEFT_X, -1.0]],
	},
	&"move_right": {
		"keys": [KEY_RIGHT, KEY_D],
		"buttons": [JOY_BUTTON_DPAD_RIGHT],
		"axes": [[JOY_AXIS_LEFT_X, 1.0]],
	},
	&"move_up": {  # grimper, se hisser, entrer dans un ascenseur
		"keys": [KEY_UP, KEY_W],
		"buttons": [JOY_BUTTON_DPAD_UP],
		"axes": [[JOY_AXIS_LEFT_Y, -1.0]],
	},
	&"move_down": {  # s'accroupir, descendre d'un rebord
		"keys": [KEY_DOWN, KEY_S],
		"buttons": [JOY_BUTTON_DPAD_DOWN],
		"axes": [[JOY_AXIS_LEFT_Y, 1.0]],
	},
	&"jump": {
		"keys": [KEY_SPACE],
		"buttons": [JOY_BUTTON_A],
		"axes": [],
	},
	&"run": {  # maintenir pour courir
		"keys": [KEY_SHIFT],
		"buttons": [JOY_BUTTON_RIGHT_SHOULDER],
		"axes": [],
	},
	&"roll": {  # roulade / esquive
		"keys": [KEY_C],
		"buttons": [JOY_BUTTON_B],
		"axes": [],
	},
	# --- Arme (J3) ---
	&"fire": {  # appui = tir ; maintien = tir chargé
		"keys": [KEY_X, KEY_J],
		"buttons": [],
		"axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	},
	&"shield": {  # maintenir pour le bouclier
		"keys": [KEY_Z, KEY_K],
		"buttons": [],
		"axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]],
	},
	# --- Interactions (J3/J6/J7) ---
	&"interact": {
		"keys": [KEY_E, KEY_ENTER],
		"buttons": [JOY_BUTTON_X],
		"axes": [],
	},
	&"throw": {  # lancer un objet (diversion sonore)
		"keys": [KEY_F],
		"buttons": [JOY_BUTTON_LEFT_SHOULDER],
		"axes": [],
	},
	&"order": {  # ordre au compagnon : court = suivre/attendre, long = activer
		"keys": [KEY_Q],
		"buttons": [JOY_BUTTON_Y],
		"axes": [],
	},
	# --- Temps et interface (J4/J9) ---
	&"rewind": {  # maintenir après une mort pour rembobiner
		"keys": [KEY_R, KEY_BACKSPACE],
		"buttons": [JOY_BUTTON_Y],
		"axes": [],
	},
	&"bracelet": {  # afficher le bracelet holographique
		"keys": [KEY_TAB],
		"buttons": [JOY_BUTTON_BACK],
		"axes": [],
	},
	&"pause": {
		"keys": [KEY_ESCAPE, KEY_P],
		"buttons": [JOY_BUTTON_START],
		"axes": [],
	},
	&"skip": {  # maintenir pour passer une cinématique
		"keys": [KEY_ESCAPE, KEY_SPACE],
		"buttons": [JOY_BUTTON_START, JOY_BUTTON_A],
		"axes": [],
	},
}


## Crée (ou recrée) toutes les actions avec leurs touches par défaut.
## Les actions intégrées de Godot (ui_accept, ui_left…) ne sont pas touchées :
## elles servent à naviguer dans les menus.
static func install_defaults() -> void:
	for action: StringName in DEFAULTS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, DEADZONE)
		for event: InputEvent in default_events(action):
			InputMap.action_add_event(action, event)


## Construit la liste des évènements (touches, boutons, axes) par défaut d'une action.
static func default_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	var spec: Dictionary = DEFAULTS[action]
	for keycode: int in spec["keys"]:
		var key := InputEventKey.new()
		key.physical_keycode = keycode as Key
		events.append(key)
	for button: int in spec["buttons"]:
		var joy_button := InputEventJoypadButton.new()
		joy_button.button_index = button as JoyButton
		joy_button.device = -1  # -1 = n'importe quelle manette
		events.append(joy_button)
	for axis_spec: Array in spec["axes"]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis_spec[0] as JoyAxis
		motion.axis_value = axis_spec[1]
		motion.device = -1
		events.append(motion)
	return events


## Liste des noms d'actions du jeu (utile pour le menu de remappage et les tests).
static func all_actions() -> Array[StringName]:
	var names: Array[StringName] = []
	for action: StringName in DEFAULTS:
		names.append(action)
	return names
