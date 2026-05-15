extends SceneTree

const Fixtures = preload("res://scripts/tests/TestFixtures.gd")
const MainScene = preload("res://scripts/Main.gd")

var _assert: TestAssert


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert = TestAssert.new()
	print("[EndToEndContinueMain] v2.1.0 — full save/continue cycle through Main.gd")
	await process_frame

	_cleanup_all()

	await _test_full_save_continue_cycle()
	await _flush()
	await _test_save_structure()
	await _flush()
	await _test_continue_restores_subsystems()
	await _flush()

	_assert.report("[EndToEndContinueMain]")

	if _assert.failures.is_empty():
		quit(0)
	else:
		quit(1)


func _flush() -> void:
	await process_frame
	await process_frame


func _cleanup_all() -> void:
	GameConfig.reset_runtime_defaults()
	_remove_if_exists(ProjectSettings.globalize_path("user://menu_preferences.json"))
	for slot in range(1, 10):
		for ext in ["", ".bak", ".tmp"]:
			_remove_if_exists(ProjectSettings.globalize_path("user://ballwar_save_slot_%d.save%s" % [slot, ext]))
		_remove_if_exists(ProjectSettings.globalize_path("user://ballwar_save_slot_%d.json" % slot))
	_remove_if_exists(ProjectSettings.globalize_path("user://ballwar_save.json"))


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _make_main(grid_size: int = 20) -> Node2D:
	GameConfig.reset_runtime_defaults()
	var main: Node2D = MainScene.new()
	main.name = "E2E_Main"
	main.selected_grid_size = grid_size
	main.selected_palette_name = "经典"
	main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	main.selected_time_limit_minutes = 5
	main.selected_save_slot = 1
	GameConfig.set_palette_by_name("经典")
	GameConfig.set_quality_by_name(GameConfig.QUALITY_MEDIUM)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	GameConfig.set_time_limit_minutes(5)
	return main


func _add_and_start(main: Node2D, mode_name: String, slot: int, grid_size: int) -> void:
	get_root().add_child(main)
	main.selected_save_slot = slot
	main.selected_game_mode_name = mode_name
	GameConfig.set_game_mode_by_name(mode_name)
	main._start_game(grid_size, true, false)
	await _flush()
	await _flush()
	await _flush()


# ======================================================================
# P1 — full save → exit → continue (OCCUPATION, 20×20)
# ======================================================================

func _test_full_save_continue_cycle() -> void:
	print("  [E2E] save → exit → continue (OCCUPATION / 20×20)")

	var main: Node2D = _make_main(20)
	await _add_and_start(main, GameConfig.GAME_MODE_OCCUPATION, 1, 20)

	_assert.that(main.runtime.battlefield != null, "start: battlefield created")
	_assert.that(main.runtime.turrets.size() == 4, "start: 4 turrets")
	_assert.that(main.runtime.chambers.size() == 4, "start: 4 chambers")

	var bf = main.runtime.battlefield
	if bf != null and is_instance_valid(bf):
		bf.apply_bullet(Vector2i(1, 1), GameConfig.Faction.RED)
		bf.apply_bullet(Vector2i(2, 2), GameConfig.Faction.RED)
		bf.apply_bullet(Vector2i(3, 3), GameConfig.Faction.GREEN)
		bf.apply_bullet(Vector2i(16, 5), GameConfig.Faction.YELLOW)
		bf.apply_bullet(Vector2i(17, 5), GameConfig.Faction.YELLOW)
		bf.apply_bullet(Vector2i(18, 5), GameConfig.Faction.YELLOW)

	for fid in main.runtime.turrets.keys():
		var t = main.runtime.turrets[fid]
		if t != null and is_instance_valid(t):
			t.health -= 5

	var cr = main.runtime.chambers.get(GameConfig.Faction.RED, null)
	if cr != null and is_instance_valid(cr):
		cr.is_locked = true
		cr.pending_count = 12

	var cb = main.runtime.chambers.get(GameConfig.Faction.BLUE, null)
	if cb != null and is_instance_valid(cb):
		cb.is_damaged = true

	main.game_elapsed_time = 142.0

	var counts_before: Dictionary = bf.count_cells_by_team() if bf != null and is_instance_valid(bf) else {}
	var turret_hp_before: Dictionary = {}
	for fid in main.runtime.turrets.keys():
		var t = main.runtime.turrets[fid]
		if t != null and is_instance_valid(t):
			turret_hp_before[fid] = t.health

	_assert.that(main._save_game_progress().get("ok", false), "save: write succeeded")

	main._save_and_exit_to_menu()
	await _flush()
	await _flush()

	_assert.that(main.runtime.battlefield == null, "cleanup: battlefield null")

	main.selected_save_slot = 1
	main.selected_game_mode_name = GameConfig.GAME_MODE_OCCUPATION
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)
	main._continue_saved_game()
	await _flush()
	await _flush()
	await _flush()
	await _flush()

	_assert.that(main.runtime.battlefield != null, "continue: battlefield restored")
	_assert.eq(main.runtime.turrets.size(), 4, "continue: 4 turrets")
	_assert.eq(main.runtime.chambers.size(), 4, "continue: 4 chambers")

	var bf2 = main.runtime.battlefield
	if bf2 != null and is_instance_valid(bf2):
		var counts_after: Dictionary = bf2.count_cells_by_team()
		for fid in counts_before.keys():
			_assert.eq(int(counts_after.get(fid, -1)), int(counts_before[fid]), "continue: faction %d grid" % fid)

	for fid in turret_hp_before.keys():
		var t = main.runtime.turrets.get(fid, null)
		if t != null and is_instance_valid(t):
			_assert.eq(t.health, int(turret_hp_before[fid]), "continue: turret %d hp" % fid)

	var cr2 = main.runtime.chambers.get(GameConfig.Faction.RED, null)
	if cr2 != null and is_instance_valid(cr2):
		_assert.eq(cr2.pending_count, 12, "continue: RED pending=12")
		_assert.that(cr2.is_locked, "continue: RED locked")

	var cb2 = main.runtime.chambers.get(GameConfig.Faction.BLUE, null)
	if cb2 != null and is_instance_valid(cb2):
		_assert.that(cb2.is_damaged, "continue: BLUE damaged")

	_assert.eq(GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_OCCUPATION, "continue: mode=OCCUPATION")

	Fixtures.cleanup_node(main)


# ======================================================================
# P2 — save structure (WILD / 10×10, direct save)
# ======================================================================

func _test_save_structure() -> void:
	print("  [E2E] save file structure (WILD / 10×10)")

	var main: Node2D = _make_main(10)
	await _add_and_start(main, GameConfig.GAME_MODE_WILD, 2, 10)

	var bf = main.runtime.battlefield
	if bf != null and is_instance_valid(bf):
		for x in range(10):
			bf.apply_bullet(Vector2i(x, 0), GameConfig.Faction.BLUE)

	_assert.that(main._save_game_progress().get("ok", false), "struct: save succeeded")

	var raw_data: Dictionary = main._load_saved_data(2, true)
	_assert.that(not raw_data.is_empty(), "struct: data loaded")
	_assert.eq(int(raw_data.get("grid_size", 0)), 10, "struct: grid_size=10")
	_assert.eq(str(raw_data.get("save_version", "")), SaveGameCodec.SAVE_SCHEMA_VERSION, "struct: save_version")
	_assert.eq(str(raw_data.get("game_mode_name", "")), GameConfig.GAME_MODE_WILD, "struct: mode=WILD")
	_assert.eq(str(raw_data.get("quality_name", "")), GameConfig.QUALITY_MEDIUM, "struct: quality=中")
	_assert.that(raw_data.has("owners"), "struct: owners present")
	_assert.that(raw_data.has("factions"), "struct: factions present")
	_assert.that(raw_data.has("event_state"), "struct: event_state present")
	_assert.that(raw_data.has("bullets"), "struct: bullets present")

	var owners: Array = raw_data.get("owners", [])
	_assert.eq(owners.size(), 10, "struct: 10 cols")
	if owners.size() == 10 and owners[0] is Array:
		_assert.eq(int(owners[0][0]), GameConfig.Faction.BLUE, "struct: cell (0,0) BLUE")

	var factions: Array = raw_data.get("factions", [])
	_assert.eq(factions.size(), 4, "struct: 4 factions")
	for fs in factions:
		if fs is Dictionary:
			var fid: int = int(fs.get("faction_id", -1))
			_assert.between(fid, 0, 3, "struct: valid faction_id")
			_assert.that(fs.has("chamber_pending_count"), "struct: faction %d pending" % fid)
			_assert.that(fs.has("turret_health"), "struct: faction %d hp" % fid)

	Fixtures.cleanup_node(main)


# ======================================================================
# P3 — continue restores: gametime, chamber pending, event state
# ======================================================================

func _test_continue_restores_subsystems() -> void:
	print("  [E2E] continue restores gametime + pending + events")

	var main: Node2D = _make_main(20)
	await _add_and_start(main, GameConfig.GAME_MODE_BASIC, 3, 20)

	var bf = main.runtime.battlefield
	if bf != null and is_instance_valid(bf):
		bf.apply_bullet(Vector2i(5, 5), GameConfig.Faction.GREEN)

	for fid in main.runtime.chambers.keys():
		var c = main.runtime.chambers[fid]
		if c != null and is_instance_valid(c):
			c.pending_count = fid * 3 + 5

	main.game_elapsed_time = 215.5

	if main.runtime.event_controller != null:
		main.runtime.event_controller.next_event_time_left = 38.0
		main.runtime.event_controller.last_event_faction = GameConfig.Faction.YELLOW
		main.runtime.event_controller.last_event_effect = EventRouletteController.EFFECT_X2

	var gametime_before: float = main.game_elapsed_time
	var pending_before: Dictionary = {}
	for fid in main.runtime.chambers.keys():
		var c = main.runtime.chambers[fid]
		if c != null and is_instance_valid(c):
			pending_before[fid] = c.pending_count

	var ev_time_before: float = 0.0
	var ev_faction_before: int = -1
	var ev_effect_before: String = ""
	if main.runtime.event_controller != null:
		ev_time_before = main.runtime.event_controller.next_event_time_left
		ev_faction_before = main.runtime.event_controller.last_event_faction
		ev_effect_before = main.runtime.event_controller.last_event_effect

	_assert.that(main._save_game_progress().get("ok", false), "subsys: save succeeded")

	main._save_and_exit_to_menu()
	await _flush()
	await _flush()

	main.selected_save_slot = 3
	main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	main._continue_saved_game()
	await _flush()
	await _flush()
	await _flush()

	_assert.between(main.game_elapsed_time, gametime_before - 0.5, gametime_before + 0.5,
		"subsys: gametime ~%.1f" % gametime_before)

	for fid in pending_before.keys():
		var c = main.runtime.chambers.get(fid, null)
		if c != null and is_instance_valid(c):
			_assert.eq(c.pending_count, int(pending_before[fid]),
				"subsys: chamber %d pending=%d" % [fid, int(pending_before[fid])])

	if main.runtime.event_controller != null:
		_assert.between(main.runtime.event_controller.next_event_time_left, ev_time_before - 1.0, ev_time_before + 1.0,
			"subsys: event countdown")
		_assert.eq(main.runtime.event_controller.last_event_faction, ev_faction_before,
			"subsys: last_event_faction")
		_assert.eq(main.runtime.event_controller.last_event_effect, ev_effect_before,
			"subsys: last_event_effect")
		_assert.that(main.runtime.event_controller.event_roulette_enabled, "subsys: event enabled")

	Fixtures.cleanup_node(main)
