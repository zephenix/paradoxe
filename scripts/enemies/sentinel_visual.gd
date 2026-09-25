class_name SentinelVisual
extends EliasVisual
## Silhouette d'une Sentinelle : le même squelette et les mêmes animations
## qu'Élias (leurs gestes sont humains, et ce n'est pas un hasard : PLAN §4.3),
## mais une autre peau. Corps sombre, tête allongée sans cheveux, et des
## marques lumineuses en spirale du même vert que le portail de l'intro.

## Vert des marques lumineuses (le vert du portail et de la jungle).
const GLOW := Color("6dffb0")


func _init() -> void:
	# Assez clair pour se détacher des fonds de nuit, plus sombre qu'Élias.
	coat_color = Color("587276")
	coat_shade = Color("435a5e")
	trousers_color = Color("33454a")
	shoes_color = Color("1a2427")
	skin_color = Color("7e9e97")
	hair_color = Color("587276")
	gun_color = Color("3b2c27")
	gun_glow = Color("ff8a5c")


## Tête allongée vers l'arrière, crâne lisse, un œil lumineux.
func _build_head(head: Node2D) -> void:
	_poly(head, [Vector2(-3, 0), Vector2(3, 0), Vector2(3, -4)], skin_color)  # cou
	_poly(head, [Vector2(-8, -4), Vector2(5, -4), Vector2(8, -9), Vector2(7, -15), Vector2(0, -20),
			Vector2(-9, -19), Vector2(-12, -13)], skin_color)
	_poly(head, [Vector2(3, -12), Vector2(7, -12), Vector2(6, -10), Vector2(3, -10)], GLOW)  # œil


## Pas de bracelet : des marques en spirale sur le buste et le front.
func _decorate(_back_fore: Node2D, torso: Node2D, head: Node2D) -> void:
	torso.add_child(_spiral(Vector2(1, -18), 7.0, 2.2))
	head.add_child(_spiral(Vector2(-4, -13), 3.5, 1.6))


## Spirale d'Archimède (le rayon grandit régulièrement à chaque tour).
func _spiral(center: Vector2, radius: float, turns: float) -> Line2D:
	var line := Line2D.new()
	line.width = 1.5
	line.default_color = GLOW
	var steps: int = 28
	for i in steps + 1:
		var k: float = float(i) / steps
		var angle: float = k * turns * TAU
		line.add_point(center + Vector2(cos(angle), sin(angle)) * radius * k)
	return line
