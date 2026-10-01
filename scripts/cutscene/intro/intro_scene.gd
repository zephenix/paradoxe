class_name IntroScene
extends Node2D
## La scène de la cinématique d'ouverture (J8) : les 11 plans (nœud « Shots »), la
## table de montage (« Montage », un AnimationPlayer) et le scénario (« Intro »,
## une IntroCutscene). Un lecteur de cinématiques ajoute les bandes noires et
## permet de passer (maintenir Échap ou Espace).
##
## À la fin (ou si on passe), on enchaîne sur le jeu (écran 2, l'arrivée), ou on
## revient à l'écran titre si l'intro a été lancée depuis le menu (« Revoir l'intro »).

signal finished

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
## Bandes noires plus larges que dans le jeu : format cinéma.
const BAR_HEIGHT: float = 80.0

## Vrai : « Revoir l'intro » depuis le menu ; on y retourne à la fin.
## (Variable « statique » : partagée, elle survit au changement de scène.)
static var return_to_title: bool = false

## Scène lancée à la fin de l'intro.
@export_file("*.tscn") var next_scene: String = "res://scenes/levels/prototype.tscn"
## Faux dans les tests : on ne change pas de scène à la fin.
var auto_leave: bool = true
## Faux dans les tests : « Passer » se commande par cutscenes.skip_held.
var input_from_devices: bool = true

var cutscenes: CutscenePlayer

@onready var intro: IntroCutscene = $Intro


func _ready() -> void:
	if return_to_title:
		next_scene = TITLE_SCENE
		return_to_title = false
	cutscenes = CutscenePlayer.new()
	cutscenes.name = "CutscenePlayer"
	cutscenes.bar_height = BAR_HEIGHT
	cutscenes.input_from_devices = input_from_devices
	add_child(cutscenes)
	_add_film_grade()
	_play.call_deferred()


## Finition « pellicule » (comme en jeu) : bords de l'image assombris, léger grain.
func _add_film_grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FilmGrade"
	layer.layer = 2
	add_child(layer)
	var grade := ColorRect.new()
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/screen_grade.gdshader")
	material.set_shader_parameter(&"vignette", 0.5)
	material.set_shader_parameter(&"grain", 0.05)
	grade.material = material
	layer.add_child(grade)


func _play() -> void:
	await cutscenes.play(intro)
	finished.emit()
	if auto_leave and is_inside_tree():
		SceneTransition.change_scene(next_scene, 1.0)
