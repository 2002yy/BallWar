extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")


class DummyOwner extends RefCounted:
	var SAVE_SLOT_COUNT: int = 5
	var selected_grid_size: int = 40
	var selected_palette_name: String = "默认随机"
	var selected_quality_name: String = GameConfig.QUALITY_MEDIUM
	var selected_game_mode_name: String = GameConfig.GAME_MODE_BASIC
	var selected_time_limit_minutes: int = 5
	var selected_save_slot: int = 3

	func _has_save_file(slot_index: int = -1) -> bool:
		return slot_index in [2, 3, 5]

	func _start_game(_grid_size: int) -> void:
		pass

	func _continue_saved_game() -> void:
		pass

	func _select_save_slot(slot_index: int) -> void:
		selected_save_slot = slot_index

	func _save_menu_preferences() -> void:
		pass

	func reset_menu_preferences() -> void:
		pass


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[StartMenuSceneTest] v2.1.10 menu bounds + slot refresh consistency")

	_reset_and_assert_runtime_defaults(t, "before start menu scene test")

	var scene_resource = load("res://scenes/ui/StartMenu.tscn")
	t.that(scene_resource != null, "scene resource loadable")
	if scene_resource == null:
		t.report("[StartMenuSceneTest]")
		quit(1)
		return

	var instance = scene_resource.instantiate()
	t.that(instance is CanvasLayer, "root is CanvasLayer")
	if instance == null:
		t.report("[StartMenuSceneTest]")
		quit(1)
		return

	get_root().add_child(instance)
	await process_frame

	var owner := DummyOwner.new()
	var summaries: Array = [
		{"slot": 1, "state": "valid", "has_data": true, "is_playable": true, "title": "基础模式｜20×20｜中", "detail": "进度 00:35｜版本 2.1.6"},
		{"slot": 2, "state": "valid", "has_data": true, "is_playable": true, "title": "占领模式｜40×40｜高", "detail": "进度 04:10｜版本 2.1.6"},
		{"slot": 3, "state": "valid", "has_data": true, "is_playable": true, "title": "基础模式｜20×20｜中", "detail": "进度 01:45｜版本 2.1.6"},
		{"slot": 4, "state": "empty", "has_data": false, "is_playable": false, "title": "空存档", "detail": "点击选择此槽"},
		{"slot": 5, "state": "valid", "has_data": true, "is_playable": true, "title": "狂野模式｜10×10｜低", "detail": "进度 00:12｜版本 2.1.6"},
	]
	var layout: Dictionary = LayoutProfiles.get_profile(40).duplicate(true)
	layout.merge(LayoutCoordinator.calculate_layout(40, Vector2(1120, 720), false), true)

	instance.setup(owner, Vector2(1120, 720), summaries, layout)
	await process_frame

	t.that(instance.has_method("get_parts"), "has get_parts")
	t.that(instance.has_method("refresh_slots"), "has refresh_slots")
	t.that(instance.has_method("refresh_save_slots"), "keeps refresh_save_slots compatibility")
	var parts: Dictionary = instance.get_parts()
	t.eq(parts["menu_save_slot_buttons"].size(), 5, "slot buttons: 5 found")

	var root_panel: Panel = instance.get_node("RootPanel")
	var preview_container: Control = instance.get_node("RootPanel/MainVBox/PreviewContainer")
	var chamber_preview: Node2D = instance.get_node("RootPanel/MainVBox/PreviewContainer/ChamberPreview")
	var slot_grid: GridContainer = instance.get_node("RootPanel/MainVBox/SavePanel/SaveVBox/SlotGrid")
	var start_button: Button = instance.get_node("RootPanel/MainVBox/ConfigPanel/ConfigVBox/ConfigRow2/StartButton")
	var continue_button: Button = instance.get_node("RootPanel/MainVBox/ContinueButton")
	var status_label: Label = instance.get_node("RootPanel/MainVBox/MenuStatusLabel")

	var start_menu_layout: Dictionary = layout.get("start_menu_layout", {})
	t.eq(root_panel.position, start_menu_layout["root_panel_rect"].position, "root panel uses centered layout position")
	t.eq(root_panel.size, start_menu_layout["root_panel_rect"].size, "root panel uses updated layout size")
	t.that(root_panel.position.x >= 0.0, "root panel left edge visible")
	t.that(root_panel.position.y >= 0.0, "root panel top edge visible")
	t.that(root_panel.position.x + root_panel.size.x <= 1120.0, "root panel right edge visible")
	t.that(root_panel.position.y + root_panel.size.y <= 720.0, "root panel bottom edge visible")

	t.eq(preview_container.clip_contents, true, "preview container clips overflow")
	t.eq(chamber_preview.position, start_menu_layout["preview_center"], "preview uses layout center")
	t.eq(chamber_preview.scale, start_menu_layout["preview_scale"], "preview uses reduced scale")
	t.that(_rect_within_parent(preview_container.position, preview_container.size, root_panel.size), "preview container stays inside root panel")
	t.that(_rect_within_parent(preview_container.position + chamber_preview.position - Vector2.ONE, Vector2(2.0, 2.0), root_panel.size), "preview center stays inside root panel")
	t.that(chamber_preview.position.x >= 0.0 and chamber_preview.position.x <= preview_container.size.x, "preview center X inside preview container")
	t.that(chamber_preview.position.y >= 0.0 and chamber_preview.position.y <= preview_container.size.y, "preview center Y inside preview container")

	t.eq(slot_grid.columns, 3, "slot grid uses 3 columns")
	t.eq(slot_grid.get_child_count(), 5, "slot grid keeps 5 buttons")
	for slot in range(1, 6):
		var btn: Button = slot_grid.get_node_or_null("SlotButton_%d" % slot) as Button
		t.that(btn != null, "slot button %d exists" % slot)
		if btn != null:
			t.that(btn.visible, "slot button %d visible" % slot)
			t.that(_rect_within_parent(slot_grid.position + btn.position, btn.size, root_panel.size), "slot button %d stays inside root panel" % slot)

	var slot_button_2: Button = slot_grid.get_node("SlotButton_2")
	var slot_button_3: Button = slot_grid.get_node("SlotButton_3")
	var slot_button_4: Button = slot_grid.get_node("SlotButton_4")
	var initial_slot_2_base: String = _normalize_slot_label(slot_button_2.text)
	t.eq(slot_button_3.text, "● 槽3｜基础｜20×20｜中", "selected slot label compacted on first setup")
	t.eq(slot_button_4.text, "槽4｜空", "empty slot label compacted on first setup")
	t.eq(start_button.text, "新局覆盖槽3", "start button shows overwrite target")
	t.eq(continue_button.text, "读取槽3", "continue button shows selected slot")
	t.eq(status_label.text, "当前存档槽：3", "status label shows selected slot")
	t.that(_rect_within_parent(continue_button.position, continue_button.size, root_panel.size), "continue button stays inside root panel")
	t.that(_rect_within_parent(status_label.position, status_label.size, root_panel.size), "status label stays inside root panel")

	owner.selected_save_slot = 2
	instance.refresh_slots(summaries)
	await process_frame

	t.eq(_normalize_slot_label(slot_button_2.text), initial_slot_2_base, "slot label format stays consistent after refresh")
	t.eq(slot_button_2.text, "● 槽2｜占领｜40×40｜高", "selected slot text keeps compact format after refresh")
	t.eq(slot_button_3.text, "槽3｜基础｜20×20｜中", "previously selected slot loses marker but keeps format")
	t.eq(start_button.text, "新局覆盖槽2", "start button retargets selected slot after refresh")
	t.eq(continue_button.text, "读取槽2", "continue button retargets selected slot after refresh")

	instance.queue_free()
	await process_frame

	_reset_and_assert_runtime_defaults(t, "after start menu scene test")
	t.report("[StartMenuSceneTest]")
	quit(0 if t.failures.is_empty() else 1)


func _normalize_slot_label(text_value: String) -> String:
	return text_value.trim_prefix("● ")


func _rect_within_parent(pos: Vector2, size: Vector2, parent_size: Vector2) -> bool:
	return pos.x >= 0.0 \
		and pos.y >= 0.0 \
		and pos.x + size.x <= parent_size.x + 0.5 \
		and pos.y + size.y <= parent_size.y + 0.5


func _reset_and_assert_runtime_defaults(t: TestAssert, context: String) -> void:
	GameConfig.reset_runtime_defaults()
	t.eq(GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_BASIC, "%s mode reset" % context)
	t.eq(GameConfig.get_quality_name(), GameConfig.QUALITY_MEDIUM, "%s quality reset" % context)
	t.eq(GameConfig.get_palette_name(), "经典", "%s palette reset" % context)
