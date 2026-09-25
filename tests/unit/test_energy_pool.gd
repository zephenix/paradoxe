extends TestCase
## Tests de la jauge d'énergie (EnergyPool) : consommation, refus quand elle est
## vide, recharge après un délai, consommation continue du bouclier.

var pool: EnergyPool
var cfg: EnergyConfig


func before_each() -> void:
	cfg = EnergyConfig.new()
	cfg.capacity = 10.0
	cfg.recharge_delay = 1.0
	cfg.recharge_rate = 2.0
	pool = EnergyPool.new()
	pool.config = cfg
	pool.set_physics_process(false)  # on fait avancer le temps à la main (tick)
	add_node(pool)


func test_starts_full() -> void:
	assert_almost_eq(pool.value, 10.0)
	assert_almost_eq(pool.ratio(), 1.0)


func test_spend_and_refuse_when_not_enough() -> void:
	assert_true(pool.try_spend(4.0))
	assert_almost_eq(pool.value, 6.0)
	assert_false(pool.try_spend(7.0), "pas assez : refusé")
	assert_almost_eq(pool.value, 6.0, 0.001, "un refus ne consomme rien")
	assert_true(pool.try_spend(6.0), "exactement ce qu'il reste : accepté")
	assert_almost_eq(pool.value, 0.0)
	assert_false(pool.try_spend(1.0), "vide : rien ne part")


func test_recharge_only_after_delay() -> void:
	pool.try_spend(5.0)
	pool.tick(0.9)
	assert_almost_eq(pool.value, 5.0, 0.001, "pas de recharge avant le délai")
	pool.tick(0.2)  # délai dépassé : recharge sur ce pas
	assert_true(pool.value > 5.0, "la recharge commence")
	for i in 60:
		pool.tick(0.1)
	assert_almost_eq(pool.value, 10.0, 0.001, "plafonnée à la capacité")


func test_spending_restarts_the_delay() -> void:
	pool.try_spend(5.0)
	pool.tick(0.8)
	pool.try_spend(1.0)
	pool.tick(0.8)
	assert_almost_eq(pool.value, 4.0, 0.001, "chaque consommation relance le délai")


func test_recharge_rate_matches_setting() -> void:
	pool.try_spend(8.0)
	pool.tick(1.0)  # fin du délai (ce pas recharge déjà 2 × 1,0 = 2 unités)
	var before: float = pool.value
	pool.tick(1.0)
	assert_almost_eq(pool.value - before, cfg.recharge_rate, 0.001, "unités par seconde")


func test_drain_is_continuous_and_stops_at_zero() -> void:
	assert_true(pool.drain(3.0, 1.0))
	assert_almost_eq(pool.value, 7.0)
	var depleted: Array[int] = [0]
	pool.depleted.connect(func() -> void: depleted[0] += 1)
	assert_false(pool.drain(10.0, 1.0), "jauge vidée : faux")
	assert_almost_eq(pool.value, 0.0, 0.001, "jamais négative")
	assert_false(pool.drain(10.0, 1.0))
	assert_eq(depleted[0], 1, "signal « vide » une seule fois")


func test_changed_signal_reports_value() -> void:
	var seen: Array[float] = []
	pool.changed.connect(func(value: float, _capacity: float) -> void: seen.append(value))
	pool.try_spend(1.0)
	pool.refill()
	assert_eq(seen, [9.0, 10.0] as Array[float])


func test_default_resources_are_consistent() -> void:
	for path: String in ["res://resources/player/energy.tres", "res://resources/enemies/sentinel_energy.tres"]:
		var c: EnergyConfig = load(path)
		assert_true(c.capacity >= c.charged_shot_cost, "%s : un tir chargé est possible jauge pleine" % path)
		assert_true(c.shot_cost > 0.0 and c.shield_cost_per_second > 0.0, path)
		assert_true(c.shield_min_energy < c.capacity, path)
