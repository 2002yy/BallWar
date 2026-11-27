extends SceneTree

# E01-A baseline harness.
#
# Runs one classic 40x40 match headlessly with a fixed seed and prints a
# sampled timeline, so two runs can be diffed for determinism.
#
# Usage:
#   BALLWAR_MATCH_SEED=12345 <godot> --headless --fixed-fps 60 \
#       --path . --script res://scripts/tests/MatchBaselineRunner.gd
#
# This runner does not assert gameplay correctness. It only records what
# happened. Exit code 0 means the capture completed, not that the match was
# "good".

const MainScene = preload("res://scripts/Main.gd")

const GRID_SIZE: int = 40
var max_sim_seconds: float = 300.0
const SAMPLE_EVERY_SECONDS: float = 10.0

var _main = null
var _ticks_per_second: int = 60
var _frame: int = 0

var _seed_used: int = 0
var _digests: Array[String] = []

var _t_first_bullet: float = -1.0
var _t_first_convert: float = -1.0
var _t_first_destroy: float = -1.0
var _t_end: float = -1.0
var _lead_changes: int = 0
var _last_leader: int = -1
var _initial_counts: Dictionary = {}
var _final_counts: Dictionary = {}
var _next_sample_at: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_seed_used = _read_seed()
	var raw_seconds: String = OS.get_environment("BALLWAR_MATCH_SECONDS")
	if raw_seconds.is_valid_float() and float(raw_seconds) > 0.0:
		max_sim_seconds = float(raw_seconds)
	_ticks_per_second = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	if _ticks_per_second <= 0:
		_ticks_per_second = 60

	print("[MatchBaseline] seed=%d grid=%d quality=%s mode=%s tick=%d" % [
		_seed_used, GRID_SIZE, GameConfig.QUALITY_MEDIUM,
		GameConfig.GAME_MODE_BASIC, _ticks_per_second
	])

	GameConfig.reset_runtime_defaults()
	GameConfig.set_quality_by_name(GameConfig.QUALITY_MEDIUM)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	_main = MainScene.new()
	_main.name = "BaselineMain"
	_main.match_seed = _seed_used
	_main.selected_grid_size = GRID_SIZE
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 5

	get_root().add_child(_main)
	await process_frame

	_main._start_game(GRID_SIZE, true, false)
	await process_frame
	await process_frame

	if _main.runtime == null or _main.runtime.battlefield == null:
		print("[MatchBaseline] ERROR: battlefield was not created")
		quit(1)
		return

	_initial_counts = _counts_snapshot()
	print("[MatchBaseline] initial_counts=%s" % _format_counts(_initial_counts))
	_digests.append("t=0.0 %s" % _sample_digest())

	await _capture_loop()
	_print_summary()
	quit(0)


func _capture_loop() -> void:
	while true:
		await physics_frame
		_frame += 1
		var t: float = float(_frame) / float(_ticks_per_second)

		if t >= _next_sample_at:
			_next_sample_at += SAMPLE_EVERY_SECONDS
			_digests.append("t=%.1f %s" % [t, _sample_digest()])
			print("[MatchBaseline] t=%6.1f %s" % [t, _sample_digest()])

		if _main.is_game_over:
			_t_end = t
			break
		if t >= max_sim_seconds:
			break


func _sample_digest() -> String:
	var counts: Dictionary = _counts_snapshot()
	_final_counts = counts
	var bullets: int = 0
	if _main.runtime.bullet_pool != null and is_instance_valid(_main.runtime.bullet_pool):
		bullets = int(_main.runtime.bullet_pool.get_active_count())

	var health_total: int = 0
	var destroyed: int = 0
	for fid in _main.runtime.turrets.keys():
		var turret = _main.runtime.turrets[fid]
		if turret == null or not is_instance_valid(turret):
			continue
		health_total += int(turret.health)
		if bool(turret.is_destroyed):
			destroyed += 1

	_track_milestones(counts, bullets, destroyed)
	return "counts=%s bullets=%d health=%d destroyed=%d fps=%d" % [
		_format_counts(counts), bullets, health_total, destroyed,
		floori(Engine.get_frames_per_second())
	]


func _track_milestones(counts: Dictionary, bullets: int, destroyed: int) -> void:
	var t: float = float(_frame) / float(_ticks_per_second)

	if _t_first_bullet < 0.0 and bullets > 0:
		_t_first_bullet = t
	if _t_first_convert < 0.0 and not _initial_counts.is_empty():
		for fid in counts.keys():
			if int(counts[fid]) != int(_initial_counts.get(fid, 0)):
				_t_first_convert = t
				break
	if _t_first_destroy < 0.0 and destroyed > 0:
		_t_first_destroy = t

	var leader: int = _leader_of(counts)
	if leader >= 0 and _last_leader >= 0 and leader != _last_leader:
		_lead_changes += 1
	if leader >= 0:
		_last_leader = leader


func _counts_snapshot() -> Dictionary:
	var result: Dictionary = {}
	if _main == null or _main.runtime == null or _main.runtime.battlefield == null:
		return result
	var raw = _main.runtime.battlefield.owner_counts
	if raw is Dictionary:
		for fid in raw.keys():
			result[int(fid)] = int(raw[fid])
	return result


func _leader_of(counts: Dictionary) -> int:
	var best_fid: int = -1
	var best_value: int = -1
	var tied: bool = false
	for fid in counts.keys():
		var value: int = int(counts[fid])
		if value > best_value:
			best_value = value
			best_fid = int(fid)
			tied = false
		elif value == best_value:
			tied = true
	return -1 if tied else best_fid


func _format_counts(counts: Dictionary) -> String:
	var keys: Array = counts.keys()
	keys.sort()
	var parts: Array[String] = []
	for fid in keys:
		parts.append("%d:%d" % [int(fid), int(counts[fid])])
	return "/".join(parts)


func _print_summary() -> void:
	var combined: String = "\n".join(_digests)
	print("[MatchBaseline] ---- summary ----")
	print("  seed            = %d" % _seed_used)
	print("  first_bullet    = %s" % _fmt_time(_t_first_bullet))
	print("  first_convert   = %s" % _fmt_time(_t_first_convert))
	print("  first_destroy   = %s" % _fmt_time(_t_first_destroy))
	print("  end             = %s" % _fmt_time(_t_end))
	print("  lead_changes    = %d" % _lead_changes)
	print("  final_counts    = %s" % _format_counts(_final_counts))
	print("  sample_digest   = %d" % combined.hash())
	print("[MatchBaseline] ---- end ----")


func _fmt_time(value: float) -> String:
	if value < 0.0:
		return "none"
	return "%.1fs" % value


func _read_seed() -> int:
	var raw: String = OS.get_environment("BALLWAR_MATCH_SEED")
	if raw.is_valid_int():
		return int(raw)
	return 12345
