extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const SaveGameCodec = preload("res://scripts/SaveGameCodec.gd")
const SaveFlowController = preload("res://scripts/SaveFlowController.gd")
const ControlChamberScript = preload("res://scripts/ControlChamber.gd")

const TEMP_SAVE_PATH: String = "user://t21_float_roundtrip.save"

var _sample_values: Array[float] = [
	1.0 / 60.0,
	-1.0 / 60.0,
	1.2666666666666666,
	21.91684488932269,
	4.24999999999999,
	0.1,
	1.0 / 3.0,
	1e-9,
	1234567.8901234567,
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[SaveBitExactnessTest] float64 must survive JSON + save pipeline bit-exactly")
	_test_codec_roundtrip(t)
	_test_file_roundtrip(t)
	_test_legacy_number_payload_still_loads(t)
	_test_left_gate_keeps_pending_in_sync(t)
	t.report("SaveBitExactnessTest")
	quit(0 if t.failures.is_empty() else 1)


func _bits(value: float) -> String:
	return var_to_bytes(value).hex_encode()


func _test_codec_roundtrip(t: TestAssert) -> void:
	var payload: Dictionary = {
		"floats": _sample_values.duplicate(),
		"nested": {"pair": [_sample_values[0], _sample_values[1]]},
		"int_value": 42,
		"text": "keep me",
	}
	var decoded = SaveGameCodec.decode_floats(JSON.parse_string(JSON.stringify(SaveGameCodec.encode_floats(payload), "", true, true)))
	t.that(decoded is Dictionary, "decoded payload must stay a Dictionary")
	if not (decoded is Dictionary):
		return
	t.eq(int(decoded.get("int_value", 0)), 42, "ints must stay ints")
	t.eq(str(decoded.get("text", "")), "keep me", "strings must stay strings")
	for i in range(_sample_values.size()):
		t.eq(_bits(float(decoded["floats"][i])), _bits(_sample_values[i]), "codec float bit-exact [%d]" % i)
	t.eq(_bits(float(decoded["nested"]["pair"][0])), _bits(_sample_values[0]), "codec nested float bit-exact")
	t.eq(_bits(float(decoded["nested"]["pair"][1])), _bits(_sample_values[1]), "codec nested negative float bit-exact")


func _test_file_roundtrip(t: TestAssert) -> void:
	var data: Dictionary = {
		"game_elapsed_time": _sample_values[2],
		"win_check_timer": _sample_values[1],
		"factions": [{"turret_burst_timer": _sample_values[1], "turret_sweep_phase": _sample_values[3]}],
	}
	var write_result: Dictionary = SaveFlowController._write_json_atomically(TEMP_SAVE_PATH, data)
	t.that(bool(write_result.get("ok", false)), "atomic write must succeed")
	var read_result: Dictionary = SaveFlowController._read_save_dictionary(TEMP_SAVE_PATH)
	t.that(bool(read_result.get("ok", false)), "atomic read must succeed")
	var restored: Dictionary = read_result.get("data", {})
	t.eq(_bits(float(restored.get("game_elapsed_time", 0.0))), _bits(_sample_values[2]), "game_elapsed_time bit-exact after file round-trip")
	t.eq(_bits(float(restored.get("win_check_timer", 0.0))), _bits(_sample_values[1]), "negative win_check_timer bit-exact after file round-trip")
	var faction: Dictionary = (restored.get("factions", []) as Array)[0]
	t.eq(_bits(float(faction.get("turret_burst_timer", 0.0))), _bits(_sample_values[1]), "turret_burst_timer bit-exact after file round-trip")
	t.eq(_bits(float(faction.get("turret_sweep_phase", 0.0))), _bits(_sample_values[3]), "turret_sweep_phase bit-exact after file round-trip")
	_remove_temp_file()


func _test_legacy_number_payload_still_loads(t: TestAssert) -> void:
	# 旧存档是普通 JSON 数字，没有 __f64 标记，必须继续按浮点读入。
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	t.that(file != null, "legacy save fixture must open")
	if file == null:
		return
	file.store_string('{"game_elapsed_time": 12.25, "factions": [{"turret_burst_timer": -0.0166666666666667}]}')
	file.close()
	var read_result: Dictionary = SaveFlowController._read_save_dictionary(TEMP_SAVE_PATH)
	var restored: Dictionary = read_result.get("data", {})
	t.eq(float(restored.get("game_elapsed_time", 0.0)), 12.25, "legacy numeric float still parses")
	var faction: Dictionary = (restored.get("factions", []) as Array)[0]
	t.eq(float(faction.get("turret_burst_timer", 0.0)), -0.0166666666666667, "legacy negative timer still parses")
	_remove_temp_file()


func _test_left_gate_keeps_pending_in_sync(t: TestAssert) -> void:
	# 回归：左门倍率必须同时更新 shadow 与 chamber_state，否则存档写的是
	# shadow、读回的是 chamber_state，续局后 pending 会分叉。
	var chamber = ControlChamberScript.new()
	root.add_child(chamber)
	chamber.pending_count = 1
	chamber.chamber_state.pending_count = 1
	chamber._on_left_gate(null)
	var expected: int = clampi(1 * GameConfig.get_gate_multiplier(), 1, GameConfig.get_max_pending_count())
	t.eq(int(chamber.pending_count), expected, "left gate multiplies shadow pending")
	t.eq(int(chamber.chamber_state.pending_count), expected, "left gate multiplies chamber_state pending")
	t.eq(int(chamber.pending_count), int(chamber.chamber_state.pending_count), "shadow and chamber_state stay in sync")
	chamber.queue_free()


func _remove_temp_file() -> void:
	if FileAccess.file_exists(TEMP_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE_PATH))
