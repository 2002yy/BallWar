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
#
# Exit codes: 0 ok, 2 capture dir not writable, 3 no viewport image.

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
		if float(_main.game_elapsed_time) >= target:
			return true
		if float(_main.game_elapsed_time) >= _max_seconds:
			return false
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
	print("[Capture] done, %d shots" % _shot_count)
	quit(0)


func _env_string(key: String, fallback: String) -> String:
	var raw: String = OS.get_environment(key)
	return fallback if raw == "" else raw


func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key)
	return int(raw) if raw.is_valid_int() else fallback


func _env_float(key: String, fallback: float) -> float:
	var raw: String = OS.get_environment(key)
	return float(raw) if raw.is_valid_float() else fallback
