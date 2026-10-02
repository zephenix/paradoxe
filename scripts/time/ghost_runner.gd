class_name GhostRunner
extends Node2D
## Le fantôme du mode chrono (J9, PLAN §5.8) : une silhouette translucide
## d'Élias qui rejoue le meilleur passage (GhostRun), en même temps que le
## joueur. Il ne touche à rien : pas de corps physique, pas de son, invisible pour
## les ennemis. Il disparaît à la fin de son passage.
##
## Le TimeTrial lui donne l'instant à montrer (seek). Il se place entre deux
## photos (GhostRun.position_at) et reprend la pose de la photo la plus proche :
## entre deux photos, l'animation continue d'elle-même.

var run: GhostRun
var visual: EliasVisual
var _last_index: int = -1


func _init(ghost_run: GhostRun = null, color: Color = Color(0.55, 1.0, 0.9, 0.4)) -> void:
	run = ghost_run
	modulate = color
	z_index = -1  # derrière Élias


func _ready() -> void:
	visual = EliasVisual.new()
	visual.name = "Visual"
	add_child(visual)
	if run:
		seek(0.0)


## Montre le fantôme tel qu'il était à l'instant « t » (secondes de course).
func seek(t: float) -> void:
	if run == null or run.sample_count() == 0:
		visible = false
		return
	visible = t <= run.time
	if not visible:
		return
	global_position = run.position_at(t)
	var index: int = run.index_at(t)
	if index != _last_index and visual:
		_last_index = index
		visual.set_facing(run.facing_at(t))
		visual.restore_pose(run.pose_at(t))
