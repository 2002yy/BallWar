extends SceneTree

const SaveGameCodec = preload("res://scripts/SaveGameCodec.gd")
const EventRouletteController = preload("res://scripts/EventRouletteController.gd")
const Battlefield = preload("res://scripts/Battlefield.gd")
const GameConfig = preload("res://scripts/GameConfig.gd")
const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const Fixtures = preload("res://scripts/tests/TestFixtures.gd")

var _assert: TestAssert

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert = TestAssert.new()
	print("[IntegrationTest] v2.0.3 — save / battlefield / win-condition coverage")
	await process_frame

	_test_save_load_roundtrip()
	await _flush()
	_test_battlefield_rules()
	await _flush()
	_test_win_conditions()
	await _flush()

	_assert.report("[IntegrationTest]")

	if _assert.failures.is_empty():
		quit(0)
	else:
		quit(1)

func _flush() -> void:
	await process_frame
	await process_frame

# ======================================================================
# P1 — save / load round-trip
# ======================================================================

func _test_save_load_roundtrip() -> void:
	print("  [P1] save/load round-trip")

	_test_save_payload_mutation()
	_test_save_codec_full_validation()
	_test_save_schema_version()
	_test_save_game_mode_persistence()
	_test_save_battlefield_owners_roundtrip()
	_test_save_faction_state_roundtrip()
	_test_save_event_state_roundtrip()

func _test_save_payload_mutation() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)
	GameConfig.set_quality_by_name("高")
	GameConfig.set_time_limit_minutes(10)

	var bf := Battlefield.new()
	bf.configure(40)
	get_root().add_child(bf)
	bf.reset_quadrants()

	bf.apply_bullet(Vector2i(5, 5), GameConfig.Faction.RED)
	bf.apply_bullet(Vector2i(6, 5), GameConfig.Faction.RED)
	bf.apply_bullet(Vector2i(7, 5), GameConfig.Faction.RED)

	_assert.eq(bf.owners[5][5], GameConfig.Faction.RED, "save payload: ownership mutation should persist")
	_assert.eq(bf.owners[4][4], GameConfig.Faction.BLUE, "save payload: untouched cell should keep original faction")
	Fixtures.cleanup_node(bf)

func _test_save_codec_full_validation() -> void:
	var raw: Dictionary = Fixtures.build_realistic_save_payload()
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)

	_assert.eq(clean.get("grid_size", 0), 10, "save codec: should preserve valid grid_size")
	_assert.eq(str(clean.get("game_mode_name", "")), GameConfig.GAME_MODE_BASIC, "save codec: should preserve valid game mode")
	_assert.eq(int(clean.get("time_limit_minutes", 0)), 5, "save codec: should preserve valid time limit")
	_assert.that(clean.has("owners"), "save codec: should preserve owners array when valid")
	_assert.that(clean.get("bullets", null) is Array, "save codec: bullets should be array")
	_assert.that(clean.has("event_state"), "save codec: should preserve event_state")

	var ev: Dictionary = clean.get("event_state", {})
	_assert.eq(float(ev.get("next_event_time_left", 0.0)), 30.5, "save codec: should preserve event countdown")
	_assert.eq(int(ev.get("last_event_faction", -1)), GameConfig.Faction.GREEN, "save codec: should preserve last event faction")
	_assert.eq(str(ev.get("last_event_effect", "")), EventRouletteController.EFFECT_X2, "save codec: should preserve last event effect")

	var factions: Array = clean.get("factions", [])
	_assert.eq(factions.size(), 4, "save codec: should keep all 4 factions")
	var blue: Dictionary = factions[GameConfig.Faction.BLUE]
	_assert.eq(int(blue.get("chamber_pending_count", 0)), 8, "save codec: should preserve chamber pending count")
	_assert.eq(int(blue.get("turret_health", 0)), GameConfig.TURRET_MAX_HEALTH, "save codec: should preserve turret health")
	_assert.that(blue.get("queued_round_modifiers", null) is Array, "save codec: queued_round_modifiers should be array")

	var invalid_raw: Dictionary = Fixtures.build_invalid_save_payload()
	var invalid_clean: Dictionary = SaveGameCodec.validate_save_data(invalid_raw)
	_assert.eq(str(invalid_clean.get("game_mode_name", "")), GameConfig.GAME_MODE_BASIC, "save codec: should normalize invalid game mode")
	_assert.gte(int(invalid_clean.get("time_limit_minutes", 0)), GameConfig.TIMED_MODE_MIN_MINUTES, "save codec: should clamp time_limit_minutes into range")

func _test_save_schema_version() -> void:
	var v1 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("1.9.34"))
	_assert.that(not v1.has("_invalid_reason"), "save schema: 1.9.34 should pass")

	var v2 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("2.0.0"))
	_assert.that(v2.has("_invalid_reason"), "save schema: 2.0.0 should be rejected (guard: 1.9 prefix)")

	var v3 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload(""))
	_assert.that(v3.has("_invalid_reason"), "save schema: empty version should be rejected")

	var v4 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("1.9.0"))
	_assert.that(not v4.has("_invalid_reason"), "save schema: 1.9.0 should pass (prefix match)")

func _test_save_game_mode_persistence() -> void:
	var mode_list: Array = GameConfig.get_game_mode_names()
	_assert.gte(mode_list.size(), 4, "game mode: should have at least 4 modes")

	var expected_modes := [GameConfig.GAME_MODE_BASIC, GameConfig.GAME_MODE_OCCUPATION, GameConfig.GAME_MODE_TIMED, GameConfig.GAME_MODE_WILD]
	for m in expected_modes:
		_assert.that(m in mode_list, "game mode: %s should be listed" % m)
		GameConfig.set_game_mode_by_name(m)
		_assert.eq(GameConfig.get_game_mode_name(), m, "game mode: set/get roundtrip for %s" % m)

	_eval_gate_and_limit()

func _eval_gate_and_limit() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	_assert.eq(GameConfig.get_gate_multiplier(), 2, "gate multiplier: basic mode should be x2")
	_assert.eq(GameConfig.get_max_pending_count(), GameConfig.BASE_MAX_PENDING_COUNT, "max pending: basic mode")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_WILD)
	_assert.eq(GameConfig.get_gate_multiplier(), 3, "gate multiplier: wild mode should be x3")
	_assert.eq(GameConfig.get_max_pending_count(), GameConfig.WILD_MAX_PENDING_COUNT, "max pending: wild mode")
	_assert.gt(GameConfig.get_max_pending_count(), GameConfig.BASE_MAX_PENDING_COUNT, "max pending: wild should exceed basic")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

func _test_save_battlefield_owners_roundtrip() -> void:
	var bf := Battlefield.new()
	bf.configure(20)
	get_root().add_child(bf)
	bf.reset_quadrants()

	var half: int = 10
	_assert.eq(bf.owners[0][0], GameConfig.Faction.BLUE, "battlefield init: top-left BLUE")
	_assert.eq(bf.owners[half][0], GameConfig.Faction.RED, "battlefield init: top-right RED")
	_assert.eq(bf.owners[0][half], GameConfig.Faction.GREEN, "battlefield init: bottom-left GREEN")
	_assert.eq(bf.owners[half][half], GameConfig.Faction.YELLOW, "battlefield init: bottom-right YELLOW")

	var counts: Dictionary = bf.count_cells_by_team()
	var expected: int = 100
	_assert.eq(int(counts.get(GameConfig.Faction.BLUE, 0)), expected, "battlefield init: BLUE 1/4 share")
	_assert.eq(int(counts.get(GameConfig.Faction.RED, 0)), expected, "battlefield init: RED 1/4 share")
	_assert.eq(int(counts.get(GameConfig.Faction.GREEN, 0)), expected, "battlefield init: GREEN 1/4 share")
	_assert.eq(int(counts.get(GameConfig.Faction.YELLOW, 0)), expected, "battlefield init: YELLOW 1/4 share")

	Fixtures.cleanup_node(bf)

func _test_save_faction_state_roundtrip() -> void:
	var raw: Dictionary = Fixtures.build_realistic_save_payload()
	raw["factions"] = [
		{"faction_id": GameConfig.Faction.BLUE,   "chamber_pending_count": 1, "chamber_locked_remaining": 0, "chamber_is_locked": false, "chamber_is_damaged": false, "chamber_ball_count": 1, "chamber_release_ball_index": -1, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [], "control_balls": [], "turret_health": GameConfig.TURRET_MAX_HEALTH, "turret_destroyed": false, "turret_sweep_phase": 0.0, "turret_rotation": 0.0, "turret_burst_remaining": 0, "turret_burst_total": 0, "turret_burst_index": 0, "turret_burst_timer": 0.0, "turret_burst_locked": false},
		{"faction_id": GameConfig.Faction.RED,    "chamber_pending_count": 7, "chamber_locked_remaining": 0, "chamber_is_locked": false, "chamber_is_damaged": false, "chamber_ball_count": 4, "chamber_release_ball_index": -1, "chamber_jammed_time_left": 2.5, "queued_round_modifiers": [{"type": "add_ball"}, {"type": "x2", "multiplier": 2}], "control_balls": [], "turret_health": 12, "turret_destroyed": false, "turret_sweep_phase": 0.0, "turret_rotation": 0.0, "turret_burst_remaining": 0, "turret_burst_total": 0, "turret_burst_index": 0, "turret_burst_timer": 0.0, "turret_burst_locked": false},
		{"faction_id": GameConfig.Faction.GREEN,  "chamber_pending_count": 1, "chamber_locked_remaining": 0, "chamber_is_locked": false, "chamber_is_damaged": true,  "chamber_ball_count": 0, "chamber_release_ball_index": -1, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [], "control_balls": [], "turret_health": 0, "turret_destroyed": true,  "turret_sweep_phase": 0.0, "turret_rotation": 0.0, "turret_burst_remaining": 0, "turret_burst_total": 0, "turret_burst_index": 0, "turret_burst_timer": 0.0, "turret_burst_locked": false},
		{"faction_id": GameConfig.Faction.YELLOW, "chamber_pending_count": 100, "chamber_locked_remaining": 50, "chamber_is_locked": true, "chamber_is_damaged": false, "chamber_ball_count": 6, "chamber_release_ball_index": 0, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [{"type": "bonus_10", "amount": 10}, {"type": "x3", "multiplier": 3}], "control_balls": [], "turret_health": 8, "turret_destroyed": false, "turret_sweep_phase": 0.5, "turret_rotation": 1.2, "turret_burst_remaining": 50, "turret_burst_total": 100, "turret_burst_index": 50, "turret_burst_timer": 0.3, "turret_burst_locked": true},
	]
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)
	var factions: Array = clean.get("factions", [])
	_assert.eq(factions.size(), 4, "faction roundtrip: 4 factions kept")

	var y: Dictionary = factions[GameConfig.Faction.YELLOW]
	_assert.eq(int(y.get("chamber_pending_count", 0)), 100, "faction roundtrip: YELLOW pending")
	_assert.eq(int(y.get("chamber_locked_remaining", 0)), 50, "faction roundtrip: YELLOW locked remaining")
	_assert.that(bool(y.get("chamber_is_locked", false)), "faction roundtrip: YELLOW locked")
	_assert.eq(int(y.get("chamber_ball_count", 0)), 6, "faction roundtrip: YELLOW ball count")
	_assert.eq(y.get("queued_round_modifiers", []).size(), 2, "faction roundtrip: YELLOW 2 queued modifiers")
	_assert.eq(int(y.get("turret_health", 0)), 8, "faction roundtrip: YELLOW turret health")
	_assert.eq(int(y.get("turret_burst_remaining", 0)), 50, "faction roundtrip: YELLOW burst remaining")

	var r: Dictionary = factions[GameConfig.Faction.RED]
	_assert.eq(float(r.get("chamber_jammed_time_left", -1.0)), 2.5, "faction roundtrip: RED jammed time")
	_assert.eq(int(r.get("turret_health", 0)), 12, "faction roundtrip: RED partial damage")

func _test_save_event_state_roundtrip() -> void:
	var controller: EventRouletteController = EventRouletteController.new()
	var dummy_main := Node.new()
	var dummy_bf := Node.new()
	controller.main_ref = dummy_main
	controller.battlefield = dummy_bf
	var empty_map := {GameConfig.Faction.BLUE: null, GameConfig.Faction.RED: null, GameConfig.Faction.GREEN: null, GameConfig.Faction.YELLOW: null}
	controller.chambers = empty_map.duplicate()
	controller.turrets = empty_map.duplicate()
	controller.event_label = null
	controller.view_ref = null

	var saved: Dictionary = {
		"event_roulette_enabled": true,
		"next_event_time_left": 45.8,
		"current_event_interval": 30.0,
		"last_event_faction": GameConfig.Faction.YELLOW,
		"last_event_effect": EventRouletteController.EFFECT_JAM,
		"reroll_count": 2,
	}
	controller.import_save_state(saved)
	var exported: Dictionary = controller.export_save_state()

	_assert.eq(float(exported.get("next_event_time_left", 0.0)), 45.8, "event state: countdown roundtrip")
	_assert.eq(int(exported.get("last_event_faction", -1)), GameConfig.Faction.YELLOW, "event state: last faction roundtrip")
	_assert.eq(str(exported.get("last_event_effect", "")), EventRouletteController.EFFECT_JAM, "event state: last effect roundtrip")
	_assert.eq(int(exported.get("reroll_count", -1)), 2, "event state: reroll count roundtrip")
	_assert.that(bool(exported.get("event_roulette_enabled", false)), "event state: enabled flag")
	_assert.eq(float(exported.get("current_event_interval", 0.0)), 30.0, "event state: interval roundtrip")

	controller.battlefield = null
	controller.main_ref = null
	Fixtures.cleanup_node(controller)
	Fixtures.cleanup_node(dummy_main)
	Fixtures.cleanup_node(dummy_bf)

# ======================================================================
# P2 — battlefield rules
# ======================================================================

func _test_battlefield_rules() -> void:
	print("  [P2] battlefield rules")

	_test_bf_initial_territory()
	_test_bf_same_faction_noop()
	_test_bf_enemy_capture()
	_test_bf_owner_counts_sync()
	_test_bf_world_to_cell()
	_test_bf_rebuild_owner_counts()

func _make_bf(grid: int) -> Battlefield:
	var bf := Battlefield.new()
	bf.configure(grid)
	get_root().add_child(bf)
	bf.reset_quadrants()
	return bf

func _test_bf_initial_territory() -> void:
	var bf := _make_bf(40)
	var h: int = 20
	_assert.eq(bf.owners[0][0], GameConfig.Faction.BLUE, "bf: 40x40 top-left BLUE")
	_assert.eq(bf.owners[h][0], GameConfig.Faction.RED, "bf: 40x40 top-right RED")
	_assert.eq(bf.owners[0][h], GameConfig.Faction.GREEN, "bf: 40x40 bottom-left GREEN")
	_assert.eq(bf.owners[h][h], GameConfig.Faction.YELLOW, "bf: 40x40 bottom-right YELLOW")

	var counts := bf.count_cells_by_team()
	var total: int = 0
	for fid in counts:
		total += int(counts[fid])
	_assert.eq(total, 1600, "bf: 40x40 total 1600 cells")
	_assert.eq(int(counts.get(GameConfig.Faction.BLUE, 0)), 400, "bf: each faction 400 cells")

	Fixtures.cleanup_node(bf)

func _test_bf_same_faction_noop() -> void:
	var bf := _make_bf(20)
	var before := bf.count_cells_by_team().duplicate()
	var result := bf.apply_bullet(Vector2i(0, 0), GameConfig.Faction.BLUE)
	_assert.eq(result, "SAME_CELL", "bf: same-faction returns SAME_CELL")
	var after := bf.count_cells_by_team()
	_assert.eq(int(after.get(GameConfig.Faction.BLUE, 0)), int(before.get(GameConfig.Faction.BLUE, 0)), "bf: same-faction no-op BLUE")
	_assert.eq(int(after.get(GameConfig.Faction.RED, 0)), int(before.get(GameConfig.Faction.RED, 0)), "bf: same-faction no-op RED")

	Fixtures.cleanup_node(bf)

func _test_bf_enemy_capture() -> void:
	var bf := _make_bf(20)
	var cell := Vector2i(10, 0)
	_assert.eq(bf.owners[cell.x][cell.y], GameConfig.Faction.RED, "bf: target starts RED")

	var before := bf.count_cells_by_team().duplicate()
	_assert.eq(bf.apply_bullet(cell, GameConfig.Faction.BLUE), "HIT_ENEMY_CELL", "bf: cross-faction returns HIT_ENEMY_CELL")
	_assert.eq(bf.owners[cell.x][cell.y], GameConfig.Faction.BLUE, "bf: cell now BLUE")

	var after := bf.count_cells_by_team()
	_assert.eq(int(after.get(GameConfig.Faction.BLUE, 0)), int(before.get(GameConfig.Faction.BLUE, 0)) + 1, "bf: BLUE +1")
	_assert.eq(int(after.get(GameConfig.Faction.RED, 0)), int(before.get(GameConfig.Faction.RED, 0)) - 1, "bf: RED -1")

	_assert.eq(bf.apply_bullet(Vector2i(999, 999), GameConfig.Faction.BLUE), "OUTSIDE", "bf: outside returns OUTSIDE")
	_assert.eq(int(bf.count_cells_by_team().get(GameConfig.Faction.BLUE, 0)), int(after.get(GameConfig.Faction.BLUE, 0)), "bf: outside bullet no effect")

	Fixtures.cleanup_node(bf)

func _test_bf_owner_counts_sync() -> void:
	var bf := _make_bf(20)
	var manual := _manual_scan(bf, 20)
	var counts := bf.count_cells_by_team()
	for fid in counts:
		_assert.eq(int(counts[fid]), int(manual.get(fid, 0)), "bf sync: pre-mutation faction %d" % fid)

	bf.apply_bullet(Vector2i(0, 0), GameConfig.Faction.RED)
	bf.apply_bullet(Vector2i(1, 1), GameConfig.Faction.GREEN)
	bf.apply_bullet(Vector2i(2, 2), GameConfig.Faction.YELLOW)

	var manual2 := _manual_scan(bf, 20)
	var counts2 := bf.count_cells_by_team()
	for fid in counts2:
		_assert.eq(int(counts2[fid]), int(manual2.get(fid, 0)), "bf sync: post-mutation faction %d" % fid)

	Fixtures.cleanup_node(bf)

func _test_bf_world_to_cell() -> void:
	var bf := Battlefield.new()
	bf.configure(40)
	bf.cell_size = 13
	get_root().add_child(bf)
	bf.position = Vector2(100, 100)

	var cell := bf.world_to_cell(Vector2(126, 126))
	_assert.eq(cell, Vector2i(2, 2), "bf: world_to_cell at (126,126) -> (2,2)")
	_assert.that(bf.is_inside(cell), "bf: (2,2) inside 40x40")
	_assert.that(not bf.is_inside(Vector2i(-1, 0)), "bf: (-1,0) outside")
	_assert.that(not bf.is_inside(Vector2i(40, 0)), "bf: (40,0) outside (max 39)")

	Fixtures.cleanup_node(bf)

func _test_bf_rebuild_owner_counts() -> void:
	var bf := _make_bf(20)
	bf.owners[0][0] = GameConfig.Faction.YELLOW
	bf.rebuild_owner_counts()

	var manual := _manual_scan(bf, 20)
	var counts := bf.count_cells_by_team()
	for fid in counts:
		_assert.eq(int(counts[fid]), int(manual.get(fid, 0)), "bf rebuild: faction %d" % fid)

	Fixtures.cleanup_node(bf)

func _manual_scan(bf: Battlefield, grid: int) -> Dictionary:
	var d: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for x in range(grid):
		for y in range(grid):
			d[bf.owners[x][y]] += 1
	return d

# ======================================================================
# P3 — win conditions (zero global GameConfig dependency, fully explicit)
# ======================================================================

func _test_win_conditions() -> void:
	print("  [P3] win conditions")

	_test_basic_win_last_turret()
	_test_basic_win_all_destroyed_draw()
	_test_basic_win_multiple_alive_no_result()
	_test_occupation_win_threshold()
	_test_occupation_no_win_below()
	_test_timed_win_leader()
	_test_timed_draw()
	_test_wild_mode()
	_test_save_version_compatibility()

func _test_basic_win_last_turret() -> void:
	var turrets := Fixtures.make_mock_turrets({
		GameConfig.Faction.BLUE: true,
		GameConfig.Faction.RED: true,
		GameConfig.Faction.YELLOW: true,
	})

	var result := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_BASIC, null, turrets)
	_assert.eq(result, GameConfig.Faction.GREEN, "win basic: last turret GREEN wins")

func _test_basic_win_all_destroyed_draw() -> void:
	var turrets := Fixtures.make_mock_turrets({
		GameConfig.Faction.BLUE: true,
		GameConfig.Faction.RED: true,
		GameConfig.Faction.GREEN: true,
		GameConfig.Faction.YELLOW: true,
	})

	var result := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_BASIC, null, turrets)
	_assert.eq(result, -2, "win basic: all destroyed draw (-2)")

func _test_basic_win_multiple_alive_no_result() -> void:
	var turrets := Fixtures.make_mock_turrets({})
	var result := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_BASIC, null, turrets)
	_assert.eq(result, -1, "win basic: multiple alive should return -1 (no winner yet)")

func _test_occupation_win_threshold() -> void:
	var bf := Battlefield.new()
	bf.configure(20)
	get_root().add_child(bf)
	bf.reset_quadrants()

	var total := 400
	var target := int(ceil(float(total) * 0.75))

	Fixtures.fill_battlefield(bf, GameConfig.Faction.RED)
	Fixtures.paint_first_cells(bf, GameConfig.Faction.BLUE, target)

	var counts := bf.count_cells_by_team()
	_assert.gte(int(counts.get(GameConfig.Faction.BLUE, 0)), target, "win occupation: BLUE cells >= 75%%")

	var turrets := Fixtures.make_mock_turrets({})
	var winner := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_OCCUPATION, bf, turrets)
	_assert.eq(winner, GameConfig.Faction.BLUE, "win occupation: BLUE at 75% wins")

	Fixtures.cleanup_node(bf)

func _test_occupation_no_win_below() -> void:
	var bf := Battlefield.new()
	bf.configure(20)
	get_root().add_child(bf)
	bf.reset_quadrants()

	var total := 400
	var below_target := int(float(total) * 0.74)

	Fixtures.fill_battlefield(bf, GameConfig.Faction.RED)
	Fixtures.paint_first_cells(bf, GameConfig.Faction.BLUE, below_target)

	var turrets := Fixtures.make_mock_turrets({})
	var winner := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_OCCUPATION, bf, turrets)
	_assert.eq(winner, -1, "win occupation: BLUE at 74%% should not trigger win (expect -1, got %d)" % winner)

	Fixtures.cleanup_node(bf)

func _test_timed_win_leader() -> void:
	var bf := Battlefield.new()
	bf.configure(20)
	get_root().add_child(bf)
	bf.reset_quadrants()

	Fixtures.fill_battlefield(bf, GameConfig.Faction.RED)
	Fixtures.paint_first_cells(bf, GameConfig.Faction.YELLOW, 201)

	var counts := bf.count_cells_by_team()
	_assert.gt(int(counts.get(GameConfig.Faction.YELLOW, 0)), int(counts.get(GameConfig.Faction.RED, 0)), "win timed: YELLOW leads RED")

	var turrets := Fixtures.make_mock_turrets({})
	var winner := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_TIMED, bf, turrets)
	_assert.eq(winner, GameConfig.Faction.YELLOW, "win timed: YELLOW leader wins (got %d)" % winner)

	Fixtures.cleanup_node(bf)

func _test_timed_draw() -> void:
	var bf := Battlefield.new()
	bf.configure(20)
	get_root().add_child(bf)
	bf.reset_quadrants()

	Fixtures.fill_battlefield(bf, GameConfig.Faction.RED)
	Fixtures.paint_first_cells(bf, GameConfig.Faction.BLUE, 200)

	var counts := bf.count_cells_by_team()
	_assert.eq(int(counts.get(GameConfig.Faction.BLUE, 0)), 200, "win timed draw: BLUE should have 200 cells")
	_assert.gte(int(counts.get(GameConfig.Faction.RED, 0)), 200, "win timed draw: RED should have >= 200 cells")

	var turrets := Fixtures.make_mock_turrets({})
	var winner := Fixtures.simulate_check_winner(GameConfig.GAME_MODE_TIMED, bf, turrets)
	_assert.eq(winner, -1, "win timed: equal score should be draw (-1)")

	Fixtures.cleanup_node(bf)

func _test_wild_mode() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_WILD)
	_assert.eq(GameConfig.get_gate_multiplier(), 3, "win wild: gate x3")
	_assert.eq(GameConfig.get_max_pending_count(), GameConfig.WILD_MAX_PENDING_COUNT, "win wild: max pending WILD_MAX")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	_assert.eq(GameConfig.get_gate_multiplier(), 2, "win wild reset: basic gate x2")

func _test_save_version_compatibility() -> void:
	var cv := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("1.9.34"))
	_assert.that(not cv.has("_invalid_reason"), "save compat: 1.9.34 passes")

	var cv2 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("2.0.0"))
	_assert.that(cv2.has("_invalid_reason"), "save compat: 2.0.0 REJECTED (1.9 prefix guard)")
