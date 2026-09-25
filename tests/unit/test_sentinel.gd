extends TestCase
## Tests des Sentinelles : patrouille, vue, ouïe, combat, bouclier, tir bas,
## poursuite, remise en place au checkpoint.
##
## Repères : sol à y = 480 (dessus). Élias est piloté par ses intentions ;
## la Sentinelle est autonome (son hasard a une graine fixe).

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const SENTINEL: PackedScene = preload("res://scenes/enemies/sentinel.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player


func before_each() -> void:
	Settings.classic_mode = false
	arena = add_node(Node2D.new())
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


## Une Sentinelle à x ; « tweak » modifie une copie de ses réglages.
func spawn_sentinel(x: float, facing: int = -1, left: float = 0.0, right: float = 0.0,
		tweak: Callable = Callable()) -> Sentinel:
	var s: Sentinel = SENTINEL.instantiate()
	s.position = Vector2(x, FLOOR_Y)
	s.start_facing = facing
	s.patrol_left_blocks = left
	s.patrol_right_blocks = right
	if tweak.is_valid():
		var cfg: SentinelConfig = s.config.duplicate()
		tweak.call(cfg)
		s.config = cfg
	arena.add_child(s)
	return s


func wait_until(condition: Callable, max_frames: int = 300) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


func enemy_projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for node in tree.get_nodes_in_group(&"projectiles"):
		var p: Projectile = node as Projectile
		if p and p.team == Projectile.TEAM_ENEMY and not p.is_queued_for_deletion():
			found.append(p)
	return found


## Tir d'Élias créé directement (sans passer par ses états), à hauteur de poitrine.
func player_shot(from_x: float, dir: int, charged: bool = false) -> Projectile:
	var p := Projectile.new()
	p.setup(null, Projectile.TEAM_PLAYER, dir, 900.0, charged, WeaponConfig.new())
	arena.add_child(p)
	p.global_position = Vector2(from_x, FLOOR_Y - 76.0)
	return p


# --- Patrouille ------------------------------------------------------------------

func test_patrols_between_its_bounds() -> void:
	var s: Sentinel = spawn_sentinel(600.0, 1, 2.0, 2.0)
	var min_x: float = INF
	var max_x: float = -INF
	for i in 60 * 12:
		min_x = minf(min_x, s.global_position.x)
		max_x = maxf(max_x, s.global_position.x)
		await wait_physics(1)
	assert_almost_eq(max_x, 600.0 + 2 * B, 6.0, "va jusqu'au bout droit")
	assert_almost_eq(min_x, 600.0 - 2 * B, 6.0, "puis jusqu'au bout gauche")
	assert_eq(s.machine.current_name, &"Patrol")


func test_stops_at_a_platform_edge() -> void:
	block(10, 7, 6, 1)  # plate-forme de x 480 à 768, dessus à y = 336
	var s: Sentinel = spawn_sentinel(600.0, 1, 0.0, 20.0)
	s.global_position = Vector2(600.0, 336.0)
	s.home = s.global_position
	await wait_physics_seconds(5.0)
	assert_almost_eq(s.global_position.y, 336.0, 2.0, "toujours sur la plate-forme")
	assert_true(s.global_position.x < 768.0, "arrêtée avant le bord")


# --- Vue -------------------------------------------------------------------------

func test_sees_player_in_front_and_shoots() -> void:
	spawn_player(300.0)
	var s: Sentinel = spawn_sentinel(700.0, -1)
	assert_true(await wait_until(func() -> bool: return s.machine.current_name == &"Combat", 10), "combat")
	var cfg: SentinelConfig = s.config
	assert_true(await wait_until(func() -> bool: return enemy_projectiles().size() > 0,
			roundi((cfg.reaction_time + cfg.aim_time) * 60.0) + 10), "tir après réaction et visée")
	assert_true(await wait_until(func() -> bool: return player.is_dead, 120), "Élias touché")


func test_does_not_see_player_behind() -> void:
	spawn_player(300.0)
	var s: Sentinel = spawn_sentinel(700.0, 1)  # regarde à droite, Élias est à gauche
	await wait_physics(60)
	assert_eq(s.machine.current_name, &"Patrol")


func test_does_not_see_through_a_wall() -> void:
	block(10, 4, 1, 6)  # mur plein de x 480 à 528
	spawn_player(300.0)
	var s: Sentinel = spawn_sentinel(700.0, -1)
	await wait_physics(60)
	assert_eq(s.machine.current_name, &"Patrol")


func test_sees_over_low_cover() -> void:
	block(10, 8.5, 1, 1.5)  # couvert de 1,5 bloc
	spawn_player(420.0)
	var s: Sentinel = spawn_sentinel(700.0, -1)
	await wait_physics(5)
	assert_true(s.sees_target, "Élias debout dépasse du couvert")


func test_does_not_see_player_out_of_range() -> void:
	spawn_player(0.0)
	var s: Sentinel = spawn_sentinel(0.0 + 700.0, -1, 0.0, 0.0,
			func(c: SentinelConfig) -> void: c.view_distance = 500.0)
	await wait_physics(30)
	assert_false(s.sees_target, "trop loin")


# --- Ouïe -----------------------------------------------------------------------

func test_hears_a_gunshot_then_searches_then_patrols_again() -> void:
	var s: Sentinel = spawn_sentinel(700.0, 1)  # dos tourné au bruit
	await wait_physics(3)
	AudioManager.emit_noise(Vector2(400.0, FLOOR_Y - 60.0), 700.0)
	await wait_physics(1)
	assert_eq(s.machine.current_name, &"Suspicious", "alertée par le bruit")
	assert_eq(s.facing, -1, "tournée vers le bruit")
	var cfg: SentinelConfig = s.config
	await wait_physics_seconds(cfg.suspicious_duration + 0.1)
	assert_eq(s.machine.current_name, &"Search", "elle va voir")
	await wait_physics_seconds(cfg.search_duration)
	assert_eq(s.machine.current_name, &"Patrol", "rien trouvé : retour à la patrouille")


func test_ignores_a_noise_out_of_earshot() -> void:
	var s: Sentinel = spawn_sentinel(700.0, 1)
	await wait_physics(3)
	AudioManager.emit_noise(Vector2(0.0, FLOOR_Y), 300.0)
	await wait_physics(2)
	assert_eq(s.machine.current_name, &"Patrol")


func test_player_shot_alerts_a_sentinel_behind_a_wall() -> void:
	block(10, 4, 1, 6)
	spawn_player(300.0)
	var s: Sentinel = spawn_sentinel(700.0, 1)
	await wait_physics(3)
	player.input.press(&"fire")
	assert_true(await wait_until(func() -> bool: return s.machine.current_name == &"Suspicious", 30),
			"le tir d'Élias s'entend à travers le mur (J6 ajoutera l'atténuation)")


# --- Combat ------------------------------------------------------------------------

func test_loses_sight_then_chases() -> void:
	spawn_player(300.0)
	var s: Sentinel = spawn_sentinel(700.0, -1)
	await wait_until(func() -> bool: return s.machine.current_name == &"Combat", 10)
	# Hors de vue (bien plus haut). Pas de respawn() : il remettrait la
	# Sentinelle à son poste (signal player_respawned).
	player.set_physics_process(false)
	player.global_position = Vector2(300.0, FLOOR_Y - 20.0 * B)
	await wait_physics_seconds(s.config.lose_sight_time + 0.1)
	assert_eq(s.machine.current_name, &"Chase", "poursuite vers le dernier endroit connu")
	assert_true(s.velocity.x < 0.0, "elle court vers lui")


func test_shield_blocks_player_shot() -> void:
	var s: Sentinel = spawn_sentinel(700.0, -1, 0.0, 0.0, func(c: SentinelConfig) -> void: c.shield_chance = 1.0)
	spawn_player(300.0)
	await wait_until(func() -> bool: return s.machine.current_name == &"Combat", 10)
	player.set_physics_process(false)  # Élias figé : on teste seulement la défense
	player_shot(400.0, 1)
	await wait_physics(30)
	assert_false(s.is_dead, "le bouclier arrête le tir")
	assert_true(s.energy.value < s.energy.config.capacity, "son bouclier consomme son énergie")


func test_unshielded_sentinel_dies_in_one_shot() -> void:
	var s: Sentinel = spawn_sentinel(700.0, -1, 0.0, 0.0, func(c: SentinelConfig) -> void: c.shield_chance = 0.0)
	var deaths: Array[int] = [0]
	s.died.connect(func() -> void: deaths[0] += 1)
	player_shot(400.0, 1)
	await wait_physics(30)
	assert_true(s.is_dead)
	assert_eq(s.machine.current_name, &"Dead")
	assert_eq(deaths[0], 1)
	assert_eq(s.collision_layer, 0, "le corps ne bloque plus les tirs")


func test_charged_shot_breaks_shield_and_next_shot_kills() -> void:
	var s: Sentinel = spawn_sentinel(700.0, -1, 0.0, 0.0, func(c: SentinelConfig) -> void: c.shield_chance = 1.0)
	spawn_player(300.0)
	await wait_until(func() -> bool: return s.machine.current_name == &"Combat", 10)
	player.set_physics_process(false)
	player_shot(400.0, 1, true)
	await wait_physics(25)
	assert_false(s.is_dead, "le tir chargé brise le bouclier sans tuer")
	assert_false(s.weapon.is_shield_up(), "bouclier brisé")
	player_shot(600.0, 1)
	await wait_physics(15)
	assert_true(s.is_dead, "sans bouclier, le tir suivant la tue")


func test_aims_low_at_a_crouching_player() -> void:
	spawn_player(300.0)
	player.input.down = true
	var s: Sentinel = spawn_sentinel(700.0, -1)
	var cfg: SentinelConfig = s.config
	assert_true(await wait_until(func() -> bool: return enemy_projectiles().size() > 0,
			roundi((cfg.reaction_time + cfg.aim_time) * 60.0) + 15))
	var shot: Projectile = enemy_projectiles()[0]
	assert_almost_eq(shot.global_position.y, FLOOR_Y + s.weapon.config.low_muzzle_offset.y, 1.0, "tir à genou")
	assert_true(await wait_until(func() -> bool: return player.is_dead, 90), "un Élias accroupi à découvert est touché")


func test_crouching_behind_cover_protects_from_shots() -> void:
	block(8, 8.5, 1, 1.5)  # couvert de 1,5 bloc (x 384 à 432) devant Élias
	spawn_player(360.0)
	player.input.down = true
	var s: Sentinel = spawn_sentinel(700.0, -1)
	await wait_physics_seconds(4.0)
	assert_false(player.is_dead, "le couvert arrête les tirs bas")
	assert_true(s.machine.current_name in [&"Combat", &"Chase", &"Search"], "la Sentinelle est en alerte")


# --- Checkpoints -----------------------------------------------------------------

func test_killed_sentinel_comes_back_when_player_respawns() -> void:
	var s: Sentinel = spawn_sentinel(700.0, -1, 0.0, 0.0, func(c: SentinelConfig) -> void: c.shield_chance = 0.0)
	s.die()
	Events.player_respawned.emit()
	assert_false(s.is_dead, "revenue à son poste")
	assert_eq(s.global_position, s.home)
	assert_eq(s.machine.current_name, &"Patrol")
	assert_eq(s.collision_layer, PhysicsLayers.ENEMIES)


func test_sentinel_killed_before_a_checkpoint_stays_dead() -> void:
	var s: Sentinel = spawn_sentinel(700.0, -1)
	s.die()
	Events.checkpoint_reached.emit(&"test")
	Events.player_respawned.emit()
	assert_true(s.is_dead, "tuée avant le checkpoint : elle ne revient pas")


# --- Tirs qui arrivent -------------------------------------------------------------

func test_shot_seen_coming_triggers_combat_toward_the_shooter() -> void:
	var s: Sentinel = spawn_sentinel(900.0, -1, 0.0, 0.0, func(c: SentinelConfig) -> void:
		c.view_distance = 200.0  # elle ne voit pas Élias, seulement le tir
		c.shield_chance = 1.0)
	spawn_player(100.0)
	player.set_physics_process(false)
	await wait_physics(3)
	var shot := Projectile.new()
	shot.setup(player, Projectile.TEAM_PLAYER, 1, 900.0, false, WeaponConfig.new())
	arena.add_child(shot)
	shot.global_position = Vector2(500.0, FLOOR_Y - 76.0)
	assert_true(await wait_until(func() -> bool: return s.machine.current_name == &"Combat", 20), "combat")
	await wait_physics(30)
	assert_false(s.is_dead, "bouclier levé à temps")
	await wait_physics_seconds(s.config.lose_sight_time + 0.3)
	assert_eq(s.machine.current_name, &"Chase", "elle part chercher le tireur")
	assert_true(s.velocity.x < 0.0, "vers la gauche, où est Élias (pas vers l'origine du monde)")


func test_shot_hidden_by_a_wall_is_ignored() -> void:
	block(15, 4, 1, 6)  # mur de x 720 à 768
	# Assez loin du mur pour ne pas ENTENDRE l'impact (J5) : on teste la vue.
	var radius: float = AudioManager.library.get_entry(&"impact_wall").noise_radius
	var s: Sentinel = spawn_sentinel(720.0 + radius + 60.0, -1)
	await wait_physics(3)
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_PLAYER, 1, 900.0, false, WeaponConfig.new())
	arena.add_child(shot)
	shot.global_position = Vector2(600.0, FLOOR_Y - 76.0)
	await wait_physics(15)
	assert_eq(s.machine.current_name, &"Patrol", "le tir s'écrase sur le mur")


func test_impact_on_a_nearby_wall_is_heard() -> void:
	block(15, 4, 1, 6)  # mur de x 720 à 768
	var s: Sentinel = spawn_sentinel(900.0, -1)
	await wait_physics(3)
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_PLAYER, 1, 900.0, false, WeaponConfig.new())
	arena.add_child(shot)
	shot.global_position = Vector2(600.0, FLOOR_Y - 76.0)
	await wait_physics(15)
	assert_eq(s.machine.current_name, &"Suspicious", "le bruit de l'impact l'intrigue")


func test_shot_from_behind_is_a_surprise() -> void:
	var s: Sentinel = spawn_sentinel(700.0, 1, 0.0, 0.0, func(c: SentinelConfig) -> void: c.shield_chance = 1.0)
	await wait_physics(3)
	var shot := Projectile.new()
	shot.setup(null, Projectile.TEAM_PLAYER, 1, 900.0, false, WeaponConfig.new())
	arena.add_child(shot)
	shot.global_position = Vector2(400.0, FLOOR_Y - 76.0)
	await wait_physics(10)
	assert_eq(s.machine.current_name, &"Patrol", "elle ne l'a pas vu venir")
	await wait_physics(20)
	assert_true(s.is_dead, "dans le dos : pas de bouclier")
