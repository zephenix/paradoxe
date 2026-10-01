extends TestCase
## Essai graphique (après J8) : textures sans raccord et leur relief, blocs et
## façades texturés, faces éclairées par les lampes, ambiance de salle (lumière
## principale, brume, poussières), halo des lampes, personnages ombrés et détaillés.

const STYLES: Array[String] = ["concrete", "brick", "metal", "planks", "fabric"]
const LEVEL: PackedScene = preload("res://scenes/levels/prototype.tscn")
const RUINS_NIGHT: RoomAtmosphere = preload("res://resources/art/atmospheres/ruins_night.tres")


func after_each() -> void:
	SceneTransition.fade_in(0.0)
	GameState.new_game()
	AudioManager.set_zone(&"", 0.0)
	AudioManager.music.silence()


## Écart moyen de luminosité entre deux colonnes (ou lignes) d'une image.
func _gap(image: Image, a: int, b: int, vertical: bool) -> float:
	var total: float = 0.0
	var count: int = image.get_height() if vertical else image.get_width()
	for i in count:
		var ca: Color = image.get_pixel(a, i) if vertical else image.get_pixel(i, a)
		var cb: Color = image.get_pixel(b, i) if vertical else image.get_pixel(i, b)
		total += absf(ca.get_luminance() - cb.get_luminance())
	return total / count


func test_textures_tile_without_seams() -> void:
	for name in STYLES:
		var style: SurfaceStyle = load("res://resources/art/surfaces/%s.tres" % name)
		assert_not_null(style.diffuse, "%s : couleur" % name)
		assert_not_null(style.normal, "%s : relief" % name)
		for texture: Texture2D in [style.diffuse, style.normal]:
			var image: Image = texture.get_image()
			image.decompress()
			var w: int = image.get_width()
			var h: int = image.get_height()
			# Le bord droit doit « continuer » le bord gauche : l'écart entre eux ne
			# dépasse pas le plus grand écart entre deux colonnes voisines de
			# l'intérieur (les joints de plaques ou de planches en font partie).
			var widest: float = 0.0
			for x in w - 1:
				widest = maxf(widest, _gap(image, x, x + 1, true))
			var tallest: float = 0.0
			for y in h - 1:
				tallest = maxf(tallest, _gap(image, y, y + 1, false))
			assert_true(_gap(image, w - 1, 0, true) <= widest + 0.01, "%s : raccord gauche-droite invisible" % texture.resource_path)
			assert_true(_gap(image, h - 1, 0, false) <= tallest + 0.01, "%s : raccord haut-bas invisible" % texture.resource_path)


func test_textured_block_has_texture_and_relief() -> void:
	var block := SolidBlock.new()
	block.size_blocks = Vector2(4, 2)
	block.style = load("res://resources/art/surfaces/concrete.tres")
	add_node(block)
	var face: Polygon2D = null
	for child in block.get_children():
		if child is Polygon2D and (child as Polygon2D).texture != null:
			face = child
	assert_not_null(face, "une face texturée")
	var texture: CanvasTexture = face.texture as CanvasTexture
	assert_not_null(texture.normal_texture, "avec son relief (normal map)")
	assert_eq(face.uv.size(), face.polygon.size(), "une coordonnée de texture par sommet")
	assert_eq(face.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED, "la texture se répète")


func test_flat_block_is_unchanged_without_style() -> void:
	var block := SolidBlock.new()
	add_node(block)
	for child in block.get_children():
		if child is Polygon2D:
			assert_null((child as Polygon2D).texture, "sans matière : aplats, comme avant")


## Avant l'essai, la forme d'ombre d'un bloc couvrait sa propre face : une lampe
## n'éclairait jamais le sol sous elle. Seules les arêtes du « dos » projettent
## l'ombre maintenant.
func test_block_face_is_not_in_its_own_shadow() -> void:
	var block := SolidBlock.new()
	add_node(block)
	var occluders: int = 0
	for child in block.get_children():
		if child is LightOccluder2D:
			occluders += 1
			assert_ne((child as LightOccluder2D).occluder.cull_mode, OccluderPolygon2D.CULL_DISABLED, "arêtes avant sans ombre")
	assert_eq(occluders, 1)


func test_room_atmosphere_adds_fog_and_dust() -> void:
	var room := Room.new()
	room.room_size = Vector2(1280, 720)
	room.atmosphere = RUINS_NIGHT
	add_node(room)
	var fog: ColorRect = room.get_node_or_null(^"Fog") as ColorRect
	assert_not_null(fog, "brume")
	assert_almost_eq(fog.position.y + fog.size.y, 720.0, 0.5, "posée au bas de la salle")
	assert_not_null(room.get_node_or_null(^"Dust"), "poussières")
	var bare := Room.new()
	add_node(bare)
	assert_null(bare.get_node_or_null(^"Fog"), "sans ambiance : pas de brume")


func test_key_light_follows_the_room() -> void:
	GameState.new_game()
	var level: Level = LEVEL.instantiate()
	level.play_opening = false
	level.get_node("Elias/Foley").free()
	add_node(level)
	var player: Player = level.player
	player.input.from_devices = false
	await wait_physics(3)
	assert_almost_eq(level.key_light.energy, 0.0, 0.001, "écran 2 : pas de lumière principale")
	player.global_position = (level.get_node("Room6/Entry") as Node2D).global_position
	await wait_physics_seconds(Level.AMBIENT_FADE + 0.5)
	assert_almost_eq(level.key_light.energy, RUINS_NIGHT.key_energy, 0.01, "écran 6 : le clair de lune")
	var grade: ShaderMaterial = level.screen_grade.material as ShaderMaterial
	assert_almost_eq(float(grade.get_shader_parameter(&"vignette")), RUINS_NIGHT.vignette, 0.01, "bords assombris")
	player.global_position = (level.get_node("Room4/Spawn") as Node2D).global_position
	await wait_physics_seconds(Level.AMBIENT_FADE + 0.5)
	assert_almost_eq(level.key_light.energy, 0.0, 0.01, "de retour à l'écran 4 : plus de lune")


func test_lamp_halo_goes_out_with_the_lamp() -> void:
	var lamp := LightSource.new()
	add_node(lamp)
	var glow: Node2D = lamp.get_node(^"Glow")
	assert_true(glow.visible, "halo allumé")
	lamp.shatter()
	assert_false(glow.visible, "lampe brisée : plus de halo")


func test_characters_are_shaded_and_dressed() -> void:
	for script: GDScript in [load("res://scripts/player/visual/elias_visual.gd"), load("res://scripts/companion/companion_visual.gd"),
			load("res://scripts/enemies/sentinel_visual.gd")]:
		var visual: Node2D = script.new()
		add_node(visual)
		var cloth: int = 0
		var shaded: int = 0
		var outlines: int = 0
		for node in visual.find_children("*", "Polygon2D", true, false):
			var p: Polygon2D = node as Polygon2D
			if p.texture != null:
				cloth += 1
			if p.vertex_colors.size() == p.polygon.size():
				shaded += 1
		outlines = visual.find_children("*", "Line2D", true, false).size()
		assert_true(cloth >= 9, "%s : vêtements en tissu (%d pièces)" % [script.resource_path.get_file(), cloth])
		assert_true(shaded >= 12, "%s : pièces en volume (%d)" % [script.resource_path.get_file(), shaded])
		assert_true(outlines >= 10, "%s : contours (%d)" % [script.resource_path.get_file(), outlines])


## Retour de jeu : « la lumière est toujours dans le dos du personnage ». Le
## côté clair des pièces suit maintenant la lampe la plus proche.
func test_character_shading_follows_the_lamp() -> void:
	var lamp := LightSource.new()
	lamp.position = Vector2(200, -60)
	lamp.radius = 400.0
	add_node(lamp)
	var visual: EliasVisual = EliasVisual.new()
	add_node(visual)
	visual.set_facing(1)  # la lampe est devant lui
	assert_true(visual.front_lit, "face à la lampe : éclairé de face")
	visual.set_facing(-1)
	assert_false(visual.front_lit, "dos à la lampe : éclairé de dos")
	lamp.shatter()
	visual.set_facing(1)
	assert_false(visual.front_lit, "lampe brisée, pas de lune : le dessin d'origine")


## Retour de jeu : le Traqueur « dessin de maternelle », redessiné. Ses
## animations calculées ne doivent jamais produire une forme impossible à
## remplir (Godot le signale par une erreur).
func test_tracker_drawing_survives_every_animation() -> void:
	var tracker := TrackerVisual.new()
	add_node(tracker)
	for animation: StringName in [&"idle", &"run", &"roar"]:
		tracker.play(animation)
		for facing: int in [1, -1]:
			tracker.set_facing(facing)
			await wait_frames(45)
	assert_eq(engine_errors().size(), 0, "aucune forme dégénérée")
