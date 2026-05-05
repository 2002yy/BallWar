extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[GameHUDSceneTest] v2.0.8 — scene load verification")

	var scene_path: String = "res://scenes/ui/GameHUD.tscn"
	var resource = load(scene_path)
	t.that(resource != null, "scene loadable")
	if resource == null:
		quit(1)
		return

	var instance = resource.instantiate()
	t.that(instance != null, "instantiable")
	t.that(instance is CanvasLayer, "root is CanvasLayer")
	if instance == null:
		quit(1)
		return

	get_root().add_child(instance)
	await process_frame

	t.that(instance.has_method("get_static_parts"), "has get_static_parts")
	var parts: Dictionary = instance.get_static_parts()
	t.that(parts.has("fps_label"), "part: fps_label")
	t.that(parts.has("event_label"), "part: event_label")
	t.that(parts.has("settings_button"), "part: settings_button")
	t.that(parts.has("pause_button"), "part: pause_button")
	t.that(parts.has("exit_button"), "part: exit_button")
	t.that(parts.has("settings_panel"), "part: settings_panel")
	t.that(parts["settings_panel"] != null, "settings_panel not null")
	t.that(parts["settings_panel"] is Panel, "settings_panel is Panel")
	t.that(parts.has("pause_overlay"), "part: pause_overlay")
	t.that(parts.has("winner_label"), "part: winner_label")

	t.that(parts["fps_label"] is Label, "fps_label is Label")
	t.that(parts["event_label"] is Label, "event_label is Label")
	t.that(parts["settings_button"] is Button, "settings_button is Button")
	t.that(parts["pause_button"] is Button, "pause_button is Button")
	t.that(parts["exit_button"] is Button, "exit_button is Button")

	t.report("[GameHUDSceneTest]")

	if t.failures.is_empty():
		quit(0)
	else:
		quit(1)
