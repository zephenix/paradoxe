extends TestCase
## Tests des bruitages d'Élias (J5) : pas selon la surface et l'allure,
## respiration selon l'effort, et « chaque action du joueur a son son ».
## Ici, contrairement aux tests de déplacement, le nœud Foley est GARDÉ.
## On écoute AudioManager.sfx_played (quel son) et noise_emitted (quel rayon).

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player
var foley: PlayerFoley
## Sons joués depuis le début du test, dans l'ordre.
var played: Array[StringName] = []
## Bruits émis par Élias : [identifiant du dernier son joué, rayon].
var noises: Array[Array] = []


func before_each() -> void:
	Settings.classic_mode = false
	played.clear()
	noises.clear()
	arena = add_node(Node2D.new())
	AudioManager.sfx_played.connect(_on_played)
	AudioManager.noise_emitted.connect(_on_noise)


func after_each() -> void:
	AudioManager.sfx_played.disconnect(_on_played)
	AudioManager.noise_emitted.disconnect(_on_noise)
	Settings.classic_mode = false


func _on_played(id: StringName) -> void:
	played.append(id)


func _on_noise(_at: Vector2, radius: float, source: Node) -> void:
	if source == player and not played.is_empty():
		noises.append([played[-1], radius])


## Ajoute un bloc solide (coordonnées et tailles en blocs).
func block(x: float, y: float, w: float, h: float, surface: StringName = &"stone") -> void:
	var solid := SolidBlock.new()
	solid.position = Vector2(x, y) * B
	solid.size_blocks = Vector2(w, h)
	solid.surface = surface
	arena.add_child(solid)


func spawn(feet: Vector2 = Vector2(200, FLOOR_Y)) -> void:
	player = ELIAS.instantiate()
	player.position = feet
	arena.add_child(player)
	player.input.from_devices = false
	foley = player.get_node("Foley")
	await wait_physics(3)
	played.clear()
	noises.clear()


func count(id: StringName) -> int:
	return played.count(id)


## Rayons de bruit émis avec un son donné.
func radii_of(id: StringName) -> Array[float]:
	var found: Array[float] = []
	for pair in noises:
		if pair[0] == id:
			found.append(pair[1])
	return found


func entry_radius(id: StringName) -> float:
	return AudioManager.library.get_entry(id).noise_radius


# --- Pas -------------------------------------------------------------------------

func test_steps_follow_the_surface() -> void:
	for surface: StringName in PlayerFoley.SURFACES:
		arena.queue_free()
		arena = add_node(Node2D.new())
		block(-20, 10, 60, 4, surface)
		await spawn()
		player.input.move = 1
		await wait_physics_seconds(1.0)
		assert_true(count(PlayerFoley.step_sound_for(surface)) >= 2, "pas sur %s : %s" % [surface, played])
		assert_eq(foley.last_surface, surface)


func test_walk_steps_are_quieter_than_run_steps() -> void:
	block(-20, 10, 80, 4)
	await spawn()
	player.input.move = 1
	await wait_physics_seconds(1.0)
	var walk: Array[float] = radii_of(&"foley_step_stone")
	noises.clear()
	player.input.run = true
	await wait_physics_seconds(1.0)
	var run: Array[float] = radii_of(&"foley_step_stone")
	assert_false(walk.is_empty(), "la marche s'entend un peu")
	assert_false(run.is_empty(), "la course s'entend")
	var r: float = entry_radius(&"foley_step_stone")
	assert_almost_eq(walk[0], r * foley.config.walk_noise, 0.01, "rayon de marche")
	assert_almost_eq(run[-1], r * foley.config.run_noise, 0.01, "rayon de course")
	assert_true(walk[0] < run[-1])


func test_crouched_steps_are_silent_for_enemies() -> void:
	block(-20, 10, 60, 4)
	await spawn()
	player.input.down = true
	await wait_physics(10)
	noises.clear()
	player.input.move = 1
	await wait_physics_seconds(1.5)
	assert_true(count(&"foley_step_stone") >= 1, "on entend ses pas soi-même : %s" % [played])
	assert_true(radii_of(&"foley_step_stone").is_empty(), "mais pas les ennemis")


# --- Gestes ----------------------------------------------------------------------

func test_turn_crouch_and_holster_have_sounds() -> void:
	block(-20, 10, 60, 4)
	await spawn()
	player.input.move = -1
	await wait_physics(30)
	player.input.move = 0
	assert_eq(count(&"foley_turn"), 1, "demi-tour")
	player.input.down = true
	await wait_physics(20)
	assert_eq(count(&"foley_crouch"), 1, "accroupi")
	player.input.move = 1
	await wait_physics(30)
	player.input.move = 0
	await wait_physics(10)
	assert_eq(count(&"foley_crouch"), 1, "avancer accroupi ne rejoue pas le son")
	player.input.down = false
	await wait_physics(20)
	player.input.press(&"fire")
	await wait_physics(5)
	assert_eq(count(&"weapon_draw"), 1, "dégainer")
	await wait_physics_seconds(player.weapon.config.holster_delay + 0.5)
	assert_eq(player.machine.current_name, &"Idle")
	assert_eq(count(&"weapon_holster"), 1, "rengainer")


## Critère de J5 : chaque action du joueur a son son.
func test_every_player_action_has_a_sound() -> void:
	block(-20, 10, 80, 4)
	block(20, 7, 4, 3)  # marche de 3 blocs : Élias s'y hisse
	await spawn(Vector2(400, FLOOR_Y))
	var checks: Array[Array] = []  # [action, son attendu]
	# Marcher, courir, déraper.
	player.input.move = 1
	await wait_physics_seconds(0.6)
	checks.append([&"marche", &"foley_step_stone"])
	player.input.run = true
	await wait_physics_seconds(0.6)
	player.input.move = -1
	await wait_physics(20)
	checks.append([&"dérapage", &"foley_skid"])
	player.input.move = 0
	player.input.run = false
	await wait_physics_seconds(0.8)
	# Sauter sur place, retomber.
	player.input.press(&"jump")
	await wait_physics_seconds(1.2)
	checks.append([&"saut", &"foley_jump"])
	checks.append([&"réception", &"foley_land"])
	# Roulade.
	player.input.press(&"roll")
	await wait_physics_seconds(0.8)
	checks.append([&"roulade", &"foley_roll"])
	# Tir, charge, bouclier.
	player.input.press(&"fire")
	await wait_physics_seconds(0.5)
	checks.append([&"dégainer", &"weapon_draw"])
	checks.append([&"tir", &"weapon_shot"])
	player.input.press(&"fire")
	player.input.fire = true
	await wait_physics_seconds(0.3)
	checks.append([&"charge", &"weapon_charge"])
	player.input.fire = false
	await wait_physics_seconds(0.3)
	player.input.shield = true
	await wait_physics_seconds(0.4)
	checks.append([&"bouclier", &"shield_up"])
	player.input.shield = false
	await wait_physics_seconds(0.4)
	checks.append([&"bouclier baissé", &"shield_down"])
	await wait_physics_seconds(player.weapon.config.holster_delay + 0.3)
	checks.append([&"rengainer", &"weapon_holster"])
	# Se hisser sur la marche (x = 960).
	player.global_position = Vector2(20 * B - 13, FLOOR_Y)
	player.facing = 1
	await wait_physics(5)
	player.input.press(&"move_up")
	await wait_physics_seconds(0.8)
	player.input.press(&"move_up")
	await wait_physics_seconds(1.2)
	checks.append([&"prise du rebord", &"foley_grab"])
	checks.append([&"se hisser", &"foley_climb"])
	# Respiration.
	await wait_physics_seconds(foley.config.breath_interval_calm + foley.config.breath_interval_jitter)
	checks.append([&"respiration", &"breath_calm"])
	for check: Array in checks:
		assert_true(count(check[1]) >= 1, "%s -> %s (joués : %s)" % [check[0], check[1], played])


# --- Respiration -----------------------------------------------------------------

func test_breath_follows_effort() -> void:
	block(-40, 10, 200, 4)
	await spawn()
	assert_eq(foley.breath_tier(), &"calm")
	player.input.move = 1
	player.input.run = true
	var seconds_to_exhaust: float = foley.config.exhausted_tier / foley.config.effort_run_per_second
	await wait_physics_seconds(seconds_to_exhaust + 1.0)
	assert_eq(foley.breath_tier(), &"exhausted", "essoufflé après une longue course (effort %.2f)" % foley.effort)
	assert_true(count(&"breath_exhausted") + count(&"breath_effort") >= 1, "on l'entend")
	player.input.run = false
	player.input.move = 0
	await wait_physics_seconds(foley.config.exhausted_tier / foley.config.effort_decay_per_second + 0.5)
	assert_eq(foley.breath_tier(), &"calm", "il reprend son souffle")
