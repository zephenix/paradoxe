extends Node2D
## Planche de poses : chaque animation d'Élias figée à plusieurs instants,
## pour vérifier les animations d'un coup d'œil (et sans écran, via capture).
##   ./tools/screenshot.sh res://tools/godot/pose_sheet.tscn build/shots/poses.png 10

## Instants montrés pour chaque animation (fractions de sa durée).
## (Trois instants : toutes les animations tiennent sur un écran de 1280×720.)
const SAMPLES: Array[float] = [0.0, 0.5, 1.0]
const CELL := Vector2(71, 142)
const COLUMNS: int = 18
const FIGURE_SCALE: float = 1.25


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("3b4550")
	background.size = Vector2(1280, 720)
	add_child(background)
	var index: int = 0
	for anim_name: String in EliasPoses.ANIMATIONS:
		for fraction in SAMPLES:
			var cell := Vector2(index % COLUMNS, floori(float(index) / COLUMNS))
			var origin: Vector2 = cell * CELL + Vector2(CELL.x * 0.5, CELL.y - 22)
			var ground := ColorRect.new()
			ground.color = Color("1c2127")
			ground.position = origin + Vector2(-CELL.x * 0.5 + 2, 0)
			ground.size = Vector2(CELL.x - 4, 3)
			add_child(ground)
			var figure := EliasVisual.new()
			figure.position = origin
			figure.scale = Vector2.ONE * FIGURE_SCALE
			add_child(figure)
			figure.seek_fraction(StringName(anim_name), fraction)
			var label := Label.new()
			label.text = "%s %d%%" % [anim_name, roundi(fraction * 100)]
			label.add_theme_font_size_override("font_size", 10)
			label.position = origin + Vector2(-CELL.x * 0.5 + 3, 4)
			add_child(label)
			index += 1
