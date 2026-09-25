extends TestCase
## Tests du combat d'Élias : dégainer, tirer, charger, se protéger, et mourir
## d'un tir. Élias est piloté par ses intentions (comme dans test_player_movement).
##
## Repères : sol à y = 480 ; Élias à x = 200, regard à droite. Les tirs ennemis
## sont créés directement (Projectile de camp « enemy ») à la hauteur voulue.

const ELIAS: PackedScene = preload("res://scenes/player/elias.tscn")
const B: float = 48.0
const FLOOR_Y: float = 480.0

var arena: Node2D
var player: Player
var states_seen: Array[StringName] = []


func before_each() -> void:
	Settings.classic_mode = false
	states_seen.clear()
	arena = add_node(Node2D.new())
	var ground := SolidBlock.new()
	ground.position = Vector2(-20, 10) * B
	ground.size_blocks = Vector2(60, 4)
	arena.add_child(ground)
	player = ELIAS.instantiate()
	player.position = Vector2(200, FLOOR_Y)
	player.get_node("Foley").free()
	arena.add_child(player)
	player.input.from_devices = false
	player.machine.state_changed.connect(func(_from: StringName, to: StringName) -> void: states_seen.append(to))
	await wait_physics(3)


func after_each() -> void:
	Settings.classic_mode = false


# --- Outils ------------------------------------------------------------------

func state() -> StringName:
	return player.machine.current_name


func projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for node in tree.get_nodes_in_group(&"projectiles"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			found.append(node as Projectile)
	return found


## Tir ennemi arrivant de la droite, à « height » pixels au-dessus du sol.
func enemy_shot(from_x: float, height: float, dir: int = -1) -> Projectile:
	var p := Projectile.new()
	var gun: WeaponConfig = load("res://resources/weapons/sentinel_gun.tres")
	p.setup(null, Projectile.TEAM_ENEMY, dir, gun.projectile_speed, false, gun)
	arena.add_child(p)
	p.global_position = Vector2(from_x, FLOOR_Y - height)
	return p


func wait_until(condition: Callable, max_frames: int = 240) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


func muzzle_height() -> float:
	return -player.weapon.config.muzzle_offset.y


# --- Tir ---------------------------------------------------------------------

func test_fire_draws_then_shoots_forward() -> void:
	var cost: float = player.energy.config.shot_cost
	player.input.press(&"fire")
	assert_true(await wait_until(func() -> bool: return projectiles().size() == 1, 30), "un projectile part")
	assert_true(&"Aim" in states_seen and &"Shoot" in states_seen, "dégainer puis tirer : %s" % [states_seen])
	var shot: Projectile = projectiles()[0]
	assert_eq(shot.direction, 1, "vers la droite")
	assert_eq(shot.team, Projectile.TEAM_PLAYER)
	assert_almost_eq(player.energy.value, player.energy.config.capacity - cost, 0.001, "un tir coûte une unité")
	await wait_physics_seconds(player.weapon.config.fire_cooldown + 0.05)
	assert_eq(state(), &"Aim", "après le recul, l'arme reste levée")


func test_fire_rate_is_limited_by_cooldown() -> void:
	for i in 20:
		player.input.press(&"fire")
		await wait_physics(1)
	var fired: int = roundi(player.energy.config.capacity - player.energy.value)
	var cfg: WeaponConfig = player.weapon.config
	var max_shots: int = 1 + floori((20.0 / 60.0 - cfg.draw_time) / cfg.fire_cooldown)
	assert_true(fired >= 1 and fired <= max_shots, "%d tirs en 1/3 s (au plus %d)" % [fired, max_shots])


func test_empty_gun_clicks_and_fires_nothing() -> void:
	player.energy.try_spend(player.energy.value)
	var dry: Array[int] = [0]
	player.weapon.dry_fired.connect(func() -> void: dry[0] += 1)
	player.input.press(&"fire")
	await wait_physics(20)
	assert_eq(projectiles().size(), 0, "sans énergie, rien ne part")
	assert_eq(dry[0], 1, "clic à vide")


func test_hold_fire_to_charge_then_release() -> void:
	var cfg: EnergyConfig = player.energy.config
	player.input.press(&"fire")
	player.input.fire = true
	assert_true(await wait_until(func() -> bool: return state() == &"Charge", 60), "la charge commence")
	await wait_physics_seconds(player.weapon.config.charge_time + 0.05)
	player.input.fire = false
	await wait_physics(2)
	var shots: Array[Projectile] = projectiles()
	assert_eq(shots.size(), 2, "le tir normal, puis le tir chargé")
	assert_true(shots.any(func(p: Projectile) -> bool: return p.charged), "un tir chargé")
	assert_almost_eq(player.energy.value, cfg.capacity - cfg.shot_cost - cfg.charged_shot_cost, 0.01)
	assert_eq(state(), &"Shoot", "recul du tir chargé")


func test_releasing_too_early_fires_no_charged_shot() -> void:
	player.input.press(&"fire")
	player.input.fire = true
	await wait_until(func() -> bool: return state() == &"Charge", 60)
	await wait_physics_seconds(player.weapon.config.charge_time * 0.5)
	player.input.fire = false
	await wait_physics(3)
	assert_eq(projectiles().size(), 1, "seulement le premier tir")
	assert_eq(state(), &"Aim")
	assert_false(player.weapon.is_charging, "charge abandonnée")


func test_fire_while_running_stops_and_shoots() -> void:
	player.input.move = 1
	player.input.run = true
	await wait_physics(30)
	player.input.press(&"fire")
	assert_true(await wait_until(func() -> bool: return projectiles().size() == 1, 30))
	player.input.move = 0
	player.input.run = false
	await wait_physics(10)
	assert_almost_eq(player.velocity.x, 0.0, 1.0, "arrêté pour tirer")


func test_turn_around_while_aiming_keeps_weapon_up() -> void:
	player.input.press(&"fire")
	await wait_until(func() -> bool: return state() == &"Aim" and projectiles().size() == 1, 60)
	await wait_physics_seconds(player.weapon.config.fire_cooldown)
	player.input.move = -1
	await wait_physics(2)
	player.input.move = 0
	assert_eq(player.facing, -1, "demi-tour")
	assert_eq(state(), &"Aim", "toujours en garde")
	player.input.press(&"fire")
	await wait_physics(5)
	assert_eq(projectiles()[-1].direction, -1, "le tir part vers la gauche")


func test_weapon_is_holstered_after_a_while() -> void:
	player.input.press(&"fire")
	await wait_until(func() -> bool: return state() == &"Aim" and projectiles().size() == 1, 60)
	await wait_physics_seconds(player.weapon.config.holster_delay + player.weapon.config.fire_cooldown + 0.2)
	assert_eq(state(), &"Idle", "arme rengainée")


func test_walking_forward_holsters_the_weapon() -> void:
	player.input.shield = false
	player.input.press(&"fire")
	await wait_until(func() -> bool: return state() == &"Aim" and projectiles().size() == 1, 60)
	await wait_physics_seconds(player.weapon.config.fire_cooldown + 0.05)
	player.input.move = 1
	await wait_physics(3)
	assert_eq(state(), &"Walk")


# --- Bouclier ------------------------------------------------------------------

func test_shield_blocks_enemy_shot_and_drains_energy() -> void:
	player.input.shield = true
	assert_true(await wait_until(func() -> bool: return player.weapon.is_shield_up(), 30), "bouclier levé")
	assert_eq(state(), &"Shield")
	enemy_shot(700.0, muzzle_height())
	await wait_physics(70)
	assert_false(player.is_dead, "le tir est arrêté")
	assert_true(player.energy.value < player.energy.config.capacity, "le bouclier consomme")
	player.input.shield = false
	await wait_physics(2)
	assert_eq(state(), &"Aim")
	assert_false(player.weapon.is_shield_up(), "bouclier baissé en relâchant")


func test_shield_falls_when_energy_runs_out_and_needs_a_new_press() -> void:
	player.energy.try_spend(player.energy.value - 1.0)
	player.input.shield = true
	await wait_until(func() -> bool: return player.weapon.is_shield_up(), 30)
	await wait_physics_seconds(1.0 / player.energy.config.shield_cost_per_second + 0.2)
	assert_false(player.weapon.is_shield_up(), "jauge vide : bouclier tombé")
	# L'énergie se recharge, mais garder la touche enfoncée ne relève pas le bouclier.
	await wait_physics_seconds(player.energy.config.recharge_delay + 0.5)
	assert_false(player.weapon.is_shield_up(), "il faut relâcher puis réappuyer")
	player.input.shield = false
	await wait_physics(2)
	player.input.shield = true
	player.input.press(&"shield")
	await wait_physics(3)
	assert_true(player.weapon.is_shield_up(), "relevé après un nouvel appui")


# --- Mort par tir ----------------------------------------------------------------

func test_enemy_shot_kills_standing_elias() -> void:
	var causes: Array[StringName] = []
	player.died.connect(func(cause: StringName) -> void: causes.append(cause))
	enemy_shot(700.0, muzzle_height())
	assert_true(await wait_until(func() -> bool: return player.is_dead, 90), "touché")
	assert_eq(causes, [&"shot"] as Array[StringName], "cause : tir")
	assert_eq(state(), &"Dead")


func test_crouching_dodges_a_standing_shot() -> void:
	player.input.down = true
	await wait_physics(10)
	assert_true(player.is_crouched)
	var shot: Projectile = enemy_shot(700.0, muzzle_height())
	await wait_physics(90)
	assert_false(player.is_dead, "le tir passe au-dessus d'Élias accroupi")
	assert_true(not is_instance_valid(shot) or shot.global_position.x < 150.0, "le tir a continué sa route")


func test_low_shot_hits_a_crouching_elias() -> void:
	player.input.down = true
	await wait_physics(10)
	enemy_shot(700.0, -player.weapon.config.low_muzzle_offset.y)
	assert_true(await wait_until(func() -> bool: return player.is_dead, 90), "un tir à genou le touche")


func test_dodge_roll_lets_a_shot_through() -> void:
	var cfg: PlayerMovementConfig = player.config
	# Le tir arrive sur Élias pendant la fenêtre d'invulnérabilité de la roulade.
	var speed: float = (load("res://resources/weapons/sentinel_gun.tres") as WeaponConfig).projectile_speed
	var roll_mid: float = cfg.roll_duration * (cfg.roll_invulnerable_window.x + cfg.roll_invulnerable_window.y) * 0.5
	var start_x: float = 200.0 + (roll_mid + 1.0 / 60.0) * speed + cfg.roll_speed() * roll_mid * 0.8
	player.input.move = 1
	player.input.press(&"roll")
	await wait_physics(1)
	player.input.move = 0
	enemy_shot(start_x, 50.0)
	await wait_physics(60)
	assert_false(player.is_dead, "invulnérable pendant la roulade d'esquive")


func test_death_interrupts_a_committed_jump() -> void:
	player.input.move = 1
	player.input.press(&"jump")
	assert_true(await wait_until(func() -> bool: return state() == &"Jump" and not player.is_on_floor(), 30))
	assert_true(player.machine.is_committed(), "le saut est engagé")
	player.kill(&"shot")
	assert_eq(state(), &"Dead", "seule la mort interrompt un mouvement engagé")


func test_dead_elias_cannot_shoot() -> void:
	player.kill(&"shot")
	player.input.press(&"fire")
	await wait_physics(20)
	assert_eq(projectiles().size(), 0)


func test_respawn_refills_energy_and_lowers_shield() -> void:
	player.input.shield = true
	await wait_until(func() -> bool: return player.weapon.is_shield_up(), 30)
	await wait_physics(30)
	player.kill(&"shot")
	assert_false(player.weapon.is_shield_up(), "bouclier baissé à la mort")
	player.respawn(Vector2(200, FLOOR_Y))
	assert_almost_eq(player.energy.value, player.energy.config.capacity, 0.001, "jauge pleine")


func test_bracelet_glow_follows_energy() -> void:
	var visual: EliasVisual = player.visual as EliasVisual
	player.energy.try_spend(player.energy.value)
	var empty_color: Color = visual._bracelet.color
	player.energy.refill()
	assert_ne(visual._bracelet.color, empty_color, "le bracelet s'éclaire quand la jauge remonte")
	assert_eq(visual._bracelet.color, EliasVisual.BRACELET_FULL)
