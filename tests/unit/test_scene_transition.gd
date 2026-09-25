extends TestCase
## Tests du rideau de transition (autoload SceneTransition).


func after_each() -> void:
	await SceneTransition.fade_in(0.0)


func test_fade_out_then_in() -> void:
	assert_false(SceneTransition.is_covering(), "rideau ouvert au départ")
	await SceneTransition.fade_out(0.05)
	assert_true(SceneTransition.is_covering(), "rideau fermé")
	await SceneTransition.fade_in(0.05)
	assert_false(SceneTransition.is_covering(), "rideau rouvert")


func test_cut_to_black_is_immediate() -> void:
	SceneTransition.cut_to_black()
	assert_true(SceneTransition.is_covering())


func test_curtain_is_drawn_above_everything() -> void:
	assert_true(SceneTransition.layer >= 100)


func test_interrupted_fade_releases_its_waiter() -> void:
	var done: Array[bool] = [false]
	var first_fade := func() -> void:
		await SceneTransition.fade_out(1.0)
		done[0] = true
	first_fade.call()
	await wait_frames(2)
	await SceneTransition.fade_in(0.05)  # interrompt le premier fondu
	await wait_frames(2)
	assert_true(done[0], "le premier fondu, interrompu, n'a pas laissé sa coroutine bloquée")


func test_fades_are_ignored_during_scene_change() -> void:
	SceneTransition.is_changing_scene = true
	await SceneTransition.fade_out(0.05)
	assert_false(SceneTransition.is_covering(), "un fondu demandé pendant un changement de scène est ignoré")
	SceneTransition.is_changing_scene = false


func test_second_scene_change_request_is_ignored() -> void:
	SceneTransition.is_changing_scene = true
	await SceneTransition.change_scene("res://scenes/ui/title_screen.tscn", 0.01)
	assert_true(SceneTransition.is_changing_scene, "demande ignorée : l'état n'a pas été modifié")
	assert_false(SceneTransition.is_covering(), "et le rideau n'a pas bougé")
	SceneTransition.is_changing_scene = false
