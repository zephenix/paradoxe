extends TestCase
## Tests des projectiles, des boucliers et de l'arme partagée (Weapon).
##
## Décor : un mur fin à x = 600 ; les cibles sont de petits corps physiques qui
## comptent les coups reçus. Un tir file à 900 px/s (15 px par image).

var arena: Node2D


## Cible d'essai : un corps sur la couche voulue, qui accepte ou esquive les tirs.
class Target:
	extends StaticBody2D
	var hits: int = 0
	var dodging: bool = false

	func _init(layer: int) -> void:
		collision_layer = layer
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 90)
		shape.shape = rect
		shape.position = Vector2(0, -45)
		add_child(shape)

	func take_hit(_projectile: Projectile) -> bool:
		if dodging:
			return false
		hits += 1
		return true


func before_each() -> void:
	arena = add_node(Node2D.new())


func _wall(x: float, width: float = 4.0) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 400)
	shape.shape = rect
	wall.position = Vector2(x, 0)
	wall.add_child(shape)
	arena.add_child(wall)


func _target(x: float, layer: int = PhysicsLayers.ENEMIES) -> Target:
	var t := Target.new(layer)
	t.position = Vector2(x, 40)
	arena.add_child(t)
	return t


func _shoot(x: float, dir: int, team: StringName = Projectile.TEAM_PLAYER, charged: bool = false,
		speed: float = 900.0) -> Projectile:
	var p := Projectile.new()
	p.setup(null, team, dir, speed, charged, WeaponConfig.new())
	arena.add_child(p)
	p.global_position = Vector2(x, 0)
	return p


func _shield(x: float, team: StringName) -> EnergyShield:
	var s := EnergyShield.new()
	s.team = team
	s.config = WeaponConfig.new()
	s.position = Vector2(x, 40)
	arena.add_child(s)
	s.raise()
	return s


func test_projectile_stops_on_a_thin_wall() -> void:
	_wall(600.0, 2.0)
	var target: Target = _target(700.0)
	var p: Projectile = _shoot(100.0, 1, Projectile.TEAM_PLAYER, false, 2400.0)
	var kinds: Array[StringName] = []
	p.impacted.connect(func(kind: StringName, _at: Vector2) -> void: kinds.append(kind))
	await wait_physics(30)
	assert_eq(kinds, [&"wall"] as Array[StringName], "arrêté par un mur de 2 px, même à 40 px par image")
	assert_eq(target.hits, 0, "la cible derrière le mur est épargnée")
	assert_false(is_instance_valid(p), "le projectile a disparu")


func test_projectile_hits_enemy_target() -> void:
	var target: Target = _target(400.0)
	_shoot(100.0, 1)
	await wait_physics(40)
	assert_eq(target.hits, 1)


func test_projectile_ignores_its_own_team() -> void:
	var friend: Target = _target(300.0, PhysicsLayers.PLAYER)
	var enemy: Target = _target(500.0)
	_shoot(100.0, 1, Projectile.TEAM_PLAYER)
	await wait_physics(40)
	assert_eq(friend.hits, 0, "un tir d'Élias ne touche pas Élias")
	assert_eq(enemy.hits, 1)


func test_enemy_projectile_goes_left_and_hits_player() -> void:
	var player_body: Target = _target(200.0, PhysicsLayers.PLAYER)
	_shoot(600.0, -1, Projectile.TEAM_ENEMY)
	await wait_physics(40)
	assert_eq(player_body.hits, 1)


func test_dodging_target_lets_the_shot_through() -> void:
	var dodger: Target = _target(300.0)
	dodger.dodging = true
	var behind: Target = _target(500.0)
	_shoot(100.0, 1)
	await wait_physics(40)
	assert_eq(behind.hits, 1, "le tir continue après une esquive")


func test_projectile_expires_after_its_range() -> void:
	var p: Projectile = _shoot(0.0, 1)
	p.max_distance = 150.0
	await wait_physics(12)
	assert_false(is_instance_valid(p), "éteint après 150 px")


func test_enemy_shield_blocks_normal_shot() -> void:
	var shield: EnergyShield = _shield(300.0, Projectile.TEAM_ENEMY)
	var behind: Target = _target(400.0)
	var blocked: Array[int] = [0]
	shield.blocked.connect(func(_p: Projectile) -> void: blocked[0] += 1)
	_shoot(100.0, 1)
	await wait_physics(30)
	assert_eq(blocked[0], 1, "le bouclier arrête le tir")
	assert_eq(behind.hits, 0)
	assert_true(shield.is_up, "un tir normal ne brise pas le bouclier")


func test_charged_shot_breaks_shield_which_cannot_be_raised_at_once() -> void:
	var shield: EnergyShield = _shield(300.0, Projectile.TEAM_ENEMY)
	var broken: Array[int] = [0]
	shield.broken.connect(func() -> void: broken[0] += 1)
	_shoot(100.0, 1, Projectile.TEAM_PLAYER, true)
	await wait_physics(30)
	assert_eq(broken[0], 1)
	assert_false(shield.is_up, "bouclier tombé")
	assert_false(shield.raise(), "impossible de le relever tout de suite")
	await wait_physics_seconds(shield.config.shield_broken_cooldown + 0.1)
	assert_true(shield.raise(), "relevable après le délai")


func test_own_shield_does_not_block_own_shots() -> void:
	_shield(300.0, Projectile.TEAM_PLAYER)
	var enemy: Target = _target(500.0)
	_shoot(100.0, 1, Projectile.TEAM_PLAYER)
	await wait_physics(40)
	assert_eq(enemy.hits, 1)


func test_lowered_shield_lets_shots_through() -> void:
	var shield: EnergyShield = _shield(300.0, Projectile.TEAM_ENEMY)
	shield.lower()
	var enemy: Target = _target(500.0)
	_shoot(100.0, 1)
	await wait_physics(40)
	assert_eq(enemy.hits, 1)


# --- L'arme partagée (Weapon) -------------------------------------------------

func _armed(x: float, team: StringName = Projectile.TEAM_PLAYER) -> Weapon:
	var holder := Node2D.new()
	holder.position = Vector2(x, 100)
	arena.add_child(holder)
	var pool := EnergyPool.new()
	pool.config = EnergyConfig.new()
	pool.set_physics_process(false)
	holder.add_child(pool)
	var weapon := Weapon.new()
	weapon.team = team
	weapon.energy = pool
	holder.add_child(weapon)
	return weapon


func test_weapon_fire_costs_energy_and_spawns_projectile_in_level() -> void:
	var weapon: Weapon = _armed(100.0)
	var p: Projectile = weapon.fire()
	assert_not_null(p)
	assert_almost_eq(weapon.energy.value, weapon.energy.config.capacity - weapon.energy.config.shot_cost)
	assert_eq(p.get_parent(), arena, "le projectile vit dans le niveau, pas sous le tireur")
	assert_eq(p.global_position, weapon.muzzle_position(), "il part du canon")


func test_weapon_fire_toward_facing() -> void:
	var weapon: Weapon = _armed(300.0)
	weapon.facing = -1
	var p: Projectile = weapon.fire()
	assert_eq(p.direction, -1)
	assert_true(p.global_position.x < 300.0, "canon devant, à gauche")
	assert_true(weapon.shield.position.x < 0.0, "le bouclier passe aussi à gauche")


func test_empty_weapon_clicks_and_fires_nothing() -> void:
	var weapon: Weapon = _armed(100.0)
	weapon.energy.try_spend(weapon.energy.value)
	var dry: Array[int] = [0]
	weapon.dry_fired.connect(func() -> void: dry[0] += 1)
	assert_null(weapon.fire(), "sans énergie, rien ne part")
	assert_eq(dry[0], 1, "clic à vide")
	assert_eq(get_tree_projectiles(), 0)


func test_shot_is_heard_by_enemies() -> void:
	var weapon: Weapon = _armed(100.0)
	var heard: Array[float] = []
	var listener := func(_at: Vector2, radius: float, _source: Node) -> void: heard.append(radius)
	AudioManager.noise_emitted.connect(listener)
	weapon.fire()
	AudioManager.noise_emitted.disconnect(listener)
	assert_eq(heard, [AudioManager.library.get_entry(weapon.config.shot_sound_id).noise_radius] as Array[float], "un tir fait du bruit")
	assert_true(heard[0] > 0.0, "rayon de bruit réglé dans la bibliothèque")


func test_charge_needs_full_time() -> void:
	var weapon: Weapon = _armed(100.0)
	weapon.start_charge()
	weapon.update_charge(weapon.config.charge_time * 0.5)
	assert_null(weapon.release_charge(), "charge incomplète : pas de tir")
	var ready: Array[int] = [0]
	weapon.charge_ready.connect(func() -> void: ready[0] += 1)
	weapon.start_charge()
	weapon.update_charge(weapon.config.charge_time * 0.6)
	weapon.update_charge(weapon.config.charge_time * 0.6)
	weapon.update_charge(0.1)
	assert_eq(ready[0], 1, "signal « prêt » une seule fois")
	var before: float = weapon.energy.value
	var p: Projectile = weapon.release_charge()
	assert_true(p != null and p.charged, "tir chargé")
	assert_almost_eq(before - weapon.energy.value, weapon.energy.config.charged_shot_cost)


func test_shield_drains_energy_and_falls_when_empty() -> void:
	var weapon: Weapon = _armed(100.0)
	assert_true(weapon.raise_shield())
	var cfg: EnergyConfig = weapon.energy.config
	assert_true(weapon.sustain_shield(1.0))
	assert_almost_eq(weapon.energy.value, cfg.capacity - cfg.shield_cost_per_second)
	var seconds: int = 0
	while weapon.sustain_shield(0.5) and seconds < 100:
		seconds += 1
	assert_false(weapon.is_shield_up(), "jauge vide : le bouclier tombe")
	assert_false(weapon.raise_shield(), "impossible de le relever à vide")


func get_tree_projectiles() -> int:
	return tree.get_nodes_in_group(&"projectiles").size()
