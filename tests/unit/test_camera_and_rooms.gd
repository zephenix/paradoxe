extends TestCase
## Tests des salles et de la caméra « écran par écran ».
##
## Décor : salle A (x 0 à 1280) et salle B (x 1280 à 2560), d'un écran chacune ;
## une grande salle (x 2560 à 5120, 960 de haut) où la caméra recule (zoom 0,75).
## Le centre d'une salle d'un écran est donc à x = 640 (A) ou 1920 (B).

var world: Node2D
var camera: CameraDirector
var target: Node2D
var room_a: Room
var room_b: Room
var big_room: Room


func before_each() -> void:
	world = add_node(Node2D.new())
	room_a = _room(Vector2(0, 0), Vector2(1280, 720), 1.0)
	room_b = _room(Vector2(1280, 0), Vector2(1280, 720), 1.0)
	big_room = _room(Vector2(2560, 0), Vector2(2560, 960), 0.75)
	target = Node2D.new()
	target.position = Vector2(200, 600)
	world.add_child(target)
	camera = CameraDirector.new()
	camera.target = target
	world.add_child(camera)
	await wait_physics(1)


func _room(at: Vector2, size: Vector2, zoom_level: float) -> Room:
	var room := Room.new()
	room.position = at
	room.room_size = size
	room.camera_zoom = zoom_level
	world.add_child(room)
	return room


func test_room_contains_points() -> void:
	assert_true(room_a.world_rect().has_point(Vector2(10, 10)))
	assert_false(room_a.world_rect().has_point(Vector2(1300, 10)))
	assert_eq(camera.room_at(Vector2(1300, 300)), room_b)
	assert_null(camera.room_at(Vector2(-50, 300)), "hors de toute salle")


func test_camera_centres_screen_sized_room() -> void:
	assert_eq(camera.current_room, room_a)
	assert_eq(camera.global_position, Vector2(640, 360), "une salle d'un écran est cadrée entière")


func test_camera_slides_to_next_room() -> void:
	var entered: Array[Room] = []
	camera.room_changed.connect(func(r: Room) -> void: entered.append(r))
	target.position = Vector2(1400, 600)
	await wait_physics(3)
	assert_eq(camera.current_room, room_b)
	assert_eq(entered, [room_b] as Array[Room])
	var x_during: float = camera.global_position.x
	assert_true(x_during > 640.0 and x_during < 1920.0, "glissement en cours (x = %.0f)" % x_during)
	await wait_physics(40)
	assert_almost_eq(camera.global_position.x, 1920.0, 0.5, "glissement terminé")


func test_cut_transition_is_instant() -> void:
	room_b.transition = Room.Transition.CUT
	target.position = Vector2(1400, 600)
	await wait_physics(2)
	assert_almost_eq(camera.global_position.x, 1920.0, 0.5)


func test_big_room_zooms_out_and_follows_within_bounds() -> void:
	target.position = Vector2(2600, 900)
	camera.snap_to_target()
	assert_almost_eq(camera.zoom.x, 0.75, 0.001, "la caméra recule")
	var half_view: Vector2 = camera.get_viewport_rect().size * 0.5 / 0.75
	assert_almost_eq(camera.global_position.x, 2560.0 + half_view.x, 0.5, "bord gauche de la salle, pas au-delà")
	target.position = Vector2(3800, 900)
	await wait_physics(2)
	assert_almost_eq(camera.global_position.x, 3800.0, 0.5, "suit Élias au milieu de la salle")


func test_room_spawn_point() -> void:
	var marker := Marker2D.new()
	marker.name = "Spawn"
	marker.position = Vector2(100, 500)
	room_b.add_child(marker)
	assert_eq(room_b.spawn_point(), Vector2(1380, 500))


func test_zoom_changes_progressively_during_slide() -> void:
	target.position = Vector2(2600, 900)  # entre dans la grande salle
	await wait_physics(4)
	assert_true(camera.zoom.x < 1.0 and camera.zoom.x > 0.75, "zoom en cours de transition (%.2f)" % camera.zoom.x)
	await wait_physics(40)
	assert_almost_eq(camera.zoom.x, 0.75, 0.001, "zoom final de la salle")


func test_room_entered_event_is_emitted_once() -> void:
	var entered: Array[Node] = []
	var on_entered := func(room: Node) -> void: entered.append(room)
	Events.room_entered.connect(on_entered)
	target.position = Vector2(1400, 600)
	await wait_physics(3)
	camera.snap_to_target()  # réapparition dans la même salle : pas de nouvel évènement
	Events.room_entered.disconnect(on_entered)
	assert_eq(entered, [room_b] as Array[Node])


func test_follows_vertically_in_tall_room() -> void:
	# Salle haute : y de 800 à 2800. La caméra (720 de haut) peut aller de
	# 800 + 360 = 1160 à 2800 - 360 = 2440.
	var tall: Room = _room(Vector2(0, 800), Vector2(1280, 2000), 1.0)
	target.position = Vector2(600, 2000)
	camera.snap_to_target()
	assert_eq(camera.current_room, tall)
	assert_almost_eq(camera.global_position.y, 2000.0 - camera.target_height, 0.5, "suit Élias verticalement")
	target.position = Vector2(600, 2790)
	await wait_physics(2)
	assert_almost_eq(camera.global_position.y, 2800.0 - 360.0, 0.5, "sans montrer le dessous de la salle")


func test_spawn_point_without_marker() -> void:
	assert_eq(room_a.spawn_point(), Vector2(96, 720 - 96), "coin bas-gauche par défaut")
