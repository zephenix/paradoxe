extends Node
## Rembobinage temporel (autoload « RewindManager », PLAN §5.5).
##
## Principe, comme un magnétoscope :
##   1. ENREGISTRER : environ 30 fois par seconde, le gestionnaire prend une
##      « photo » de chaque objet du groupe « rewindable » (Élias, Sentinelles…) :
##      chacun fournit capture_state() -> Dictionary. Seules les 5 dernières
##      secondes sont gardées (mémoire circulaire : la plus vieille photo est
##      jetée quand une nouvelle arrive).
##   2. REMBOBINER : à la mort d'Élias, le monde est figé et, tant que le joueur
##      maintient la touche, un curseur remonte le temps ; la photo de ce moment
##      est réappliquée à chaque objet (apply_state).
##   3. REPRENDRE : au relâchement, le monde repart de la dernière photo
##      « stable » avant le curseur (voir plus bas) ; chaque objet se remet dans
##      un état cohérent (resume_state) et l'histoire postérieure est effacée.
##
## Un objet rembobinable implémente donc trois fonctions :
##     capture_state() -> Dictionary     ce qu'il faut retenir de lui
##     apply_state(state)                 se replacer (position, pose, énergie…)
##     resume_state(state)                repartir de là (état de sa machine)
## Une photo peut dire « "stable": false » : on ne peut pas reprendre à cet
## instant (par exemple au milieu d'un hissage) ; on reprend alors un peu avant.
##
## Analogie Excel : chaque photo est une ligne d'un tableau (instant, état de
## chaque objet) ; le tableau garde 150 lignes et on efface la plus ancienne à
## chaque ajout. Rembobiner = relire les lignes en remontant.
##
## Les tirs en vol ne sont pas enregistrés : ils sont effacés au rembobinage.
## Le mode classique n'a pas de rembobinage.

## Groupe Godot des objets à enregistrer.
const GROUP: StringName = &"rewindable"

## Réglages (durée d'historique, utilisations, vitesse…).
var config: RewindConfig = preload("res://resources/rewind.tres")
## Vrai quand l'enregistrement tourne.
var recording: bool = false
## Vrai pendant un rembobinage (du début du défilement arrière à la reprise).
var is_rewinding: bool = false

## Photos, de la plus ancienne à la plus récente :
## {"time": instant, "states": [[identifiant de l'objet, son état], …]}.
var _frames: Array[Dictionary] = []
## Horloge de l'enregistrement (secondes de jeu écoulées).
var _clock: float = 0.0
var _since_capture: float = 0.0
## Instant visé par le défilement arrière.
var _cursor: float = 0.0


func _ready() -> void:
	# Le rembobinage se déroule pendant que le jeu est en pause : ce nœud doit
	# continuer de fonctionner.
	process_mode = Node.PROCESS_MODE_ALWAYS


## Le rembobinage est-il disponible ? (faux en mode classique)
func is_available() -> bool:
	return not GameState.is_classic_mode()


## Efface l'historique et commence à enregistrer (début de niveau, réapparition).
func start_recording() -> void:
	clear()
	recording = is_available()
	if recording:
		capture()


## Arrête l'enregistrement, après une dernière photo (mort d'Élias).
func stop_recording() -> void:
	if recording:
		capture()
	recording = false


func clear() -> void:
	_frames.clear()
	_clock = 0.0
	_since_capture = 0.0
	is_rewinding = false


## Durée couverte par l'historique (secondes).
func history_length() -> float:
	if _frames.size() < 2:
		return 0.0
	return _frames[-1]["time"] - _frames[0]["time"]


func frame_count() -> int:
	return _frames.size()


## Vrai si Élias peut rembobiner maintenant : mode moderne, utilisations
## restantes, et assez d'historique.
func can_rewind() -> bool:
	return is_available() and GameState.rewinds_left > 0 and history_length() >= config.min_rewind


func _physics_process(delta: float) -> void:
	if not recording or get_tree().paused:
		return
	_clock += delta
	_since_capture += delta
	var period: float = 1.0 / config.captures_per_second
	if _since_capture >= period - 0.0001:
		_since_capture -= period
		capture()


## Prend une photo de tous les objets rembobinables.
func capture() -> void:
	var states: Array = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if node.has_method(&"capture_state") and not node.is_queued_for_deletion():
			states.append([node.get_instance_id(), node.call(&"capture_state")])
	_frames.append({"time": _clock, "states": states})
	# Mémoire circulaire : on jette ce qui dépasse la durée d'historique.
	while _frames.size() > 2 and _clock - _frames[0]["time"] > config.history_seconds + 0.0001:
		_frames.pop_front()


# --------------------------------------------------------------------------
# Rembobinage
# --------------------------------------------------------------------------

## Début du défilement arrière : les tirs en vol disparaissent, le son s'étouffe.
func begin_rewind() -> void:
	if _frames.is_empty():
		return
	is_rewinding = true
	_cursor = _frames[-1]["time"]
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		node.queue_free()
	AudioManager.set_muffle(config.muffle, 0.25)
	AudioManager.play_loop_sfx(&"rewind", &"rewind_loop", 0.15)


## Remonte le temps de « real_delta » secondes réelles (× rewind_speed) et
## replace le monde à cet instant. Renvoie le temps remonté depuis la mort.
func scrub(real_delta: float) -> float:
	if not is_rewinding:
		return 0.0
	_cursor = maxf(_frames[0]["time"], _cursor - config.rewind_speed * real_delta)
	_apply(_frame_index_at(_cursor))
	return rewound()


## Temps remonté depuis la mort (secondes d'historique).
func rewound() -> float:
	if _frames.is_empty():
		return 0.0
	return _frames[-1]["time"] - _cursor


## Vrai si le curseur est au bout de l'historique (on ne peut pas remonter plus).
func at_oldest() -> bool:
	return not _frames.is_empty() and _cursor <= _frames[0]["time"] + 0.0001


## Fin du défilement : si on a remonté au moins min_rewind, le monde repart de la
## dernière photo stable avant le curseur, une utilisation est décomptée, et
## l'enregistrement reprend. Renvoie faux (sans rien consommer) si on a remonté
## trop peu : le monde reste figé, le joueur peut réessayer ou choisir le checkpoint.
func finish_rewind() -> bool:
	if not is_rewinding:
		return false
	if rewound() < config.min_rewind:
		return false
	var index: int = _frame_index_at(_cursor)
	while index > 0 and not _is_stable(_frames[index]):
		index -= 1
	_apply(index)
	for pair: Array in _frames[index]["states"]:
		var node: Object = instance_from_id(pair[0])
		if is_instance_valid(node) and node.has_method(&"resume_state"):
			node.call(&"resume_state", pair[1])
	# L'histoire après ce point n'a « pas eu lieu » : on l'efface.
	_frames.resize(index + 1)
	_clock = _frames[index]["time"]
	_since_capture = 0.0
	GameState.rewinds_left = maxi(GameState.rewinds_left - 1, 0)
	_end_effects()
	AudioManager.play_sfx(&"rewind_release")
	is_rewinding = false
	recording = true
	return true


## Abandonne le rembobinage (le joueur choisit le checkpoint) : le monde est
## remis tel qu'il était au moment de la mort, avant la réapparition.
func cancel_rewind() -> void:
	if is_rewinding:
		_apply(_frames.size() - 1)
		_end_effects()
	is_rewinding = false


func _end_effects() -> void:
	AudioManager.set_muffle(0.0, 0.2)
	AudioManager.stop_loop(&"rewind", 0.1)


## Indice de la dernière photo prise avant (ou à) l'instant t.
func _frame_index_at(t: float) -> int:
	var index: int = 0
	for i in _frames.size():
		if _frames[i]["time"] <= t + 0.0001:
			index = i
		else:
			break
	return index


func _apply(index: int) -> void:
	for pair: Array in _frames[index]["states"]:
		var node: Object = instance_from_id(pair[0])
		if is_instance_valid(node) and node.has_method(&"apply_state"):
			node.call(&"apply_state", pair[1])


## Une photo est stable si aucun objet n'y déclare "stable": false.
func _is_stable(frame: Dictionary) -> bool:
	for pair: Array in frame["states"]:
		if not (pair[1] as Dictionary).get("stable", true):
			return false
	return true
