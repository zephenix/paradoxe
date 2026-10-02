class_name GhostRun
extends Resource
## Un passage enregistré en mode chrono (J9, PLAN §5.8) : la trace d'Élias, prise
## à intervalles réguliers (20 fois par seconde), et son temps total. Le meilleur
## est sauvegardé (user://ghost_best.res) et rejoué par un fantôme (GhostRunner).
##
## Analogie Excel : un tableau dont chaque ligne est un instant (une « photo »
## d'Élias) et dont les colonnes sont la position, le sens du regard, et
## l'animation en cours. Les colonnes sont des tableaux « compacts »
## (PackedVector2Array…) : un passage de 5 minutes fait 6 000 lignes, et le
## fichier reste petit.

## Temps du passage (secondes de jeu), de l'écran 2 à la fin.
@export var time: float = 0.0
## Photos par seconde.
@export var sample_rate: float = 20.0
## Les colonnes : une valeur par photo.
@export var positions: PackedVector2Array = PackedVector2Array()
@export var facings: PackedByteArray = PackedByteArray()  # 1 : vers la droite, 0 : vers la gauche
@export var anim_ids: PackedInt32Array = PackedInt32Array()  # numéro dans anim_names
@export var anim_times: PackedFloat32Array = PackedFloat32Array()  # instant dans l'animation
@export var anim_speeds: PackedFloat32Array = PackedFloat32Array()
## Noms des animations rencontrées (chaque nom n'est écrit qu'une fois).
@export var anim_names: PackedStringArray = PackedStringArray()


## Ajoute une photo : position, sens du regard, pose (EliasVisual.capture_pose()).
func add_sample(position: Vector2, facing: int, pose: Dictionary) -> void:
	positions.append(position)
	facings.append(1 if facing >= 0 else 0)
	var anim: String = String(pose.get("anim", &"idle"))
	var id: int = anim_names.find(anim)
	if id < 0:
		anim_names.append(anim)
		id = anim_names.size() - 1
	anim_ids.append(id)
	anim_times.append(float(pose.get("time", 0.0)))
	anim_speeds.append(float(pose.get("speed", 1.0)))


func sample_count() -> int:
	return positions.size()


## Numéro de la photo prise juste avant l'instant « t » (secondes).
func index_at(t: float) -> int:
	return clampi(floori(t * sample_rate), 0, maxi(sample_count() - 1, 0))


## Position à l'instant « t », entre deux photos (interpolation linéaire, comme
## une règle de trois entre deux lignes du tableau).
func position_at(t: float) -> Vector2:
	if sample_count() == 0:
		return Vector2.ZERO
	var i: int = index_at(t)
	if i >= sample_count() - 1:
		return positions[sample_count() - 1]
	var k: float = clampf(t * sample_rate - i, 0.0, 1.0)
	var a: Vector2 = positions[i]
	var b: Vector2 = positions[i + 1]
	# Un saut de plus de 200 px entre deux photos (réapparition, rembobinage) :
	# on ne glisse pas d'un point à l'autre, on y est d'un coup.
	return a if a.distance_to(b) > 200.0 else a.lerp(b, k)


func facing_at(t: float) -> int:
	return 1 if sample_count() == 0 or facings[index_at(t)] == 1 else -1


## Pose à l'instant « t » (pour EliasVisual.restore_pose).
func pose_at(t: float) -> Dictionary:
	if sample_count() == 0:
		return {}
	var i: int = index_at(t)
	return {"anim": StringName(anim_names[anim_ids[i]]), "time": anim_times[i], "speed": anim_speeds[i]}


## Sauvegarde le passage. Renvoie vrai si tout s'est bien passé.
func save_to(path: String) -> bool:
	return ResourceSaver.save(self, path) == OK


## Charge un passage ; null s'il n'y en a pas (ou si le fichier est abîmé).
static func load_from(path: String) -> GhostRun:
	if not ResourceLoader.exists(path):
		return null
	var run: GhostRun = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as GhostRun
	if run == null or run.sample_count() == 0 or run.facings.size() != run.sample_count() \
			or run.anim_ids.size() != run.sample_count() or run.time <= 0.0:
		return null
	for id: int in run.anim_ids:
		if id < 0 or id >= run.anim_names.size():
			return null
	return run
