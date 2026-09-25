extends TestCase
## Vérifie les réglages du projet dont dépendent l'export et l'audio Web.


func test_renderer_is_compatibility() -> void:
	# Seul moteur de rendu disponible sur le Web.
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility")


func test_web_audio_uses_stream_playback() -> void:
	# 0 = Stream (tous les effets de bus) ; 1 = Sample (pas d'effets). Voir PLAN §6.10.
	assert_eq(ProjectSettings.get_setting("audio/general/default_playback_type.web"), 0)


func test_base_resolution() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")


func test_version_is_semantic() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	var regex := RegEx.create_from_string("^\\d+\\.\\d+\\.\\d+([-+].+)?$")
	assert_not_null(regex.search(version), "version « %s » au format X.Y.Z" % version)


func test_main_scene_exists() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(main_scene), main_scene)


func test_autoloads_are_present_in_order() -> void:
	var expected: Array[String] = ["Events", "Settings", "GameState", "AudioManager", "RewindManager", "SceneTransition"]
	var children: Array[Node] = tree.root.get_children()
	for i in expected.size():
		assert_eq(children[i].name, expected[i], "autoload n°%d" % i)
