extends SceneTree

var _assert: TestAssert

const DEFAULT_VIEWPORT: Vector2 = Vector2(1120, 720)
const GRID_SIZES := [10, 20, 30, 40, 50, 60]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert = TestAssert.new()
	print("[LayoutSanity] v2.0.6 — layout boundary tests (default viewport)")
	await process_frame

	for grid_size in GRID_SIZES:
		_test_viewport_bounds(grid_size, DEFAULT_VIEWPORT, false)
		_test_viewport_bounds(grid_size, DEFAULT_VIEWPORT, true)

	_test_bottom_hud_group()
	_test_roulette_centered()
	_test_event_perf_no_overlap()
	_test_button_not_under_chamber()

	_assert.report("[LayoutSanity]")

	if _assert.failures.is_empty():
		quit(0)
	else:
		quit(1)

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

		var bpos: Vector2 = layout["add_ball_positions"][faction_id]
		var bsize: Vector2 = layout.get("side_button_size", Vector2(96, 42))
		_assert.that(_rect_inside_viewport(Rect2(bpos, bsize), viewport), "%s: +球 %d inside" % [label, faction_id])

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
	for grid_size in [10, 20, 30, 40, 50, 60]:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var hud: Dictionary = layout["hud_positions"]
		var bottom_rect: Rect2 = hud["bottom_hud_rect"]
		_assert.that(bottom_rect.position.x >= 4.0, "hud group x >= 4 @ %d" % grid_size)
		_assert.that(bottom_rect.position.x + bottom_rect.size.x <= DEFAULT_VIEWPORT.x - 4.0, "hud group right in bounds @ %d" % grid_size)

func _test_roulette_centered() -> void:
	for grid_size in [10, 20, 30, 40, 50, 60]:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var stage: Rect2 = layout["roulette_stage_rect"]
		_assert.that(_rect_inside_viewport(stage, DEFAULT_VIEWPORT), "roulette %d inside" % grid_size)
		var cx: float = DEFAULT_VIEWPORT.x * 0.5
		_assert.that(abs(stage.position.x + stage.size.x * 0.5 - cx) < 1.0, "roulette %d centered" % grid_size)

func _test_event_perf_no_overlap() -> void:
	for grid_size in [10, 20, 30, 40, 50, 60]:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		var hud: Dictionary = layout["hud_positions"]
		var fps_rect: Rect2 = hud["fps_label_rect"]
		var event_rect: Rect2 = hud["event_label_rect"]
		_assert.that(not fps_rect.intersects(event_rect), "fps/event no overlap %d" % grid_size)

func _test_button_not_under_chamber() -> void:
	for grid_size in [10, 20, 30, 40, 50, 60]:
		var layout: Dictionary = LayoutCoordinator.calculate_layout(grid_size, DEFAULT_VIEWPORT, false)
		for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.GREEN]:
			var cpos: Vector2 = layout["chamber_positions"][faction_id]
			var csize: Vector2 = layout["chamber_size"]
			var bpos: Vector2 = layout["add_ball_positions"][faction_id]
			_assert.that(bpos.x + 50.0 < cpos.x or bpos.x > cpos.x + csize.x, "btn %d not under chamber %d" % [faction_id, grid_size])

func _rect_inside_viewport(r: Rect2, vp: Vector2) -> bool:
	var inside := r.position.x >= -1.0 and r.position.y >= -1.0
	inside = inside and r.position.x + r.size.x <= vp.x + 1.0
	inside = inside and r.position.y + r.size.y <= vp.y + 1.0
	return inside

func _point_inside_viewport(p: Vector2, vp: Vector2) -> bool:
	return p.x >= -1.0 and p.y >= -1.0 and p.x <= vp.x + 1.0 and p.y <= vp.y + 1.0
