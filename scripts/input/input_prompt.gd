class_name InputPrompt
extends RefCounted
## Les noms des touches, tels que le joueur les voit (J9, PLAN §5.11).
##
## Les commandes sont réglées sur des touches PHYSIQUES (leur place sur le
## clavier) : la touche « Q » d'un clavier QWERTY est à la place du « A » d'un
## clavier AZERTY. Pour l'afficher, on demande au système quelle lettre est
## gravée à cette place sur le clavier du joueur : un joueur AZERTY lit « A ».
## À la manette, on affiche le nom du bouton (disposition Xbox).
##
## Les textes des salles utilisent des « jetons » entre accolades, remplacés au
## moment de l'affichage : « {jump} : sauter » devient « Espace : sauter » au
## clavier et « A : sauter » à la manette. Comme une formule Excel qui irait
## chercher la valeur d'une cellule plutôt que de l'écrire en dur.

## Noms français des touches spéciales (le système les donne en anglais).
const KEY_NAMES: Dictionary = {
	"Space": "Espace", "Shift": "Maj", "Escape": "Échap", "Enter": "Entrée", "Tab": "Tab",
	"Backspace": "Retour arrière", "Up": "Haut", "Down": "Bas", "Left": "Gauche", "Right": "Droite",
	"Ctrl": "Ctrl", "Alt": "Alt", "Delete": "Suppr", "Insert": "Inser", "Home": "Début", "End": "Fin",
	"PageUp": "Page préc.", "PageDown": "Page suiv.", "CapsLock": "Verr. maj",
}

## Noms des boutons de manette (disposition Xbox).
const BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Select", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "Croix haut", JOY_BUTTON_DPAD_DOWN: "Croix bas",
	JOY_BUTTON_DPAD_LEFT: "Croix gauche", JOY_BUTTON_DPAD_RIGHT: "Croix droite",
}

## Jetons spéciaux (plusieurs commandes à la fois).
const COMBINED: Dictionary = {
	&"move": ["Flèches", "Stick gauche"],
}


## Nom d'un évènement (touche, bouton, axe) ; « ? » s'il est inconnu.
static func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		var name: String = OS.get_keycode_string(code)
		return KEY_NAMES.get(name, name)
	if event is InputEventJoypadButton:
		return BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "Bouton %d" % (event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "Stick G gauche" if motion.axis_value < 0.0 else "Stick G droite"
			JOY_AXIS_LEFT_Y:
				return "Stick G haut" if motion.axis_value < 0.0 else "Stick G bas"
			_:
				return "Axe %d" % motion.axis
	return "?"


## Vrai si l'évènement vient d'une manette.
static func is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Nom de la touche (ou du bouton) principale d'une commande, pour le clavier ou
## la manette. Plusieurs touches au clavier : « X ou J ».
static func action_label(action: StringName, gamepad: bool) -> String:
	if COMBINED.has(action):
		return COMBINED[action][1 if gamepad else 0]
	if not InputMap.has_action(action):
		return "?"
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		if is_pad(event) == gamepad:
			var name: String = event_label(event)
			if not names.has(name):
				names.append(name)
	if names.is_empty():
		return "-"
	# Au clavier, les deux premières touches (« X ou J ») ; les flèches et les
	# lettres de déplacement doublent les mêmes commandes : on n'en garde qu'une.
	if gamepad or action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		return names[0]
	return " ou ".join(names.slice(0, 2))


## Remplace les jetons {commande} d'un texte par le nom des touches.
static func fill(template: String, gamepad: bool) -> String:
	var out: String = template
	var start: int = out.find("{")
	while start >= 0:
		var stop: int = out.find("}", start)
		if stop < 0:
			break
		var token: StringName = StringName(out.substr(start + 1, stop - start - 1))
		var label: String = action_label(token, gamepad)
		out = out.substr(0, start) + label + out.substr(stop + 1)
		start = out.find("{", start + label.length())
	return out
