extends TestCase
## Écrans 4 et 5 du prototype, de bout en bout (critère de J7) : la capture
## dans la clairière, la rencontre en cellule, puis l'évasion à deux (leviers
## ensemble, plaque de pression, casier, ascenseur manœuvré par l'un pour
## l'autre) jusqu'à la sortie. Élias est piloté comme par un joueur ; le
## compagnon ne reçoit que des ordres.

const LEVEL: PackedScene = preload("res://scenes/levels/prototype.tscn")

var level: Level
var player: Player
var buddy: Companion
var room5: Room
var elevator: Elevator


func before_each() -> void:
	Settings.classic_mode = false
	level = LEVEL.instantiate()
	level.get_node("Elias/Foley").free()
	add_node(level)
	player = level.player
	player.input.from_devices = false
	level.death.input_from_devices = false
	level.cutscenes.input_from_devices = false
	room5 = level.get_node("Room5")
	buddy = room5.get_node("Companion")
	elevator = room5.get_node("Elevator")
	await wait_physics(3)


func after_each() -> void:
	Engine.time_scale = 1.0
	tree.paused = false
	SceneTransition.fade_in(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.stop_loop(Elevator.LOOP_ID, 0.0)


# --- Outils ------------------------------------------------------------------

## Abscisse et ordonnée locales à la salle 5.
func lx() -> float:
	return player.global_position.x - room5.global_position.x


func ly(node: Node2D) -> float:
	return node.global_position.y - room5.global_position.y


func walk_to(x: float, room_x: float, max_frames: int = 900) -> bool:
	player.input.move = 1 if x > player.global_position.x - room_x else -1
	var dir: int = player.input.move
	for i in max_frames:
		if (player.global_position.x - room_x - x) * dir >= 0.0:
			break
		await wait_physics(1)
	player.input.move = 0
	await wait_physics(4)
	return absf(player.global_position.x - room_x - x) < 20.0


func face(dir: int) -> void:
	player.facing = dir
	await wait_physics(2)


func interact() -> void:
	player.input.press(&"interact")
	await wait_physics_seconds(player.config.interact_duration + 0.1)


func order(seconds: float) -> void:
	player.input.order = true
	await wait_physics_seconds(seconds)
	player.input.order = false
	await wait_physics(3)


func wait_for(condition: Callable, max_frames: int = 1200) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await wait_physics(1)
	return condition.call()


# --- Tests ---------------------------------------------------------------------

func test_capture_then_meeting() -> void:
	assert_false(GameState.unarmed, "armé au départ")
	player.input.move = 1
	assert_true(await wait_for(func() -> bool: return level.cutscenes.playing, 900), "la capture commence")
	player.input.move = 0
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 3000), "capture et rencontre jouées")
	assert_true(GameState.unarmed, "son arme est confisquée")
	assert_eq(GameState.checkpoint_id, &"cellule", "réapparition dans la cellule")
	assert_true(room5.world_rect().has_point(player.global_position), "Élias est dans la salle 5")
	assert_false(SceneTransition.is_covering(), "l'image est revenue")
	assert_true(player.input.move == 0 and not player.is_dead)
	assert_eq(buddy.machine.current_name, &"Wait", "le compagnon attend dans sa cellule")


func test_cutscene_can_be_skipped() -> void:
	player.input.move = 1
	assert_true(await wait_for(func() -> bool: return level.cutscenes.playing, 900))
	player.input.move = 0
	level.cutscenes.skip_held = true
	assert_true(await wait_for(func() -> bool: return not level.cutscenes.playing, 400),
			"en maintenant « Passer », tout se termine vite")
	level.cutscenes.skip_held = false
	assert_true(GameState.unarmed)
	assert_true(room5.world_rect().has_point(player.global_position), "même état final")
	await wait_physics(5)
	assert_false(SceneTransition.is_covering(), "pas d'écran noir")


func test_screens_4_and_5_end_to_end() -> void:
	# --- Écran 4 : la capture (passée pour aller vite) ---
	player.input.move = 1
	assert_true(await wait_for(func() -> bool: return level.cutscenes.playing, 900))
	player.input.move = 0
	level.cutscenes.skip_held = true
	await wait_for(func() -> bool: return not level.cutscenes.playing, 400)
	level.cutscenes.skip_held = false
	await wait_physics(10)
	var rx: float = room5.global_position.x
	# --- Cellules : les deux leviers ensemble ---
	assert_true(await walk_to(350.0, rx), "près de son levier")
	await face(1)
	await interact()
	assert_true((room5.get_node("LeverA") as Lever).on, "levier A tiré")
	await order(buddy.config.long_press_time + 0.1)
	var bars_a: Door = room5.get_node("BarsA")
	assert_true(await wait_for(func() -> bool: return bars_a.is_open(), 400), "les deux portes de cellule s'ouvrent")
	# --- Le couloir : la plaque de pression ---
	await order(0.1)
	assert_eq(buddy.mode, &"Follow", "le compagnon suit")
	assert_true(await walk_to(880.0, rx), "près de la plaque")
	await wait_physics_seconds(1.5)
	await order(buddy.config.long_press_time + 0.1)
	var door_c: Door = room5.get_node("DoorC")
	assert_true(await wait_for(func() -> bool: return door_c.is_open(), 600), "il tient la plaque : la porte s'ouvre")
	assert_true(await walk_to(1110.0, rx), "de l'autre côté de la porte")
	await face(1)
	await interact()
	assert_true((room5.get_node("LeverC") as Lever).on, "le levier la bloque ouverte")
	await order(0.1)
	# --- Le casier : l'arme ---
	assert_true(await walk_to(1230.0, rx), "devant le casier")
	await face(1)
	await interact()
	assert_false(GameState.unarmed, "arme retrouvée")
	# --- L'ascenseur, manœuvré par l'un pour l'autre ---
	assert_true(await walk_to(1700.0, rx), "sur l'ascenseur")
	await wait_physics_seconds(2.0)
	await order(buddy.config.long_press_time + 0.1)
	assert_true(await wait_for(func() -> bool: return elevator.is_at_top(), 900), "le compagnon l'envoie en haut")
	assert_almost_eq(ly(player), 240.0, 4.0, "Élias en haut")
	assert_true(await walk_to(1510.0, rx), "sur le palier")
	await face(-1)
	await interact()
	assert_true(await wait_for(func() -> bool: return elevator.is_at_bottom(), 900), "le terminal le renvoie en bas")
	await order(0.1)
	assert_eq(buddy.mode, &"Follow")
	assert_true(await wait_for(func() -> bool: return absf(buddy.global_position.x - elevator.center_x()) < 10.0, 900),
			"le compagnon monte sur l'ascenseur")
	await interact()
	assert_true(await wait_for(func() -> bool: return elevator.is_at_top(), 900), "et Élias le fait monter")
	assert_almost_eq(ly(buddy), 240.0, 4.0, "le compagnon est en haut")
	# --- La sortie ---
	var exit: ExitZone = room5.get_node("Exit")
	assert_true(await walk_to(1240.0, rx), "à la sortie")
	assert_true(await wait_for(func() -> bool: return exit.reached, 600), "sortie atteinte, à deux")
	assert_false(player.is_dead)
