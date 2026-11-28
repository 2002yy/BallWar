extends SceneTree

const Fixtures = preload("res://scripts/tests/TestFixtures.gd")

var _assert: TestAssert

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_assert = TestAssert.new()
	print("[IntegrationTest] v2.0.4 — save / battlefield / win-condition / evaluator / match-config coverage")
	await process_frame

	_test_save_load_roundtrip()
	await _flush()
	_test_battlefield_rules()
	await _flush()
	_test_win_conditions()
	await _flush()
	_test_match_config_and_volley()
	await _flush()
	_test_bullet_attributes_and_reset()
	await _flush()
	_test_special_bullet_profiles()
	await _flush()
	_test_fire_ledger()
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
	_assert.that(not v2.has("_invalid_reason"), "save schema: 2.0.0 should pass")

	var v3 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload(""))
	_assert.that(v3.has("_invalid_reason"), "save schema: empty version should be rejected")

	var v4 := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload("1.9.0"))
	_assert.that(not v4.has("_invalid_reason"), "save schema: 1.9.0 should remain compatible")

	for valid_version in ["1.9", "2.0", "1.9.99", "2.0.123", "2.0.1.2"]:
		var valid_data := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload(valid_version))
		_assert.that(not valid_data.has("_invalid_reason"), "save schema: accepted numeric legacy version %s" % valid_version)

	for invalid_version in ["1.90.0", "2.01.0", "2.0broken", "1.9.2beta", "2.0.", "2.0..1", "2.0.-1", "2.0.+1", "2.0.1 ", "2.0.alpha"]:
		var invalid_data := SaveGameCodec.validate_save_data(Fixtures.build_minimal_save_payload(invalid_version))
		_assert.that(invalid_data.has("_invalid_reason"), "save schema: reject malformed or lookalike version %s" % invalid_version)

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

	_test_wce_api_basic()
	_test_wce_api_occupation()
	_test_wce_api_timed()
	_test_wce_api_wild()
	_test_wce_evaluate_dispatcher()
	_test_basic_win_last_turret()
	_test_basic_win_all_destroyed_draw()
	_test_basic_win_multiple_alive_no_result()
	_test_occupation_win_threshold()
	_test_occupation_no_win_below()
	_test_timed_win_leader()
	_test_timed_draw()
	_test_wild_mode()
	_test_save_version_compatibility()

func _test_wce_api_basic() -> void:
	var turrets := {}
	var mock_green := Turret.new()
	mock_green.is_destroyed = false
	turrets[GameConfig.Faction.GREEN] = mock_green
	for fid in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.YELLOW]:
		var m := Turret.new()
		m.is_destroyed = true
		turrets[fid] = m

	var r: Dictionary = WinConditionEvaluator.evaluate_basic(turrets)
	_assert.eq(r.ended, true, "WCE basic: single alive ends game")
	_assert.eq(r.winner, GameConfig.Faction.GREEN, "WCE basic: GREEN wins")
	_assert.eq(r.draw, false, "WCE basic: not draw")
	_assert.eq(r.sub_text, "终局", "WCE basic: sub_text 终局")
	_assert.eq(r.reason, "basic", "WCE basic: reason basic")

	mock_green.is_destroyed = true
	var r2: Dictionary = WinConditionEvaluator.evaluate_basic(turrets)
	_assert.eq(r2.ended, true, "WCE basic: all destroyed ends game")
	_assert.eq(r2.draw, true, "WCE basic: all destroyed = draw")
	_assert.eq(r2.reason, "basic", "WCE basic draw: reason basic")

	for m in turrets.values():
		Fixtures.cleanup_node(m if m is Node else null)

func _test_wce_api_occupation() -> void:
	var counts := {GameConfig.Faction.BLUE: 300, GameConfig.Faction.RED: 50, GameConfig.Faction.GREEN: 25, GameConfig.Faction.YELLOW: 25}
	var r: Dictionary = WinConditionEvaluator.evaluate_occupation(counts, 400, 75)
	_assert.eq(r.ended, true, "WCE occ: 300/400=75%% ends")
	_assert.eq(r.winner, GameConfig.Faction.BLUE, "WCE occ: BLUE wins at 75%%")
	_assert.eq(r.reason, "occupation", "WCE occ: reason occupation")

	var counts2 := {GameConfig.Faction.BLUE: 280, GameConfig.Faction.RED: 120, GameConfig.Faction.GREEN: 0, GameConfig.Faction.YELLOW: 0}
	var r2: Dictionary = WinConditionEvaluator.evaluate_occupation(counts2, 400, 75)
	_assert.eq(r2.ended, false, "WCE occ: 70%% does not end")

	var tie := {GameConfig.Faction.BLUE: 200, GameConfig.Faction.RED: 200, GameConfig.Faction.GREEN: 0, GameConfig.Faction.YELLOW: 0}
	var r3: Dictionary = WinConditionEvaluator.evaluate_occupation(tie, 400, 75)
	_assert.eq(r3.ended, false, "WCE occ: tied leader no win")

func _test_wce_api_timed() -> void:
	var counts := {GameConfig.Faction.BLUE: 10, GameConfig.Faction.RED: 50, GameConfig.Faction.GREEN: 20, GameConfig.Faction.YELLOW: 20}
	var r: Dictionary = WinConditionEvaluator.evaluate_timed(counts, true)
	_assert.eq(r.ended, true, "WCE timed: expired=true ends")
	_assert.eq(r.winner, GameConfig.Faction.RED, "WCE timed: RED leader wins")
	_assert.eq(r.reason, "timed", "WCE timed: reason timed")

	var r2: Dictionary = WinConditionEvaluator.evaluate_timed(counts, false)
	_assert.eq(r2.ended, false, "WCE timed: expired=false no result")

	var tie := {GameConfig.Faction.BLUE: 50, GameConfig.Faction.RED: 50, GameConfig.Faction.GREEN: 0, GameConfig.Faction.YELLOW: 0}
	var r3: Dictionary = WinConditionEvaluator.evaluate_timed(tie, true)
	_assert.eq(r3.ended, true, "WCE timed: tie expired ends")
	_assert.eq(r3.draw, true, "WCE timed: tie = draw")

func _test_wce_api_wild() -> void:
	var turrets := {}
	for fid in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var m := Turret.new()
		m.is_destroyed = true
		turrets[fid] = m

	var r: Dictionary = WinConditionEvaluator.evaluate(GameConfig.GAME_MODE_WILD, turrets, {}, 0, false)
	_assert.eq(r.ended, true, "WCE wild: evaluates as basic, all dead = draw")
	_assert.eq(r.draw, true, "WCE wild: draw")
	_assert.eq(r.reason, "basic", "WCE wild: reason basic (delegates to basic)")

	for m in turrets.values():
		Fixtures.cleanup_node(m)

	var t2 := {}
	var alive := Turret.new()
	alive.is_destroyed = false
	t2[GameConfig.Faction.YELLOW] = alive
	for fid in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN]:
		var m := Turret.new()
		m.is_destroyed = true
		t2[fid] = m

	var r2: Dictionary = WinConditionEvaluator.evaluate(GameConfig.GAME_MODE_WILD, t2, {}, 0, false)
	_assert.eq(r2.ended, true, "WCE wild: last turret YELLOW wins")
	_assert.eq(r2.winner, GameConfig.Faction.YELLOW, "WCE wild: YELLOW wins")

	for m in t2.values():
		Fixtures.cleanup_node(m)

func _test_wce_evaluate_dispatcher() -> void:
	var turrets := {}
	for fid in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var m := Turret.new()
		m.is_destroyed = true
		turrets[fid] = m

	var r: Dictionary = WinConditionEvaluator.evaluate(GameConfig.GAME_MODE_BASIC, turrets, {}, 0, false)
	_assert.eq(r.ended, true, "WCE dispatch: BASIC → evaluate_basic")

	var r2: Dictionary = WinConditionEvaluator.evaluate("invalid_mode", turrets, {}, 0, false)
	_assert.eq(r2.ended, false, "WCE dispatch: unknown mode returns no-op")

	for m in turrets.values():
		Fixtures.cleanup_node(m)

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
	_assert.that(not cv2.has("_invalid_reason"), "save compat: 2.0.0 passes")

# ======================================================================
# P4 — match config / weapon ruleset / fire conversion
# ======================================================================

func _test_match_config_and_volley() -> void:
	print("  [P4] match config / weapon ruleset / volley allocation")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_TIMED)
	GameConfig.set_quality_by_name(GameConfig.QUALITY_LOW)

	var config := MatchConfig.capture_current(30, 777)
	_assert.eq(config.map_id, MatchConfig.CLASSIC_MAP_ID, "match config: default map is classic")
	_assert.eq(config.weapon_ruleset_id, WeaponRuleset.CLASSIC_ID, "match config: default ruleset is classic")
	_assert.eq(config.grid_size, 30, "match config: keeps the grid it was given")
	_assert.eq(config.seed_value, 777, "match config: keeps the seed")
	_assert.eq(config.mode_name, GameConfig.GAME_MODE_TIMED, "match config: snapshots the current mode")
	_assert.eq(config.quality_name, GameConfig.QUALITY_LOW, "match config: snapshots the current quality")
	_assert.that(config.weapon_ruleset.is_unlocked(WeaponRuleset.BulletType.STANDARD), "classic ruleset: standard unlocked")
	_assert.that(not config.weapon_ruleset.is_unlocked(WeaponRuleset.BulletType.PIERCING), "classic ruleset: piercing locked")

	config.map_id = "unknown_map"
	config.weapon_ruleset_id = "unknown_ruleset"
	config.mode_name = "unknown_mode"
	config.quality_name = "unknown_quality"
	config.grid_size = 41
	config.sanitize()
	_assert.eq(config.map_id, MatchConfig.CLASSIC_MAP_ID, "match config sanitize: unknown map falls back to classic")
	_assert.eq(config.weapon_ruleset_id, WeaponRuleset.CLASSIC_ID, "match config sanitize: unknown ruleset falls back to classic")
	_assert.eq(config.mode_name, GameConfig.GAME_MODE_BASIC, "match config sanitize: unknown mode falls back to basic")
	_assert.eq(config.quality_name, GameConfig.QUALITY_MEDIUM, "match config sanitize: unknown quality falls back to medium")
	_assert.eq(config.grid_size, 40, "match config sanitize: invalid grid falls back to 40")

	var classic := WeaponRuleset.classic()
	var plain := classic.allocate(37)
	_assert.eq(int(plain.get(WeaponRuleset.BulletType.STANDARD, 0)), 37, "classic volley: all fire becomes standard shots")
	_assert.eq(WeaponRuleset.total_shots(plain), 37, "classic volley: no fire is lost")

	var mixed := WeaponRuleset.with_unlocked([WeaponRuleset.BulletType.PIERCING])
	_assert.that(mixed.is_unlocked(WeaponRuleset.BulletType.STANDARD), "mixed ruleset: standard is mandatory")
	_assert.that(mixed.is_unlocked(WeaponRuleset.BulletType.PIERCING), "mixed ruleset: requested type is unlocked")

	var split := mixed.allocate(100, {WeaponRuleset.BulletType.PIERCING: 50})
	_assert.eq(int(split.get(WeaponRuleset.BulletType.PIERCING, 0)), 10, "allocation: 100 fire at 50% buys 10 piercing")
	_assert.eq(int(split.get(WeaponRuleset.BulletType.STANDARD, 0)), 50, "allocation: the other 50 fire stays standard")
	_assert.eq(WeaponRuleset.total_shots(split), 60, "allocation: 100 fire becomes 60 projectiles (10x5 + 50x1)")

	var tiny := mixed.allocate(3, {WeaponRuleset.BulletType.PIERCING: 50})
	_assert.eq(int(tiny.get(WeaponRuleset.BulletType.PIERCING, 0)), 0, "allocation: 1 fire cannot buy a 5-cost bullet")
	_assert.eq(WeaponRuleset.total_shots(tiny), 3, "allocation: unspent fire returns to standard")

	var locked := classic.allocate(10, {WeaponRuleset.BulletType.PIERCING: 100})
	_assert.eq(int(locked.get(WeaponRuleset.BulletType.PIERCING, 0)), 0, "allocation: locked type is ignored")
	_assert.eq(WeaponRuleset.total_shots(locked), 10, "allocation: locked type leaves all fire standard")

	var overspend := mixed.allocate(10, {WeaponRuleset.BulletType.PIERCING: 100})
	_assert.eq(int(overspend.get(WeaponRuleset.BulletType.PIERCING, 0)), 2, "allocation: 10 fire buys 2 piercing")
	_assert.eq(int(overspend.get(WeaponRuleset.BulletType.STANDARD, 0)), 0, "allocation: no standard left when fire is fully spent")
	_assert.eq(WeaponRuleset.total_shots(overspend), 2, "allocation: 10 fire cannot buy more than 2 piercing shots")

	_assert.eq(WeaponRuleset.total_shots(classic.allocate(-5)), 0, "allocation: negative fire yields an empty volley")

	var again := mixed.allocate(100, {WeaponRuleset.BulletType.PIERCING: 50})
	_assert.eq(str(again), str(split), "allocation: same input produces the same volley")

# ======================================================================
# P5 — bullet attributes / pool reuse / collision toggle
# ======================================================================

func _test_bullet_attributes_and_reset() -> void:
	print("  [P5] bullet attributes / pool reset / collision toggle")

	var battlefield := Battlefield.new()
	battlefield.configure(40)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()

	var pool := BulletPool.new()
	get_root().add_child(pool)
	pool.set_battlefield(battlefield)

	var bullet = pool.spawn_bullet(0, Vector2(100.0, 100.0), Vector2.RIGHT, battlefield, {})
	_assert.eq(int(bullet.type_id), WeaponRuleset.BulletType.STANDARD, "bullet: type defaults to standard")
	_assert.eq(int(bullet.cost), 1, "bullet: standard costs 1")
	_assert.eq(bullet.speed, GameConfig.BULLET_SPEED, "bullet: standard speed")
	_assert.eq(bullet.physical_radius, GameConfig.BULLET_RADIUS, "bullet: standard physical radius")
	_assert.eq(bullet.mass, 1.0, "bullet: standard mass")
	_assert.eq(int(bullet.energy), 1, "bullet: standard energy")
	_assert.eq(int(bullet.damage), GameConfig.BULLET_DAMAGE, "bullet: standard damage")
	_assert.that(not bullet.controlled, "bullet: classic mode leaves the bullet self-driven")

	# 模拟上一颗特殊弹的残留，回收后必须完全回到普通弹属性。
	bullet.speed = 75.6
	bullet.physical_radius = 10.0
	bullet.mass = 6.0
	bullet.energy = 4
	bullet.damage = 8
	pool.recycle_bullet(bullet)
	var reused = pool.spawn_bullet(1, Vector2(120.0, 100.0), Vector2.RIGHT, battlefield, {})
	_assert.that(reused == bullet, "pool: recycled node is reused")
	_assert.eq(reused.speed, GameConfig.BULLET_SPEED, "pool reset: speed restored")
	_assert.eq(reused.physical_radius, GameConfig.BULLET_RADIUS, "pool reset: radius restored")
	_assert.eq(reused.mass, 1.0, "pool reset: mass restored")
	_assert.eq(int(reused.energy), 1, "pool reset: energy restored")
	_assert.eq(int(reused.damage), GameConfig.BULLET_DAMAGE, "pool reset: damage restored")

	pool.set_collision_enabled(true)
	_assert.that(pool.collision_enabled, "collision: toggle turns on")
	_assert.that(reused.controlled, "collision: active bullets hand control to the pool")
	pool.set_collision_enabled(false)
	_assert.that(not pool.collision_enabled, "collision: toggle turns off")
	_assert.that(not reused.controlled, "collision: bullets return to self-driven mode")

	pool.clear_active()
	pool.free()
	Fixtures.cleanup_node(battlefield)

# ======================================================================
# P7 — cross-burst fire ledger
# ======================================================================

func _test_fire_ledger() -> void:
	print("  [P7] fire ledger accumulation")

	var piercing_only := WeaponRuleset.with_unlocked([WeaponRuleset.BulletType.PIERCING])
	var ledger := FireLedger.new()
	var piercing_shots := 0
	var standard_shots := 0
	for i in range(5):
		var volley: Dictionary = ledger.allocate(2, {WeaponRuleset.BulletType.PIERCING: 50}, piercing_only)
		piercing_shots += int(volley.get(WeaponRuleset.BulletType.PIERCING, 0))
		standard_shots += int(volley.get(WeaponRuleset.BulletType.STANDARD, 0))
	_assert.eq(piercing_shots, 1, "ledger: 5 x 2 fire at 50% buys exactly 1 piercing")
	_assert.eq(standard_shots, 5, "ledger: the same 10 fire still buys 5 standard")
	_assert.eq(ledger.remaining_units(), 0, "ledger: no residual units after the example")
	_assert.that(ledger.is_balanced(), "ledger: produced = spent + remaining")

	var full := FireLedger.new()
	var empty_volley: Dictionary = full.allocate(2, {WeaponRuleset.BulletType.PIERCING: 100}, piercing_only)
	_assert.that(empty_volley.is_empty(), "ledger: 100% special with too little fire yields no bullets")
	_assert.eq(full.remaining_units(), 200, "ledger: the fire stays in the special account")
	var later: Dictionary = full.allocate(4, {WeaponRuleset.BulletType.PIERCING: 100}, piercing_only)
	_assert.eq(int(later.get(WeaponRuleset.BulletType.PIERCING, 0)), 1, "ledger: accumulated balance pays out next time")
	_assert.eq(full.remaining_units(), 100, "ledger: only the cost is deducted")
	_assert.that(full.is_balanced(), "ledger: balance still conserved")

	var classic := FireLedger.new()
	var plain: Dictionary = classic.allocate(5, {}, WeaponRuleset.classic())
	_assert.eq(int(plain.get(WeaponRuleset.BulletType.STANDARD, 0)), 5, "ledger: 0% mix is pure standard")
	_assert.eq(classic.remaining_units(), 0, "ledger: 0% mix leaves no balance")

	var dual := WeaponRuleset.with_unlocked([WeaponRuleset.BulletType.PIERCING, WeaponRuleset.BulletType.EXPLOSIVE])
	var mixed := FireLedger.new()
	var split: Dictionary = mixed.allocate(100, {
		WeaponRuleset.BulletType.PIERCING: 40,
		WeaponRuleset.BulletType.EXPLOSIVE: 30,
	}, dual)
	_assert.eq(int(split.get(WeaponRuleset.BulletType.PIERCING, 0)), 8, "ledger: 40 fire buys 8 piercing")
	_assert.eq(int(split.get(WeaponRuleset.BulletType.EXPLOSIVE, 0)), 3, "ledger: 30 fire buys 3 explosive")
	_assert.eq(int(split.get(WeaponRuleset.BulletType.STANDARD, 0)), 30, "ledger: the remaining 30 fire stays standard")
	_assert.that(mixed.is_balanced(), "ledger: multi-type split is conserved")

	var invalid := FireLedger.new()
	var rejected: Dictionary = invalid.allocate(10, {
		WeaponRuleset.BulletType.PIERCING: 60,
		WeaponRuleset.BulletType.EXPLOSIVE: 52,
	}, dual)
	_assert.eq(invalid.last_error, "shares_sum:112", "ledger: shares over 100% are rejected explicitly")
	_assert.eq(int(rejected.get(WeaponRuleset.BulletType.STANDARD, 0)), 10, "ledger: rejected split falls back to all standard")
	_assert.that(invalid.is_balanced(), "ledger: rejection does not create or destroy fire")

	var snapshot: Dictionary = full.snapshot()
	var restored := FireLedger.new()
	restored.restore(snapshot)
	_assert.eq(restored.remaining_units(), full.remaining_units(), "ledger: snapshot keeps the balance")
	var resumed: Dictionary = restored.allocate(4, {WeaponRuleset.BulletType.PIERCING: 100}, piercing_only)
	_assert.eq(int(resumed.get(WeaponRuleset.BulletType.PIERCING, 0)), 1, "ledger: restored balance keeps paying out")
	_assert.that(restored.is_balanced(), "ledger: restored ledger is still conserved")

	var locked := FireLedger.new()
	var locked_volley: Dictionary = locked.allocate(5, {WeaponRuleset.BulletType.PIERCING: 50}, WeaponRuleset.classic())
	_assert.eq(locked.last_error, "unlocked:2", "ledger: a locked type is rejected, not silently ignored")
	_assert.eq(int(locked_volley.get(WeaponRuleset.BulletType.STANDARD, 0)), 5, "ledger: locked type keeps all fire standard")

	# 已兑换 / 已发射 / 待发射 必须分开。
	var fired := FireLedger.new()
	fired.allocate(10, {WeaponRuleset.BulletType.PIERCING: 50}, piercing_only)
	fired.note_fired(WeaponRuleset.BulletType.PIERCING, 1)
	fired.note_fired(WeaponRuleset.BulletType.STANDARD, 5)
	_assert.eq(fired.pending_units(), 0, "ledger: fired shots leave no pending units")
	_assert.that(fired.is_balanced(), "ledger: fired accounting is conserved")

	var lost := FireLedger.new()
	lost.allocate(10, {WeaponRuleset.BulletType.PIERCING: 50}, piercing_only)
	lost.note_lost(WeaponRuleset.BulletType.PIERCING, 1)
	_assert.eq(lost.lost_units, 500, "ledger: a cancelled piercing shot is recorded as 5 fire lost")
	_assert.eq(lost.pending_units(), 500, "ledger: the rest of the converted fire is still pending")
	_assert.that(lost.is_balanced(), "ledger: lost accounting is conserved")

	var broken := FireLedger.new()
	broken.restore({"special": [[2, 50000]], "standard": 0, "consumed_fire": 1, "converted_units": 0})
	_assert.that(not broken.restore_ok, "ledger: an unbalanced snapshot is flagged on restore")

	# 存档契约：weapon_config 的边界值要被清洗，而不是原样回放。
	var raw: Dictionary = Fixtures.build_minimal_save_payload("2.1.0")
	raw["weapon_config"] = {"pierce": -3, "mix_pierce": 150, "blast": 9, "mix_blast": -1}
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)
	var weapon: Dictionary = clean.get("weapon_config", {})
	_assert.eq(int(weapon.get("pierce", 0)), 1, "save: invalid pierce clamps to 1")
	_assert.eq(int(weapon.get("mix_pierce", 0)), 100, "save: mix clamps to 100")
	_assert.eq(int(weapon.get("blast", -1)), 3, "save: blast clamps to 3")
	_assert.eq(int(weapon.get("mix_blast", -1)), 0, "save: negative mix clamps to 0")
	raw["weapon_config"] = {"pierce": -1, "mix_pierce": 50, "blast": 2, "mix_blast": 50}
	var clean_infinite: Dictionary = SaveGameCodec.validate_save_data(raw)
	_assert.eq(int(clean_infinite.get("weapon_config", {}).get("pierce", 0)), -1, "save: infinite pierce survives as -1")

func _test_special_bullet_profiles() -> void:
	print("  [P6] piercing / explosive profiles")

	var battlefield := Battlefield.new()
	battlefield.configure(40)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()

	var pool := BulletPool.new()
	get_root().add_child(pool)
	pool.set_battlefield(battlefield)
	pool.set_experiment_profiles(5, 1)

	# 穿透：连续占 5 格后消失；第 6 格保持原归属。
	var piercer = pool.spawn_bullet(0, battlefield.to_global(Vector2(325.0, 325.0)), Vector2.RIGHT, battlefield, {}, WeaponRuleset.BulletType.PIERCING)
	_assert.eq(int(piercer.max_enemy_captures), 5, "piercing: profile carries the capture budget")
	for step in range(5):
		piercer._pending_cell = Vector2i(25 + step, 25)
		piercer._pending_has_cell = true
		piercer.resolve_tick()
	_assert.eq(int(piercer.enemy_captures_done), 5, "piercing: five cells consumed")
	_assert.that(not piercer.is_active, "piercing: bullet is gone after the budget")
	_assert.eq(int(battlefield.owners[30][25]), GameConfig.Faction.YELLOW, "piercing: the sixth cell is untouched")

	# 同一格重复结算不得重复扣次数。
	var repeat = pool.spawn_bullet(0, battlefield.to_global(Vector2(325.0, 338.0)), Vector2.RIGHT, battlefield, {}, WeaponRuleset.BulletType.PIERCING)
	repeat._pending_cell = Vector2i(25, 26)
	repeat._pending_has_cell = true
	repeat.resolve_tick()
	repeat._pending_cell = Vector2i(25, 26)
	repeat._pending_has_cell = true
	repeat.resolve_tick()
	_assert.eq(int(repeat.enemy_captures_done), 1, "piercing: staying on the same cell does not double-charge")

	# 爆炸 r=1：3×3 = 9 格，触发格先被占领，其余 8 格计入 explosion_cells。
	var blaster = pool.spawn_bullet(0, battlefield.to_global(Vector2(461.5, 461.5)), Vector2.RIGHT, battlefield, {}, WeaponRuleset.BulletType.EXPLOSIVE)
	blaster._pending_cell = Vector2i(35, 35)
	blaster._pending_has_cell = true
	blaster.resolve_tick()
	_assert.eq(int(blaster.explosion_cells), 8, "explosive: radius 1 captures the 8 neighbours around the trigger")
	_assert.that(not blaster.is_active, "explosive: bullet is consumed on detonation")

	# 边界裁剪：贴着左边界爆炸只结算界内格子。
	var edge = pool.spawn_bullet(0, battlefield.to_global(Vector2(6.5, 273.0)), Vector2.RIGHT, battlefield, {}, WeaponRuleset.BulletType.EXPLOSIVE)
	edge._pending_cell = Vector2i(0, 21)
	edge._pending_has_cell = true
	edge.resolve_tick()
	_assert.eq(int(edge.explosion_cells), 5, "explosive: boundary clips the blast to in-board cells")

	pool.recycle_bullet(repeat)
	var reused = pool.spawn_bullet(1, battlefield.to_global(Vector2(200.0, 200.0)), Vector2.RIGHT, battlefield, {})
	_assert.eq(int(reused.max_enemy_captures), 1, "pool reset: pierce budget returns to standard")
	_assert.eq(int(reused.enemy_captures_done), 0, "pool reset: capture progress cleared")
	_assert.eq(int(reused.explosion_radius), 0, "pool reset: blast radius cleared")

	pool.clear_active()
	pool.free()
	Fixtures.cleanup_node(battlefield)
