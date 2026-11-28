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
# Audio arm for the on/off trace comparison:
#   on    - default, the shipped audio graph runs for the whole match
#   off   - audio node exists but play() short-circuits (a player muting the bus)
#   none  - audio node is freed before the match starts, so the presentation bus
#           has no subscriber at all (the strongest "audio does not exist" arm)
var _audio_arm: String = "on"

# 实验模式：绕过控制仓，定时让四个炮台同时齐射，用于制造高密度弹幕对照。
# 默认关闭，不影响经典基线。
var _experiment_fire: bool = false
var _experiment_fire_interval: float = 1.0
var _experiment_fire_count: int = 40
var _active_samples: Array[float] = []
var _trace_write_failed: bool = false
var _max_share: float = 0.0
var _max_reversal: float = 0.0
var _min_share_seen: Dictionary = {0: 1.0, 1: 1.0, 2: 1.0, 3: 1.0}
var _empty_ticks: int = 0
var _low_ticks: int = 0
var _metric_ticks: int = 0
var _growth: Array = []

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
	_audio_arm = _env_string("BALLWAR_AUDIO", "on").strip_edges().to_lower()
	if not ["on", "off", "none"].has(_audio_arm):
		printerr("[Probe] BALLWAR_AUDIO must be on|off|none, got '%s'." % _audio_arm)
		quit(2)
		return
	_experiment_fire = _env_flag("BALLWAR_EXPERIMENT_FIRE", false)
	_experiment_fire_interval = _env_float("BALLWAR_EXPERIMENT_FIRE_INTERVAL", 1.0)
	_experiment_fire_count = _env_int("BALLWAR_EXPERIMENT_FIRE_COUNT", 40)
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
	_main.selected_palette_name = _env_string("BALLWAR_TEST_PALETTE", "经典")
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 5

	_probe = ClockProbe.new()
	_probe.name = "ClockProbe"

	get_root().add_child(_main)
	get_root().add_child(_probe)
	await process_frame

	if not _apply_audio_arm():
		quit(2)
		return

	_main._start_game(GRID_SIZE, true, false)

	if _main.runtime == null or _main.runtime.battlefield == null:
		print("[Probe] ERROR: battlefield was not created")
		quit(3)
		return

	if not _assert_config():
		quit(2)
		return

	if _main.runtime.bullet_pool != null and is_instance_valid(_main.runtime.bullet_pool):
		_main.runtime.bullet_pool.collision_resolver.track_near_misses = _env_flag("BALLWAR_TRACK_NEAR_MISS", false)

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
	if not footer_written or trace_error != OK or _trace_write_failed:
		printerr("[Probe] Cannot finish trace (footer=%s error=%s failed=%s)." % [
			str(footer_written), error_string(trace_error), str(_trace_write_failed)
		])
		quit(4)
		return
	_print_summary()
	_write_audio_report()
	quit(0)


# Applies the audio arm BEFORE the match exists, so every arm starts from the
# same node tree minus the audio node. Returns false on an unusable arm.
#
# The point of three arms instead of two: "off" still runs the whole presentation
# bus and the throttling code, while "none" removes the subscriber entirely. If
# only "none" matches and "off" does not, the divergence lives in the event
# plumbing rather than in audio playback - that difference is the useful part.
func _apply_audio_arm() -> bool:
	if _main.audio_manager == null:
		print("[Probe] AUDIO arm=%s (no audio node present)" % _audio_arm)
		return true
	match _audio_arm:
		"on":
			pass
		"off":
			_main.audio_manager.set_enabled(false)
		"none":
			_main.remove_child(_main.audio_manager)
			_main.audio_manager.free()
			_main.audio_manager = null
		_:
			return false
	print("[Probe] AUDIO arm=%s" % _audio_arm)
	return true


# Proof that the arm actually did something. An "audio on" run in which nothing
# was ever played would match an "audio off" run for the wrong reason, and that
# is the vacuous comparison this file has to avoid.
func _write_audio_report() -> void:
	var played: Dictionary = {}
	var emitted: Dictionary = {}
	if _main != null and is_instance_valid(_main):
		# Read the bus directly, not through AudioManager: in the "none" arm there
		# is no AudioManager left to ask, and the question "did the GAME emit the
		# same events in every arm" has to be answerable for all three arms.
		if _main.presentation_events != null:
			emitted = _main.presentation_events.snapshot()
		if _main.audio_manager != null:
			played = _main.audio_manager.play_counts()
	var total_played: int = 0
	for key in played.keys():
		total_played += int(played[key])
	var total_emitted: int = 0
	for key in emitted.keys():
		total_emitted += int(emitted[key])
	var report: Dictionary = {
		"arm": _audio_arm,
		"label": _label,
		"seed": _seed_used,
		"ticks": _tick,
		"event_counts": emitted,
		"event_total": total_emitted,
		"played_counts": played,
		"played_total": total_played,
	}
	var path: String = "user://audio_%s.json" % _label
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("[Probe] AUDIO_REPORT %s" % JSON.stringify(report))


func _capture_loop(max_ticks: int) -> void:
	while _tick < max_ticks:
		await physics_frame
		_tick += 1
		_maybe_experiment_fire()
		_record_tick()
		if _main.is_game_over:
			_end_reason = "game_over"
			break
	if _end_reason == "unknown":
		_end_reason = "time_cap"

func _maybe_experiment_fire() -> void:
	if not _experiment_fire or _main == null or _main.runtime == null:
		return
	var interval_ticks: int = maxi(1, int(round(_experiment_fire_interval * float(_ticks_per_second))))
	if _tick % interval_ticks != 0:
		return
	var volley: Dictionary = {WeaponRuleset.BulletType.STANDARD: _experiment_fire_count}
	if _main.runtime.match_config != null and _main.runtime.match_config.has_method("allocate_volley"):
		volley = _main.runtime.match_config.allocate_volley(_experiment_fire_count)
	for turret in _main.runtime.turrets.values():
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			turret.fire_volley(volley)


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
	_sample_metrics()
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
	var turret_rules: Array = []
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

		turret_rules.append([fid, turret.sweep_phase, turret.rotation, turret.burst_total,
			turret.burst_origin_angle, turret.burst_timer, turret.burst_locked])

	var chamber_sig: Array = []
	var chamber_rules: Array = []
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
		chamber_rules.append([fid, chamber.jammed_time_left, chamber.chamber_state.queued_round_modifiers])
		for index in range(chamber.balls.size()):
			var ball = chamber.balls[index]
			if not is_instance_valid(ball):
				chamber_sig.append("%d:ball:%d:gone" % [fid, index])
				continue
			var stuck: Dictionary = chamber.stuck_states.get(ball.get_instance_id(), {})
			chamber_sig.append("%d:ball:%d:%s" % [fid, index, var_to_str([
				ball.position, ball.velocity, ball.radius, chamber.get_ball_stay_time(ball), stuck
			]).replace("\n", "")])

	var bullet_rules: Array[int] = []
	if _main.runtime.bullet_pool != null and is_instance_valid(_main.runtime.bullet_pool):
		for bullet in _main.runtime.bullet_pool.get_active_bullets():
			if bullet == null or not is_instance_valid(bullet):
				continue
			bullet_rules.append(hash([bullet.faction_id, bullet.global_position, bullet.direction,
				bullet.age, bullet.speed, bullet.last_cell, bullet.turret_hit_check_timer]))
			bullets.append("%d:%.2f:%.2f" % [
				int(bullet.faction_id),
				float(bullet.global_position.x),
				float(bullet.global_position.y)
			])
	bullets.sort()

	var event_sig: String = "none"
	var event_rules: Array = []
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

		var pending: Dictionary = controller._pending_payload
		event_rules = [
			controller.next_event_time_left, controller._presentation_time_left,
			pending.get("faction_id", -1), pending.get("final_effect", ""), pending.get("effect_sequence", [])
		]

	var turret_h: int = hash([turret_sig, turret_rules])
	var chamber_h: int = hash([chamber_sig, chamber_rules])
	var bullet_h: int = hash(bullet_rules)
	var event_h: int = hash([event_sig, event_rules])
	var payload: Array = [
		owners_hash, turret_h, chamber_h, bullet_h, event_h,
		_main.game_elapsed_time, _main.win_check_timer, _main.is_game_over,
		_main.runtime.match_random.simulation_states()
	]
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
			int(_main.runtime.battlefield.grid_size), GameConfig.get_palette_name()
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
		if not _trace_file.store_line(line):
			printerr("[Probe] trace write failed at tick %d: %s" % [_tick, error_string(_trace_file.get_error())])
			_trace_write_failed = true
			break
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
	print("  experiment_fire  = %s (count=%d interval=%.2fs)" % [
		str(_experiment_fire), _experiment_fire_count, _experiment_fire_interval
	])
	_print_final_cells()
	_print_collision_summary()
	_print_production_summary()
	_print_load_summary()
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


func _print_collision_summary() -> void:
	var pool = null
	if _main != null and _main.runtime != null:
		pool = _main.runtime.bullet_pool
	if pool == null or not is_instance_valid(pool) or not pool.has_method("get_collision_stats"):
		return
	print("[Probe] ---- collision (perf, not state) ----")
	var stats: Dictionary = pool.get_collision_stats()
	print("  enabled          = %s" % str(stats.get("enabled", false)))
	print("  experiment       = pierce=%d mix_pierce=%d blast=%d mix_blast=%d" % [
		int(stats.get("piercing_captures", 1)),
		int(_main.runtime.match_config.piercing_mix_percent) if _main.runtime.match_config != null else 0,
		int(stats.get("explosion_radius", 0)),
		int(_main.runtime.match_config.explosion_mix_percent) if _main.runtime.match_config != null else 0,
	])
	print("  bucket_size      = %.1f (cells=%d)" % [
		float(stats.get("bucket_size", 0.0)), int(stats.get("bucket_cells", 0))
	])
	print("  totals           = pairs=%d checks=%d near_misses=%d hits=%d" % [
		int(stats.get("total_bucket_pairs", 0)),
		int(stats.get("total_distance_checks", 0)),
		int(stats.get("total_near_misses", 0)),
		int(stats.get("total_hits", 0)),
	])
	print("  collision_usec   = avg=%.0f max=%d" % [
		float(stats.get("usec_total", 0)) / maxf(1.0, float(_tick)),
		int(stats.get("usec_max", 0)),
	])
	print("  pool_step        = avg=%.2fms max=%.2fms" % [
		float(stats.get("step_usec_total", 0)) / maxf(1.0, float(_tick)) / 1000.0,
		float(stats.get("step_usec_max", 0)) / 1000.0,
	])
	print("  depth / blast    = max_capture_depth=%d explosion_cells=%d" % [
		int(stats.get("max_capture_depth", 0)),
		int(stats.get("total_explosion_cells", 0)),
	])
	print("  spawned_total    = %d by_type=%s" % [
		int(stats.get("total_spawned", 0)),
		str(stats.get("spawned_by_type", {})),
	])
	print("  peak_active      = %d" % int(pool.get_peak_active_count()))

func _print_production_summary() -> void:
	if _main == null or _main.runtime == null:
		return
	print("[Probe] ---- production (perf, not state) ----")
	var chambers: Dictionary = _main.runtime.chambers
	var faction_ids: Array = chambers.keys()
	faction_ids.sort()
	for faction_id in faction_ids:
		var chamber = chambers[faction_id]
		if chamber == null or not is_instance_valid(chamber):
			continue
		var stats: Dictionary = chamber.get_production_stats()
		print("  f%d balls=%d releases=%d fire=%d max=%d gates=%d relaunch=%d locks=%d locked=%.1fs" % [
			int(faction_id),
			int(stats.get("balls", 0)),
			int(stats.get("releases", 0)),
			int(stats.get("fire_released", 0)),
			int(stats.get("max_release", 0)),
			int(stats.get("gate_multiplier_hits", 0)),
			int(stats.get("relaunches", 0)),
			int(stats.get("lock_count", 0)),
			float(stats.get("locked_seconds", 0.0)),
		])
		print("     ledger[%s] balanced=%s error=%s" % [
			str(stats.get("ledger", "")),
			str(stats.get("ledger_balanced", false)),
			str(stats.get("ledger_error", "")),
		])
		print("     ledger_units converted=%d fired=%d pending=%d lost=%d remain=%d restore_ok=%s" % [
			int(stats.get("ledger_converted_units", 0)),
			int(stats.get("ledger_fired_units", 0)),
			int(stats.get("ledger_pending_units", 0)),
			int(stats.get("ledger_lost_units", 0)),
			int(stats.get("ledger_remaining_units", 0)),
			str(stats.get("ledger_restore_ok", true)),
		])
	var pool = _main.runtime.bullet_pool
	if pool != null and is_instance_valid(pool):
		var pool_stats: Dictionary = pool.get_collision_stats()
		print("  shots_by_faction = %s" % str(pool_stats.get("spawned_by_faction", {})))

func _sample_metrics() -> void:
	if _main == null or _main.runtime == null:
		return
	var pool = _main.runtime.bullet_pool
	var active: int = 0
	if pool != null and is_instance_valid(pool):
		active = int(pool.get_active_count())
	_active_samples.append(float(active))
	if active <= 0:
		_empty_ticks += 1
	if active < 10:
		_low_ticks += 1
	_metric_ticks += 1

	var battlefield = _main.runtime.battlefield
	if battlefield == null:
		return
	var total_cells: float = float(maxi(1, battlefield.grid_size * battlefield.grid_size))
	var counts: Dictionary = battlefield.owner_counts
	for faction_id in [0, 1, 2, 3]:
		var share: float = float(int(counts.get(faction_id, 0))) / total_cells
		_max_share = maxf(_max_share, share)
		_max_reversal = maxf(_max_reversal, share - float(_min_share_seen.get(faction_id, 1.0)))
		if share < float(_min_share_seen.get(faction_id, 1.0)):
			_min_share_seen[faction_id] = share
	if _tick % 600 == 0 and _growth.size() < 20:
		_growth.append([
			_tick / _ticks_per_second,
			int(counts.get(0, 0)), int(counts.get(1, 0)), int(counts.get(2, 0)), int(counts.get(3, 0)),
		])

func _print_load_summary() -> void:
	if _active_samples.is_empty():
		return
	print("[Probe] ---- load (perf, not state) ----")
	print("  active           = p50=%.0f p95=%.0f peak=%.0f" % [
		_percentile(_active_samples, 0.50),
		_percentile(_active_samples, 0.95),
		_array_max(_active_samples),
	])
	print("  territory        = max_share=%.1f%% max_reversal=%.1fpp" % [
		_max_share * 100.0,
		_max_reversal * 100.0,
	])
	print("  activity         = empty_ticks=%.1f%% low10_ticks=%.1f%%" % [
		100.0 * float(_empty_ticks) / maxf(1.0, float(_metric_ticks)),
		100.0 * float(_low_ticks) / maxf(1.0, float(_metric_ticks)),
	])
	var curve: Array[String] = []
	for sample in _growth:
		curve.append("%ds:%d/%d/%d/%d" % [int(sample[0]), int(sample[1]), int(sample[2]), int(sample[3]), int(sample[4])])
	print("  growth           = %s" % " ".join(curve))

func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(round(ratio * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return sorted[index]

func _array_max(values: Array[float]) -> float:
	var result: float = 0.0
	for value in values:
		result = maxf(result, value)
	return result

func _print_final_cells() -> void:
	if _main == null or _main.runtime == null or _main.runtime.battlefield == null:
		return
	var counts: Dictionary = _main.runtime.battlefield.count_cells_by_team()
	print("[Probe] ---- final cells ----")
	print("  blue=%d red=%d green=%d yellow=%d" % [
		int(counts.get(GameConfig.Faction.BLUE, 0)),
		int(counts.get(GameConfig.Faction.RED, 0)),
		int(counts.get(GameConfig.Faction.GREEN, 0)),
		int(counts.get(GameConfig.Faction.YELLOW, 0)),
	])


func _tick_text(tick: int) -> String:
	if tick < 0:
		return "none"
	return "tick %d (%.2fs)" % [tick, float(tick) / float(_ticks_per_second)]


func _env_string(key: String, fallback: String) -> String:
	var raw: String = OS.get_environment(key)
	return fallback if raw == "" else raw


func _env_flag(key: String, fallback: bool) -> bool:
	var raw: String = OS.get_environment(key).strip_edges().to_lower()
	if raw == "":
		return fallback
	return raw == "1" or raw == "true" or raw == "yes" or raw == "on"


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	return int(raw) if raw.is_valid_int() else fallback


func _env_float(key: String, fallback: float) -> float:
	var raw: String = OS.get_environment(key)
	return float(raw) if raw.is_valid_float() else fallback
