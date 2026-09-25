extends TestCase
## Tests des salles et de la caméra « écran par écran ».

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
