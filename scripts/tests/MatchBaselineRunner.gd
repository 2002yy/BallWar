extends SceneTree

# Determinism probe (stage 0A).
#
# Runs one classic match headlessly with a fixed seed and writes a per-tick
# trace of simulation state, so two runs can be compared tick by tick to find
# the FIRST divergent tick.
#
# Deliberately excluded from the simulation digest:
#   - FPS, frame times, memory, render pressure (they are perf, not state)
#   - HUD values, trail/particle counts, animation state
#
# Usage: bash scripts/tests/determinism_probe.sh <label> [seconds]
# Exit codes: 0 ok, 2 invalid config, 3 no battlefield, 4 trace write failed,
# 5 user data is not isolated.

const MainScene = preload("res://scripts/Main.gd")
const IsolatedUserProfile = preload("res://scripts/IsolatedUserProfile.gd")

const GRID_SIZE: int = 40
const TRACE_FLUSH_EVERY: int = 120

var _main = null
var _probe = null
var _ticks_per_second: int = 60
var _tick: int = 0

var _seed_used: int = 0
var _max_seconds: float = 90.0
var _label: String = "run"

var _trace_file: FileAccess = null
var _trace_lines: Array[String] = []
var _trace_path: String = ""

# Optional verbose window: dumps the raw per-object signatures instead of hashes,
# so a divergent tick can be read directly instead of guessed from a hash change.
var _detail_file: FileAccess = null
var _detail_from: int = -1
var _detail_to: int = -1

var _initial_owners_hash: int = 0
var _initial_health_total: int = -1
var _last_leader: int = -1
var _lead_changes: int = 0

var _first_bullet_tick: int = -1
var _first_cell_change_tick: int = -1
var _first_health_drop_tick: int = -1
var _first_destroy_tick: int = -1
var _first_event_start_tick: int = -1
var _first_event_apply_tick: int = -1
var _last_event_effect: String = ""

var _end_reason: String = "unknown"


# Counts how many times each clock actually runs, and the real delta sums.
class ClockProbe extends Node:
	var process_calls: int = 0
	var process_delta_sum: float = 0.0
	var process_delta_min: float = 999.0
	var process_delta_max: float = 0.0
	var physics_calls: int = 0
	var physics_delta_sum: float = 0.0
	var physics_delta_min: float = 999.0
	var physics_delta_max: float = 0.0

	func _process(delta: float) -> void:
		process_calls += 1
		process_delta_sum += delta
		process_delta_min = minf(process_delta_min, delta)
		process_delta_max = maxf(process_delta_max, delta)

	func _physics_process(delta: float) -> void:
		physics_calls += 1
		physics_delta_sum += delta
		physics_delta_min = minf(physics_delta_min, delta)
		physics_delta_max = maxf(physics_delta_max, delta)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_seed_used = _env_int("BALLWAR_MATCH_SEED", 12345)
	_max_seconds = _env_float("BALLWAR_MATCH_SECONDS", 90.0)
	_label = _env_string("BALLWAR_TRACE_LABEL", "run")
	_ticks_per_second = MatchClock.TICKS_PER_SECOND

	if not IsolatedUserProfile.is_fresh("BALLWAR_PROBE_TOKEN", ".ballwar-probe"):
		printerr("[Probe] Refusing to run outside a fresh probe profile. Use determinism_probe.sh.")
		quit(5)
		return
	if not _label.is_valid_filename() or not is_finite(_max_seconds) or _max_seconds <= 0.0:
		printerr("[Probe] Invalid trace label or duration.")
		quit(2)
		return

	print("[Probe] label=%s seed=%d window=%.1fs tick_rate=%d" % [_label, _seed_used, _max_seconds, _ticks_per_second])

	GameConfig.reset_runtime_defaults()
	GameConfig.set_quality_by_name(GameConfig.QUALITY_MEDIUM)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	_main = MainScene.new()
	_main.name = "ProbeMain"
	_main.match_seed = _seed_used
	_main.selected_grid_size = GRID_SIZE
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 5

	_probe = ClockProbe.new()
	_probe.name = "ClockProbe"

	get_root().add_child(_main)
	get_root().add_child(_probe)
	await process_frame

	_main._start_game(GRID_SIZE, true, false)

	if _main.runtime == null or _main.runtime.battlefield == null:
		print("[Probe] ERROR: battlefield was not created")
		quit(3)
		return

	if not _assert_config():
		quit(2)
		return

	_trace_path = "user://trace_%s.tsv" % _label
	_trace_file = FileAccess.open(_trace_path, FileAccess.WRITE)
	if _trace_file == null:
		print("[Probe] ERROR: cannot open trace file %s" % _trace_path)
		quit(4)
		return

	_open_detail_window()

	_initial_owners_hash = _owners_hash()
	_initial_health_total = _health_total_now()
	_write_trace_header()
	_record_tick()
	var speed: int = _env_int("BALLWAR_TEST_SPEED", 1)
	if speed != 1:
		if _main.dev_speed == null or speed not in MatchClock.SPEEDS:
			printerr("[Probe] Test speed requires an isolated DEV-SPEED session and a supported rate.")
			quit(2)
			return
		_main.dev_speed.clock.set_speed(speed)

	var max_ticks: int = int(ceil(_max_seconds * float(_ticks_per_second)))
	var started_usec: int = Time.get_ticks_usec()
	await _capture_loop(max_ticks)
	var wall_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	print("[Probe] speed_target=%dx wall=%.3fs effective=%.3fx" % [
		speed, wall_seconds, (_tick * MatchClock.STEP_SECONDS) / maxf(wall_seconds, 0.000001)
	])
	_flush_trace()
	var footer_written: bool = _trace_file.store_line("# end\t%s\t%d\t%d" % [_end_reason, _tick, max_ticks])
	_trace_file.flush()
	var trace_error: Error = _trace_file.get_error()
	_trace_file.close()
	_close_detail()
	if not footer_written or trace_error != OK:
		printerr("[Probe] Cannot finish trace.")
		quit(4)
		return
	_print_summary()
	quit(0)


func _capture_loop(max_ticks: int) -> void:
	while _tick < max_ticks:
		await physics_frame
		_tick += 1
		_record_tick()
		if _main.is_game_over:
			_end_reason = "game_over"
			break
	if _end_reason == "unknown":
		_end_reason = "time_cap"


func _record_tick() -> void:
	if _trace_file == null:
		return

	var state: Dictionary = _sim_state()
	# perf columns (proc/phys) are recorded but never hashed into sim_hash
	_trace_lines.append("%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d" % [
		_tick,
		int(state["sim_hash"]),
		int(state["owners_h"]),
		int(state["turret_h"]),
		int(state["chamber_h"]),
		int(state["bullet_h"]),
		int(state["event_h"]),
		int(state["bullets"]),
		int(state["leader"]),
		int(state["health_total"]),
		_probe.process_calls,
		_probe.physics_calls,
		# Measured FPS is a wall-clock value, never simulation state. It is logged
		# only to correlate divergence with the FPS-gated code paths in Turret.
		floori(Engine.get_frames_per_second())
	])

	_track_milestones(state)
	_write_detail(state)
	if _trace_lines.size() >= TRACE_FLUSH_EVERY:
		_flush_trace()


# Simulation-only state. Nothing here may depend on frame rate or rendering.
func _sim_state() -> Dictionary:
	var owners_hash: int = _owners_hash()
	var bullets: Array = []
	var health_total: int = 0
	var destroyed_count: int = 0
	var turret_sig: Array = []
	var turret_ids: Array = _main.runtime.turrets.keys()
	turret_ids.sort()

	for fid in turret_ids:
		var turret = _main.runtime.turrets[fid]
		if turret == null or not is_instance_valid(turret):
			turret_sig.append("%d:gone" % int(fid))
			continue
		var health: int = int(turret.health)
		var destroyed: bool = bool(turret.is_destroyed)
		health_total += health
		if destroyed:
			destroyed_count += 1
		# burst_timer / burst_index are simulation state: they decide WHEN the next
		# shot leaves, so leaving them out of the digest delays divergence reports
		# by a tick and hides the real cause.
		turret_sig.append("%d:%d:%d:%d:%.4f:%d" % [
			int(fid), health, 1 if destroyed else 0,
			int(turret.burst_remaining),
			float(turret.burst_timer),
			int(turret.burst_index)
		])

	var chamber_sig: Array = []
	var chamber_ids: Array = _main.runtime.chambers.keys()
	chamber_ids.sort()
	for fid in chamber_ids:
		var chamber = _main.runtime.chambers[fid]
		if chamber == null or not is_instance_valid(chamber):
			chamber_sig.append("%d:gone" % int(fid))
			continue
		chamber_sig.append("%d:%d:%d:%d:%d:%d:%.2f" % [
			int(fid),
			int(chamber.pending_count),
			int(chamber.locked_remaining),
			1 if bool(chamber.is_locked) else 0,
			1 if bool(chamber.is_damaged) else 0,
			chamber.balls.size(),
			float(chamber.jammed_time_left)
		])
		for index in range(chamber.balls.size()):
			var ball = chamber.balls[index]
			if not is_instance_valid(ball):
				chamber_sig.append("%d:ball:%d:gone" % [fid, index])
				continue
			var stuck: Dictionary = chamber.stuck_states.get(ball.get_instance_id(), {})
			chamber_sig.append("%d:ball:%d:%s" % [fid, index, var_to_str([
				ball.position, ball.velocity, ball.radius, chamber.get_ball_stay_time(ball), stuck
			]).replace("\n", "")])

	if _main.runtime.bullet_pool != null and is_instance_valid(_main.runtime.bullet_pool):
		for bullet in _main.runtime.bullet_pool.get_active_bullets():
			if bullet == null or not is_instance_valid(bullet):
				continue
			bullets.append("%d:%.2f:%.2f" % [
				int(bullet.faction_id),
				float(bullet.global_position.x),
				float(bullet.global_position.y)
			])
	bullets.sort()

	var event_sig: String = "none"
	var controller = _main.runtime.event_controller
	if controller != null and is_instance_valid(controller):
		event_sig = "%d:%.3f:%d:%s:%d:%d" % [
			1 if bool(controller.event_roulette_enabled) else 0,
			float(controller.next_event_time_left),
			int(controller.last_event_faction),
			str(controller.last_event_effect),
			int(controller.reroll_count),
			1 if bool(controller.is_presenting_event) else 0
		]

	var turret_h: int = hash(turret_sig)
	var chamber_h: int = hash(chamber_sig)
	var bullet_h: int = hash(bullets)
	var event_h: int = hash(event_sig)
	var payload: Array = [owners_hash, turret_h, chamber_h, bullet_h, event_h]
	return {
		"sim_hash": hash(payload),
		"owners_h": owners_hash,
		"turret_h": turret_h,
		"chamber_h": chamber_h,
		"bullet_h": bullet_h,
		"event_h": event_h,
		"owners_hash": owners_hash,
		"bullets": bullets.size(),
		"health_total": health_total,
		"destroyed": destroyed_count,
		"leader": _leader_of(),
		"turret_sig": turret_sig,
		"chamber_sig": chamber_sig,
		"bullet_sig": bullets,
	}


func _owners_hash() -> int:
	var battlefield = _main.runtime.battlefield
	if battlefield == null:
		return 0
	return int(hash(battlefield.owners))


func _health_total_now() -> int:
	var total: int = 0
	for fid in _main.runtime.turrets.keys():
		var turret = _main.runtime.turrets[fid]
		if turret != null and is_instance_valid(turret):
			total += int(turret.health)
	return total


func _leader_of() -> int:
	var battlefield = _main.runtime.battlefield
	if battlefield == null:
		return -1
	var counts = battlefield.owner_counts
	if not (counts is Dictionary):
		return -1
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


func _track_milestones(state: Dictionary) -> void:
	if _first_bullet_tick < 0 and int(state["bullets"]) > 0:
		_first_bullet_tick = _tick
	if _first_cell_change_tick < 0 and int(state["owners_hash"]) != _initial_owners_hash:
		_first_cell_change_tick = _tick
	if _first_destroy_tick < 0 and int(state["destroyed"]) > 0:
		_first_destroy_tick = _tick
	if _first_health_drop_tick < 0 and _initial_health_total >= 0:
		if int(state["health_total"]) < _initial_health_total:
			_first_health_drop_tick = _tick

	var leader: int = int(state["leader"])
	if leader >= 0 and _last_leader >= 0 and leader != _last_leader:
		_lead_changes += 1
	if leader >= 0:
		_last_leader = leader

	var controller = _main.runtime.event_controller
	if controller != null and is_instance_valid(controller):
		if _first_event_start_tick < 0 and bool(controller.is_presenting_event):
			_first_event_start_tick = _tick
		var effect: String = str(controller.last_event_effect)
		if effect != "" and effect != _last_event_effect:
			if _first_event_apply_tick < 0:
				_first_event_apply_tick = _tick
			_last_event_effect = effect


func _assert_config() -> bool:
	var failures: Array[String] = []

	if GameConfig.get_quality_name() != GameConfig.QUALITY_MEDIUM:
		failures.append("quality=%s want=%s" % [GameConfig.get_quality_name(), GameConfig.QUALITY_MEDIUM])
	if GameConfig.get_game_mode_name() != GameConfig.GAME_MODE_BASIC:
		failures.append("mode=%s want=%s" % [GameConfig.get_game_mode_name(), GameConfig.GAME_MODE_BASIC])
	if int(_main.runtime.battlefield.grid_size) != GRID_SIZE:
		failures.append("grid=%d want=%d" % [int(_main.runtime.battlefield.grid_size), GRID_SIZE])
	if _main.runtime.turrets.size() != 4:
		failures.append("turrets=%d want=4" % _main.runtime.turrets.size())
	if _main.runtime.chambers.size() != 4:
		failures.append("chambers=%d want=4" % _main.runtime.chambers.size())
	if int(_main.selected_grid_size) != GRID_SIZE:
		failures.append("selected_grid_size=%d (menu prefs leaked?)" % int(_main.selected_grid_size))

	if failures.is_empty():
		print("[Probe] CONFIG_OK quality=%s mode=%s grid=%d palette=%s" % [
			GameConfig.get_quality_name(), GameConfig.get_game_mode_name(),
			int(_main.runtime.battlefield.grid_size), _main.selected_palette_name
		])
		return true

	for item in failures:
		print("[Probe] CONFIG_MISMATCH %s" % item)
	return false


func _write_trace_header() -> void:
	if _trace_file == null:
		return
	_trace_file.store_line("# tick\tsim_hash\towners_h\tturret_h\tchamber_h\tbullet_h\tevent_h\tbullets\tleader\thealth_total\tproc\tphys\tfps\n# NOTE: proc/phys/fps are perf columns. sim_hash is computed WITHOUT them.")


func _open_detail_window() -> void:
	_detail_from = _env_int("BALLWAR_DETAIL_FROM", -1)
	_detail_to = _env_int("BALLWAR_DETAIL_TO", _detail_from)
	if _detail_from < 0:
		return
	var path: String = "user://detail_%s.tsv" % _label
	_detail_file = FileAccess.open(path, FileAccess.WRITE)
	if _detail_file == null:
		print("[Probe] WARN: cannot open detail file %s" % path)
		_detail_from = -1
		return
	_detail_file.store_line("# tick\tkind\tsignature")
	print("[Probe] detail window = %d..%d -> %s" % [
		_detail_from, _detail_to, ProjectSettings.globalize_path(path)
	])


func _write_detail(state: Dictionary) -> void:
	if _detail_file == null:
		return
	if _tick < _detail_from or _tick > _detail_to:
		return
	for sig in state["turret_sig"]:
		_detail_file.store_line("%d\tturret\t%s" % [_tick, str(sig)])
	for sig in state["chamber_sig"]:
		_detail_file.store_line("%d\tchamber\t%s" % [_tick, str(sig)])
	for sig in state["bullet_sig"]:
		_detail_file.store_line("%d\tbullet\t%s" % [_tick, str(sig)])
	_detail_file.store_line("%d\tevent\t%s" % [_tick, _event_sig_now()])
	_detail_file.store_line("%d\tqueue\t%d" % [_tick, _total_burst_queue()])


# Sum of burst_remaining across all turrets. This is the value Turret reads via
# _current_total_queue() to pick both the shot budget and the interval multiplier.
func _total_burst_queue() -> int:
	var total: int = 0
	for fid in _main.runtime.turrets.keys():
		var turret = _main.runtime.turrets[fid]
		if turret != null and is_instance_valid(turret):
			total += int(turret.burst_remaining)
	return total


func _event_sig_now() -> String:
	var controller = _main.runtime.event_controller
	if controller == null or not is_instance_valid(controller):
		return "none"
	return "%d:%.3f:%d:%s:%d:%d" % [
		1 if bool(controller.event_roulette_enabled) else 0,
		float(controller.next_event_time_left),
		int(controller.last_event_faction),
		str(controller.last_event_effect),
		int(controller.reroll_count),
		1 if bool(controller.is_presenting_event) else 0
	]


func _flush_trace() -> void:
	if _trace_file == null or _trace_lines.is_empty():
		return
	for line in _trace_lines:
		_trace_file.store_line(line)
	_trace_lines.clear()
	_trace_file.flush()


func _close_detail() -> void:
	if _detail_file == null:
		return
	_detail_file.flush()
	_detail_file.close()
	_detail_file = null


func _print_summary() -> void:
	print("[Probe] ---- summary ----")
	print("  label            = %s" % _label)
	print("  seed             = %d" % _seed_used)
	print("  ticks            = %d (%.2fs sim)" % [_tick, float(_tick) / float(_ticks_per_second)])
	print("  end_reason       = %s" % _end_reason)
	print("  trace_file       = %s" % ProjectSettings.globalize_path(_trace_path))
	print("  first_bullet     = %s" % _tick_text(_first_bullet_tick))
	print("  first_cell_change= %s" % _tick_text(_first_cell_change_tick))
	print("  first_health_drop= %s" % _tick_text(_first_health_drop_tick))
	print("  first_destroy    = %s" % _tick_text(_first_destroy_tick))
	print("  first_event_start= %s" % _tick_text(_first_event_start_tick))
	print("  first_event_apply= %s" % _tick_text(_first_event_apply_tick))
	print("  lead_changes     = %d" % _lead_changes)
	# Perf is reported separately and never feeds the simulation digest.
	print("[Probe] ---- clocks (perf, not state) ----")
	print("  process_calls    = %d" % _probe.process_calls)
	print("  physics_calls    = %d" % _probe.physics_calls)
	print("  ratio p/physics  = %.3f" % (float(_probe.process_calls) / maxf(1.0, float(_probe.physics_calls))))
	print("  process delta    = sum %.3f min %.5f max %.5f" % [
		_probe.process_delta_sum, _probe.process_delta_min, _probe.process_delta_max
	])
	print("  physics delta    = sum %.3f min %.5f max %.5f" % [
		_probe.physics_delta_sum, _probe.physics_delta_min, _probe.physics_delta_max
	])
	print("[Probe] ---- end ----")


func _tick_text(tick: int) -> String:
	if tick < 0:
		return "none"
	return "tick %d (%.2fs)" % [tick, float(tick) / float(_ticks_per_second)]


func _env_string(key: String, fallback: String) -> String:
	var raw: String = OS.get_environment(key)
	return fallback if raw == "" else raw


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	return int(raw) if raw.is_valid_int() else fallback


func _env_float(key: String, fallback: float) -> float:
	var raw: String = OS.get_environment(key)
	return float(raw) if raw.is_valid_float() else fallback
