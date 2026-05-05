extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[StartMenuSceneTest] v2.0.7 — scene load verification")

	var scene_path: String = "res://scenes/ui/StartMenu.tscn"

	var scene_resource = load(scene_path)
	t.that(scene_resource != null, "scene resource loadable")
	if scene_resource == null:
		printerr("FATAL: cannot load %s" % scene_path)
		quit(1)
		return

	var instance = scene_resource.instantiate()
	t.that(instance != null, "scene instantiable")
	t.that(instance is CanvasLayer, "root is CanvasLayer")
	if instance == null:
		quit(1)
		return

	# Must add to tree for @onready vars to initialize
	get_root().add_child(instance)
	await process_frame

	t.that(instance.has_method("get_parts"), "has get_parts")

	var parts: Dictionary = instance.get_parts()
	t.that(parts.has("menu_layer"), "parts: menu_layer")
	t.that(parts.has("menu_title_label"), "parts: menu_title_label")
	t.that(parts.has("menu_start_button"), "parts: menu_start_button")
	t.that(parts.has("menu_continue_button"), "parts: menu_continue_button")
	t.that(parts.has("menu_save_slot_buttons"), "parts: menu_save_slot_buttons")
	t.that(parts.has("menu_status_label"), "parts: menu_status_label")

	var sb: Dictionary = parts["menu_save_slot_buttons"]
	t.that(sb is Dictionary, "save_slot_buttons is Dictionary")

	t.that(parts["menu_start_button"] is Button, "start_button is Button")
	t.that(parts["menu_continue_button"] is Button, "continue_button is Button")
	t.that(parts["menu_status_label"] is Label, "label is Label")
	t.that(instance.get("start_button") != null, "@onready start_button")
	t.that(instance.get("continue_button") != null, "@onready continue_button")
	t.that(instance.get("menu_status_label") != null, "@onready menu_status_label")
	t.that(instance.get("title_label") != null, "@onready title_label")

	t.that(instance.has_node("RootPanel/ChamberPreview"), "ChamberPreview node exists in .tscn")
	t.that(instance.has_node("RootPanel/SubtitleLabel"), "SubtitleLabel node exists")
	t.that(instance.has_node("RootPanel/MobileHint"), "MobileHint node exists")
	t.that(instance.has_node("RootPanel/ConfigPanel/ModeTip"), "ModeTip node exists")

	t.report("[StartMenuSceneTest]")

	if t.failures.is_empty():
		quit(0)
	else:
		quit(1)
