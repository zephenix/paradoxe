extends TestCase
## Tests de la perception des Sentinelles (J6, PLAN §5.4) : lumière, cône de
## vision, posture, jauge de suspicion, bruit atténué par les murs, lampes,
## mode classique.
##
## Arène : sol à y = 480, dans une salle (Room) dont on règle la lumière
## ambiante. La Sentinelle monte la garde à x = 700, regard vers la gauche ;
## Élias arrive par la gauche.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const SENTINEL: PackedScene = preload("res://scenes/enemies/sentinel.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0
const DARK: float = 0.15

var arena: Node2D
var room: Room
var player: Player
var sentinel: Sentinel
var cfg: SentinelConfig


func before_each() -> void:
	Settings.classic_mode = false
	arena = add_node(Node2D.new())
	room = Room.new()
	room.position = Vector2(-20, -10) * B
	room.room_size = Vector2(80, 24) * B
	room.ambient_light = 1.0
	arena.add_child(room)
	block(-20, 10, 80, 4)


func after_each() -> void:
	Settings.classic_mode = false


# --- Outils ------------------------------------------------------------------

func block(x: float, y: float, w: float, h: float) -> SolidBlock:
	var solid := SolidBlock.new()
	solid.position = Vector2(x, y) * B
	solid.size_blocks = Vector2(w, h)
	arena.add_child(solid)
	return solid


func spawn_player(x: float, facing: int = 1) -> void:
	player = ELIAS.instantiate()
	player.position = Vector2(x, FLOOR_Y)
	player.start_facing = facing
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false


func spawn_sentinel(x: float = 700.0, facing: int = -1) -> Sentinel:
	sentinel = SENTINEL.instantiate()
	sentinel.position = Vector2(x, FLOOR_Y)
	sentinel.start_facing = facing
	sentinel.patrol_left_blocks = 0.0
	sentinel.patrol_right_blocks = 0.0
	arena.add_child(sentinel)
	cfg = sentinel.config
	return sentinel


func lamp(at: Vector2, radius: float = 280.0, energy: float = 0.9) -> LightSource:
	var light := LightSource.new()
	light.position = at
	light.radius = radius
	light.energy = energy
	arena.add_child(light)
	return light


## Élias à « distance » pixels devant la Sentinelle (à sa gauche).
func setup(distance: float, ambient: float) -> void:
	room.ambient_light = ambient
	spawn_sentinel()
	spawn_player(700.0 - distance)
	await wait_physics(3)


func state() -> StringName:
	return sentinel.machine.current_name


# --- Lumière ---------------------------------------------------------------------

func test_light_level_is_ambient_plus_lamps() -> void:
	room.ambient_light = 0.2
	await wait_physics(1)
	assert_almost_eq(Lighting.level_at(arena, Vector2(0, 400)), 0.2, 0.001, "lumière ambiante seule")
	var light: LightSource = lamp(Vector2(0, 200), 300.0, 0.8)
	await wait_physics(1)
	var expected: float = 0.2 + 0.8 * (1.0 - 200.0 / 300.0)
	assert_almost_eq(Lighting.level_at(arena, Vector2(0, 400)), expected, 0.001, "ambiante + énergie × (1 - d/r)")
	assert_almost_eq(Lighting.level_at(arena, Vector2(0, 510)), 0.2, 0.001, "hors du rayon : ambiante")
	light.shatter()
	assert_almost_eq(Lighting.level_at(arena, Vector2(0, 400)), 0.2, 0.001, "lampe brisée : plus de lumière")
	assert_false(light.lit)


func test_walls_cast_shadows_in_the_calculation() -> void:
	room.ambient_light = 0.1
	lamp(Vector2(0, 300), 400.0, 1.0)
	block(2, 4, 1, 6)  # mur de x 96 à 144, du haut jusqu'au sol
	await wait_physics(1)
	assert_true(Lighting.level_at(arena, Vector2(60, 430)) > 0.5, "côté lampe : éclairé")
	assert_almost_eq(Lighting.level_at(arena, Vector2(200, 430)), 0.1, 0.001, "derrière le mur : dans l'ombre")


func test_light_is_capped_at_one() -> void:
	room.ambient_light = 1.0
	lamp(Vector2(0, 400), 300.0, 1.0)
	await wait_physics(1)
	assert_almost_eq(Lighting.level_at(arena, Vector2(0, 420)), 1.0, 0.001)


# --- Vue ---------------------------------------------------------------------------

func test_full_light_means_immediate_combat() -> void:
	await setup(300.0, 1.0)
	assert_true(sentinel.visibility >= cfg.clear_sight, "silhouette nette (%.2f)" % sentinel.visibility)
	await wait_physics(5)
	assert_eq(state(), &"Combat", "comme en J3 en pleine lumière")


func test_darkness_hides_elias_at_a_distance() -> void:
	await setup(400.0, DARK)
	player.input.down = true
	await wait_physics(10)
	assert_true(sentinel.visibility > 0.0, "une vague silhouette")
	assert_true(sentinel.visibility * cfg.sight_gain < cfg.suspicion_decay, "trop vague pour l'inquiéter (%.3f)" % sentinel.visibility)
	await wait_physics_seconds(8.0)
	assert_eq(state(), &"Patrol", "accroupi dans le noir, à distance : jamais repéré")
	assert_almost_eq(sentinel.suspicion, 0.0, 0.001)


func test_darkness_only_delays_detection_up_close() -> void:
	await setup(180.0, DARK)  # debout, assez près
	assert_true(sentinel.visibility < cfg.clear_sight, "pas nette (%.2f)" % sentinel.visibility)
	await wait_physics_seconds(0.5)
	assert_eq(state(), &"Patrol", "pas de réaction immédiate dans le noir")
	# La suspicion monte peu à peu : elle finit par s'alerter, puis par le reconnaître.
	assert_true(await wait_until_state(&"Suspicious", 900), "elle s'alerte (suspicion %.2f)" % sentinel.suspicion)
	assert_true(await wait_until_state(&"Combat", 1200), "à force de le regarder, elle le reconnaît")


func test_crouching_makes_elias_less_visible() -> void:
	await setup(350.0, 0.5)
	var standing: float = sentinel.visibility
	player.input.down = true
	await wait_physics(20)
	assert_true(player.is_crouched)
	assert_almost_eq(sentinel.visibility, standing * cfg.crouch_visibility, 0.03,
			"accroupi : %.0f %% de la visibilité debout" % (cfg.crouch_visibility * 100.0))


func test_a_lamp_reveals_elias_in_the_dark() -> void:
	var light: LightSource = lamp(Vector2(350, 330), 280.0, 0.9)
	await setup(350.0, DARK)  # Élias à x = 350, sous la lampe
	await wait_physics(3)
	assert_true(sentinel.visibility >= cfg.clear_sight, "sous la lampe : vu (%.2f)" % sentinel.visibility)
	light.shatter()
	await wait_physics(1)
	assert_true(sentinel.visibility < cfg.clear_sight, "lampe brisée : dans le noir (%.2f)" % sentinel.visibility)


func test_close_up_she_notices_even_in_the_dark() -> void:
	await setup(70.0, 0.0)
	assert_almost_eq(sentinel.visibility, 1.0, 0.001, "tout près : vu")
	await wait_physics(5)
	assert_eq(state(), &"Combat")


func test_nothing_is_seen_behind_her() -> void:
	room.ambient_light = 1.0
	spawn_sentinel(700.0, 1)  # regard vers la droite
	spawn_player(400.0)
	await wait_physics(10)
	assert_almost_eq(sentinel.visibility, 0.0, 0.001)
	assert_eq(state(), &"Patrol")


func test_vision_cone_excludes_steep_angles() -> void:
	room.ambient_light = 1.0
	block(11.25, 7.5, 2, 0.5)  # plate-forme de x 540 à 636, dessus à y = 360 (2,5 blocs plus haut)
	spawn_sentinel(700.0, -1)
	spawn_player(590.0)
	player.global_position = Vector2(590.0, 360.0)
	await wait_physics(10)
	# 110 px de côté, 120 px plus haut : dans la portée et la hauteur de vue,
	# mais sous un angle de plus de 35° : hors du cône.
	assert_true(player.is_on_floor(), "Élias est sur la plate-forme")
	assert_almost_eq(sentinel.visibility, 0.0, 0.001, "hors du cône de vision")
	# Le même écart, à l'horizontale : vu.
	player.global_position = Vector2(590.0 - 60.0, FLOOR_Y)
	await wait_physics(3)
	assert_true(sentinel.visibility > 0.0, "de face : vu")


func test_a_wall_blocks_the_view() -> void:
	room.ambient_light = 1.0
	block(10, 6, 1, 4)  # mur de x 480 à 528
	await setup(300.0, 1.0)
	assert_almost_eq(sentinel.visibility, 0.0, 0.001)
	await wait_physics(10)
	assert_eq(state(), &"Patrol")


# --- Jauge de suspicion -----------------------------------------------------------

func test_suspicion_decays_back_to_calm() -> void:
	await setup(2000.0, 1.0)  # Élias hors de vue
	sentinel.suspicion = 0.2  # sous le seuil d'alerte
	await wait_physics_seconds(1.0)
	assert_almost_eq(sentinel.suspicion, 0.2 - cfg.suspicion_decay, 0.01, "elle retombe doucement")
	assert_eq(state(), &"Patrol")


func test_faint_clue_alerts_then_she_calms_down() -> void:
	await setup(2000.0, 1.0)
	sentinel.hear(Vector2(400, FLOOR_Y), cfg.suspicious_threshold + 0.05)
	assert_eq(state(), &"Suspicious", "un petit indice l'alerte")
	await wait_physics_seconds(cfg.suspicious_duration + 0.2)
	assert_eq(state(), &"Patrol", "rien d'autre : elle se rassure")


func test_strong_clue_sends_her_searching() -> void:
	await setup(2000.0, 1.0)
	sentinel.hear(Vector2(400, FLOOR_Y), cfg.search_threshold + 0.1)
	await wait_physics_seconds(cfg.suspicious_duration + 0.2)
	assert_eq(state(), &"Search", "indice sérieux : elle va voir")


func test_guard_returns_to_her_post_and_resumes_her_watch() -> void:
	await setup(2000.0, 1.0)  # garde à x = 700, regard vers la gauche ; Élias hors de vue
	# Un bruit devant elle, à gauche : elle ira voir, et reviendra en marchant
	# vers la droite (dos à son sens de guet).
	sentinel.hear(Vector2(500, FLOOR_Y), cfg.search_threshold + 0.1)
	assert_eq(sentinel.facing, -1, "tournée vers le bruit")
	assert_true(await wait_until_state(&"Search", 300), "elle va voir")
	assert_true(await wait_until_state(&"Patrol", 900), "rien trouvé : elle revient")
	var home_reached: bool = false
	for i in 600:
		await wait_physics(1)
		if absf(sentinel.global_position.x - 700.0) < 4.0:
			home_reached = true
			break
	assert_true(home_reached, "de retour à son poste")
	await wait_physics(3)
	assert_eq(sentinel.facing, -1, "elle reprend sa surveillance dans son sens de départ")


# --- Ouïe -------------------------------------------------------------------------

func test_noise_through_a_wall_carries_less_far() -> void:
	room.ambient_light = 1.0
	spawn_sentinel(700.0, 1)  # dos tourné
	await wait_physics(3)
	var open_radius: float = sentinel.heard_radius_of(Vector2(450, FLOOR_Y), 400.0)
	assert_almost_eq(open_radius, 400.0, 0.01, "rien entre eux")
	block(12, 6, 1, 4)  # mur de x 576 à 624
	await wait_physics(1)
	var walled: float = sentinel.heard_radius_of(Vector2(450, FLOOR_Y), 400.0)
	assert_almost_eq(walled, 400.0 * cfg.wall_attenuation, 0.01, "un mur : rayon réduit")
	AudioManager.emit_noise(Vector2(450, FLOOR_Y), 400.0)  # à 250 px, rayon réduit à 200
	await wait_physics(2)
	assert_eq(state(), &"Patrol", "étouffé par le mur")
	AudioManager.emit_noise(Vector2(560, FLOOR_Y), 400.0)  # à 140 px : entendu malgré le mur
	await wait_physics(2)
	assert_eq(state(), &"Suspicious")


func test_close_noise_worries_more_than_far_noise() -> void:
	room.ambient_light = 1.0
	spawn_sentinel(700.0, 1)
	await wait_physics(3)
	AudioManager.emit_noise(Vector2(700.0 - 380.0, FLOOR_Y), 400.0)
	var far: float = sentinel.suspicion
	sentinel.suspicion = 0.0
	sentinel.machine.transition_to(&"Patrol")
	AudioManager.emit_noise(Vector2(700.0 - 40.0, FLOOR_Y), 400.0)
	var near: float = sentinel.suspicion
	assert_true(near > far + 0.3, "proche %.2f, lointain %.2f" % [near, far])
	assert_true(far >= cfg.noise_suspicion_far - 0.001)


# --- Mode classique -----------------------------------------------------------------

func test_classic_mode_ignores_the_darkness() -> void:
	Settings.classic_mode = true
	await setup(450.0, DARK)
	assert_almost_eq(sentinel.visibility, 1.0, 0.001, "dans son champ de vision : vu")
	await wait_physics(5)
	assert_eq(state(), &"Combat", "comme dans les jeux d'origine")


# --- Lampes ---------------------------------------------------------------------------

func test_a_shot_breaks_a_lamp_and_the_noise_alerts() -> void:
	room.ambient_light = DARK
	var light: LightSource = lamp(Vector2(500, 404), 280.0, 0.9)  # à hauteur de tir
	spawn_sentinel(900.0, 1)  # dos tourné, à 400 px
	await wait_physics(3)
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_PLAYER, 1, 900.0, false, WeaponConfig.new())
	arena.add_child(shot)
	shot.global_position = Vector2(300, 404)
	await wait_physics(20)
	assert_false(light.lit, "la lampe est brisée")
	assert_false(is_instance_valid(shot), "le tir s'arrête sur la lampe")
	assert_eq(state(), &"Suspicious", "le bruit de verre l'alerte")


func test_lamp_state_follows_rewind_and_respawn() -> void:
	var light: LightSource = lamp(Vector2(0, 300))
	await wait_physics(1)
	var lit_state: Dictionary = light.capture_state()
	light.shatter()
	light.apply_state(lit_state)
	assert_true(light.lit, "rembobinée : rallumée")
	light.shatter()
	Events.player_respawned.emit()
	assert_true(light.lit, "réapparition au checkpoint : réparée")
	light.shatter()
	Events.checkpoint_reached.emit(&"test_lampe")
	Events.player_respawned.emit()
	assert_false(light.lit, "brisée avant le checkpoint : elle le reste")


func wait_until_state(target: StringName, max_frames: int) -> bool:
	for i in max_frames:
		if state() == target:
			return true
		await wait_physics(1)
	return state() == target
