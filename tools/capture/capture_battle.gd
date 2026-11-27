extends SceneTree

# Battle capture harness for art / UI review.
#
# Runs the REAL Main.tscn and takes the same start path as the menu button
# (StartMenu.gd:401 -> Main._start_game(grid_size)), so what gets captured is
# the shipped scene tree, not a reimplementation. It never touches gameplay
# rules: it only waits, screenshots, and quits.
#
# Usage (windowed, NOT --headless: a headless run has no rendered viewport):
#   CAPTURE_OUT=<dir> CAPTURE_SHOTS=menu,start:0,early:8,mid:20 \
#   <godot_console> --path . --script res://tools/capture/capture_battle.gd
#
# Environment:
#   CAPTURE_OUT       directory for PNGs (default: user://captures)
#   CAPTURE_SHOTS     comma separated name:seconds. Use "menu" for the start
#                     menu and "result" for the results panel; both are special
#                     and ignore the seconds value.
#   CAPTURE_SECONDS   hard cap on battle length in seconds (default 60)
#   CAPTURE_GRID      grid size (default 40)
#   CAPTURE_PALETTE   palette name (default 经典)
#   CAPTURE_TIME_LIMIT  match time limit in minutes (default 1, so the results
#                     panel is reachable inside a short capture run)
#   CAPTURE_SEED      match seed; set a fixed one when comparing before/after
#                     performance on the same match (default -1 = random)
#   CAPTURE_PERF      "1" writes perf.json with frame-time statistics
#   CAPTURE_RESIZE_AT battle second at which to resize the window
#   CAPTURE_RESIZE_TO "WxH" target for CAPTURE_RESIZE_AT
#   CAPTURE_NO_VSYNC  "1" disables vsync. Frame-time comparison needs this:
#                     with vsync the renderer is pinned to the display refresh
#                     (240 Hz here) and both builds report the same 4.166 ms,
#                     which measures the cap, not the cost.
#   CAPTURE_SAVE_RESTORE  "save" | "restore". Two-process coordinate round trip:
#                     process 1 saves mid-match, process 2 (started at a
#                     DIFFERENT window size) continues that save. Requires the
#                     same CAPTURE_OUT so the snapshots can be compared.
#   CAPTURE_SAVE_SLOT save slot for the probe (default 5 = last real slot);
#                     an out-of-range slot is rejected, never clamped
#   CAPTURE_SAVE_AT   battle second at which process 1 saves (default 12)
#   CAPTURE_TOL       max allowed battlefield-local deviation in px (default 0.5)
#   CAPTURE_FILL_CHAMBERS "1" (default) tops up all four chambers through the
#                     public add_control_ball() before the probe saves, so the
#                     comparison runs on dozens of bullets instead of two.
#   CAPTURE_TRACE     "1" prints the live bullet count every 5 battle seconds
#   CAPTURE_AUDIO     "on" (default) or "off". "off" mutes the SFX path so the
#                     same match can be captured with and without audio; without
#                     this the only way to compare was to edit the code under
#                     measurement, which is not a comparison.
#
# Exit codes: 0 ok, 2 capture dir not writable, 3 no viewport image,
#             4 save/restore local-coordinate mismatch, 5 match ended early,
#             6 save failed.

const MAIN_SCENE = preload("res://scenes/Main.tscn")

var _main = null
var _out_dir: String = ""
var _plan: Array = []
var _max_seconds: float = 60.0
var _grid: int = 40
var _palette: String = "经典"
var _time_limit: int = 1
var _seed_value: int = -1
var _mode: String = GameConfig.GAME_MODE_BASIC
var _want_perf: bool = false
var _shot_count: int = 0

var _frame_times: PackedFloat64Array = PackedFloat64Array()
var _perf_start_usec: int = 0
var _warm_seconds: float = 2.0

var _save_phase: String = ""
var _save_slot: int = 5
var _save_at: float = 12.0
var _tol_px: float = 0.5
var _exit_code: int = 0
var _trace: bool = false
var _trace_next: float = 5.0
var _fill_chambers: bool = false
var _audio_off: bool = false


# A fresh 40x40 match only keeps 1-4 bullets alive at any instant, which makes a
# coordinate comparison an anecdote instead of a sample. Filling the chambers
# through the same public call the "+ball" button uses raises the release rate
# without touching any rule: it is a test fixture, not a different simulation.
func _fill_all_chambers() -> void:
	if _main == null or _main.runtime == null or _main.runtime.chambers == null:
		return
	var added: int = 0
	for faction in _main.runtime.chambers.keys():
		var chamber = _main.runtime.chambers[faction]
		if chamber == null or not is_instance_valid(chamber) or not chamber.has_method("add_control_ball"):
			continue
		for i in 64:
			if not chamber.add_control_ball():
				break
			added += 1
	print("[Probe] fixture: added %d control balls" % added)


# Switches the audio path off inside the same build, so the two captures differ
# in one thing only. set_enabled(false) short-circuits play() before it touches
# a player, which is the whole cost this comparison is trying to measure.
func _apply_audio_switch() -> void:
	if _main == null or _main.audio_manager == null:
		return
	if _audio_off:
		_main.audio_manager.set_enabled(false)
		print("[Capture] audio disabled for this run")
	else:
		print("[Capture] audio enabled for this run")


# Bullet count over time. The pool has no event to hook, and "how many are alive
# at 26 s" is exactly the number that decides whether a coordinate comparison is
# a sample or an anecdote.
func _trace_in_flight(elapsed: float) -> void:
	if elapsed < _trace_next:
		return
	_trace_next += 5.0
	var pool = _main.runtime.bullet_pool if _main != null and _main.runtime != null else null
	if pool == null:
		return
	var active: int = pool.get_active_bullets().size() if pool.has_method("get_active_bullets") else -1
	print("[Trace] t=%.1f active=%d children=%d" % [elapsed, active, pool.get_child_count()])


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if _env_string("CAPTURE_NO_VSYNC", "") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("[Capture] vsync disabled for frame-time measurement")
	_out_dir = _env_string("CAPTURE_OUT", ProjectSettings.globalize_path("user://captures"))
	_max_seconds = _env_float("CAPTURE_SECONDS", 60.0)
	_resize_at = _env_float("CAPTURE_RESIZE_AT", -1.0)
	var resize_str: String = _env_string("CAPTURE_RESIZE_TO", "")
	if resize_str.contains("x"):
		var parts: PackedStringArray = resize_str.split("x")
		_resize_to = Vector2i(int(parts[0]), int(parts[1]))
	_grid = _env_int("CAPTURE_GRID", 40)
	_palette = _env_string("CAPTURE_PALETTE", "经典")
	_time_limit = maxi(1, _env_int("CAPTURE_TIME_LIMIT", 1))
	_seed_value = _env_int("CAPTURE_SEED", -1)
	_mode = GameConfig._normalize_game_mode_name(_env_string("CAPTURE_MODE", GameConfig.GAME_MODE_BASIC))
	_want_perf = _env_string("CAPTURE_PERF", "0") == "1"
	_plan = _parse_plan(_env_string("CAPTURE_SHOTS", "menu,start:0,early:8,mid:20"))
	_save_phase = _env_string("CAPTURE_SAVE_RESTORE", "").strip_edges().to_lower()
	_save_slot = clampi(_env_int("CAPTURE_SAVE_SLOT", 5), 1, 9)
	_save_at = _env_float("CAPTURE_SAVE_AT", 12.0)
	_tol_px = _env_float("CAPTURE_TOL", 0.5)
	_trace = _env_string("CAPTURE_TRACE", "0") == "1"
	_fill_chambers = _env_string("CAPTURE_FILL_CHAMBERS", "1") == "1"
	_audio_off = _env_string("CAPTURE_AUDIO", "on").strip_edges().to_lower() == "off"
	_force_fire = _env_string("CAPTURE_FORCE_FIRE", "0") == "1"
	_force_fire_interval = maxf(0.1, _env_float("CAPTURE_FORCE_FIRE_INTERVAL", 1.0))
	_force_fire_count = maxi(1, _env_int("CAPTURE_FORCE_FIRE_COUNT", 40))

	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		print("[Capture] ERROR: cannot create %s" % _out_dir)
		quit(2)
		return
	if not DirAccess.dir_exists_absolute(_out_dir):
		print("[Capture] ERROR: %s is not a directory" % _out_dir)
		quit(2)
		return

	print("[Capture] out=%s" % _out_dir)
	print("[Capture] plan=%s" % str(_plan))
	print("[Capture] display=%s window=%s" % [
		DisplayServer.get_name(),
		str(DisplayServer.window_get_size())
	])

	_main = MAIN_SCENE.instantiate()
	_main.name = "CaptureMain"
	get_root().add_child(_main)

	# Let the menu finish its entrance animation and the preview scene settle.
	for i in 8:
		await process_frame

	if _save_phase != "":
		await _run_save_restore()
		_finish()
		return

	if _plan.size() > 0 and str(_plan[0]["name"]) == "menu":
		await _shot("menu")
		_plan.remove_at(0)

	if _plan.is_empty():
		_finish()
		return

	# Same values a player would have chosen; set before _start_game because
	# that method copies them into GameConfig.
	_main.selected_grid_size = _grid
	_main.selected_palette_name = _palette
	_main.selected_quality_name = GameConfig.QUALITY_HIGH
	_main.selected_game_mode_name = _mode
	_main.selected_time_limit_minutes = _time_limit
	_main.selected_save_slot = 5
	_main.match_seed = _seed_value

	_main._start_game(_grid, false, true)
	for i in 4:
		await process_frame
	_apply_audio_switch()
	# Perf comparison needs events to exist. A fresh match keeps 1-4 bullets alive
	# and produces about one presentation event per second, which is far too thin
	# to show any audio cost; topping up the chambers through the same public call
	# the +ball button uses raises the rate without touching a rule.
	if _fill_chambers:
		_fill_all_chambers()

	# Save-coordinate contract: this must NOT depend on the window size, or a
	# save taken at one resolution restores to the wrong place at another.
	# Gated behind CAPTURE_DIAG so ordinary runs stay quiet.
	if _env_string("CAPTURE_DIAG", "") == "1" and _main != null and _main.runtime != null and _main.runtime.battlefield != null:
		var xf: Transform2D = _main.call("_board_transform") if _main.has_method("_board_transform") else Transform2D()
		print("[Capture] canvas=%s board_scale=%.4f battlefield.global_position=%s" % [
			_main.get_viewport_rect().size, xf.get_scale().x, _main.runtime.battlefield.global_position])
		var blue = _main.runtime.chambers.get(GameConfig.Faction.BLUE)
		if blue != null and is_instance_valid(blue):
			var ct: Transform2D = blue.get_global_transform_with_canvas()
			print("[Capture] chamber(BLUE) draw_origin=%s draw_scale=%.4f  sim_position=%s" % [
				ct.origin, ct.get_scale().x, blue.position])

	_warm_seconds = 2.0
	_perf_start_usec = Time.get_ticks_usec()

	while not _plan.is_empty():
		var step: Dictionary = _plan[0]
		var want: String = str(step["name"])
		if want == "result":
			await _wait_for_result()
			await _shot("result")
			_plan.remove_at(0)
			continue
		var target: float = float(step["seconds"])
		if not await _wait_battle_time(target):
			print("[Capture] WARN: time cap reached before shot '%s'" % want)
			await _shot("%s_capped" % want)
			_plan.remove_at(0)
			continue
		await _shot(want)
		_plan.remove_at(0)

	_finish()


# Advances until the in-game clock passes `target`. Returns false if the match
# ended or the capture cap was hit first.
var _resize_at: float = -1.0
var _resize_to: Vector2i = Vector2i.ZERO
var _resize_done: bool = false

# 互撞原型的高压场景：绕过控制仓，定时让四个炮台同时齐射。
var _force_fire: bool = false
var _force_fire_interval: float = 1.0
var _force_fire_count: int = 40
var _next_force_fire_at: float = 0.0


func _maybe_force_fire(elapsed: float) -> void:
	if not _force_fire or elapsed < _next_force_fire_at:
		return
	_next_force_fire_at = elapsed + _force_fire_interval
	if _main == null or _main.runtime == null:
		return
	var volley: Dictionary = {WeaponRuleset.BulletType.STANDARD: _force_fire_count}
	if _main.runtime.match_config != null and _main.runtime.match_config.has_method("allocate_volley"):
		volley = _main.runtime.match_config.allocate_volley(_force_fire_count)
	for turret in _main.runtime.turrets.values():
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			turret.fire_volley(volley)


# Live-resize test: changing the window while a match runs must re-apply the
# layout without restarting the match.
func _maybe_resize(elapsed: float) -> void:
	if _resize_done or _resize_at < 0.0 or _resize_to == Vector2i.ZERO:
		return
	if elapsed < _resize_at:
		return
	_resize_done = true
	DisplayServer.window_set_size(_resize_to)
	print("[Capture] resized window to %dx%d at %.2fs" % [_resize_to.x, _resize_to.y, elapsed])


func _wait_battle_time(target: float) -> bool:
	var guard: int = 0
	var last_usec: int = Time.get_ticks_usec()
	while true:
		guard += 1
		if guard > 1000000:
			return false
		if _main == null or not is_instance_valid(_main):
			return false
		if bool(_main.is_game_over):
			return false
		_maybe_resize(float(_main.game_elapsed_time))
		_maybe_force_fire(float(_main.game_elapsed_time))
		if float(_main.game_elapsed_time) >= target:
			return true
		if float(_main.game_elapsed_time) >= _max_seconds:
			return false
		if _trace:
			_trace_in_flight(float(_main.game_elapsed_time))
		await process_frame
		var now_usec: int = Time.get_ticks_usec()
		_sample_frame(now_usec - last_usec)
		last_usec = now_usec
	return false


# Warm-up frames are excluded: shader compilation and the first texture uploads
# happen once and would otherwise dominate a short run.
func _sample_frame(delta_usec: int) -> void:
	if not _want_perf:
		return
	if float(Time.get_ticks_usec() - _perf_start_usec) / 1000000.0 < _warm_seconds:
		return
	if delta_usec <= 0:
		return
	_frame_times.append(float(delta_usec) / 1000.0)


func _write_perf() -> void:
	if not _want_perf:
		return
	var path: String = "%s/perf.json" % _out_dir
	var values: Array = []
	for v in _frame_times:
		values.append(v)
	values.sort()
	var n: int = values.size()
	var out: Dictionary = {
		"samples": n,
		"warmup_seconds_excluded": _warm_seconds,
		"grid": _grid,
		"seed": _seed_value,
		"quality": GameConfig.get_quality_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window": str(DisplayServer.window_get_size()),
	}
	if n > 0:
		var total: float = 0.0
		for v in values:
			total += v
		out["frame_ms_avg"] = snappedf(total / float(n), 0.001)
		out["frame_ms_p50"] = snappedf(values[int(float(n) * 0.5)], 0.001)
		out["frame_ms_p95"] = snappedf(values[mini(n - 1, int(float(n) * 0.95))], 0.001)
		out["frame_ms_p99"] = snappedf(values[mini(n - 1, int(float(n) * 0.99))], 0.001)
		out["frame_ms_min"] = snappedf(values[0], 0.001)
		out["frame_ms_max"] = snappedf(values[n - 1], 0.001)
		out["fps_from_avg"] = snappedf(1000.0 / (total / float(n)), 0.1)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("[Capture] WARN: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	print("[Capture] perf -> %s" % path)
	print("[Capture] perf %s" % JSON.stringify(out))


func _wait_for_result() -> void:
	while true:
		if _main == null or not is_instance_valid(_main):
			return
		if bool(_main.is_game_over):
			# Give the result panel a moment to finish appearing.
			for i in 20:
				await process_frame
			return
		if float(_main.game_elapsed_time) >= _max_seconds:
			return
		await process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = get_root().get_texture()
	if tex == null:
		print("[Capture] ERROR: root viewport has no texture (headless?)")
		quit(3)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("[Capture] ERROR: viewport image is null")
		quit(3)
		return
	_shot_count += 1
	var path: String = "%s/%02d_%s.png" % [_out_dir, _shot_count, label]
	var err: int = img.save_png(path)
	if err != OK:
		print("[Capture] ERROR: save_png(%s) -> %d" % [path, err])
		quit(3)
		return
	print("[Capture] shot %s  %dx%d  elapsed=%.2fs" % [
		path, img.get_width(), img.get_height(),
		float(_main.game_elapsed_time) if _main != null else 0.0
	])


func _parse_plan(raw: String) -> Array:
	var plan: Array = []
	for chunk in raw.split(",", false):
		var part: String = chunk.strip_edges()
		if part == "":
			continue
		if part.find(":") >= 0:
			var kv: PackedStringArray = part.split(":", false, 1)
			plan.append({
				"name": kv[0].strip_edges(),
				"seconds": float(kv[1]) if kv.size() > 1 and kv[1].is_valid_float() else 0.0,
			})
		else:
			plan.append({"name": part, "seconds": 0.0})
	return plan


func _finish() -> void:
	_write_perf()
	if _env_string("CAPTURE_DIAG", "") == "1" and _main != null and is_instance_valid(_main) and _main.audio_manager != null:
		print("[Capture] audio_played = ", _main.audio_manager.play_counts())
	print("[Capture] done, %d shots" % _shot_count)
	quit(_exit_code)


# --- save / restore coordinate round trip -----------------------------------
#
# The question this answers is NOT "does the code look right". It is: a save
# written while the board was drawn at one resolution, restored on a machine
# drawing it at another, must put every bullet back at the same place **relative
# to the battlefield**. Global positions are expected to differ between the two
# runs when the board origin or scale differs, so the probe reports both numbers:
# a large global delta with a zero local delta is the pass condition, and it is
# also what proves the comparison is not vacuous.
#
# The restore is drained synchronously on purpose: Main._process_pending_bullet_restore()
# spawns the queue in batches of GameConfig.get_restore_per_frame() per frame, and
# bullets start moving as soon as a frame passes. Draining inside one frame keeps
# the measurement at the restored state instead of at "restored state + N frames
# of travel".

func _run_save_restore() -> void:
	_main.selected_grid_size = _grid
	_main.selected_palette_name = _palette
	_main.selected_quality_name = GameConfig.QUALITY_HIGH
	_main.selected_game_mode_name = _mode
	_main.selected_time_limit_minutes = _time_limit
	_main.selected_save_slot = _save_slot
	_main.match_seed = _seed_value

	if _save_phase == "save":
		# SaveFlowController clamps an out-of-range slot onto the last real slot,
		# so asking for slot 6 would silently overwrite the player's slot 5.
		# Detect the clamp by comparing resolved paths and refuse instead.
		var path_here: String = _main._get_save_path(_save_slot)
		var path_prev: String = _main._get_save_path(maxi(1, _save_slot - 1))
		print("[Probe] save path for slot %d: %s" % [_save_slot, path_here])
		if _save_slot > 1 and path_here == path_prev:
			print("[Probe] ERROR: slot %d is out of range and resolves onto slot %d - refusing to clobber it" % [_save_slot, _save_slot - 1])
			_exit_code = 6
			return
		# clear_save = true: the probe owns this slot, start from a fresh match.
		_main._start_game(_grid, false, true)
		for i in 4:
			await process_frame
		if _fill_chambers:
			_fill_all_chambers()
		if not await _wait_battle_time(_save_at):
			print("[Probe] ERROR: match ended or cap hit before %.2fs" % _save_at)
			_exit_code = 5
			return
		var snap: Dictionary = _snapshot()
		_write_state(snap, "before")
		print("[Probe] phase=save canvas=%s board_scale=%.4f bf_origin=%s bullets=%d t=%.2f" % [
			str(snap["canvas"]), float(snap["board_scale"]), str(snap["battlefield_global"]),
			int(snap["bullet_count"]), float(snap["game_elapsed_time"])])
		if int(snap["bullet_count"]) <= 0:
			print("[Probe] ERROR: no bullets alive at %.2fs, nothing to compare" % _save_at)
			_exit_code = 5
			return
		var result: Dictionary = _main._save_game_progress()
		if not bool(result.get("ok", false)):
			print("[Probe] ERROR: save failed: %s" % str(result.get("error_message", "")))
			_exit_code = 6
			return
		print("[Probe] save ok, slot=%d" % _save_slot)
		return

	if _save_phase == "restore":
		var before: Dictionary = _read_state("before")
		if before.is_empty():
			print("[Probe] ERROR: no state_before.json in %s" % _out_dir)
			_exit_code = 5
			return
		_main._continue_saved_game()
		if _main.runtime == null or _main.runtime.battlefield == null:
			print("[Probe] ERROR: continue did not build a battlefield")
			_exit_code = 5
			return
		var drain_calls: int = 0
		for i in 5000:
			if _main.bullet_restore_queue.pending_count() <= 0:
				break
			_main._process_pending_bullet_restore()
			drain_calls += 1
		var after: Dictionary = _snapshot()
		_write_state(after, "after")
		print("[Probe] phase=restore canvas=%s board_scale=%.4f bf_origin=%s bullets=%d t=%.2f drain_calls=%d pending=%d" % [
			str(after["canvas"]), float(after["board_scale"]), str(after["battlefield_global"]),
			int(after["bullet_count"]), float(after["game_elapsed_time"]), drain_calls,
			int(_main.bullet_restore_queue.pending_count())])
		_compare_and_report(before, after)
		return

	print("[Probe] ERROR: unknown CAPTURE_SAVE_RESTORE=%s (use save|restore)" % _save_phase)
	_exit_code = 5


func _snapshot() -> Dictionary:
	var bf = _main.runtime.battlefield
	var xf: Transform2D = _main.call("_board_transform") if _main.has_method("_board_transform") else Transform2D()
	var bullets: Array = []
	var pool = _main.runtime.bullet_pool
	var source: Array = pool.get_active_bullets() if pool != null and pool.has_method("get_active_bullets") else []
	for node in source:
		if not (node is Bullet) or not node.is_active:
			continue
		var local: Vector2 = bf.to_local(node.global_position)
		bullets.append({
			"faction": int(node.faction_id),
			"local": [local.x, local.y],
			"global": [node.global_position.x, node.global_position.y],
			"age": float(node.age),
		})
	var canvas: Vector2 = _main.get_viewport_rect().size
	var win: Vector2i = DisplayServer.window_get_size()
	return {
		"canvas": [canvas.x, canvas.y],
		"window": [win.x, win.y],
		"board_scale": xf.get_scale().x,
		"battlefield_global": [bf.global_position.x, bf.global_position.y],
		"game_elapsed_time": float(_main.game_elapsed_time),
		"grid_size": int(bf.grid_size),
		"bullet_count": bullets.size(),
		"bullets": bullets,
	}


func _compare_and_report(before: Dictionary, after: Dictionary) -> void:
	var a: Array = _sorted_bullets(before.get("bullets", []))
	var b: Array = _sorted_bullets(after.get("bullets", []))
	var pairs: int = mini(a.size(), b.size())
	var local_max: float = 0.0
	var global_max: float = 0.0
	var worst: String = ""
	for i in range(pairs):
		var la: Vector2 = _vec(a[i], "local")
		var lb: Vector2 = _vec(b[i], "local")
		var ga: Vector2 = _vec(a[i], "global")
		var gb: Vector2 = _vec(b[i], "global")
		var dl: float = la.distance_to(lb)
		var dg: float = ga.distance_to(gb)
		if dl > local_max:
			local_max = dl
			worst = "faction=%d saved_local=%s restored_local=%s" % [int(a[i]["faction"]), str(la), str(lb)]
		global_max = maxf(global_max, dg)

	var passed: bool = pairs > 0 and local_max <= _tol_px
	if pairs == 0:
		print("[Probe] ERROR: nothing comparable (before=%d after=%d)" % [a.size(), b.size()])
	var verdict: Dictionary = {
		"pairs": pairs,
		"bullets_saved": a.size(),
		"bullets_restored": b.size(),
		"local_max_px": snappedf(local_max, 0.0001),
		"global_max_px": snappedf(global_max, 0.0001),
		"tolerance_px": _tol_px,
		"worst_pair": worst,
		"canvas_before": before.get("canvas", []),
		"canvas_after": after.get("canvas", []),
		"board_scale_before": snappedf(float(before.get("board_scale", 0.0)), 0.0001),
		"board_scale_after": snappedf(float(after.get("board_scale", 0.0)), 0.0001),
		"bf_origin_before": before.get("battlefield_global", []),
		"bf_origin_after": after.get("battlefield_global", []),
		"elapsed_before": snappedf(float(before.get("game_elapsed_time", 0.0)), 0.001),
		"elapsed_after": snappedf(float(after.get("game_elapsed_time", 0.0)), 0.001),
		"passed": passed,
	}
	var path: String = "%s/save_restore_verdict.json" % _out_dir
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(verdict, "  "))
		f.close()
	print("[Probe] verdict %s" % JSON.stringify(verdict))
	var label: String = "PASS" if passed else "FAIL"
	print("[Probe] %s  local_max=%.4fpx  global_max=%.4fpx  pairs=%d  canvas %s -> %s" % [
		label, local_max, global_max, pairs, str(before.get("canvas", [])), str(after.get("canvas", []))])
	if not passed:
		print("[Probe] worst: %s" % worst)
		_exit_code = 4


func _sorted_bullets(list: Array) -> Array:
	var copy: Array = []
	for entry in list:
		if entry is Dictionary:
			copy.append(entry)
	copy.sort_custom(func(x, y):
		var fx: int = int(x.get("faction", 0))
		var fy: int = int(y.get("faction", 0))
		if fx != fy:
			return fx < fy
		var lx: Vector2 = _vec(x, "local")
		var ly: Vector2 = _vec(y, "local")
		if not is_equal_approx(lx.x, ly.x):
			return lx.x < ly.x
		return lx.y < ly.y)
	return copy


func _vec(entry: Dictionary, key: String) -> Vector2:
	var raw = entry.get(key, [])
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


func _write_state(snap: Dictionary, phase: String) -> void:
	var path: String = "%s/state_%s.json" % [_out_dir, phase]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("[Probe] WARN: cannot write %s" % path)
		return
	f.store_string(JSON.stringify(snap, "  "))
	f.close()
	print("[Probe] state -> %s" % path)


func _read_state(phase: String) -> Dictionary:
	var path: String = "%s/state_%s.json" % [_out_dir, phase]
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _env_string(key: String, fallback: String) -> String:
	var raw: String = OS.get_environment(key)
	return fallback if raw == "" else raw


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	return int(raw) if raw.is_valid_int() else fallback


func _env_float(key: String, fallback: float) -> float:
	var raw: String = OS.get_environment(key)
	return float(raw) if raw.is_valid_float() else fallback
