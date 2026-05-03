extends SceneTree

const SaveGameCodec = preload("res://scripts/SaveGameCodec.gd")
const EventRouletteController = preload("res://scripts/EventRouletteController.gd")
const ControlChamber = preload("res://scripts/ControlChamber.gd")
const Turret = preload("res://scripts/Turret.gd")
const GameConfig = preload("res://scripts/GameConfig.gd")
const Battlefield = preload("res://scripts/Battlefield.gd")
const LayoutProfiles = preload("res://scripts/LayoutProfiles.gd")

var _failures: Array[String] = []
var _passes: int = 0

# ---- boilerplate ------------------------------------------------------

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[IntegrationTest] Starting BallWar integration tests")
	await process_frame

	_test_save_load_roundtrip()
	await _flush()
	_test_battlefield_rules()
	await _flush()
	_test_win_conditions()
	await _flush()

	if _failures.is_empty():
		print("[IntegrationTest] PASS (%d checks)" % _passes)
		quit(0)
		return

	push_error("[IntegrationTest] FAIL (%d failures)" % _failures.size())
	for failure in _failures:
		push_error(failure)
	quit(1)

func _assert(b: bool, msg: String) -> void:
	if b:
		_passes += 1
	else:
		_failures.append(msg)

func _eq(actual, expected, msg: String) -> void:
	if actual == expected:
		_passes += 1
	else:
		_failures.append("%s | expected=%s actual=%s" % [msg, str(expected), str(actual)])

func _cleanup_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.queue_free()
	else:
		node.free()

func _flush() -> void:
	await process_frame
	await process_frame

# ---- P1: save / load round-trip --------------------------------------

func _test_save_load_roundtrip() -> void:
	print("  [P1] save/load round-trip")

	_test_save_payload_construction()
	_test_save_codec_full_validation()
	_test_save_schema_version()
	_test_save_game_mode_persistence()
	_test_save_battlefield_owners_roundtrip()
	_test_save_faction_state_roundtrip()
	_test_save_event_state_roundtrip()

func _test_save_payload_construction() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)
	GameConfig.set_quality_by_name("高")
	GameConfig.set_time_limit_minutes(10)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(40)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()

	var cell: Vector2i = Vector2i(5, 5)
	battlefield.apply_bullet(cell, GameConfig.Faction.RED)
	battlefield.apply_bullet(Vector2i(6, 5), GameConfig.Faction.RED)
	battlefield.apply_bullet(Vector2i(7, 5), GameConfig.Faction.RED)

	var owners: Array = battlefield.owners
	_eq(owners[5][5], GameConfig.Faction.RED, "save payload: ownership mutation should persist in owners array")
	_eq(owners[4][4], GameConfig.Faction.BLUE, "save payload: un-touched cell should keep original faction")
	_cleanup_node(battlefield)
	await _flush()

func _test_save_codec_full_validation() -> void:
	var raw: Dictionary = _build_realistic_save_payload()
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)
	_clean_save_codec_assertions(clean)

func _build_realistic_save_payload() -> Dictionary:
	var owners: Array = []
	for x in range(10):
		var col: Array = []
		for y in range(10):
			col.append(GameConfig.Faction.BLUE)
		owners.append(col)
	owners[0][0] = GameConfig.Faction.RED

	return {
		"save_version": "1.9.34",
		"save_slot": 1,
		"grid_size": 10,
		"palette_name": "经典",
		"quality_name": "中",
		"game_mode_name": GameConfig.GAME_MODE_BASIC,
		"time_limit_minutes": 5,
		"owners": owners,
		"game_elapsed_time": 120.0,
		"is_game_over": false,
		"factions": _build_save_faction_states(),
		"bullets": [],
		"winner_text": "",
		"event_state": _build_save_event_state(),
	}

func _build_save_faction_states() -> Array:
	var result: Array = []
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		result.append({
			"faction_id": faction_id,
			"chamber_pending_count": 8,
			"chamber_locked_remaining": 0,
			"chamber_is_locked": false,
			"chamber_is_damaged": false,
			"chamber_ball_count": 2,
			"chamber_release_ball_index": -1,
			"chamber_jammed_time_left": 0.0,
			"queued_round_modifiers": [],
			"control_balls": [],
			"turret_health": GameConfig.TURRET_MAX_HEALTH,
			"turret_destroyed": false,
			"turret_sweep_phase": 0.0,
			"turret_rotation": 0.0,
			"turret_burst_remaining": 0,
			"turret_burst_total": 0,
			"turret_burst_index": 0,
			"turret_burst_timer": 0.0,
			"turret_burst_locked": false,
		})
	return result

func _build_save_event_state() -> Dictionary:
	return {
		"event_roulette_enabled": true,
		"next_event_time_left": 30.5,
		"current_event_interval": 60.0,
		"last_event_faction": GameConfig.Faction.GREEN,
		"last_event_effect": EventRouletteController.EFFECT_X2,
		"reroll_count": 0,
	}

func _clean_save_codec_assertions(clean: Dictionary) -> void:
	_eq(clean.get("grid_size", 0), 10, "save codec: should preserve valid grid_size")
	_eq(str(clean.get("game_mode_name", "")), GameConfig.GAME_MODE_BASIC, "save codec: should preserve valid game mode")
	_eq(int(clean.get("time_limit_minutes", 0)), 5, "save codec: should preserve valid time limit")
	_assert(clean.has("owners"), "save codec: should preserve owners array when valid")
	_assert(clean.get("bullets", null) is Array, "save codec: bullets should be array")
	_assert(clean.has("event_state"), "save codec: should preserve event_state")

	var raw_event: Dictionary = clean.get("event_state", {})
	_eq(float(raw_event.get("next_event_time_left", 0.0)), 30.5, "save codec: should preserve event countdown")
	_eq(int(raw_event.get("last_event_faction", -1)), GameConfig.Faction.GREEN, "save codec: should preserve last event faction")
	_eq(str(raw_event.get("last_event_effect", "")), EventRouletteController.EFFECT_X2, "save codec: should preserve last event effect")

	var factions: Array = clean.get("factions", [])
	_eq(factions.size(), 4, "save codec: should keep all 4 factions")
	var blue_faction: Dictionary = factions[GameConfig.Faction.BLUE]
	_eq(int(blue_faction.get("chamber_pending_count", 0)), 8, "save codec: should preserve chamber pending count")
	_eq(int(blue_faction.get("turret_health", 0)), GameConfig.TURRET_MAX_HEALTH, "save codec: should preserve turret health")
	_assert(blue_faction.get("queued_round_modifiers", null) is Array, "save codec: queued_round_modifiers should be array")

	var invalid_raw: Dictionary = {
		"save_version": "1.9.0",
		"grid_size": 40,
		"quality_name": "中",
		"game_mode_name": "not_a_mode",
		"time_limit_minutes": 5,
		"factions": [],
	}
	var invalid_clean: Dictionary = SaveGameCodec.validate_save_data(invalid_raw)
	_eq(str(invalid_clean.get("game_mode_name", "")), GameConfig.GAME_MODE_BASIC, "save codec: should normalize invalid game mode")
	_eq(int(invalid_clean.get("time_limit_minutes", 0)), 5, "save codec: should clamp time_limit_minutes to valid range")

func _test_save_schema_version() -> void:
	var v1: Dictionary = SaveGameCodec.validate_save_data({"save_version": "1.9.34", "grid_size": 40, "quality_name": "中", "game_mode_name": GameConfig.GAME_MODE_BASIC, "time_limit_minutes": 5, "factions": []})
	_assert(not v1.has("_invalid_reason"), "save schema: valid 1.9.x version should pass")

	var v2: Dictionary = SaveGameCodec.validate_save_data({"save_version": "2.0.0", "grid_size": 40, "quality_name": "中", "game_mode_name": GameConfig.GAME_MODE_BASIC, "time_limit_minutes": 5, "factions": []})
	_assert(v2.has("_invalid_reason"), "save schema: 2.0.0 version should be rejected (guard: save major prefix is 1.9)")

	var v3: Dictionary = SaveGameCodec.validate_save_data({"save_version": "", "grid_size": 40, "quality_name": "中", "game_mode_name": GameConfig.GAME_MODE_BASIC, "time_limit_minutes": 5, "factions": []})
	_assert(v3.has("_invalid_reason"), "save schema: empty version should be rejected")

func _test_save_game_mode_persistence() -> void:
	var mode_list: Array = GameConfig.get_game_mode_names()
	_assert(mode_list.size() >= 4, "game mode: should have at least 4 modes")
	_assert(GameConfig.GAME_MODE_BASIC in mode_list, "game mode: basic mode should be listed")
	_assert(GameConfig.GAME_MODE_OCCUPATION in mode_list, "game mode: occupation mode should be listed")
	_assert(GameConfig.GAME_MODE_TIMED in mode_list, "game mode: timed mode should be listed")
	_assert(GameConfig.GAME_MODE_WILD in mode_list, "game mode: wild mode should be listed")

	for mode_name in mode_list:
		GameConfig.set_game_mode_by_name(mode_name)
		_eq(GameConfig.get_game_mode_name(), mode_name, "game mode: should persist %s" % mode_name)

	_eq(GameConfig.get_gate_multiplier(), 2, "gate multiplier: basic/occupation/timed should be x2")
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_WILD)
	_eq(GameConfig.get_gate_multiplier(), 3, "gate multiplier: wild mode should be x3")
	_eq(GameConfig.get_max_pending_count(), GameConfig.WILD_MAX_PENDING_COUNT, "wild mode: max pending should be wild-specific limit")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

func _test_save_battlefield_owners_roundtrip() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var half: int = 10
	_eq(battlefield.owners[0][0], GameConfig.Faction.BLUE, "battlefield init: top-left should be BLUE")
	_eq(battlefield.owners[half][0], GameConfig.Faction.RED, "battlefield init: top-right should be RED")
	_eq(battlefield.owners[0][half], GameConfig.Faction.GREEN, "battlefield init: bottom-left should be GREEN")
	_eq(battlefield.owners[half][half], GameConfig.Faction.YELLOW, "battlefield init: bottom-right should be YELLOW")

	var initial_counts: Dictionary = battlefield.count_cells_by_team()
	var expected_per_faction: int = (20 * 20) / 4
	_eq(int(initial_counts.get(GameConfig.Faction.BLUE, 0)), expected_per_faction, "battlefield init: BLUE should own exactly 1/4 of cells")
	_eq(int(initial_counts.get(GameConfig.Faction.RED, 0)), expected_per_faction, "battlefield init: RED should own exactly 1/4 of cells")
	_eq(int(initial_counts.get(GameConfig.Faction.GREEN, 0)), expected_per_faction, "battlefield init: GREEN should own exactly 1/4 of cells")
	_eq(int(initial_counts.get(GameConfig.Faction.YELLOW, 0)), expected_per_faction, "battlefield init: YELLOW should own exactly 1/4 of cells")

	_cleanup_node(battlefield)
	await _flush()

func _test_save_faction_state_roundtrip() -> void:
	var raw: Dictionary = _build_realistic_save_payload()
	raw["factions"] = [
		{
			"faction_id": GameConfig.Faction.RED,
			"chamber_pending_count": 7,
			"chamber_locked_remaining": 0,
			"chamber_is_locked": false,
			"chamber_is_damaged": false,
			"chamber_ball_count": 4,
			"chamber_release_ball_index": -1,
			"chamber_jammed_time_left": 2.5,
			"queued_round_modifiers": [{"type": "add_ball"}, {"type": "x2", "multiplier": 2}],
			"control_balls": [],
			"turret_health": 12,
			"turret_destroyed": false,
			"turret_sweep_phase": 0.0,
			"turret_rotation": 0.0,
			"turret_burst_remaining": 0,
			"turret_burst_total": 0,
			"turret_burst_index": 0,
			"turret_burst_timer": 0.0,
			"turret_burst_locked": false,
		},
		{"faction_id": GameConfig.Faction.BLUE, "chamber_pending_count": 1, "chamber_locked_remaining": 0, "chamber_is_locked": false, "chamber_is_damaged": false, "chamber_ball_count": 1, "chamber_release_ball_index": -1, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [], "control_balls": [], "turret_health": GameConfig.TURRET_MAX_HEALTH, "turret_destroyed": false, "turret_sweep_phase": 0.0, "turret_rotation": 0.0, "turret_burst_remaining": 0, "turret_burst_total": 0, "turret_burst_index": 0, "turret_burst_timer": 0.0, "turret_burst_locked": false},
		{"faction_id": GameConfig.Faction.GREEN, "chamber_pending_count": 1, "chamber_locked_remaining": 0, "chamber_is_locked": false, "chamber_is_damaged": true, "chamber_ball_count": 0, "chamber_release_ball_index": -1, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [], "control_balls": [], "turret_health": 0, "turret_destroyed": true, "turret_sweep_phase": 0.0, "turret_rotation": 0.0, "turret_burst_remaining": 0, "turret_burst_total": 0, "turret_burst_index": 0, "turret_burst_timer": 0.0, "turret_burst_locked": false},
		{"faction_id": GameConfig.Faction.YELLOW, "chamber_pending_count": 100, "chamber_locked_remaining": 50, "chamber_is_locked": true, "chamber_is_damaged": false, "chamber_ball_count": 6, "chamber_release_ball_index": 0, "chamber_jammed_time_left": 0.0, "queued_round_modifiers": [{"type": "bonus_10", "amount": 10}, {"type": "x3", "multiplier": 3}], "control_balls": [], "turret_health": 8, "turret_destroyed": false, "turret_sweep_phase": 0.5, "turret_rotation": 1.2, "turret_burst_remaining": 50, "turret_burst_total": 100, "turret_burst_index": 50, "turret_burst_timer": 0.3, "turret_burst_locked": true},
	]
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)
	var factions: Array = clean.get("factions", [])
	_eq(factions.size(), 4, "faction roundtrip: should keep 4 factions")

	var yellow_faction: Dictionary = factions[GameConfig.Faction.YELLOW]
	_eq(int(yellow_faction.get("chamber_pending_count", 0)), 100, "faction roundtrip: YELLOW pending count")
	_eq(int(yellow_faction.get("chamber_locked_remaining", 0)), 50, "faction roundtrip: YELLOW locked remaining")
	_assert(bool(yellow_faction.get("chamber_is_locked", false)), "faction roundtrip: YELLOW should be locked")
	_eq(int(yellow_faction.get("chamber_ball_count", 0)), 6, "faction roundtrip: YELLOW ball count")
	_eq(float(yellow_faction.get("chamber_jammed_time_left", -1.0)), 0.0, "faction roundtrip: YELLOW jammed time")
	var yellow_modifiers: Array = yellow_faction.get("queued_round_modifiers", [])
	_eq(yellow_modifiers.size(), 2, "faction roundtrip: YELLOW should have 2 queued modifiers")
	_eq(int(yellow_faction.get("turret_health", 0)), 8, "faction roundtrip: YELLOW turret health")
	_eq(int(yellow_faction.get("turret_burst_remaining", 0)), 50, "faction roundtrip: YELLOW burst remaining")

	var red_faction: Dictionary = factions[GameConfig.Faction.RED]
	_eq(float(red_faction.get("chamber_jammed_time_left", -1.0)), 2.5, "faction roundtrip: RED jammed time should be preserved")
	_eq(int(red_faction.get("turret_health", 0)), 12, "faction roundtrip: RED turret partial damage preserved")

func _test_save_event_state_roundtrip() -> void:
	var controller: EventRouletteController = EventRouletteController.new()
	var dummy_main: Node = Node.new()
	var dummy_battlefield: Node = Node.new()
	controller.main_ref = dummy_main
	controller.battlefield = dummy_battlefield
	controller.chambers = {
		GameConfig.Faction.BLUE: null,
		GameConfig.Faction.RED: null,
		GameConfig.Faction.GREEN: null,
		GameConfig.Faction.YELLOW: null,
	}
	controller.turrets = {
		GameConfig.Faction.BLUE: null,
		GameConfig.Faction.RED: null,
		GameConfig.Faction.GREEN: null,
		GameConfig.Faction.YELLOW: null,
	}
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
	_eq(float(exported.get("next_event_time_left", 0.0)), 45.8, "event state: countdown preserved through import/export")
	_eq(int(exported.get("last_event_faction", -1)), GameConfig.Faction.YELLOW, "event state: last faction preserved")
	_eq(str(exported.get("last_event_effect", "")), EventRouletteController.EFFECT_JAM, "event state: last effect preserved")
	_eq(int(exported.get("reroll_count", -1)), 2, "event state: reroll count preserved")
	_assert(bool(exported.get("event_roulette_enabled", false)), "event state: enabled flag preserved")
	_eq(float(exported.get("current_event_interval", 0.0)), 30.0, "event state: interval preserved")

	controller.battlefield = null
	controller.main_ref = null
	_cleanup_node(controller)
	_cleanup_node(dummy_main)
	_cleanup_node(dummy_battlefield)

# ---- P2: battlefield rules -------------------------------------------

func _test_battlefield_rules() -> void:
	print("  [P2] battlefield rules")

	_test_battlefield_initial_territory()
	_test_battlefield_same_faction_noop()
	_test_battlefield_enemy_capture()
	_test_battlefield_owner_counts_sync()
	_test_battlefield_world_to_cell()
	_test_battlefield_rebuild_owner_counts()

func _test_battlefield_initial_territory() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(40)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var half: int = 20
	_eq(battlefield.owners[0][0], GameConfig.Faction.BLUE, "battlefield: 40x40 top-left quadrant should be BLUE")
	_eq(battlefield.owners[half][0], GameConfig.Faction.RED, "battlefield: 40x40 top-right quadrant should be RED")
	_eq(battlefield.owners[0][half], GameConfig.Faction.GREEN, "battlefield: 40x40 bottom-left quadrant should be GREEN")
	_eq(battlefield.owners[half][half], GameConfig.Faction.YELLOW, "battlefield: 40x40 bottom-right quadrant should be YELLOW")

	var counts: Dictionary = battlefield.count_cells_by_team()
	var total: int = 0
	for fid in counts.keys():
		total += int(counts[fid])
	_eq(total, 1600, "battlefield: 40x40 total cells should be 1600")
	_eq(int(counts.get(GameConfig.Faction.BLUE, 0)), 400, "battlefield: each faction starts with 400 cells on 40x40")

	_cleanup_node(battlefield)
	await _flush()

func _test_battlefield_same_faction_noop() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var before_counts: Dictionary = battlefield.count_cells_by_team().duplicate()
	var result: String = battlefield.apply_bullet(Vector2i(0, 0), GameConfig.Faction.BLUE)
	_eq(result, "SAME_CELL", "battlefield: same-faction bullet should return SAME_CELL")
	var after_counts: Dictionary = battlefield.count_cells_by_team()
	_eq(int(after_counts.get(GameConfig.Faction.BLUE, 0)), int(before_counts.get(GameConfig.Faction.BLUE, 0)), "battlefield: same-faction bullet should not change BLUE count")
	_eq(int(after_counts.get(GameConfig.Faction.RED, 0)), int(before_counts.get(GameConfig.Faction.RED, 0)), "battlefield: same-faction bullet should not change RED count")

	_cleanup_node(battlefield)
	await _flush()

func _test_battlefield_enemy_capture() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var half: int = 10
	var red_cell: Vector2i = Vector2i(half, 0)
	_eq(battlefield.owners[red_cell.x][red_cell.y], GameConfig.Faction.RED, "battlefield: target cell should start as RED")

	var before: Dictionary = battlefield.count_cells_by_team().duplicate()
	var result: String = battlefield.apply_bullet(red_cell, GameConfig.Faction.BLUE)
	_eq(result, "HIT_ENEMY_CELL", "battlefield: enemy faction bullet should return HIT_ENEMY_CELL")
	_eq(battlefield.owners[red_cell.x][red_cell.y], GameConfig.Faction.BLUE, "battlefield: enemy bullet should change cell to attacker faction")

	var after: Dictionary = battlefield.count_cells_by_team()
	_eq(int(after.get(GameConfig.Faction.BLUE, 0)), int(before.get(GameConfig.Faction.BLUE, 0)) + 1, "battlefield: BLUE count should increase by 1 after capture")
	_eq(int(after.get(GameConfig.Faction.RED, 0)), int(before.get(GameConfig.Faction.RED, 0)) - 1, "battlefield: RED count should decrease by 1 after losing cell")

	var outside: String = battlefield.apply_bullet(Vector2i(999, 999), GameConfig.Faction.BLUE)
	_eq(outside, "OUTSIDE", "battlefield: bullet outside grid should return OUTSIDE")

	var outside_counts: Dictionary = battlefield.count_cells_by_team()
	_eq(int(outside_counts.get(GameConfig.Faction.BLUE, 0)), int(after.get(GameConfig.Faction.BLUE, 0)), "battlefield: outside bullet should not affect any counts")

	_cleanup_node(battlefield)
	await _flush()

func _test_battlefield_owner_counts_sync() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var total_from_manual: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for x in range(20):
		for y in range(20):
			total_from_manual[battlefield.owners[x][y]] += 1

	var counts: Dictionary = battlefield.count_cells_by_team()
	for fid in counts.keys():
		_eq(int(counts[fid]), int(total_from_manual.get(fid, 0)), "battlefield: count_cells_by_team should match manual scan for faction %d" % fid)

	battlefield.apply_bullet(Vector2i(0, 0), GameConfig.Faction.RED)
	battlefield.apply_bullet(Vector2i(1, 1), GameConfig.Faction.GREEN)
	battlefield.apply_bullet(Vector2i(2, 2), GameConfig.Faction.YELLOW)

	var total_from_manual2: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for x in range(20):
		for y in range(20):
			total_from_manual2[battlefield.owners[x][y]] += 1
	var counts2: Dictionary = battlefield.count_cells_by_team()
	for fid in counts2.keys():
		_eq(int(counts2[fid]), int(total_from_manual2.get(fid, 0)), "battlefield: owner counts should stay in sync after multiple captures for faction %d" % fid)

	_cleanup_node(battlefield)
	await _flush()

func _test_battlefield_world_to_cell() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(40)
	battlefield.cell_size = 13
	get_root().add_child(battlefield)
	await process_frame

	battlefield.position = Vector2(100, 100)
	var cell: Vector2i = battlefield.world_to_cell(Vector2(100 + 26, 100 + 26))
	_eq(cell, Vector2i(2, 2), "battlefield: world_to_cell at (126,126) should be (2,2) when origin at (100,100)")
	_assert(battlefield.is_inside(cell), "battlefield: cell (2,2) should be inside 40x40 grid")
	_assert(not battlefield.is_inside(Vector2i(-1, 0)), "battlefield: cell (-1,0) should be outside")
	_assert(not battlefield.is_inside(Vector2i(40, 0)), "battlefield: cell (40,0) should be outside (max index is 39)")

	_cleanup_node(battlefield)
	await _flush()

func _test_battlefield_rebuild_owner_counts() -> void:
	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	battlefield.owners[0][0] = GameConfig.Faction.YELLOW
	battlefield.rebuild_owner_counts()

	var counts: Dictionary = battlefield.count_cells_by_team()
	var total_from_manual: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for x in range(20):
		for y in range(20):
			total_from_manual[battlefield.owners[x][y]] += 1
	for fid in counts.keys():
		_eq(int(counts[fid]), int(total_from_manual.get(fid, 0)), "battlefield: rebuild_owner_counts should sync counts after external owners mutation for faction %d" % fid)

	_cleanup_node(battlefield)
	await _flush()

# ---- P3: win conditions ----------------------------------------------

const MAIN_SAVE_MAJOR_PREFIX: String = "1.9"

func _test_win_conditions() -> void:
	print("  [P3] win conditions")

	_test_basic_win_last_turret()
	_test_basic_win_all_destroyed_draw()
	_test_occupation_win_threshold()
	_test_occupation_no_win_below_threshold()
	_test_timed_win_score_leader()
	_test_timed_draw()
	_test_wild_mode_gate_and_limit()
	_test_save_version_compatibility()

func _test_basic_win_last_turret() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets({
		GameConfig.Faction.BLUE: {"is_destroyed": true},
		GameConfig.Faction.RED: {"is_destroyed": true},
		GameConfig.Faction.GREEN: {"is_destroyed": false},
		GameConfig.Faction.YELLOW: {"is_destroyed": true},
	})

	var winner: int = _simulate_check_winner(battlefield, turrets)
	_eq(winner, GameConfig.Faction.GREEN, "win condition basic: last surviving turret (GREEN) should win")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_basic_win_all_destroyed_draw() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets({
		GameConfig.Faction.BLUE: {"is_destroyed": true},
		GameConfig.Faction.RED: {"is_destroyed": true},
		GameConfig.Faction.GREEN: {"is_destroyed": true},
		GameConfig.Faction.YELLOW: {"is_destroyed": true},
	})

	var winner: int = _simulate_check_winner(battlefield, turrets)
	_eq(winner, -2, "win condition basic: all turrets destroyed should be draw (-2)")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_occupation_win_threshold() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets_all_alive()

	var total_cells: int = 20 * 20
	var target: int = int(ceil(float(total_cells) * 0.75))
	_uniform_paint(battlefield, GameConfig.Faction.BLUE, target)

	var winner: int = _simulate_check_winner(battlefield, turrets)
	_eq(winner, GameConfig.Faction.BLUE, "win condition occupation: BLUE should win at exactly 75 percent")

	var counts: Dictionary = battlefield.count_cells_by_team()
	_assert(int(counts.get(GameConfig.Faction.BLUE, 0)) >= target, "win condition occupation: BLUE cell count should be at least 75 percent threshold")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_occupation_no_win_below_threshold() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets_all_alive()

	var total_cells: int = 20 * 20
	var below_target: int = int(float(total_cells) * 0.70)
	_uniform_paint(battlefield, GameConfig.Faction.RED, below_target)

	var winner: int = _simulate_check_winner(battlefield, turrets)
	_eq(winner, -1, "win condition occupation: below 75 percent should not trigger win")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_timed_win_score_leader() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_TIMED)
	GameConfig.set_time_limit_minutes(5)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets_all_alive()

	_paint_sector(battlefield, 0, 0, 10, 20, GameConfig.Faction.YELLOW)
	_paint_sector(battlefield, 10, 0, 20, 10, GameConfig.Faction.YELLOW)
	_paint_sector(battlefield, 10, 10, 20, 20, GameConfig.Faction.YELLOW)

	var counts: Dictionary = battlefield.count_cells_by_team()
	_assert(int(counts.get(GameConfig.Faction.YELLOW, 0)) > int(counts.get(GameConfig.Faction.BLUE, 0)), "win condition timed: YELLOW should have most cells")
	_assert(int(counts.get(GameConfig.Faction.YELLOW, 0)) > int(counts.get(GameConfig.Faction.RED, 0)), "win condition timed: YELLOW should lead RED")
	_assert(int(counts.get(GameConfig.Faction.YELLOW, 0)) > int(counts.get(GameConfig.Faction.GREEN, 0)), "win condition timed: YELLOW should lead GREEN")

	var winner: int = _get_timed_winner(battlefield)
	_eq(winner, GameConfig.Faction.YELLOW, "win condition timed: leader at time expiry should win")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_timed_draw() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_TIMED)

	var battlefield: Battlefield = Battlefield.new()
	battlefield.configure(20)
	get_root().add_child(battlefield)
	battlefield.reset_quadrants()
	await process_frame

	var turrets: Dictionary = _mock_turrets_all_alive()
	var winner: int = _get_timed_winner(battlefield)
	_eq(winner, -1, "win condition timed: even score distribution should be draw (-1)")

	_cleanup_node(battlefield)
	_cleanup_turrets(turrets)
	await _flush()

func _test_wild_mode_gate_and_limit() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_WILD)
	_eq(GameConfig.get_gate_multiplier(), 3, "wild mode: gate multiplier should be x3")
	_eq(GameConfig.get_max_pending_count(), GameConfig.WILD_MAX_PENDING_COUNT, "wild mode: max pending should be WILD_MAX_PENDING_COUNT")
	_assert(GameConfig.get_max_pending_count() > GameConfig.BASE_MAX_PENDING_COUNT, "wild mode: max pending should exceed basic mode limit")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	_eq(GameConfig.get_gate_multiplier(), 2, "basic mode: gate multiplier should be x2")
	_eq(GameConfig.get_max_pending_count(), GameConfig.BASE_MAX_PENDING_COUNT, "basic mode: max pending should be BASE_MAX_PENDING_COUNT")

func _test_save_version_compatibility() -> void:
	var data_valid: Dictionary = {
		"save_version": "1.9.34",
		"grid_size": 40,
		"quality_name": "中",
		"game_mode_name": GameConfig.GAME_MODE_BASIC,
		"time_limit_minutes": 5,
		"factions": [],
	}
	var clean_valid: Dictionary = SaveGameCodec.validate_save_data(data_valid)
	_assert(not clean_valid.has("_invalid_reason"), "save compat: 1.9.34 version should pass")

	var data_v1_9_0: Dictionary = {
		"save_version": "1.9.0",
		"grid_size": 40,
		"quality_name": "中",
		"game_mode_name": GameConfig.GAME_MODE_BASIC,
		"time_limit_minutes": 5,
		"factions": [],
	}
	var clean_v1_9_0: Dictionary = SaveGameCodec.validate_save_data(data_v1_9_0)
	_assert(not clean_v1_9_0.has("_invalid_reason"), "save compat: 1.9.0 version should pass (prefix match)")

	var data_v2_0: Dictionary = {
		"save_version": "2.0.0",
		"grid_size": 40,
		"quality_name": "中",
		"game_mode_name": GameConfig.GAME_MODE_BASIC,
		"time_limit_minutes": 5,
		"factions": [],
	}
	var clean_v2_0: Dictionary = SaveGameCodec.validate_save_data(data_v2_0)
	_assert(clean_v2_0.has("_invalid_reason"), "save compat: 2.0.0 version should be REJECTED (major prefix is 1.9)")

# ---- helpers ----------------------------------------------------------

func _mock_turrets(overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var info: Dictionary = overrides.get(faction_id, {"is_destroyed": false})
		var mock := Node.new()
		mock.is_destroyed = bool(info.get("is_destroyed", false))
		get_root().add_child(mock)
		result[faction_id] = mock
	return result

func _mock_turrets_all_alive() -> Dictionary:
	return _mock_turrets({})

func _cleanup_turrets(turrets: Dictionary) -> void:
	for mock in turrets.values():
		_cleanup_node(mock)

func _simulate_check_winner(battlefield: Battlefield, turrets: Dictionary) -> int:
	var mode_name: String = GameConfig.get_game_mode_name()

	if mode_name == GameConfig.GAME_MODE_OCCUPATION:
		var counts: Dictionary = battlefield.count_cells_by_team()
		var total: int = 0
		var best_id: int = -1
		var best_count: int = -1
		var tied: bool = false
		for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
			var count: int = int(counts.get(faction_id, 0))
			total += count
			if count > best_count:
				best_count = count
				best_id = int(faction_id)
				tied = false
			elif count == best_count:
				tied = true
		if total <= 0 or tied:
			return -1
		var target_percent: int = GameConfig.get_occupation_target_percent()
		if best_count * 100 >= total * target_percent:
			return best_id
		return -1

	var alive: Array = []
	for faction_id in turrets.keys():
		var turret = turrets[faction_id]
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			alive.append(faction_id)

	if alive.size() == 1:
		return int(alive[0])
	elif alive.size() == 0:
		return -2
	return -1

func _get_timed_winner(battlefield: Battlefield) -> int:
	var counts: Dictionary = battlefield.count_cells_by_team()
	var best_id: int = -1
	var best_count: int = -1
	var tied: bool = false
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var count: int = int(counts.get(faction_id, 0))
		if count > best_count:
			best_count = count
			best_id = faction_id
			tied = false
		elif count == best_count:
			tied = true
	if tied:
		return -1
	return best_id

func _uniform_paint(battlefield: Battlefield, faction_id: int, target_cells: int) -> void:
	var painted: int = 0
	for x in range(battlefield.grid_size):
		for y in range(battlefield.grid_size):
			if painted >= target_cells:
				return
			battlefield.owners[x][y] = faction_id
			painted += 1
	battlefield.rebuild_owner_counts()

func _paint_sector(battlefield: Battlefield, x_start: int, y_start: int, x_end: int, y_end: int, faction_id: int) -> void:
	for x in range(x_start, mini(x_end, battlefield.grid_size)):
		for y in range(y_start, mini(y_end, battlefield.grid_size)):
			battlefield.owners[x][y] = faction_id
	battlefield.rebuild_owner_counts()
