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
