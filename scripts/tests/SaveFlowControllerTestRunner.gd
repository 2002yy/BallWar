extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const SaveFlowController = preload("res://scripts/SaveFlowController.gd")

class MockLabel extends RefCounted:
	var text: String = ""

class MockBattlefield extends RefCounted:
	var grid_size: int = 40
	var owners: Array = [0, 1, 2, 3]

class MockEventController extends RefCounted:
	func export_save_state() -> Dictionary:
		return {"event_roulette_enabled": true}

class MockButton extends Button:
	pass

class MockContinueOwner extends RefCounted:
	var selected_palette_name: String = "default"
	var selected_quality_name: String = "mid"
	var selected_game_mode_name: String = "basic"
	var selected_time_limit_minutes: int = 5

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[SaveFlowControllerTest] v2.1.10 save-path + invalid-slot verification")

	_reset_and_assert_runtime_defaults(t, "before get_save_path")
	_test_get_save_path(t)
	_reset_and_assert_runtime_defaults(t, "after get_save_path")

	_reset_and_assert_runtime_defaults(t, "before has_save_file")
	_test_has_save_file(t)
	_reset_and_assert_runtime_defaults(t, "after has_save_file")

	_reset_and_assert_runtime_defaults(t, "before load_saved_data")
	_test_load_saved_data(t)
	_reset_and_assert_runtime_defaults(t, "after load_saved_data")

	_reset_and_assert_runtime_defaults(t, "before prepare_continue_payload")
	_test_prepare_continue_payload(t)
	_reset_and_assert_runtime_defaults(t, "after prepare_continue_payload")

	_reset_and_assert_runtime_defaults(t, "before prepare_continue_payload_integrity")
	_test_prepare_continue_payload_integrity(t)
	_reset_and_assert_runtime_defaults(t, "after prepare_continue_payload_integrity")

	_reset_and_assert_runtime_defaults(t, "before build_continue_runtime_state")
	_test_build_continue_runtime_state(t)
	_reset_and_assert_runtime_defaults(t, "after build_continue_runtime_state")

	_reset_and_assert_runtime_defaults(t, "before apply_continue_selection_state")
	_test_apply_continue_selection_state(t)
	_reset_and_assert_runtime_defaults(t, "after apply_continue_selection_state")

	_reset_and_assert_runtime_defaults(t, "before apply_continue_game_config")
	_test_apply_continue_game_config(t)
	_reset_and_assert_runtime_defaults(t, "after apply_continue_game_config")

	_reset_and_assert_runtime_defaults(t, "before build_continue_start_values")
	_test_build_continue_start_values(t)
	_reset_and_assert_runtime_defaults(t, "after build_continue_start_values")

	_reset_and_assert_runtime_defaults(t, "before prepare_continue_start_plan")
	_test_prepare_continue_start_plan(t)
	_reset_and_assert_runtime_defaults(t, "after prepare_continue_start_plan")

	_reset_and_assert_runtime_defaults(t, "before apply_continue_start_plan")
	_test_apply_continue_start_plan(t)
	_reset_and_assert_runtime_defaults(t, "after apply_continue_start_plan")

	_reset_and_assert_runtime_defaults(t, "before build_save_slot_summaries")
	_test_build_save_slot_summaries(t)
	_reset_and_assert_runtime_defaults(t, "after build_save_slot_summaries")

	_reset_and_assert_runtime_defaults(t, "before invalid_save_slot_summaries")
	_test_invalid_save_slot_summaries(t)
	_reset_and_assert_runtime_defaults(t, "after invalid_save_slot_summaries")

	_reset_and_assert_runtime_defaults(t, "before slot_selection_status_and_ui")
	await _test_slot_selection_status_and_ui(t)
	_reset_and_assert_runtime_defaults(t, "after slot_selection_status_and_ui")

	_reset_and_assert_runtime_defaults(t, "before write_game_progress")
	_test_write_game_progress(t)
	_reset_and_assert_runtime_defaults(t, "after write_game_progress")

	t.report("[SaveFlowControllerTest]")
	quit(0 if t.failures.is_empty() else 1)

func _test_get_save_path(t: TestAssert) -> void:
	var template: String = "user://slot_%d.json"
	t.eq(SaveFlowController.get_save_path(1, template, 5), "user://slot_1.json", "path keeps valid slot")
	t.eq(SaveFlowController.get_save_path(0, template, 5), "user://slot_1.json", "path clamps low slot")
	t.eq(SaveFlowController.get_save_path(9, template, 5), "user://slot_5.json", "path clamps high slot")
	t.eq(SaveFlowController.normalize_slot(-1, 3, 5), 3, "normalize uses selected slot when input below range")
	t.eq(SaveFlowController.normalize_slot(8, 3, 5), 5, "normalize clamps explicit slot")

func _test_has_save_file(t: TestAssert) -> void:
	var path_template: String = "user://saveflow_has_file_slot_%d.json"
	var slot2_path: String = SaveFlowController.get_save_path(2, path_template, 5)
	var slot2_abs: String = ProjectSettings.globalize_path(slot2_path)
	var slot2_backup_abs: String = ProjectSettings.globalize_path(SaveFlowController.get_backup_path(slot2_path))
	if FileAccess.file_exists(slot2_path):
		DirAccess.remove_absolute(slot2_abs)
	if FileAccess.file_exists(SaveFlowController.get_backup_path(slot2_path)):
		DirAccess.remove_absolute(slot2_backup_abs)

	var file := FileAccess.open(slot2_path, FileAccess.WRITE)
	if file != null:
		file.store_string("{}")

	t.that(SaveFlowController.has_save_file(2, 1, 5, path_template, "user://legacy_missing.json"), "has_save_file detects explicit slot file")
	DirAccess.remove_absolute(slot2_abs)
	var backup_file := FileAccess.open(SaveFlowController.get_backup_path(slot2_path), FileAccess.WRITE)
	if backup_file != null:
		backup_file.store_string("{}")
	t.that(SaveFlowController.has_save_file(2, 1, 5, path_template, "user://legacy_missing.json"), "has_save_file detects backup file")
	t.that(not SaveFlowController.has_save_file(3, 1, 5, path_template, "user://legacy_missing.json"), "has_save_file false when slot missing")

	if FileAccess.file_exists(slot2_path):
		DirAccess.remove_absolute(slot2_abs)
	if FileAccess.file_exists(SaveFlowController.get_backup_path(slot2_path)):
		DirAccess.remove_absolute(slot2_backup_abs)

func _test_load_saved_data(t: TestAssert) -> void:
	var path_template: String = "user://saveflow_load_slot_%d.json"
	var slot1_path: String = SaveFlowController.get_save_path(1, path_template, 5)
	var slot1_abs: String = ProjectSettings.globalize_path(slot1_path)
	var slot1_backup_path: String = SaveFlowController.get_backup_path(slot1_path)
	var slot1_backup_abs: String = ProjectSettings.globalize_path(slot1_backup_path)
	var legacy_path: String = "user://saveflow_legacy.json"
	var legacy_abs: String = ProjectSettings.globalize_path(legacy_path)

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(slot1_backup_path):
		DirAccess.remove_absolute(slot1_backup_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

	var slot_file := FileAccess.open(slot1_path, FileAccess.WRITE)
	if slot_file != null:
		slot_file.store_string("{\"save_version\":\"1.9.99\",\"grid_size\":40}")
		slot_file.flush()
		slot_file = null

	var parsed: Dictionary = SaveFlowController.load_saved_data(1, 1, 5, path_template, legacy_path, true)
	t.eq(parsed.get("grid_size", -1), 40, "load_saved_data reads slot file")

	var corrupt_file := FileAccess.open(slot1_path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{not-json")
		corrupt_file.flush()
		corrupt_file = null
	var backup_file := FileAccess.open(slot1_backup_path, FileAccess.WRITE)
	if backup_file != null:
		backup_file.store_string("{\"save_version\":\"2.0.0\",\"grid_size\":50}")
		backup_file.flush()
		backup_file = null

	var recovered: Dictionary = SaveFlowController.load_saved_data_result(1, 1, 5, path_template, legacy_path, true)
	t.that(bool(recovered.get("ok", false)), "load_saved_data_result recovers from backup")
	t.eq(int(recovered.get("data", {}).get("grid_size", -1)), 50, "load_saved_data_result uses backup payload")
	t.eq(str(recovered.get("source_kind", "")), "backup", "load_saved_data_result marks backup source")

	DirAccess.remove_absolute(slot1_abs)
	DirAccess.remove_absolute(slot1_backup_abs)
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	if legacy_file != null:
		legacy_file.store_string("{\"save_version\":\"1.9.88\",\"grid_size\":30}")
		legacy_file.flush()
		legacy_file = null

	var legacy_parsed: Dictionary = SaveFlowController.load_saved_data(1, 1, 5, path_template, legacy_path, true)
	t.eq(legacy_parsed.get("grid_size", -1), 30, "load_saved_data falls back to legacy slot 1 file")

	var missing_data: Dictionary = SaveFlowController.load_saved_data(2, 1, 5, path_template, legacy_path, true)
	t.that(missing_data.is_empty(), "load_saved_data returns empty when slot missing")

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(slot1_backup_path):
		DirAccess.remove_absolute(slot1_backup_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

func _test_prepare_continue_payload(t: TestAssert) -> void:
	var path_template: String = "user://saveflow_prepare_slot_%d.json"
	var slot1_path: String = SaveFlowController.get_save_path(1, path_template, 5)
	var slot1_abs: String = ProjectSettings.globalize_path(slot1_path)
	var slot1_backup_path: String = SaveFlowController.get_backup_path(slot1_path)
	var slot1_backup_abs: String = ProjectSettings.globalize_path(slot1_backup_path)
	var legacy_path: String = "user://saveflow_prepare_legacy.json"
	var legacy_abs: String = ProjectSettings.globalize_path(legacy_path)

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(slot1_backup_path):
		DirAccess.remove_absolute(slot1_backup_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

	var missing: Dictionary = SaveFlowController.prepare_continue_payload(1, 1, 5, path_template, legacy_path, true)
	t.that(not bool(missing.get("ok", false)), "prepare_continue_payload rejects missing save")
	t.eq(str(missing.get("error_message", "")), "\u5b58\u6863\u8bfb\u53d6\u5931\u8d25\u6216\u5b58\u6863\u5df2\u635f\u574f", "missing save message")

	var invalid_file := FileAccess.open(slot1_path, FileAccess.WRITE)
	if invalid_file != null:
		invalid_file.store_string("{\"save_version\":\"9.9.9\",\"grid_size\":40}")
		invalid_file.flush()
		invalid_file = null

	var invalid: Dictionary = SaveFlowController.prepare_continue_payload(1, 1, 5, path_template, legacy_path, true)
	t.that(not bool(invalid.get("ok", false)), "prepare_continue_payload rejects incompatible version")
	t.that(str(invalid.get("warning_message", "")).contains("9.9.9"), "incompatible version warning kept")
	DirAccess.remove_absolute(slot1_abs)

	var valid_file := FileAccess.open(slot1_path, FileAccess.WRITE)
	if valid_file != null:
		valid_file.store_string("{\"save_version\":\"2.0.0\",\"grid_size\":40,\"quality_name\":\"\u4e2d\"}")
		valid_file.flush()
		valid_file = null

	var valid_prepared: Dictionary = SaveFlowController.prepare_continue_payload(1, 1, 5, path_template, legacy_path, true)
	t.that(bool(valid_prepared.get("ok", false)), "prepare_continue_payload accepts valid save")
	t.eq(int(valid_prepared.get("data", {}).get("grid_size", -1)), 40, "prepared payload returns clean data")

	var broken_primary := FileAccess.open(slot1_path, FileAccess.WRITE)
	if broken_primary != null:
		broken_primary.store_string("{bad-json")
		broken_primary.flush()
		broken_primary = null
	var backup_valid := FileAccess.open(slot1_backup_path, FileAccess.WRITE)
	if backup_valid != null:
		backup_valid.store_string("{\"save_version\":\"2.0.0\",\"grid_size\":30,\"quality_name\":\"\u4e2d\"}")
		backup_valid.flush()
		backup_valid = null
	var recovered_prepare: Dictionary = SaveFlowController.prepare_continue_payload(1, 1, 5, path_template, legacy_path, true)
	t.that(bool(recovered_prepare.get("ok", false)), "prepare_continue_payload accepts recovered backup save")
	t.eq(str(recovered_prepare.get("status_message", "")), SaveFlowController.BACKUP_RECOVERED_STATUS_MESSAGE, "prepare_continue_payload exposes backup recovery status")

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(slot1_backup_path):
		DirAccess.remove_absolute(slot1_backup_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

func _test_prepare_continue_payload_integrity(t: TestAssert) -> void:
	var path_template: String = "user://saveflow_prepare_integrity_slot_%d.json"
	var slot1_path: String = SaveFlowController.get_save_path(1, path_template, 5)
	var slot1_abs: String = ProjectSettings.globalize_path(slot1_path)
	var legacy_path: String = "user://saveflow_prepare_integrity_legacy.json"
	var legacy_abs: String = ProjectSettings.globalize_path(legacy_path)

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

	var tampered_payload: Dictionary = SaveGameCodec.attach_payload_hash({
		"save_version": "2.0.0",
		"grid_size": 40,
		"quality_name": GameConfig.QUALITY_MEDIUM,
		"game_mode_name": GameConfig.GAME_MODE_BASIC,
	})
	tampered_payload["grid_size"] = 60

	var tampered_file := FileAccess.open(slot1_path, FileAccess.WRITE)
	if tampered_file != null:
		tampered_file.store_string(JSON.stringify(tampered_payload))
		tampered_file.close()

	var prepared: Dictionary = SaveFlowController.prepare_continue_payload(1, 1, 5, path_template, legacy_path, true)
	t.that(bool(prepared.get("ok", false)), "prepare_continue_payload should keep tampered but readable saves playable")
	t.eq(str(prepared.get("status_message", "")), SaveFlowController.SAVE_INTEGRITY_STATUS_MESSAGE, "prepare_continue_payload should expose integrity repair status")
	t.eq(str(prepared.get("warning_message", "")), SaveFlowController.SAVE_INTEGRITY_WARNING_MESSAGE, "prepare_continue_payload should expose integrity repair warning")
	t.eq(int(prepared.get("data", {}).get("grid_size", -1)), 60, "prepare_continue_payload repair mode should continue with sanitized tampered payload")

	if FileAccess.file_exists(slot1_path):
		DirAccess.remove_absolute(slot1_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_abs)

func _test_build_continue_runtime_state(t: TestAssert) -> void:
	var state: Dictionary = SaveFlowController.build_continue_runtime_state(
		{
			"palette_name": "\u7ecf\u5178",
			"quality_name": "\u9ad8",
			"game_mode_name": GameConfig.GAME_MODE_TIMED,
			"time_limit_minutes": 999,
			"grid_size": 40,
			"game_elapsed_time": -3.0,
		},
		5
	)

	t.eq(str(state.get("palette_name", "")), "\u7ecf\u5178", "continue runtime keeps palette")
	t.eq(str(state.get("quality_name", "")), "\u9ad8", "continue runtime keeps quality")
	t.eq(str(state.get("game_mode_name", "")), GameConfig.GAME_MODE_TIMED, "continue runtime keeps game mode")
	t.eq(int(state.get("time_limit_minutes", -1)), GameConfig.TIMED_MODE_MAX_MINUTES, "continue runtime clamps time limit")
	t.eq(int(state.get("grid_size", -1)), 40, "continue runtime keeps sanitized grid size")
	t.eq(float(state.get("game_elapsed_time", -1.0)), 0.0, "continue runtime clamps negative elapsed time")

func _test_apply_continue_selection_state(t: TestAssert) -> void:
	var owner := MockContinueOwner.new()
	var applied: Dictionary = SaveFlowController.apply_continue_selection_state({
		"selected_palette_name": "\u7ecf\u5178",
		"selected_quality_name": "\u9ad8",
		"selected_game_mode_name": GameConfig.GAME_MODE_TIMED,
		"selected_time_limit_minutes": 9,
	}, owner)

	t.eq(owner.selected_palette_name, "\u7ecf\u5178", "apply continue selection sets palette")
	t.eq(owner.selected_quality_name, "\u9ad8", "apply continue selection sets quality")
	t.eq(owner.selected_game_mode_name, GameConfig.GAME_MODE_TIMED, "apply continue selection sets mode")
	t.eq(owner.selected_time_limit_minutes, 9, "apply continue selection sets time limit")
	t.eq(str(applied.get("selected_quality_name", "")), "\u9ad8", "apply continue selection returns selection state")

func _test_apply_continue_game_config(t: TestAssert) -> void:
	var applied: Dictionary = SaveFlowController.apply_continue_game_config({
		"palette_name": "\u7ecf\u5178",
		"quality_name": "\u4e2d",
		"game_mode_name": GameConfig.GAME_MODE_TIMED,
		"time_limit_minutes": 7,
	})

	t.eq(str(applied.get("palette_name", "")), "\u7ecf\u5178", "apply continue config returns palette")
	t.eq(str(applied.get("quality_name", "")), "\u4e2d", "apply continue config returns quality")
	t.eq(str(applied.get("game_mode_name", "")), GameConfig.GAME_MODE_TIMED, "apply continue config returns mode")
	t.eq(int(applied.get("time_limit_minutes", -1)), 7, "apply continue config returns time limit")

func _test_build_continue_start_values(t: TestAssert) -> void:
	var values: Dictionary = SaveFlowController.build_continue_start_values({
		"grid_size": 60,
		"game_elapsed_time": 18.5,
	})

	t.eq(int(values.get("grid_size", -1)), 60, "continue start values keep grid size")
	t.eq(float(values.get("game_elapsed_time", -1.0)), 18.5, "continue start values keep elapsed time")

func _test_prepare_continue_start_plan(t: TestAssert) -> void:
	var before_palette: String = GameConfig.get_palette_name()
	var before_quality: String = GameConfig.get_quality_name()
	var before_mode: String = GameConfig.get_game_mode_name()
	var before_minutes: int = GameConfig.get_time_limit_minutes()
	var plan: Dictionary = SaveFlowController.prepare_continue_start_plan({
		"palette_name": "\u7ecf\u5178",
		"quality_name": "\u9ad8",
		"game_mode_name": GameConfig.GAME_MODE_TIMED,
		"time_limit_minutes": 6,
		"grid_size": 80,
		"game_elapsed_time": 12.0,
	}, 5)

	t.eq(int(plan.get("data", {}).get("grid_size", -1)), 40, "continue start plan sanitizes grid size")
	t.eq(str(plan.get("game_config", {}).get("game_mode_name", "")), GameConfig.GAME_MODE_TIMED, "continue start plan exposes pure config state")
	t.eq(float(plan.get("start_values", {}).get("game_elapsed_time", -1.0)), 12.0, "continue start plan exposes start values")
	t.eq(str(plan.get("selection_state", {}).get("selected_game_mode_name", "")), GameConfig.GAME_MODE_TIMED, "continue start plan exposes selection state")
	t.eq(str(plan.get("game_config", {}).get("quality_name", "")), "\u9ad8", "continue start plan exposes quality in config state")
	t.eq(int(plan.get("game_config", {}).get("time_limit_minutes", -1)), 6, "continue start plan exposes time limit in config state")
	t.eq(str(plan.get("banner", {}).get("subtitle", "")), "\u7ee7\u7eed\u4f5c\u6218", "continue start plan exposes banner config")
	t.eq(str(plan.get("banner", {}).get("title", "")), "\u9886\u571f\u6218\u4e89", "continue start plan exposes banner title")
	t.that(not plan.has("applied_config"), "continue start plan drops legacy applied_config key")
	t.that(not plan.has("banner_title"), "continue start plan drops legacy flattened banner keys")
	t.eq(GameConfig.get_palette_name(), before_palette, "continue start prepare should not mutate palette config")
	t.eq(GameConfig.get_quality_name(), before_quality, "continue start prepare should not mutate quality config")
	t.eq(GameConfig.get_game_mode_name(), before_mode, "continue start prepare should not mutate mode config")
	t.eq(GameConfig.get_time_limit_minutes(), before_minutes, "continue start prepare should not mutate time limit config")

func _test_apply_continue_start_plan(t: TestAssert) -> void:
	GameConfig.set_palette_by_name("\u7ecf\u5178")
	GameConfig.set_quality_by_name("\u4f4e")
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	GameConfig.set_time_limit_minutes(5)
	var owner := MockContinueOwner.new()
	var plan: Dictionary = SaveFlowController.prepare_continue_start_plan({
		"palette_name": "\u7ecf\u5178",
		"quality_name": "\u9ad8",
		"game_mode_name": GameConfig.GAME_MODE_TIMED,
		"time_limit_minutes": 8,
		"grid_size": 50,
		"game_elapsed_time": 24.0,
	}, 5)
	var applied: Dictionary = SaveFlowController.apply_continue_start_plan(plan, owner)

	t.eq(owner.selected_quality_name, "\u9ad8", "apply continue start plan updates owner selection state")
	t.eq(owner.selected_game_mode_name, GameConfig.GAME_MODE_TIMED, "apply continue start plan updates owner game mode")
	t.eq(owner.selected_time_limit_minutes, 8, "apply continue start plan updates owner time limit")
	t.eq(GameConfig.get_quality_name(), "\u9ad8", "apply continue start plan applies quality config")
	t.eq(GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_TIMED, "apply continue start plan applies game mode config")
	t.eq(GameConfig.get_time_limit_minutes(), 8, "apply continue start plan applies time limit config")
	t.eq(str(applied.get("game_config", {}).get("quality_name", "")), "\u9ad8", "apply continue start plan returns applied config state")
	t.eq(str(applied.get("selection_state", {}).get("selected_quality_name", "")), "\u9ad8", "apply continue start plan returns applied selection state")

func _test_build_save_slot_summaries(t: TestAssert) -> void:
	var summaries: Array = SaveFlowController.build_save_slot_summaries(
		4,
		func(slot: int, _allow_legacy: bool) -> Dictionary:
			if slot == 2:
				return {
					"save_version": "9.9.9",
					"grid_size": 60,
					"game_mode_name": GameConfig.GAME_MODE_TIMED,
					"quality_name": "\u9ad8",
					"game_elapsed_time": 125.0,
				}
			if slot == 3:
				return {
					"save_version": "2.0.0",
					"_invalid_reason": "\u575f\u6863",
				}
			if slot == 4:
				return {
					"grid_size": 60,
					"game_mode_name": GameConfig.GAME_MODE_TIMED,
					"quality_name": "\u9ad8",
					"game_elapsed_time": 125.0,
					"save_version": "2.0.0",
				}
			return {}
	)

	t.eq(summaries.size(), 4, "summary count matches slot count")
	t.that(not summaries[0]["has_data"], "empty slot marked empty")
	t.eq(summaries[0]["title"], "\u7a7a\u5b58\u6863", "empty slot title")
	t.eq(str(summaries[1]["state"]), "incompatible", "unsupported save version marked incompatible")
	t.eq(summaries[1]["title"], "\u7248\u672c\u4e0d\u517c\u5bb9", "incompatible slot title")
	t.that(not bool(summaries[1]["is_playable"]), "incompatible slot not playable")
	t.eq(str(summaries[2]["state"]), "damaged", "missing grid size marked damaged")
	t.eq(summaries[2]["title"], "\u5b58\u6863\u635f\u574f", "damaged slot title")
	t.that(not bool(summaries[2]["is_playable"]), "damaged slot not playable")
	t.that(bool(summaries[3]["has_data"]), "filled slot marked filled")
	t.eq(summaries[3]["title"], "%s\uFF5C%d\u00D7%d\uFF5C%s" % [GameConfig.GAME_MODE_TIMED, 60, 60, "\u9ad8"], "filled slot title format")
	t.that(str(summaries[3]["detail"]).contains("02:05"), "filled slot detail includes formatted time")
	t.that(str(summaries[3]["detail"]).contains("2.0.0"), "filled slot detail includes version")


func _test_invalid_save_slot_summaries(t: TestAssert) -> void:
	var path_template: String = "user://saveflow_invalid_slot_%d.json"
	var legacy_path: String = "user://saveflow_invalid_legacy.json"
	for slot in [1, 2]:
		var slot_path: String = SaveFlowController.get_save_path(slot, path_template, 5)
		var slot_abs: String = ProjectSettings.globalize_path(slot_path)
		if FileAccess.file_exists(slot_path):
			DirAccess.remove_absolute(slot_abs)
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

	var damaged_file := FileAccess.open(SaveFlowController.get_save_path(1, path_template, 5), FileAccess.WRITE)
	if damaged_file != null:
		damaged_file.store_string("{bad-json")
		damaged_file.flush()
		damaged_file = null

	var incompatible_file := FileAccess.open(SaveFlowController.get_save_path(2, path_template, 5), FileAccess.WRITE)
	if incompatible_file != null:
		incompatible_file.store_string("{\"save_version\":\"9.9.9\",\"grid_size\":40,\"quality_name\":\"\\u9ad8\"}")
		incompatible_file.flush()
		incompatible_file = null

	var summaries: Array = SaveFlowController.build_save_slot_summaries(
		2,
		func(slot: int, allow_legacy: bool) -> Dictionary:
			return SaveFlowController.load_saved_data(slot, 1, 5, path_template, legacy_path, allow_legacy)
	)

	t.eq(str(summaries[0]["state"]), "empty", "damaged json without recovery should not appear readable")
	t.that(not bool(summaries[0]["is_playable"]), "damaged json slot not playable")
	t.eq(str(summaries[1]["state"]), "incompatible", "unsupported version slot stays incompatible")
	t.eq(summaries[1]["title"], "\u7248\u672c\u4e0d\u517c\u5bb9", "unsupported version title remains incompatible")
	t.that(not bool(summaries[1]["is_playable"]), "unsupported version slot not playable")

	for slot in [1, 2]:
		var slot_path: String = SaveFlowController.get_save_path(slot, path_template, 5)
		if FileAccess.file_exists(slot_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path))
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))

func _test_slot_selection_status_and_ui(t: TestAssert) -> void:
	t.eq(
		SaveFlowController.build_slot_selection_status(2, true),
		"\u5df2\u9009\u62e9\u5b58\u6863\u69fd 2\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863",
		"filled slot status message"
	)
	t.eq(
		SaveFlowController.build_slot_selection_status(4, false),
		"\u5df2\u9009\u62e9\u7a7a\u5b58\u6863\u69fd 4\uff0c\u65b0\u6e38\u620f\u4f1a\u4fdd\u5b58\u5728\u8fd9\u91cc",
		"empty slot status message"
	)

	var root := Control.new()
	get_root().add_child(root)
	var button1 := MockButton.new()
	var button2 := MockButton.new()
	root.add_child(button1)
	root.add_child(button2)
	var continue_button := MockButton.new()
	root.add_child(continue_button)

	SaveFlowController.refresh_menu_slot_ui(
		{1: button1, 2: button2},
		2,
		[
			{"slot": 1, "state": "empty", "title": "\u7a7a\u5b58\u6863"},
			{"slot": 2, "state": "valid", "title": "\u57fa\u7840\u6a21\u5f0f\uFF5C40\u00D740\uFF5C\u4e2d"},
		],
		continue_button,
		true
	)

	t.eq(button1.text, "\u69fd1\uFF5C\u7a7a", "slot 1 text format")
	t.eq(button2.text, "\u25cf \u69fd2\uFF5C\u57fa\u7840\uFF5C40\u00D740\uFF5C\u4e2d", "slot 2 selected text format")
	t.that(not continue_button.disabled, "continue button enabled when selected slot has save")
	t.eq(continue_button.text, "\u8bfb\u53d6\u69fd2", "continue button text format")

	root.queue_free()
	await process_frame

func _test_write_game_progress(t: TestAssert) -> void:
	var save_path: String = "user://saveflow_controller_test_slot_2.json"
	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var backup_path: String = SaveFlowController.get_backup_path(save_path)
	var backup_abs: String = ProjectSettings.globalize_path(backup_path)
	var temp_path: String = SaveFlowController.get_temp_path(save_path)
	var temp_abs: String = ProjectSettings.globalize_path(temp_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_abs)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_abs)

	var winner_label := MockLabel.new()
	winner_label.text = "winner"
	var ok: bool = SaveFlowController.write_game_progress(
		2,
		"user://saveflow_controller_test_slot_%d.json",
		5,
		{},
		{},
		MockBattlefield.new(),
		null,
		MockEventController.new(),
		42.5,
		false,
		winner_label
	)

	t.that(ok, "save write returns true")
	t.that(FileAccess.file_exists(save_path), "save file created")
	var file := FileAccess.open(save_path, FileAccess.READ)
	t.that(file != null, "save file readable")
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		t.that(parsed is Dictionary, "save file contains dictionary json")
		if parsed is Dictionary:
			t.eq(parsed.get("save_slot", -1), 2, "save payload keeps selected slot")
			t.eq(parsed.get("grid_size", -1), 40, "save payload keeps battlefield grid")
			t.eq(parsed.get("winner_text", ""), "winner", "save payload keeps winner text")
			t.that(parsed.has(SaveGameCodec.PAYLOAD_HASH_KEY), "save payload should include integrity hash")
		file = null

	var second_result: Dictionary = SaveFlowController.write_game_progress_result(
		2,
		"user://saveflow_controller_test_slot_%d.json",
		5,
		{},
		{},
		MockBattlefield.new(),
		null,
		MockEventController.new(),
		99.0,
		false,
		winner_label
	)
	t.that(bool(second_result.get("ok", false)), "atomic save result returns ok")
	t.that(FileAccess.file_exists(backup_path), "backup file created on overwrite")
	t.that(not FileAccess.file_exists(temp_path), "temp file cleaned after atomic save")

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_abs)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_abs)


func _reset_and_assert_runtime_defaults(t: TestAssert, context: String) -> void:
	GameConfig.reset_runtime_defaults()
	t.eq(GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_BASIC, "%s mode reset" % context)
	t.eq(GameConfig.get_quality_name(), GameConfig.QUALITY_MEDIUM, "%s quality reset" % context)
	t.eq(GameConfig.get_palette_name(), "\u7ecf\u5178", "%s palette reset" % context)
