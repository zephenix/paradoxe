extends IntroShot
## Plan 5 — plan moyen, de profil : Élias traverse un couloir éclairé par
## intermittence. Il marche sur place au centre de l'image ; c'est le décor qui
## défile (comme un travelling latéral). Ses pas déclenchent le bruit de métal.

const FLOOR_Y: float = 560.0
const CEILING_Y: float = 170.0
const SPEED: float = 170.0   # vitesse de défilement du décor (pixels/s)
const NEON_GAP: float = 330.0

var elias: EliasVisual


func _ready() -> void:
	super._ready()
	elias = EliasVisual.new()
	elias.name = "Elias"
	elias.position = Vector2(560.0, FLOOR_Y)
	elias.scale = Vector2(1.8, 1.8)
	add_child(elias)
	elias.set_facing(1)
	elias.anim_event.connect(_on_anim_event)
	visibility_changed.connect(func() -> void:
		if visible:
			elias.play(&"walk"))


## Un pas d'Élias (évènement de son animation) : bruit de pas sur le métal.
func _on_anim_event(event_name: StringName) -> void:
	if visible and event_name == &"footstep":
		AudioManager.play_sfx(&"foley_step_metal", null, null, -3.0)


## Un néon est-il allumé ? Chacun clignote à sa façon (formule fixe, pas de hasard).
func _neon_on(index: int) -> bool:
	var t: float = time * (2.0 + (index % 3)) + index * 1.7
	return sin(t) + sin(t * 2.3) > -0.9 or index % 4 == 1


func _draw() -> void:
	fill(Color("0b0f15"))
	var scroll: float = time * SPEED
	# Mur du fond : panneaux qui défilent lentement (loin : parallaxe 0,6).
	var far: float = fposmod(scroll * 0.6, 160.0)
	for i in 10:
		var x: float = i * 160.0 - far
		var panel := Rect2(x + 4.0, CEILING_Y + 30.0, 152.0, FLOOR_Y - CEILING_Y - 30.0)
		tex_poly([panel.position, Vector2(panel.end.x, panel.position.y), panel.end, Vector2(panel.position.x, panel.end.y)], Color("232c38"), METAL)
		draw_line(Vector2(x + 20.0, 330.0), Vector2(x + 140.0, 330.0), Color("1d2530"), 2.0)
	# Plafond, sol (caillebotis).
	draw_rect(Rect2(0, CEILING_Y - 60.0, W, 60.0), Color("07090d"))
	draw_rect(Rect2(0, FLOOR_Y, W, 90.0), Color("161b22"))
	var grate: float = fposmod(scroll, 24.0)
	for i in 56:
		draw_line(Vector2(i * 24.0 - grate, FLOOR_Y + 4.0), Vector2(i * 24.0 - grate - 8.0, FLOOR_Y + 60.0), Color("0e1217"), 2.0)
	# Néons : un tube au plafond et un cône de lumière dessous, quand il est allumé.
	var first: int = int(floor(scroll / NEON_GAP))
	for k in range(-1, 6):
		var index: int = first + k
		var x: float = index * NEON_GAP - scroll + 200.0
		var on: bool = _neon_on(index)
		draw_rect(Rect2(x - 60.0, CEILING_Y - 8.0, 120.0, 8.0), Color("e9fff7") if on else Color("2a3138"))
		if on:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 60, CEILING_Y), Vector2(x + 60, CEILING_Y),
					Vector2(x + 200, FLOOR_Y), Vector2(x - 200, FLOOR_Y)]), Color(0.85, 1.0, 0.95, 0.07))
	# Piliers au premier plan : ils passent vite (parallaxe 1,6), très sombres.
	var near: float = fposmod(scroll * 1.6, 700.0)
	for i in 3:
		var x: float = i * 700.0 - near
		draw_rect(Rect2(x, 0.0, 70.0, H), Color("040507"))
