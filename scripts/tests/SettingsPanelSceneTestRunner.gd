extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[SettingsPanelSceneTest] v2.0.8 — scene load verification")

	var scene_path: String = "res://scenes/ui/SettingsPanel.tscn"
	var resource = load(scene_path)
	t.that(resource != null, "scene loadable")
	if resource == null:
		quit(1)
		return

	var instance = resource.instantiate()
	t.that(instance != null, "instantiable")
	t.that(instance is Panel, "root is Panel")
	if instance == null:
		quit(1)
		return

	get_root().add_child(instance)
	await process_frame

	t.that(instance.has_node("ContentLabel"), "has ContentLabel")
	t.that(instance.has_node("Bg"), "has Bg")
	t.that(instance.has_method("show_content"), "has show_content method")
	t.that(instance.has_method("hide_panel"), "has hide_panel method")

	instance.show_content("中", "电脑")
	t.that(instance.visible, "visible after show_content")
	instance.hide_panel()
	t.that(not instance.visible, "hidden after hide_panel")

	t.report("[SettingsPanelSceneTest]")

	if t.failures.is_empty():
		quit(0)
	else:
		quit(1)
