class_name CameraDirector
extends Camera2D
## Caméra « écran par écran ».
##
## Elle regarde dans quelle salle se trouve Élias. Quand il change de salle,
## elle glisse vers la nouvelle (ou coupe net, selon la salle), avec un fondu
## de zoom. Dans une salle plus grande que l'écran, elle suit Élias sans
## jamais montrer l'extérieur de la salle. Les couches de parallaxe (Parallax2D)
## suivent automatiquement la caméra : un léger décalage de profondeur accompagne
## chaque glissement.

## Émis quand la caméra adopte une nouvelle salle.
signal room_changed(room: Room)

## Nœud suivi (Élias).
@export var target: Node2D
## Durée du glissement entre deux salles (secondes).
@export var slide_duration: float = 0.45
## Hauteur (pixels) du point suivi au-dessus des pieds : le centre du corps.
@export var target_height: float = 45.0

var current_room: Room
var _from_position: Vector2
var _from_zoom: float = 1.0
var _transition_time: float = -1.0  # < 0 : pas de transition en cours


func _ready() -> void:
	position_smoothing_enabled = false
	make_current()
	snap_to_target()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var room: Room = room_at(_target_point())
	if room and room != current_room:
		_enter_room(room)
	if current_room == null:
		return
	var zoom_goal: float = current_room.camera_zoom
	var goal: Vector2 = framing_for(current_room, _target_point(), zoom_goal)
	if _transition_time >= 0.0:
		_transition_time += delta
		var k: float = clampf(_transition_time / slide_duration, 0.0, 1.0)
		var t: float = ease(k, -2.2)  # accélère puis ralentit
		global_position = _from_position.lerp(goal, t)
		var z: float = lerpf(_from_zoom, zoom_goal, t)
		zoom = Vector2(z, z)
		if k >= 1.0:
			_transition_time = -1.0
	else:
		global_position = goal
		zoom = Vector2(zoom_goal, zoom_goal)


## Recadre immédiatement (début de niveau, réapparition). N'annonce une entrée
## de salle (signaux) que si la salle a vraiment changé : une réapparition dans
## la même salle ne doit pas, par exemple, relancer son ambiance sonore (J5).
func snap_to_target() -> void:
	if target == null:
		return
	var previous: Room = current_room
	current_room = room_at(_target_point())
	if current_room:
		zoom = Vector2(current_room.camera_zoom, current_room.camera_zoom)
		global_position = framing_for(current_room, _target_point(), current_room.camera_zoom)
		if current_room != previous:
			room_changed.emit(current_room)
			Events.room_entered.emit(current_room)
	_transition_time = -1.0


## Salle contenant « point » (la première trouvée), ou null.
func room_at(point: Vector2) -> Room:
	for node in get_tree().get_nodes_in_group(&"rooms"):
		var room: Room = node as Room
		if room and room.world_rect().has_point(point):
			return room
	return null


## Centre de caméra pour cadrer « room » en suivant « point », sans sortir de la salle.
func framing_for(room: Room, point: Vector2, zoom_level: float) -> Vector2:
	var rect: Rect2 = room.world_rect()
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / zoom_level
	var center := Vector2.ZERO
	for axis in 2:
		if rect.size[axis] <= half_view[axis] * 2.0:
			center[axis] = rect.get_center()[axis]
		else:
			center[axis] = clampf(point[axis], rect.position[axis] + half_view[axis], rect.end[axis] - half_view[axis])
	return center


func _enter_room(room: Room) -> void:
	var first: bool = current_room == null
	current_room = room
	if first or room.transition == Room.Transition.CUT:
		_transition_time = -1.0
	else:
		_from_position = global_position
		_from_zoom = zoom.x
		_transition_time = 0.0
	room_changed.emit(room)
	Events.room_entered.emit(room)


func _target_point() -> Vector2:
	return target.global_position + Vector2(0, -target_height)
