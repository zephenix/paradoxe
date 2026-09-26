extends TestCase
## Salle G (infiltration, J6) : on la traverse sans se faire repérer, comme un
## joueur prudent (critère de J6 : « salle d'infiltration jouable »).
##
## Le plan :
##   1. passer sur le tas de gravats (des pierres pour plus tard) ;
##   2. attendre que la Sentinelle 1 s'éloigne, grimper sur la passerelle basse ;
##   3. la traverser accroupi (pas muets) au-dessus d'elle : en hauteur, elle ne
##      voit pas Élias ;
##   4. attendre que la Sentinelle 2 tourne le dos, descendre de l'autre côté
##      du pilier ;
##   5. avancer accroupi, grimper sur la passerelle haute, et la traverser
##      accroupi jusqu'à la sortie.
## À aucun moment une Sentinelle ne doit passer au combat.

const LEVEL: PackedScene = preload("res://scenes/levels/test_level.tscn")

var level: Level
var player: Player
var room: Room
var s1: Sentinel
var s2: Sentinel
## Vrai si une Sentinelle de la salle est passée au combat.
var spotted: bool = false


func before_each() -> void:
	Settings.classic_mode = false
	spotted = false
	level = LEVEL.instantiate()
	level.get_node("Elias/Foley").free()
	add_node(level)
	player = level.player
	player.input.from_devices = false
	level.death.input_from_devices = false
	room = level.get_node("RoomG")
	s1 = room.get_node("Sentinel1")
	s2 = room.get_node("Sentinel2")
	for s: Sentinel in [s1, s2]:
		s.machine.state_changed.connect(func(_from: StringName, to: StringName) -> void:
			if to == &"Combat":
				spotted = true)
	await wait_physics(2)
	player.global_position = room.get_node("Spawn").global_position
	await wait_physics(30)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	Settings.classic_mode = false
	AudioManager.set_zone(&"", 0.0)


# --- Outils ------------------------------------------------------------------

## Abscisse locale à la salle G.
func gx() -> float:
	return player.global_position.x - room.global_position.x


## Marche (ou avance accroupi) jusqu'à l'abscisse locale « x ».
func go_to(x: float, crouched: bool, max_frames: int = 900) -> bool:
	player.input.down = crouched
	player.input.move = 1 if x > gx() else -1
	var dir: int = player.input.move
	for i in max_frames:
		if (gx() - x) * dir >= 0.0:
			break
		await wait_physics(1)
	player.input.move = 0
	await wait_physics(2)
	return absf(gx() - x) < 16.0


## Attend une condition (au plus max_frames images).
func wait_for(condition: Callable, max_frames: int = 1200) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


## Se hisser sur le rebord devant soi (debout, « haut »).
func climb_up() -> bool:
	player.input.down = false
	await wait_physics(15)  # se relever
	player.input.press(&"move_up")
	var ok: bool = await wait_for(func() -> bool: return player.machine.current_name == &"LedgeHang", 90)
	if ok:
		player.input.press(&"move_up")
	return await wait_for(func() -> bool: return player.machine.current_name == &"Idle" and player.is_on_floor(), 120)


# --- Test ----------------------------------------------------------------------

func test_room_g_can_be_crossed_unseen() -> void:
	assert_eq(room.ambient_light, 0.15, "salle dans la pénombre")
	# 1) Le tas de gravats.
	assert_true(await go_to(250.0, false), "au tas de gravats")
	assert_eq(player.stones, player.throw_config.max_stones, "des pierres ramassées")
	# 2) Au pied de la passerelle basse ; on attend que la Sentinelle 1 s'éloigne.
	assert_true(await go_to(419.0, false), "au pied de la passerelle basse")
	assert_true(await wait_for(func() -> bool: return s1.facing == 1 and s1.global_position.x - room.global_position.x > 700.0),
			"la Sentinelle 1 tourne le dos")
	assert_true(await climb_up(), "sur la passerelle basse")
	assert_almost_eq(player.global_position.y - room.global_position.y, 528.0, 2.0)
	# 3) Traversée accroupie, au-dessus de la Sentinelle 1.
	assert_true(await go_to(1240.0, true), "au bout de la passerelle basse")
	assert_false(spotted, "pas repéré sur la passerelle")
	# 4) On attend que la Sentinelle 2 s'éloigne vers la droite, puis on descend
	#    de l'autre côté du pilier.
	assert_true(await wait_for(func() -> bool: return s2.facing == 1 and s2.global_position.x - room.global_position.x > 1480.0, 1500),
			"la Sentinelle 2 tourne le dos")
	player.input.down = false
	await wait_physics(15)
	player.input.down = true
	assert_true(await wait_for(func() -> bool: return player.machine.current_name == &"LedgeHang", 90), "suspendu au bord")
	player.input.down = false
	await wait_physics(5)
	player.input.press(&"move_down")
	assert_true(await wait_for(func() -> bool: return player.is_on_floor() and player.machine.current_name in [&"Idle", &"Crouch"], 120),
			"au sol, de l'autre côté du pilier")
	assert_true(gx() > 1260.0, "à droite du pilier")
	# 5) Accroupi jusqu'au pied de la passerelle haute, puis on grimpe.
	assert_true(await go_to(1475.0, true), "au pied de la passerelle haute")
	assert_true(await climb_up(), "sur la passerelle haute")
	assert_true(await go_to(1800.0, true), "à la sortie")
	assert_false(spotted, "traversée sans être repéré")
	assert_false(player.is_dead)
