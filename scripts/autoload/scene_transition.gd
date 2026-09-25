extends CanvasLayer
## Transitions entre scènes (autoload « SceneTransition »).
##
## Un rideau noir, dessiné au-dessus de tout le reste, qu'on ouvre et ferme en
## fondu. Sert aux changements de scène (menu → jeu), aux coupures au noir des
## cinématiques et au retour au checkpoint après une mort.
##
## Utilisation (le mot-clé « await » attend la fin du fondu avant de continuer) :
##     await SceneTransition.fade_out(0.5)
##     await SceneTransition.change_scene("res://scenes/levels/prototype.tscn")

## Émis quand un changement de scène est terminé (rideau rouvert).
signal scene_changed
## Émis quand le fondu en cours se termine OU est interrompu par un autre :
## ainsi, une coroutine qui attendait un fondu ne reste jamais bloquée.
signal _fade_ended

## Vrai pendant un changement de scène : les autres demandes (fondus d'un
## niveau, second clic sur un bouton…) sont alors ignorées.
var is_changing_scene: bool = false

var _curtain: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 100  # au-dessus de tous les autres calques
	process_mode = Node.PROCESS_MODE_ALWAYS
	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color.BLACK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ne bloque pas les clics
	_curtain.modulate.a = 0.0
	add_child(_curtain)


## Ferme le rideau (l'écran devient noir) en « duration » secondes.
## Sans effet pendant un changement de scène (qui gère lui-même le rideau).
func fade_out(duration: float = 0.5) -> void:
	if is_changing_scene:
		return
	await _fade_to(1.0, duration)


## Ouvre le rideau (l'image réapparaît) en « duration » secondes.
func fade_in(duration: float = 0.5) -> void:
	if is_changing_scene:
		return
	await _fade_to(0.0, duration)


## Noir immédiat (coupure franche de cinéma).
func cut_to_black() -> void:
	_stop_current_fade()
	_curtain.modulate.a = 1.0


## Vrai si le rideau est (même partiellement) fermé.
func is_covering() -> bool:
	return _curtain.modulate.a > 0.0


## Change de scène derrière le rideau : fondu au noir, chargement, fondu retour.
## Une seconde demande pendant un changement en cours est ignorée.
func change_scene(path: String, fade_duration: float = 0.5) -> void:
	if is_changing_scene:
		return
	is_changing_scene = true
	await _fade_to(1.0, fade_duration)
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition : impossible de charger %s (erreur %d)" % [path, err])
	# On attend une image pour laisser la nouvelle scène s'installer.
	await get_tree().process_frame
	await _fade_to(0.0, fade_duration)
	is_changing_scene = false
	scene_changed.emit()


func _fade_to(alpha: float, duration: float) -> void:
	_stop_current_fade()
	if duration <= 0.0:
		_curtain.modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(_curtain, "modulate:a", alpha, duration)
	_tween.finished.connect(_fade_ended.emit)
	await _fade_ended


## Interrompt le fondu en cours. Tween.kill() n'émet pas « finished » : on émet
## donc _fade_ended nous-mêmes, pour libérer la coroutine qui attendait ce fondu.
func _stop_current_fade() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
		_fade_ended.emit()
