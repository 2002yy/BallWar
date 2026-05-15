extends SceneTree

var _assert: TestAssert

const DEFAULT_VIEWPORT: Vector2 = Vector2(1120, 720)
const GRID_SIZES := [10, 20, 30, 40, 50, 60]
const GameHUDScene = preload("res://scenes/ui/GameHUD.tscn")

class DummyOwner extends RefCounted:
	func _on_scores_changed(_counts: Dictionary) -> void:
		pass

	func _on_turret_destroyed(_faction_id: int) -> void:
		pass

	func _on_turret_burst_lock_changed(_faction_id: int, _locked: bool) -> void:
		pass

	func _on_turret_burst_progress(_faction_id: int, _remaining: int) -> void:
		pass

	func _on_chamber_release_requested(_faction_id: int, _bullet_count: int, _chamber) -> void:
		pass

	func _on_ball_count_changed(_faction_id: int, _count: int) -> void:
		pass

	func _add_ball_to_chamber(_faction_id: int) -> void:
		pass

	func _toggle_settings_panel() -> void:
		pass

	func _toggle_pause() -> void:
		pass

	func _save_and_exit_to_menu() -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert = TestAssert.new()
	print("[LayoutSanity] v2.1.5 - layout boundary and runtime application tests")
	await process_frame

	for grid_size in GRID_SIZES:
		_test_viewport_bounds(grid_size, DEFAULT_VIEWPORT, false)
		_test_viewport_bounds(grid_size, DEFAULT_VIEWPORT, true)

	_test_bottom_hud_group()
	_test_roulette_centered()
	_test_event_perf_no_overlap()
	_test_button_not_under_chamber()
	await _test_runtime_layout_application(40, false)
	await _test_runtime_layout_application(40, true)

	_assert.report("[LayoutSanity]")

	if _assert.failures.is_empty():
		quit(0)
	else:
		quit(1)

func _build_layout(grid_size: int, viewport: Vector2, is_mobile: bool) -> Dictionary:
	var layout: Dictionary = LayoutProfiles.get_profile(grid_size).duplicate(true)
	layout.merge(LayoutCoordinator.calculate_layout(grid_size, viewport, is_mobile), true)
	return layout

func _test_viewport_bounds(grid_size: int, viewport: Vector2, is_mobile: bool) -> void:
	var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, viewport, is_mobile)
	var label := "layout %dx%d %s" % [grid_size, grid_size, "mobile" if is_mobile else "desktop"]

	var bf_rect: Rect2 = layout["battlefield_rect"]
	_assert.that(_rect_inside_viewport(bf_rect, viewport), "%s: battlefield inside" % label)
	_assert.that(bf_rect.size.x > 0.0 and bf_rect.size.y > 0.0, "%s: battlefield positive size" % label)

	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var tpos: Vector2 = layout["turret_positions"][faction_id]
		_assert.that(_point_inside_viewport(tpos, viewport), "%s: turret %d inside" % [label, faction_id])

		var cpos: Vector2 = layout["chamber_positions"][faction_id]
		var csize: Vector2 = layout["chamber_size"]
		_assert.that(_point_inside_viewport(cpos, viewport), "%s: chamber %d pos inside" % [label, faction_id])
		_assert.that(_rect_inside_viewport(Rect2(cpos, csize), viewport), "%s: chamber %d rect inside" % [label, faction_id])

		var bpos: Vector2 = layout["add_ball_button_positions"][faction_id]
		var bsize: Vector2 = layout.get("add_ball_button_size", Vector2(96, 42))
		_assert.that(_rect_inside_viewport(Rect2(bpos, bsize), viewport), "%s: +ball %d inside" % [label, faction_id])

	for button_name in ["settings", "pause", "exit"]:
		var pos: Vector2 = layout["side_button_positions"][button_name]
		var ssz: Vector2 = layout["side_button_size"]
		_assert.that(_rect_inside_viewport(Rect2(pos, ssz), viewport), "%s: %s inside" % [label, button_name])

	var hud: Dictionary = layout["hud_positions"]
	var fps_rect: Rect2 = hud["fps_label_rect"]
	var event_rect: Rect2 = hud["event_label_rect"]
	var bottom_rect: Rect2 = hud["bottom_hud_rect"]
	_assert.that(_rect_inside_viewport(fps_rect, viewport), "%s: fps_label inside" % label)
	_assert.that(_rect_inside_viewport(event_rect, viewport), "%s: event_label inside" % label)
	_assert.that(_rect_inside_viewport(bottom_rect, viewport), "%s: bottom_hud_group inside" % label)

func _test_bottom_hud_group() -> void:
	for grid_size in GRID_SIZES:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var hud: Dictionary = layout["hud_positions"]
		var bottom_rect: Rect2 = hud["bottom_hud_rect"]
		_assert.that(bottom_rect.position.x >= 4.0, "hud group x >= 4 @ %d" % grid_size)
		_assert.that(bottom_rect.position.x + bottom_rect.size.x <= DEFAULT_VIEWPORT.x - 4.0, "hud group right in bounds @ %d" % grid_size)

func _test_roulette_centered() -> void:
	for grid_size in GRID_SIZES:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var stage: Rect2 = layout["roulette_stage_rect"]
		_assert.that(_rect_inside_viewport(stage, DEFAULT_VIEWPORT), "roulette %d inside" % grid_size)
		var cx: float = DEFAULT_VIEWPORT.x * 0.5
		_assert.that(abs(stage.position.x + stage.size.x * 0.5 - cx) < 1.0, "roulette %d centered" % grid_size)

func _test_event_perf_no_overlap() -> void:
	for grid_size in GRID_SIZES:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var hud: Dictionary = layout["hud_positions"]
		var fps_rect: Rect2 = hud["fps_label_rect"]
		var event_rect: Rect2 = hud["event_label_rect"]
		_assert.that(not fps_rect.intersects(event_rect), "fps/event no overlap %d" % grid_size)

func _test_button_not_under_chamber() -> void:
	for grid_size in GRID_SIZES:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.GREEN]:
			var cpos: Vector2 = layout["chamber_positions"][faction_id]
			var csize: Vector2 = layout["chamber_size"]
			var bpos: Vector2 = layout["add_ball_button_positions"][faction_id]
			var bsize: Vector2 = layout.get("add_ball_button_size", Vector2(96, 42))
			_assert.that(bpos.x + bsize.x < cpos.x or bpos.x > cpos.x + csize.x, "btn %d not under chamber %d" % [faction_id, grid_size])

func _test_runtime_layout_application(grid_size: int, is_mobile: bool) -> void:
	var owner := DummyOwner.new()
	var layout: Dictionary = _build_layout(grid_size, DEFAULT_VIEWPORT, is_mobile)
	var label := "runtime %dx%d %s" % [grid_size, grid_size, "mobile" if is_mobile else "desktop"]

	var game_layer := Node2D.new()
	get_root().add_child(game_layer)

	var scene_nodes: Dictionary = GameSceneBuilder.create_battlefield(owner, game_layer, grid_size, layout, DEFAULT_VIEWPORT)
	var battlefield = scene_nodes["battlefield"]
	var bullet_pool = scene_nodes["bullet_container"]
	var chamber_scale: float = float(scene_nodes.get("chamber_scale", layout.get("chamber_scale", 0.80)))
	var turrets: Dictionary = GameSceneBuilder.create_turrets(owner, game_layer, battlefield, bullet_pool, layout)
	var chambers: Dictionary = GameSceneBuilder.create_control_chambers(owner, game_layer, battlefield, turrets, layout, chamber_scale, DEFAULT_VIEWPORT)
	var button_nodes: Dictionary = GameHudView.create_control_buttons(owner, game_layer, chambers, layout, DEFAULT_VIEWPORT, is_mobile)

	var hud = GameHUDScene.instantiate()
	get_root().add_child(hud)
	await process_frame
	hud.setup_static(owner, DEFAULT_VIEWPORT, layout, is_mobile)
	await process_frame

	var roulette = load("res://scripts/EventRouletteView.gd").new()
	get_root().add_child(roulette)
	roulette.setup(DEFAULT_VIEWPORT, layout, is_mobile)
	await process_frame

	_assert_vec2_close(battlefield.position, layout["battlefield_rect"].position, "%s: battlefield uses layout rect" % label)
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		_assert_vec2_close(turrets[faction_id].global_position, layout["turret_positions"][faction_id], "%s: turret %d uses layout" % [label, faction_id])
		_assert_vec2_close(chambers[faction_id].global_position, layout["chamber_positions"][faction_id], "%s: chamber %d uses layout" % [label, faction_id])
		_assert_vec2_close(button_nodes["add_ball_buttons"][faction_id].position, layout["add_ball_button_positions"][faction_id], "%s: add-ball %d uses layout" % [label, faction_id])

	var hud_positions: Dictionary = layout["hud_positions"]
	_assert_vec2_close(hud.top_panel.position, hud_positions["top_panel_rect"].position, "%s: top panel uses layout" % label)
	_assert_vec2_close(hud.settings_button.position, layout["side_button_positions"]["settings"], "%s: settings button uses layout" % label)
	_assert_vec2_close(hud.pause_button.position, layout["side_button_positions"]["pause"], "%s: pause button uses layout" % label)
	_assert_vec2_close(hud.exit_button.position, layout["side_button_positions"]["exit"], "%s: exit button uses layout" % label)
	_assert_vec2_close(hud.fps_label.position, hud_positions["fps_label_rect"].position, "%s: fps label uses layout" % label)
	_assert_vec2_close(hud.event_label.position, hud_positions["event_label_rect"].position, "%s: event label uses layout" % label)
	_assert_vec2_close(hud.winner_label.position, hud_positions["winner_label_rect"].position, "%s: winner label uses layout" % label)

	var roulette_stage_rect: Rect2 = layout["roulette_stage_rect"]
	_assert_vec2_close(roulette.stage_panel.position, Vector2(roulette_stage_rect.position.x, roulette._stage_hidden_y), "%s: roulette stage x uses layout" % label)
	_assert_vec2_close(roulette.stage_panel.size, roulette_stage_rect.size, "%s: roulette size uses layout" % label)
	_assert.that(abs(roulette._stage_shown_y - roulette_stage_rect.position.y) < 0.01, "%s: roulette shown y uses layout" % label)

	if roulette.get_parent() != null:
		roulette.queue_free()
	if hud.get_parent() != null:
		hud.queue_free()
	if game_layer.get_parent() != null:
		game_layer.queue_free()
	await process_frame

func _assert_vec2_close(actual: Vector2, expected: Vector2, label: String) -> void:
	_assert.that(actual.distance_to(expected) < 0.01, "%s | actual=%s expected=%s" % [label, actual, expected])

func _rect_inside_viewport(r: Rect2, vp: Vector2) -> bool:
	var inside := r.position.x >= -1.0 and r.position.y >= -1.0
	inside = inside and r.position.x + r.size.x <= vp.x + 1.0
	inside = inside and r.position.y + r.size.y <= vp.y + 1.0
	return inside

func _point_inside_viewport(p: Vector2, vp: Vector2) -> bool:
	return p.x >= -1.0 and p.y >= -1.0 and p.x <= vp.x + 1.0 and p.y <= vp.y + 1.0
