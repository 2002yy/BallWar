extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

class DummyOwner extends RefCounted:
	var SAVE_SLOT_COUNT: int = 5
	var selected_grid_size: int = 40
	var selected_palette_name: String = ""
	var selected_quality_name: String = ""
	var selected_game_mode_name: String = ""
	var selected_time_limit_minutes: int = 5
	var selected_save_slot: int = 1

	func _has_save_file(_slot_index: int = -1) -> bool:
		return false

	func _start_game(_grid_size: int) -> void:
		pass

	func _continue_saved_game() -> void:
		pass

	func _select_save_slot(_slot_index: int) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[StartMenuSceneTest] v2.0.7 - scene load verification")

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

	var slot_buttons: Dictionary = parts["menu_save_slot_buttons"]
	t.that(slot_buttons is Dictionary, "save_slot_buttons is Dictionary")

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
	t.that(instance.has_node("RootPanel/ConfigPanel/ConfigBg"), "ConfigBg node exists")

	var preview_scene = load("res://scenes/ui/PreviewScene.tscn")
	var preview_instance = null
	t.that(preview_scene != null, "PreviewScene.tscn loadable")
	if preview_scene != null:
		preview_instance = preview_scene.instantiate()
		t.that(preview_instance.has_node("Board"), "PreviewScene has Board")
		t.that(preview_instance.has_node("ChamberBottomLeft"), "PreviewScene has ChamberBottomLeft")
		t.that(preview_instance.has_node("ChamberBottomRight"), "PreviewScene has ChamberBottomRight")
		t.that(preview_instance.has_node("TurretTopLeft"), "PreviewScene has TurretTopLeft")

	var config_panel: Control = instance.get_node("RootPanel/ConfigPanel")
	var config_bg: ColorRect = instance.get_node("RootPanel/ConfigPanel/ConfigBg")
	var preview_node: Node2D = instance.get_node("RootPanel/ChamberPreview")
	var start_button: Button = instance.get_node("RootPanel/ConfigPanel/StartButton")

	var config_pos_before: Vector2 = config_panel.position
	var config_size_before: Vector2 = config_panel.size
	var config_bg_pos_before: Vector2 = config_bg.position
	var config_bg_size_before: Vector2 = config_bg.size
	var preview_pos_before: Vector2 = preview_node.position
	var preview_scale_before: Vector2 = preview_node.scale
	var start_button_pos_before: Vector2 = start_button.position
	var start_button_size_before: Vector2 = start_button.size

	var owner := DummyOwner.new()
	instance.setup(owner, Vector2(1120, 720), [])

	t.eq(config_panel.position, config_pos_before, "setup should not override ConfigPanel position")
	t.eq(config_panel.size, config_size_before, "setup should not override ConfigPanel size")
	t.eq(config_bg.position, config_bg_pos_before, "setup should not override ConfigBg position")
	t.eq(config_bg.size, config_bg_size_before, "setup should not override ConfigBg size")
	t.eq(preview_node.position, preview_pos_before, "setup should not override ChamberPreview position")
	t.eq(preview_node.scale, preview_scale_before, "setup should not override ChamberPreview scale")
	t.eq(start_button.position, start_button_pos_before, "setup should not override StartButton position")
	t.eq(start_button.size, start_button_size_before, "setup should not override StartButton size")

	if preview_instance != null and is_instance_valid(preview_instance):
		preview_instance.queue_free()
	instance.queue_free()
	await process_frame
	await process_frame

	t.report("[StartMenuSceneTest]")

	if t.failures.is_empty():
		quit(0)
	else:
		quit(1)
