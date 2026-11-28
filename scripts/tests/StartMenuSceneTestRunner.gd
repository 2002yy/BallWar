extends SceneTree

# 主菜单的场景级回归闸门。
#
# 历史：v2.1.11（M01）把单页面板改成四页 + 30/70 双栏；v2.1.12（M01-I2）又把
# 左栏改成常驻主导航、右栏改成页面宿主。两次都只改结构，所以这个 runner 的
# 职责一直没变：
#
#   1. 节点查找用场景唯一名（%Name），节点挪位置不用改测试。
#   2. 业务断言全部保留 —— 槽位文案、继续按钮文案、状态文案、配置持久化回调。
#   3. 几何断言跟着结构走：外留白、中心棋盘尺寸、导航条数、每页按钮都在面板内。
#
# M01-I2 新增的三条是这轮真正出过问题的失效方式：
#   外留白退回 80px（界面缩成一张卡片）、中心棋盘退回 240px（战场没有冲击力）、
#   左栏退回两个按钮（下半部分空一大块）。它们必须有断言，否则下一轮又会漂回去。

const TestAssert = preload("res://scripts/tests/TestAssert.gd")

const PAGE_MAIN := "main"
const PAGE_MODE := "mode"
const PAGE_CONFIG := "config"
const PAGE_HELP := "help"
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
	print("[StartMenuSceneTest] v2.1.12 persistent navigation menu shell")

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
	await process_frame

	# ---------------------------------------------------------------- 契约
	t.that(instance.has_method("get_parts"), "has get_parts")
	t.that(instance.has_method("refresh_slots"), "has refresh_slots")
	t.that(instance.has_method("show_page"), "has show_page")
	var parts: Dictionary = instance.get_parts()
	t.eq(parts["menu_save_slot_buttons"].size(), 5, "slot buttons: 5 found")

	# 静态文案 helper 被 SaveFlowController 以 StartMenuUi 名义 preload 调用，
	# 属于对外契约。它们不再直接挂在某个按钮上（主操作已改成常驻导航条），
	# 但输出仍然必须稳定 —— 这里直接断言函数，不删旧断言。
	t.eq(StartMenu.build_slot_label(3, summaries[2], 3), "\u25cf \u69fd3\uFF5C\u57fa\u7840\uFF5C20\u00D720\uFF5C\u4e2d", "build_slot_label keeps the compact format")
	t.eq(StartMenu.build_continue_button_text(3), "\u8bfb\u53d6\u69fd3", "build_continue_button_text keeps the slot suffix")
	t.eq(StartMenu.build_start_button_label(3, true), "\u5f00\u59cb\u65b0\u6e38\u620f", "build_start_button_label keeps the new-game copy")
	t.eq(StartMenu.build_start_button_text(3), "\u65b0\u5c40\u8986\u76d6\u69fd3", "build_start_button_text keeps the overwrite copy")
	t.eq(StartMenu.build_status_label(3, true), "\u5df2\u9009\u62e9\u5b58\u6863\u69fd 3\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863", "build_status_label keeps the overwrite warning")

	# ---------------------------------------------------------------- 结构与几何
	var root_panel: Panel = instance.get_node("%RootPanel")
	var action_column: Control = instance.get_node("RootPanel/Columns/ActionColumn")
	var stage_column: Control = instance.get_node("%StageColumn")
	var preview_container: Control = instance.get_node("%PreviewContainer")
	var chamber_preview: Node2D = instance.get_node("%ChamberPreview")
	var stage_chrome: Control = instance.get_node("%StageChrome")
	var page_host: Control = instance.get_node("%PageHost")

	var start_menu_layout: Dictionary = layout.get("start_menu_layout", {})
	# Control 内部存的是锚点偏移量，position/size 是读的时候再算出来的，
	# 所以同一个 Rect2 设进去再读回来会差最后几位浮点。这里按 0.05 px 比较，
	# 不是放宽标准 —— 半个像素以下本来就不可能画出来。
	t.that(_near_vec(root_panel.position, start_menu_layout["root_panel_rect"].position, 0.05), "root panel uses the layout position")
	t.that(_near_vec(root_panel.size, start_menu_layout["root_panel_rect"].size, 0.05), "root panel uses the layout size")
	t.that(root_panel.position.x >= 0.0, "root panel left edge visible")
	t.that(root_panel.position.y >= 0.0, "root panel top edge visible")
	t.that(root_panel.position.x + root_panel.size.x <= 1120.5, "root panel right edge visible")
	t.that(root_panel.position.y + root_panel.size.y <= 720.5, "root panel bottom edge visible")

	# 屏幕利用率：旧版四边各留 78px 纯黑，整块界面读作"飘在背景上的一张卡片"。
	# 目标区间取用户裁定的 24–32px，左右上下都要，单边达标不算。
	var margin_left: float = root_panel.position.x
	var margin_right: float = 1120.0 - (root_panel.position.x + root_panel.size.x)
	var margin_top: float = root_panel.position.y
	var margin_bottom: float = 720.0 - (root_panel.position.y + root_panel.size.y)
	t.between(margin_left, 24.0, 32.0, "left outer margin is 24-32 px")
	t.between(margin_right, 24.0, 32.0, "right outer margin is 24-32 px")
	t.between(margin_top, 24.0, 32.0, "top outer margin is 24-32 px")
	t.between(margin_bottom, 24.0, 32.0, "bottom outer margin is 24-32 px")
	t.gt(root_panel.size.x * root_panel.size.y, 1120.0 * 720.0 * 0.86, "root panel covers 86%+ of the screen area")

	# 30 / 70 双栏：操作区必须真的是三成左右，否则"右侧是战场"就只是名义上的。
	var action_ratio: float = action_column.size.x / maxf(1.0, action_column.size.x + stage_column.size.x)
	t.between(action_ratio, 0.26, 0.34, "action column keeps the ~30% split")
	t.that(stage_column.size.x > action_column.size.x, "stage column is the wider of the two")
	# 两栏都用布局矩形显式摆放。一旦某个子节点的最小宽度把操作区撑宽，
	# 舞台就会和它重叠，所以这里把"实际宽度 == 布局宽度"钉住。
	var layout_action_width: float = (start_menu_layout["action_column_rect"] as Rect2).size.x
	t.between(action_column.size.x - layout_action_width, -0.5, 0.5, "action column honours the layout width")
	var layout_gap: float = float(start_menu_layout.get("column_gap", 16.0))
	t.between(stage_column.position.x - (action_column.size.x + layout_gap), -0.5, 0.5, "columns are separated by the layout gap")

	# 右侧必须是真战场，不是一张图：PreviewScene 的四个控制仓和四个炮台都要在。
	var preview_scene: Node = chamber_preview.get_node_or_null("PreviewScene")
	t.that(preview_scene != null, "shipped preview scene is attached")
	if preview_scene != null:
		for chamber_name in ["ChamberTopLeft", "ChamberTopRight", "ChamberBottomLeft", "ChamberBottomRight"]:
			t.that(preview_scene.get_node_or_null(chamber_name) != null, "preview keeps %s" % chamber_name)
		for turret_name in ["TurretTopLeft", "TurretTopRight", "TurretBottomLeft", "TurretBottomRight"]:
			t.that(preview_scene.get_node_or_null(turret_name) != null, "preview keeps %s" % turret_name)
		# 机身是"一台机器"而不是"五件摆在一起的零件"：机架必须在场。
		t.that(preview_scene.get_node_or_null("Chassis") != null, "preview keeps the chassis that ties the parts together")

	t.eq(preview_container.clip_contents, true, "preview container clips overflow")
	t.eq(chamber_preview.position, start_menu_layout["preview_center"], "preview uses layout center")
	t.eq(chamber_preview.scale, start_menu_layout["preview_scale"], "preview uses computed scale")
	t.that(chamber_preview.scale.x > 0.90, "preview scale reaches near 1:1 (old strip was 0.40)")

	# 中心棋盘的实际像素尺寸：用户裁定的 320–350px 是这轮的核心指标。
	# 直接读 Board 的 board_size 再乘预览缩放，比目测截图可靠。
	if preview_scene != null:
		var board_node: Node = preview_scene.get_node_or_null("Board")
		t.that(board_node != null, "preview keeps the board")
		if board_node != null:
			var board_px: float = float(board_node.get("board_size")) * chamber_preview.scale.x
			t.between(board_px, 320.0, 350.0, "central board renders at 320-350 px")

	# ------------------------------------------- 阵营数据一致性（M01-I2 收口）
	# 预览与正式战斗共享「阵营 ID / 四角映射 / 调色板」同一份数据定义。
	# 旧版把四种颜色硬编码在 .tscn，预览四角 = 红/黄/绿/蓝，战斗四角 =
	# 蓝/红/绿/黄，只有左下绿一致。这里把映射、坐标和取色来源都钉住。
	var expected_corners := LayoutCoordinator.corner_factions()
	t.eq(int(expected_corners["top_left"]), int(GameConfig.Faction.BLUE), "shared corner map: top-left is BLUE")
	t.eq(int(expected_corners["top_right"]), int(GameConfig.Faction.RED), "shared corner map: top-right is RED")
	t.eq(int(expected_corners["bottom_left"]), int(GameConfig.Faction.GREEN), "shared corner map: bottom-left is GREEN")
	t.eq(int(expected_corners["bottom_right"]), int(GameConfig.Faction.YELLOW), "shared corner map: bottom-right is YELLOW")

	var battle_layout := LayoutCoordinator.calculate_layout(40, Vector2(1280, 720), false)
	var turret_pos: Dictionary = battle_layout["turret_positions"]
	var pos_tl: Vector2 = turret_pos[int(expected_corners["top_left"])]
	var pos_tr: Vector2 = turret_pos[int(expected_corners["top_right"])]
	var pos_bl: Vector2 = turret_pos[int(expected_corners["bottom_left"])]
	var pos_br: Vector2 = turret_pos[int(expected_corners["bottom_right"])]
	t.that(pos_tl.x < pos_tr.x and pos_tl.y < pos_bl.y and pos_tr.y < pos_br.y and pos_bl.x < pos_br.x,
		"battle turret coordinates are generated from the shared corner map")

	if preview_scene != null:
		var corner_nodes := {
			"top_left": ["ChamberTopLeft", "TurretTopLeft"],
			"top_right": ["ChamberTopRight", "TurretTopRight"],
			"bottom_left": ["ChamberBottomLeft", "TurretBottomLeft"],
			"bottom_right": ["ChamberBottomRight", "TurretBottomRight"],
		}
		for corner_key in LayoutCoordinator.CORNER_KEYS:
			var expected_id: int = int(expected_corners[corner_key])
			for corner_part_name in corner_nodes[corner_key]:
				var corner_part: Node = preview_scene.get_node_or_null(corner_part_name)
				if corner_part != null:
					t.eq(int(corner_part.get("faction_id")), expected_id,
						"%s uses shared faction id for %s" % [corner_part_name, corner_key])
		var expected_order := LayoutCoordinator.corner_faction_order()
		for order_part_name in ["Board", "Chassis"]:
			var order_part: Node = preview_scene.get_node_or_null(order_part_name)
			if order_part != null:
				t.eq(order_part.get("corner_faction_ids"), expected_order,
					"%s uses shared corner faction order" % order_part_name)

		# 实际调色板数量以 GameConfig.get_palette_names() 为准（当前 5 套）。
		# 颜色必须在绘制时实时取 GameConfig.faction_color()，不能有本地缓存。
		var board_colors_node: Node = preview_scene.get_node_or_null("Board")
		t.that(board_colors_node != null and board_colors_node.has_method("faction_color_at"),
			"board exposes live faction colours")
		for palette_name in GameConfig.get_palette_names():
			GameConfig.set_palette_by_name(str(palette_name))
			if preview_scene.has_method("apply_faction_ids"):
				preview_scene.call("apply_faction_ids")
			var palette_ok: bool = board_colors_node != null and board_colors_node.has_method("faction_color_at")
			if palette_ok:
				for i in range(4):
					var want: Color = GameConfig.faction_color(int(expected_order[i]))
					var got: Color = board_colors_node.call("faction_color_at", i)
					if absf(got.r - want.r) > 0.001 or absf(got.g - want.g) > 0.001 or absf(got.b - want.b) > 0.001:
						palette_ok = false
			t.that(palette_ok, "preview board colour follows palette %s" % palette_name)
		GameConfig.reset_runtime_defaults()
		if preview_scene.has_method("apply_faction_ids"):
			preview_scene.call("apply_faction_ids")
		t.eq(GameConfig.get_palette_name(), "\u7ecf\u5178", "palette restored to classic after preview checks")

	t.that(_rect_inside(preview_container.get_global_rect(), root_panel.get_global_rect()), "preview container stays inside root panel")
	t.that(_rect_inside(stage_chrome.get_global_rect(), root_panel.get_global_rect()), "stage chrome stays inside root panel")
	t.that(preview_container.position.x >= 0.0 and preview_container.position.y >= 0.0, "preview sits at the stage inner origin")
	t.that(preview_container.position.x + preview_container.size.x <= stage_column.size.x + 0.5, "preview fits the stage width")
	t.that(preview_container.position.y + preview_container.size.y <= stage_column.size.y + 0.5, "preview fits the stage height")
	t.that(_rect_inside(page_host.get_global_rect(), root_panel.get_global_rect()), "page host stays inside root panel")

	# ---------------------------------------------------------------- 常驻主导航
	var nav_start: Button = instance.get_node("%NavStartButton")
	var nav_continue: Button = instance.get_node("%NavContinueButton")
	var nav_config: Button = instance.get_node("%NavConfigButton")
	var nav_help: Button = instance.get_node("%NavHelpButton")
	var nav_quit: Button = instance.get_node("%NavQuitButton")
	t.eq(nav_start.text, "\u5f00\u59cb\u6e38\u620f", "primary nav carries the start action")
	t.eq(nav_continue.text, "\u7ee7\u7eed\u6e38\u620f", "nav carries the continue entry")
	t.eq(nav_config.text, "\u5bf9\u5c40\u8bbe\u7f6e", "nav carries the settings entry")
	t.eq(nav_help.text, "\u73a9\u6cd5\u8bf4\u660e", "nav carries the how-to-play entry")
	t.eq(nav_quit.text, "\u9000\u51fa\u6e38\u620f", "nav carries the quit entry")
	# 参考图的左栏是一排占满整列高度的导航条。只放两个按钮就是上一版
	# "左下角空一大块"的根因，所以条数本身要断言。
	var nav_list: VBoxContainer = nav_start.get_parent()
	t.eq(nav_list.get_child_count(), 5, "left column keeps the full five-item navigation")
	for button in [nav_start, nav_continue, nav_config, nav_help, nav_quit]:
		t.that(_rect_inside(button.get_global_rect(), root_panel.get_global_rect()), "nav button %s stays inside the root panel" % button.name)
		t.that(button.icon != null, "nav button %s carries an svg icon" % button.name)
	# 左栏最后一块是配置摘要，它必须真的落地，而不是被撑到面板外。
	for label_name in ["%MainModeValue", "%MainMapValue", "%MainQualityValue"]:
		var value_label: Label = instance.get_node(label_name)
		t.that(value_label.text.length() > 0, "summary value %s is filled" % label_name)
		t.that(_rect_inside(value_label.get_global_rect(), root_panel.get_global_rect()), "summary value %s stays inside the root panel" % label_name)
	# 导航条必须真的是"一排"：上下相邻且不重叠。
	t.that(nav_continue.position.y > nav_start.position.y, "nav items flow downward")
	t.that(nav_help.position.y + nav_help.size.y <= nav_list.size.y + 0.5, "nav list is tall enough for all five items")

	# ---------------------------------------------------------------- 槽位业务
	var slot_grid: GridContainer = instance.get_node("%SlotGrid")
	var continue_button: Button = instance.get_node("%ContinueButton")
	var status_label: Label = instance.get_node("%MenuStatusLabel")

	t.eq(slot_grid.columns, 1, "slot grid stays a single column")
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
	t.eq(continue_button.text, "\u8bfb\u53d6\u69fd3", "continue button shows selected slot")
	t.eq(status_label.text, "\u5df2\u9009\u62e9\u5b58\u6863\u69fd 3\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863", "status label explains overwrite target")

	# 状态栏和平台提示现在归通栏状态条。它们在旧版是排在左栏可扩展页宿主之后，
	# 被首帧的假最小高度挤到面板外，实机截图里整块消失 —— 必须继续钉住。
	var mobile_hint: Label = instance.get_node("%MobileHint")
	var version_label: Label = instance.get_node("%VersionLabel")
	t.that(_rect_inside(status_label.get_global_rect(), root_panel.get_global_rect()), "status label stays inside the root panel")
	t.that(_rect_inside(mobile_hint.get_global_rect(), root_panel.get_global_rect()), "platform hint stays inside the root panel")
	t.that(_rect_inside(version_label.get_global_rect(), root_panel.get_global_rect()), "version label stays inside the root panel")
	t.that(version_label.text.begins_with("v"), "version label still carries the project version")
	# 状态条必须在两栏下方，不能和左栏内容抢同一块高度。
	t.that(status_label.get_global_rect().position.y >= action_column.get_global_rect().position.y + action_column.size.y - 1.0,
		"footer bar sits below the two columns")

	owner.selected_save_slot = 2
	instance.refresh_slots(summaries)
	await process_frame

	t.eq(_normalize_slot_label(slot_button_2.text), initial_slot_2_base, "slot label format stays consistent after refresh")
	t.eq(slot_button_2.text, "\u25cf \u69fd2\uFF5C\u5360\u9886\uFF5C40\u00D740\uFF5C\u9ad8", "selected slot text keeps compact format after refresh")
	t.eq(slot_button_3.text, "\u69fd3\uFF5C\u57fa\u7840\uFF5C20\u00D720\uFF5C\u4e2d", "previously selected slot loses marker but keeps format")
	t.eq(continue_button.text, "\u8bfb\u53d6\u69fd2", "continue button retargets selected slot after refresh")
	t.eq(status_label.text, "\u5df2\u9009\u62e9\u5b58\u6863\u69fd 2\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863", "status label retargets selected slot after refresh")
	# 选中态靠 toggle 组，不靠 modulate：两个槽不能同时是"选中"。
	t.that(slot_button_2.button_pressed, "selected slot 2 is toggled on")
	t.that(not slot_button_3.button_pressed, "deselected slot 3 is toggled off")

	# ---------------------------------------------------------------- 页面导航
	var main_page: Control = instance.get_node("%MainMenuPage")
	var mode_page: Control = instance.get_node("%ModeSelectPage")
	var config_page: Control = instance.get_node("%MatchConfigPage")
	var help_page: Control = instance.get_node("%HelpPage")
	var continue_page: Control = instance.get_node("%ContinuePage")

	t.eq(instance.current_page(), PAGE_MAIN, "menu opens on the main page")
	t.that(main_page.visible, "main page visible on open")
	t.that(not mode_page.visible and not config_page.visible and not help_page.visible and not continue_page.visible,
		"only the main page is visible on open")
	# 主菜单页没有对应的高亮导航项（它是"首页"），三个可选页都不该亮着。
	t.that(not nav_continue.button_pressed and not nav_config.button_pressed and not nav_help.button_pressed,
		"no nav item is highlighted on the home page")

	nav_continue.pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_CONTINUE, "continue entry opens the continue page")
	t.that(continue_page.visible and not main_page.visible, "continue page replaces the main page")
	t.that(nav_continue.button_pressed, "continue nav item is highlighted on its own page")
	instance.get_node("%ContinueBackButton").pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MAIN, "continue page back button returns to the main page")
	t.that(not nav_continue.button_pressed, "nav highlight clears when leaving the page")

	nav_start.pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MODE, "start nav leads to mode select")
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

	# 覆盖存档保护：Main._start_game(clear_save=true) 会删掉当前槽的存档、
	# 备份和临时文件。槽里已有存档时，点「开始对局」只能弹确认框，不能开局。
	var overwrite_dialog: ConfirmationDialog = instance.get_node("%OverwriteDialog")
	t.eq(overwrite_dialog.visible, false, "overwrite dialog is closed by default")
	owner.selected_save_slot = 3
	var starts_before: int = owner.start_game_calls
	start_match_button.pressed.emit()
	await process_frame
	t.eq(overwrite_dialog.visible, true, "start on an occupied slot opens the overwrite dialog")
	t.eq(owner.start_game_calls, starts_before, "start on an occupied slot does not delete the save yet")
	t.that(overwrite_dialog.dialog_text.find("\u5220\u9664") >= 0, "overwrite dialog explains the deletion")
	overwrite_dialog.confirmed.emit()
	await process_frame
	t.gt(owner.start_game_calls, starts_before, "confirmed start routes into Main._start_game")
	t.eq(owner.last_start_grid, owner.selected_grid_size, "start match forwards the selected grid size")

	# 空槽不该被确认框打扰：仍走原来的直接开局路径。
	overwrite_dialog.hide()
	owner.selected_save_slot = 4
	var empty_starts: int = owner.start_game_calls
	start_match_button.pressed.emit()
	await process_frame
	t.eq(overwrite_dialog.visible, false, "empty slot does not open the overwrite dialog")
	t.gt(owner.start_game_calls, empty_starts, "empty slot starts the match directly")

	# ---------------------------------------------------------------- 玩法说明与退出
	nav_help.pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_HELP, "help nav opens the how-to-play page")
	t.that(nav_help.button_pressed, "help nav item is highlighted")
	instance.get_node("%HelpBackButton").pressed.emit()
	await process_frame
	t.eq(instance.current_page(), PAGE_MAIN, "help back button returns to the main page")

	# 安卓返回键 / Esc 的惯例：内页回上一级，而不是直接退出。
	instance.show_page(PAGE_CONFIG)
	await process_frame
	t.that(instance._handle_back(), "back request is consumed on an inner page")
	t.eq(instance.current_page(), PAGE_MODE, "config page goes back to mode select")
	instance._handle_back()
	await process_frame
	t.eq(instance.current_page(), PAGE_MAIN, "mode page goes back to the main page")

	# 退出入口：必须弹确认框，而不是直接杀进程 —— 测试跑在这里被退出就等于
	# 静默通过。只验"对话框出来了"，绝不确认它。
	var quit_dialog: ConfirmationDialog = instance.get_node("%QuitDialog")
	t.eq(quit_dialog.visible, false, "quit dialog is closed by default")
	nav_quit.pressed.emit()
	await process_frame
	t.eq(quit_dialog.visible, true, "quit entry opens the confirmation dialog")
	t.eq(quit_dialog.dialog_text.find("退出") >= 0, true, "quit dialog explains what is about to happen")
	quit_dialog.hide()
	await process_frame

	# ---------------------------------------------------------------- 每页几何
	# 页面放到右栏之后最容易出的问题就是按钮溢出到面板外，所以每页都要验一遍。
	for page_key in [PAGE_MAIN, PAGE_MODE, PAGE_CONFIG, PAGE_HELP, PAGE_CONTINUE]:
		instance.show_page(page_key)
		await process_frame
		await process_frame
		t.eq(instance.current_page(), page_key, "page %s openable" % page_key)
		var page_node: Control = instance.get_node("%" + _page_node_name(page_key))
		t.that(page_node.visible, "page %s visible after show_page" % page_key)
		t.that(_near_vec(page_node.size, page_host.size, 0.5),
			"page %s is sized by the page host (actual=%s expected=%s)" % [page_key, str(page_node.size), str(page_host.size)])
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
		PAGE_HELP:
			return "HelpPage"
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
