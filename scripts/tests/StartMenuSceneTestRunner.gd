extends SceneTree

# 主菜单的场景级回归闸门。v2.1.11（M01）把单页面板改成四页 + 30/70 双栏之后，
# 这个 runner 做了两件事：
#
#   1. 节点查找从硬编码长路径（RootPanel/MainVBox/ConfigPanel/...）改成
#      场景唯一名（%Name）。节点再挪位置不用改测试。
#   2. 保留全部业务断言 —— 槽位文案、开始/继续按钮文案、状态文案、
#      配置持久化回调，一条都没删。
#
# 新增的是导航与几何：四个页面必须都能打开、每页的按钮都必须落在面板内。
# 这些是新结构才有的失效方式（页面切成 30% 之后按钮会被挤出去），
# 所以必须有断言，而且不新建第二个 runner —— 重复的 runner 只会两边慢慢分叉。

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

const PAGE_MAIN := "main"
const PAGE_MODE := "mode"
const PAGE_CONFIG := "config"
const PAGE_CONTINUE := "continue"


class DummyOwner extends RefCounted:
	var SAVE_SLOT_COUNT: int = 5
	var selected_grid_size: int = 40
	var selected_palette_name: String = "\u9ed8\u8ba4\u968f\u673a"
	var selected_quality_name: String = GameConfig.QUALITY_MEDIUM
	var selected_game_mode_name: String = GameConfig.GAME_MODE_BASIC
	var selected_time_limit_minutes: int = 5
	var selected_save_slot: int = 3

	var save_preferences_calls: int = 0
	var reset_calls: int = 0
	var start_game_calls: int = 0
	var last_start_grid: int = -1

	func _has_save_file(slot_index: int = -1) -> bool:
		return slot_index in [2, 3, 5]

	func _start_game(_grid_size: int) -> void:
		start_game_calls += 1
		last_start_grid = _grid_size

	func _continue_saved_game() -> void:
		pass

	func _select_save_slot(slot_index: int) -> void:
		selected_save_slot = slot_index

	func _save_menu_preferences() -> void:
		save_preferences_calls += 1

	func reset_menu_preferences() -> void:
		reset_calls += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[StartMenuSceneTest] v2.1.11 four-page menu shell")

	_reset_and_assert_runtime_defaults(t, "before start menu scene test")

	var scene_resource = load("res://scenes/ui/StartMenu.tscn")
	t.that(scene_resource != null, "scene resource loadable")
	if scene_resource == null:
		t.report("[StartMenuSceneTest]")
		quit(1)
		return

	var instance = scene_resource.instantiate()
	t.that(instance is CanvasLayer, "root is CanvasLayer")
	if instance == null or not (instance is CanvasLayer):
		t.report("[StartMenuSceneTest]")
		quit(1)
		return

	get_root().add_child(instance)
	await process_frame

	var owner := DummyOwner.new()
	var summaries: Array = [
		{"slot": 1, "state": "valid", "has_data": true, "is_playable": true, "title": "\u57fa\u7840\u6a21\u5f0f\uFF5C20\u00D720\uFF5C\u4e2d", "detail": "\u8fdb\u5ea6 00:35\uFF5C\u7248\u672c 2.1.6"},
		{"slot": 2, "state": "valid", "has_data": true, "is_playable": true, "title": "\u5360\u9886\u6a21\u5f0f\uFF5C40\u00D740\uFF5C\u9ad8", "detail": "\u8fdb\u5ea6 04:10\uFF5C\u7248\u672c 2.1.6"},
		{"slot": 3, "state": "valid", "has_data": true, "is_playable": true, "title": "\u57fa\u7840\u6a21\u5f0f\uFF5C20\u00D720\uFF5C\u4e2d", "detail": "\u8fdb\u5ea6 01:45\uFF5C\u7248\u672c 2.1.6"},
		{"slot": 4, "state": "empty", "has_data": false, "is_playable": false, "title": "\u7a7a\u5b58\u6863", "detail": "\u70b9\u51fb\u9009\u62e9\u6b64\u69fd"},
		{"slot": 5, "state": "valid", "has_data": true, "is_playable": true, "title": "\u72c2\u91ce\u6a21\u5f0f\uFF5C10\u00D710\uFF5C\u4f4e", "detail": "\u8fdb\u5ea6 00:12\uFF5C\u7248\u672c 2.1.6"},
	]
	var layout: Dictionary = LayoutProfiles.get_profile(40).duplicate(true)
	layout.merge(LayoutCoordinator.calculate_layout(40, Vector2(1120, 720), false), true)

	instance.setup(owner, Vector2(1120, 720), summaries, layout)
	await process_frame

	# ---------------------------------------------------------------- 契约
	t.that(instance.has_method("get_parts"), "has get_parts")
	t.that(instance.has_method("refresh_slots"), "has refresh_slots")
	t.that(instance.has_method("show_page"), "has show_page")
	var parts: Dictionary = instance.get_parts()
	t.eq(parts["menu_save_slot_buttons"].size(), 5, "slot buttons: 5 found")

	# ---------------------------------------------------------------- 结构与几何
	var root_panel: Panel = instance.get_node("%RootPanel")
	var action_column: Control = instance.get_node("RootPanel/Columns/ActionColumn")
	var stage_column: Control = instance.get_node("%StageColumn")
	var preview_container: Control = instance.get_node("%PreviewContainer")
	var chamber_preview: Node2D = instance.get_node("%ChamberPreview")
	var stage_chrome: Control = instance.get_node("%StageChrome")

	var start_menu_layout: Dictionary = layout.get("start_menu_layout", {})
	# Control 内部存的是锚点偏移量，position/size 是读的时候再算出来的，
	# 所以同一个 Rect2 设进去再读回来会差最后几位浮点。这里按 0.05 px 比较，
	# 不是放宽标准 —— 半个像素以下本来就不可能画出来。
	t.that(_near_vec(root_panel.position, start_menu_layout["root_panel_rect"].position, 0.05), "root panel uses centered layout position")
	t.that(_near_vec(root_panel.size, start_menu_layout["root_panel_rect"].size, 0.05), "root panel uses updated layout size")
	t.that(root_panel.position.x >= 0.0, "root panel left edge visible")
	t.that(root_panel.position.y >= 0.0, "root panel top edge visible")
	t.that(root_panel.position.x + root_panel.size.x <= 1120.5, "root panel right edge visible")
	t.that(root_panel.position.y + root_panel.size.y <= 720.5, "root panel bottom edge visible")

	# 30 / 70 双栏：操作区必须真的是三成左右，否则"右侧是战场"就只是名义上的。
	var action_ratio: float = action_column.size.x / maxf(1.0, action_column.size.x + stage_column.size.x)
	t.between(action_ratio, 0.26, 0.34, "action column keeps the ~30% split")
	t.that(stage_column.size.x > action_column.size.x, "stage column is the wider of the two")
	# 两栏都用布局矩形显式摆放。一旦某个子节点的最小宽度把操作区撑宽，
	# 舞台就会和它重叠，所以这里把"实际宽度 == 布局宽度"钉住。
	var layout_action_width: float = (start_menu_layout["action_column_rect"] as Rect2).size.x
	t.between(action_column.size.x - layout_action_width, -0.5, 0.5, "action column honours the layout width")
	var layout_gap: float = float(start_menu_layout.get("column_gap", 18.0))
	t.between(stage_column.position.x - (action_column.size.x + layout_gap), -0.5, 0.5, "columns are separated by the layout gap")

	# 右侧必须是真战场，不是一张图：PreviewScene 的四个控制仓和四个炮台都要在。
	var preview_scene: Node = chamber_preview.get_node_or_null("PreviewScene")
	t.that(preview_scene != null, "shipped preview scene is attached")
	if preview_scene != null:
		for chamber_name in ["ChamberTopLeft", "ChamberTopRight", "ChamberBottomLeft", "ChamberBottomRight"]:
			t.that(preview_scene.get_node_or_null(chamber_name) != null, "preview keeps %s" % chamber_name)
		for turret_name in ["TurretTopLeft", "TurretTopRight", "TurretBottomLeft", "TurretBottomRight"]:
			t.that(preview_scene.get_node_or_null(turret_name) != null, "preview keeps %s" % turret_name)

	t.eq(preview_container.clip_contents, true, "preview container clips overflow")
	t.eq(chamber_preview.position, start_menu_layout["preview_center"], "preview uses layout center")
	t.eq(chamber_preview.scale, start_menu_layout["preview_scale"], "preview uses computed scale")
	t.that(chamber_preview.scale.x > 0.40, "preview scale is larger than the old 0.40 strip")
	t.that(_rect_inside(preview_container.get_global_rect(), root_panel.get_global_rect()), "preview container stays inside root panel")
	t.that(_rect_inside(stage_chrome.get_global_rect(), root_panel.get_global_rect()), "stage chrome stays inside root panel")
	t.that(preview_container.position.x >= 0.0 and preview_container.position.y >= 0.0, "preview sits at the stage inner origin")
	t.that(preview_container.position.x + preview_container.size.x <= stage_column.size.x + 0.5, "preview fits the stage width")
	t.that(preview_container.position.y + preview_container.size.y <= stage_column.size.y + 0.5, "preview fits the stage height")

	# ---------------------------------------------------------------- 槽位业务
	var slot_grid: GridContainer = instance.get_node("%SlotGrid")
	var start_button: Button = instance.get_node("%StartButton")
	var continue_button: Button = instance.get_node("%ContinueButton")
	var status_label: Label = instance.get_node("%MenuStatusLabel")

	t.eq(slot_grid.columns, 1, "slot grid is a single column inside the narrow action column")
	t.eq(slot_grid.get_child_count(), 5, "slot grid keeps 5 buttons")
	for slot in range(1, 6):
		var btn: Button = slot_grid.get_node_or_null("SlotButton_%d" % slot) as Button
		t.that(btn != null, "slot button %d exists" % slot)

	var slot_button_2: Button = slot_grid.get_node("SlotButton_2")
	var slot_button_3: Button = slot_grid.get_node("SlotButton_3")
	var slot_button_4: Button = slot_grid.get_node("SlotButton_4")
	var initial_slot_2_base: String = _normalize_slot_label(slot_button_2.text)
	t.eq(slot_button_3.text, "\u25cf \u69fd3\uFF5C\u57fa\u7840\uFF5C20\u00D720\uFF5C\u4e2d", "selected slot label compacted on first setup")
	t.eq(slot_button_4.text, "\u69fd4\uFF5C\u7a7a", "empty slot label compacted on first setup")
	t.eq(start_button.text, "\u5f00\u59cb\u65b0\u6e38\u620f", "start button uses clearer new-game copy")
	t.eq(continue_button.text, "\u8bfb\u53d6\u69fd3", "continue button shows selected slot")
	t.eq(status_label.text, "\u5df2\u9009\u62e9\u5b58\u6863\u69fd 3\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863", "status label explains overwrite target")
	# 状态栏和底部提示是 ActionColumn 里排在"可扩展的 PageHost"之后的节点。
	# 一旦某个自动换行标签在首帧把最小高度算爆，整列会被撑高，这两个就会
	# 被挤到面板外面 —— 上一版就是这样在实机截图里整块消失的。
	var mobile_hint: Label = instance.get_node("RootPanel/Columns/ActionColumn/MobileHint")
	t.that(_rect_inside(status_label.get_global_rect(), root_panel.get_global_rect()), "status label stays inside the root panel")
	t.that(_rect_inside(mobile_hint.get_global_rect(), root_panel.get_global_rect()), "mobile hint stays inside the root panel")

	owner.selected_save_slot = 2
	instance.refresh_slots(summaries)
	await process_frame

	t.eq(_normalize_slot_label(slot_button_2.text), initial_slot_2_base, "slot label format stays consistent after refresh")
	t.eq(slot_button_2.text, "\u25cf \u69fd2\uFF5C\u5360\u9886\uFF5C40\u00D740\uFF5C\u9ad8", "selected slot text keeps compact format after refresh")
	t.eq(slot_button_3.text, "\u69fd3\uFF5C\u57fa\u7840\uFF5C20\u00D720\uFF5C\u4e2d", "previously selected slot loses marker but keeps format")
	t.eq(start_button.text, "\u5f00\u59cb\u65b0\u6e38\u620f", "start button stays clear after refresh")
	t.eq(continue_button.text, "\u8bfb\u53d6\u69fd2", "continue button retargets selected slot after refresh")
	t.eq(status_label.text, "\u5df2\u9009\u62e9\u5b58\u6863\u69fd 2\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863", "status label retargets selected slot after refresh")
	# 选中态靠 toggle 组，不靠 modulate：两个槽不能同时是"选中"。
	t.that(slot_button_2.button_pressed, "selected slot 2 is toggled on")
	t.that(not slot_button_3.button_pressed, "deselected slot 3 is toggled off")

	# ---------------------------------------------------------------- 四页导航
	var main_page: Control = instance.get_node("%MainMenuPage")
	var mode_page: Control = instance.get_node("%ModeSelectPage")
	var config_page: Control = instance.get_node("%MatchConfigPage")
	var continue_page: Control = instance.get_node("%ContinuePage")

	t.eq(instance.current_page(), PAGE_MAIN, "menu opens on the main page")
	t.that(main_page.visible, "main page visible on open")
	t.that(not mode_page.visible and not config_page.visible and not continue_page.visible, "only the main page is visible on open")

	var continue_entry: Button = instance.get_node("%ContinueEntryButton")
	continue_entry.pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_CONTINUE, "continue entry opens the continue page")
	t.that(continue_page.visible and not main_page.visible, "continue page replaces the main page")
	instance.get_node("%ContinueBackButton").pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MAIN, "continue page back button returns to the main page")

	start_button.pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MODE, "start button leads to mode select")
	t.that(mode_page.visible and not main_page.visible, "mode page replaces the main page")

	# 四种现有玩法必须完整在场，而且是从 GameConfig 长出来的，不是写死的四个按钮。
	var mode_names: Array = GameConfig.get_game_mode_names()
	t.eq(mode_names.size(), 4, "GameConfig still exposes four modes")
	var mode_card_host: Node = instance.get_node("%ModeCardHost")
	t.eq(mode_card_host.get_child_count(), mode_names.size(), "one mode card per configured mode")
	for mode_name in mode_names:
		var found: bool = false
		for child in mode_card_host.get_children():
			if child is Button and (child as Button).text == str(mode_name):
				found = true
				break
		t.that(found, "mode card present for %s" % str(mode_name))

	# 点一张卡必须真的改到 owner，并且立刻落一次偏好。
	var occupation_card: Button = null
	for child in mode_card_host.get_children():
		if child is Button and (child as Button).text == GameConfig.GAME_MODE_OCCUPATION:
			occupation_card = child
			break
	t.that(occupation_card != null, "occupation mode card resolvable")
	if occupation_card != null:
		var saves_before: int = owner.save_preferences_calls
		occupation_card.button_pressed = true
		await process_frame
		t.eq(owner.selected_game_mode_name, GameConfig.GAME_MODE_OCCUPATION, "mode card writes the selected mode to the owner")
		t.gt(owner.save_preferences_calls, saves_before, "mode card persists preferences")

	instance.get_node("%ModeNextButton").pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_CONFIG, "mode page advances to match config")
	instance.get_node("%ConfigBackButton").pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MODE, "config back button returns to mode select")

	instance.get_node("%ModeNextButton").pressed.emit()
	await process_frame
	var start_match_button: Button = instance.get_node("%StartMatchButton")
	t.that(start_match_button.text.length() > 0, "start match button carries copy")

	# 开局必须仍然走 Main 的 _start_game(grid_size)，参数也仍然是网格大小。
	var starts_before: int = owner.start_game_calls
	start_match_button.pressed.emit()
	await process_frame
	t.gt(owner.start_game_calls, starts_before, "start match routes into Main._start_game")
	t.eq(owner.last_start_grid, owner.selected_grid_size, "start match forwards the selected grid size")

	# ---------------------------------------------------------------- 每页几何
	# 切成 30% 之后最容易出的问题就是按钮溢出，所以四页都要验一遍。
	for page_key in [PAGE_MAIN, PAGE_MODE, PAGE_CONFIG, PAGE_CONTINUE]:
		instance.show_page(page_key)
		await process_frame
		await process_frame
		t.eq(instance.current_page(), page_key, "page %s openable" % page_key)
		var page_node: Control = instance.get_node("%" + _page_node_name(page_key))
		t.that(page_node.visible, "page %s visible after show_page" % page_key)
		var overflow: Array = _overflowing_buttons(page_node, root_panel)
		t.that(overflow.is_empty(), "page %s keeps every button inside the panel (%s)" % [page_key, str(overflow)])

	# 回到主菜单页收尾，避免把 _remembered_page 留在别的页上。
	instance.show_page(PAGE_MAIN)
	await process_frame

	instance.queue_free()
	await process_frame

	_reset_and_assert_runtime_defaults(t, "after start menu scene test")
	t.report("[StartMenuSceneTest]")
	quit(0 if t.failures.is_empty() else 1)


func _page_node_name(page_key: String) -> String:
	match page_key:
		PAGE_MODE:
			return "ModeSelectPage"
		PAGE_CONFIG:
			return "MatchConfigPage"
		PAGE_CONTINUE:
			return "ContinuePage"
		_:
			return "MainMenuPage"


func _overflowing_buttons(node: Node, panel: Control) -> Array:
	var out: Array = []
	var panel_rect: Rect2 = panel.get_global_rect().grow(0.5)
	for child in node.get_children():
		if child is Button:
			var button: Button = child
			if not button.visible:
				continue
			if not _rect_inside(button.get_global_rect(), panel_rect):
				out.append(String(button.name))
		out.append_array(_overflowing_buttons(child, panel))
	return out


func _normalize_slot_label(text_value: String) -> String:
	return text_value.trim_prefix("\u25cf ")


func _near_vec(actual: Vector2, expected: Vector2, tolerance: float) -> bool:
	return absf(actual.x - expected.x) <= tolerance and absf(actual.y - expected.y) <= tolerance


func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 \
		and inner.position.y >= outer.position.y - 0.5 \
		and inner.position.x + inner.size.x <= outer.position.x + outer.size.x + 0.5 \
		and inner.position.y + inner.size.y <= outer.position.y + outer.size.y + 0.5


func _reset_and_assert_runtime_defaults(t: TestAssert, context: String) -> void:
	GameConfig.reset_runtime_defaults()
	t.eq(GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_BASIC, "%s mode reset" % context)
	t.eq(GameConfig.get_quality_name(), GameConfig.QUALITY_MEDIUM, "%s quality reset" % context)
	t.eq(GameConfig.get_palette_name(), "\u7ecf\u5178", "%s palette reset" % context)
