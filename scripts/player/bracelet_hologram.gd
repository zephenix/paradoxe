class_name BraceletHologram
extends CanvasLayer
## L'hologramme du bracelet d'Élias (J9, PLAN §5.10). Pas d'interface
## permanente : tout passe par ce petit écran de lumière qui s'élève au-dessus de
## son poignet gauche.
##
## Quatre lignes :
##   - énergie : une barre par unité (rouge orangé quand il en reste peu) ;
##   - poches : l'arme (si Élias l'a), les objets, et les pierres portées ;
##   - rembobinages restants (ou « infini ») ; absent en mode classique ;
##   - objectif de la salle : une flèche vers la cible et une phrase courte
##     (Room.objective et Room.objective_target).
##
## Deux façons de l'afficher :
##   - open() : touche « Bracelet », tout l'hologramme pendant show_time secondes
##     (un second appui le referme) ;
##   - flash(ligne) : une seule ligne, brièvement, quand elle change (pierre
##     ramassée ou lancée, énergie dépensée…).
## Le jeu continue pendant ce temps, comme pour un vrai geste.
##
## Pourquoi un CanvasLayer ? La salle peut être plongée dans la pénombre (teinte
## du CanvasModulate du niveau) : un hologramme est une lumière, il ne doit pas
## s'assombrir. Le calque « suit la caméra » (follow_viewport_enabled) : on y place
## les dessins en coordonnées du monde, comme s'ils étaient dans la salle.
## Créé par le Player (comme l'indicateur d'ordre) ; réglages :
## resources/player/bracelet.tres.

## Les lignes possibles, de haut en bas.
const ROWS: Array[StringName] = [&"energy", &"pockets", &"rewinds", &"objective"]
## Couleurs de l'hologramme (le vert d'eau du bracelet).
const GLOW: Color = Color("7dffd8")
const LOW: Color = Color("ff8a5c")
const DIM: Color = Color(0.49, 1.0, 0.85, 0.22)
## Taille d'une ligne et largeur minimale (pixels).
const ROW_HEIGHT: float = 18.0
const MIN_WIDTH: float = 132.0
const PADDING: float = 7.0
const FONT_SIZE: int = 12

var config: BraceletConfig = preload("res://resources/player/bracelet.tres")

## Vrai si tout l'hologramme est ouvert (touche « Bracelet »), jusqu'à ce qu'il
## commence à s'effacer.
var is_open: bool = false
## Ligne affichée brièvement (&"" : aucune).
var brief_row: StringName = &""

var _player: Player
var _panel: Node2D
var _timer: float = 0.0
## Vrai si le contenu affiché est l'hologramme complet (il le reste pendant son fondu).
var _full: bool = false
var _unfold: float = 0.0
var _time: float = 0.0


func _init(owner_player: Player = null) -> void:
	_player = owner_player


func _ready() -> void:
	layer = 6  # au-dessus du jeu, du grain (3) et des textes des salles (4, 5)
	follow_viewport_enabled = true
	_panel = Node2D.new()
	_panel.name = "Panel"
	_panel.draw.connect(_draw_panel)
	add_child(_panel)
	_panel.visible = false


# --------------------------------------------------------------------------
# Commandes
# --------------------------------------------------------------------------

## Touche « Bracelet » : ouvre tout l'hologramme, ou le referme s'il l'était.
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if not is_open:
		AudioManager.play_sfx(&"bracelet_open", _wrist(), _player)
	is_open = true
	_full = true
	brief_row = &""
	_timer = config.show_time + config.fade_time
	_show()


func close() -> void:
	if not is_open:
		return
	is_open = false
	AudioManager.play_sfx(&"bracelet_close", _wrist(), _player)
	_timer = minf(_timer, config.fade_time)  # fondu de sortie


## Affiche une ligne quelques instants (sans toucher à l'hologramme complet
## s'il est déjà ouvert : la ligne y est déjà, à jour).
func flash(row: StringName) -> void:
	if is_open:
		return
	_full = false
	brief_row = row
	_timer = config.brief_time + config.fade_time
	_show()


## Fait disparaître l'hologramme tout de suite, sans son (mort, réapparition).
func hide_now() -> void:
	is_open = false
	_full = false
	brief_row = &""
	_timer = 0.0
	_unfold = 0.0
	if _panel:
		_panel.visible = false


## Vrai si quelque chose est affiché (même en train de s'effacer).
func is_showing() -> bool:
	return _timer > 0.0


## Les lignes affichées en ce moment, de haut en bas.
func visible_rows() -> Array[StringName]:
	var rows: Array[StringName] = []
	if not is_showing():
		return rows
	if not _full:
		if brief_row != &"":
			rows.append(brief_row)
		return rows
	for row: StringName in ROWS:
		if row == &"rewinds" and not RewindManager.is_available():
			continue  # mode classique : pas de rembobinage
		if row == &"objective" and objective_text() == "":
			continue
		rows.append(row)
	return rows


func _show() -> void:
	if _panel and not _panel.visible:
		_unfold = 0.0
		_panel.visible = true


# --------------------------------------------------------------------------
# Ce qu'il montre
# --------------------------------------------------------------------------

## Phrase de l'objectif de la salle où se trouve Élias ("" : aucune).
func objective_text() -> String:
	var room: Room = _room()
	return room.objective if room else ""


## Direction (unitaire, dans le monde) de la cible de l'objectif depuis Élias ;
## Vector2.ZERO s'il n'y en a pas ou si Élias y est déjà.
func objective_direction() -> Vector2:
	var room: Room = _room()
	if room == null or _player == null:
		return Vector2.ZERO
	var point: Vector2 = room.objective_point()
	if point == Vector2.INF:
		return Vector2.ZERO
	var offset: Vector2 = point - _player.global_position
	if offset.length() < config.objective_near:
		return Vector2.ZERO
	return offset.normalized()


func _room() -> Room:
	if _player == null or not _player.is_inside_tree():
		return null
	return Room.find_at(_player, _player.global_position)


## Où est le bracelet, dans le monde (le poignet gauche d'Élias).
func _wrist() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	return _player.visual.bracelet_position()


# --------------------------------------------------------------------------
# Affichage
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_showing():
		return
	_time += delta
	_timer -= delta
	_unfold = minf(_unfold + delta / maxf(config.unfold_time, 0.01), 1.0)
	if _timer <= 0.0:
		hide_now()
		return
	if is_open and _timer <= config.fade_time:
		is_open = false  # le temps d'affichage est écoulé : il s'efface
	# Au-dessus d'Élias, en coordonnées du monde ; taille constante à l'écran,
	# même quand la caméra recule (zoom < 1).
	_panel.position = _player.global_position + Vector2(0.0, -config.height) if _player else Vector2.ZERO
	var camera: Camera2D = _panel.get_viewport().get_camera_2d()
	_panel.scale = Vector2.ONE / camera.zoom if camera else Vector2.ONE
	_panel.modulate.a = clampf(_timer / config.fade_time, 0.0, 1.0) * (0.92 + 0.08 * sin(_time * 23.0))
	_panel.queue_redraw()


func _draw_panel() -> void:
	var rows: Array[StringName] = visible_rows()
	if rows.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var width: float = MIN_WIDTH
	if rows.has(&"objective"):
		width = maxf(width, font.get_string_size(objective_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 34.0 + PADDING * 2.0)
	var height: float = rows.size() * ROW_HEIGHT + PADDING * 2.0
	# Il se déplie de bas en haut (depuis le poignet).
	var unfold: float = ease(_unfold, 0.4)
	var top: float = -height * unfold
	var rect := Rect2(-width * 0.5, top, width, height * unfold)
	# Le faisceau : du poignet jusqu'au bas de l'hologramme.
	var wrist: Vector2 = (_wrist() - _panel.position) / _panel.scale
	_panel.draw_colored_polygon(PackedVector2Array([wrist + Vector2(-2.0, 0.0), wrist + Vector2(2.0, 0.0),
			Vector2(width * 0.3, 0.0), Vector2(-width * 0.3, 0.0)]), Color(GLOW, 0.08))
	_panel.draw_line(wrist, Vector2(0.0, 0.0), Color(GLOW, 0.25), 1.0)
	# Le cadre : un fond sombre et translucide, des lignes de balayage, un liseré.
	_panel.draw_rect(rect, Color(0.02, 0.12, 0.11, 0.55))
	var y: float = rect.position.y + 1.0
	while y < rect.end.y:
		_panel.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(GLOW, 0.05), 1.0)
		y += 3.0
	_panel.draw_rect(rect, Color(GLOW, 0.55), false, 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		_panel.draw_circle(corner, 1.5, GLOW)
	if unfold < 0.95:
		return  # le contenu n'apparaît qu'une fois déplié
	for i in rows.size():
		var row_y: float = top + PADDING + i * ROW_HEIGHT + ROW_HEIGHT * 0.5
		var left: float = -width * 0.5 + PADDING
		match rows[i]:
			&"energy":
				_draw_energy(left, row_y, width - PADDING * 2.0)
			&"pockets":
				_draw_pockets(left, row_y)
			&"rewinds":
				_draw_rewinds(left, row_y)
			&"objective":
				_draw_objective(left, row_y, font)


## L'énergie : un éclair, puis une barre par unité (la dernière à moitié pleine…).
func _draw_energy(left: float, y: float, room_width: float) -> void:
	_draw_bolt(Vector2(left + 5.0, y))
	if _player == null:
		return
	var value: float = _player.energy.value
	var capacity: float = _player.energy.config.capacity
	var bars: int = ceili(capacity)
	var start: float = left + 16.0
	var step: float = minf(9.0, (room_width - 16.0) / maxf(bars, 1))
	var color: Color = LOW if value < 2.0 else GLOW
	for i in bars:
		var bar := Rect2(start + i * step, y - 5.0, step - 2.0, 10.0)
		_panel.draw_rect(bar, DIM)
		var fill: float = clampf(value - i, 0.0, 1.0)
		if fill > 0.0:
			_panel.draw_rect(Rect2(bar.position.x, bar.end.y - bar.size.y * fill, bar.size.x, bar.size.y * fill), color)


## Les poches : l'arme, les autres objets, puis les pierres (pleines = portées).
func _draw_pockets(left: float, y: float) -> void:
	var x: float = left
	if GameState.has_item(&"pistol"):
		_draw_pistol(Vector2(x, y))
		x += 26.0
	for item: StringName in GameState.inventory:
		if item == &"pistol":
			continue
		_panel.draw_rect(Rect2(x, y - 5.0, 10.0, 10.0), GLOW, false, 1.5)
		x += 16.0
	if _player == null:
		return
	x += 4.0
	for i in _player.throw_config.max_stones:
		var at := Vector2(x + 6.0 + i * 15.0, y)
		var stone := PackedVector2Array([at + Vector2(-6, 2), at + Vector2(-3, -5), at + Vector2(4, -4), at + Vector2(6, 2), at + Vector2(1, 5)])
		if i < _player.stones:
			_panel.draw_colored_polygon(stone, GLOW)
		else:
			stone.append(stone[0])
			_panel.draw_polyline(stone, DIM, 1.5)


## Les rembobinages : une flèche qui tourne à rebours, puis un point par
## utilisation restante (ou le signe « infini »).
func _draw_rewinds(left: float, y: float) -> void:
	var c := Vector2(left + 6.0, y)
	_panel.draw_arc(c, 5.5, -PI * 0.2, PI * 1.5, 14, GLOW, 1.5)
	_panel.draw_colored_polygon(PackedVector2Array([c + Vector2(0.5, -9.0), c + Vector2(0.5, -2.5), c + Vector2(-4.0, -5.5)]), GLOW)
	var x: float = left + 20.0
	if Settings.infinite_rewinds:
		var points := PackedVector2Array()
		for k in 25:
			var a: float = k / 24.0 * TAU
			points.append(Vector2(x + 9.0, y) + Vector2(cos(a) * 8.0, sin(2.0 * a) * 3.5))
		_panel.draw_polyline(points, GLOW, 1.5)
		return
	var total: int = RewindManager.config.uses_per_checkpoint
	for i in total:
		var at := Vector2(x + 4.0 + i * 11.0, y)
		if i < GameState.rewinds_left:
			_panel.draw_circle(at, 3.5, GLOW)
		else:
			_panel.draw_arc(at, 3.5, 0.0, TAU, 10, DIM, 1.0)


## L'objectif : une flèche vers la cible (un cercle si on y est), et la phrase.
func _draw_objective(left: float, y: float, font: Font) -> void:
	var c := Vector2(left + 7.0, y)
	var direction: Vector2 = objective_direction()
	if direction == Vector2.ZERO:
		_panel.draw_arc(c, 5.0, 0.0, TAU, 14, GLOW, 1.5)
		_panel.draw_circle(c, 1.8, GLOW)
	else:
		var tip: Vector2 = c + direction * 7.0
		var side: Vector2 = direction.orthogonal() * 4.0
		_panel.draw_line(c - direction * 6.0, tip, GLOW, 2.0)
		_panel.draw_colored_polygon(PackedVector2Array([tip + direction * 2.0, tip - direction * 4.0 + side,
				tip - direction * 4.0 - side]), GLOW)
	var text_at := Vector2(left + 20.0, y + FONT_SIZE * 0.35)
	_panel.draw_string_outline(font, text_at, objective_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, Color(0.0, 0.08, 0.07, 0.8))
	_panel.draw_string(font, text_at, objective_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GLOW)


func _draw_bolt(at: Vector2) -> void:
	_panel.draw_colored_polygon(PackedVector2Array([at + Vector2(1, -7), at + Vector2(-4, 1), at + Vector2(0, 1),
			at + Vector2(-1, 7), at + Vector2(4, -1), at + Vector2(0, -1)]), GLOW)


## Le pistolet, de profil (canon vers la droite).
func _draw_pistol(at: Vector2) -> void:
	_panel.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -4), at + Vector2(20, -4), at + Vector2(20, 0),
			at + Vector2(8, 0), at + Vector2(6, 6), at + Vector2(1, 6), at + Vector2(2, 0), at + Vector2(0, 0)]), GLOW)
	_panel.draw_rect(Rect2(at + Vector2(10, -3), Vector2(5, 2)), Color(0.02, 0.12, 0.11))  # la cellule d'énergie
