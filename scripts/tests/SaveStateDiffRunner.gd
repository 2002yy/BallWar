extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

var _main
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = MainScript.new()
	_main.name = "SaveDiffMain"
	_main.match_seed = 12345
	_main.selected_grid_size = 40
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 5
	GameConfig.set_quality_by_name(GameConfig.QUALITY_MEDIUM)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	root.add_child(_main)
	await process_frame
	_main._start_game(40, true, false)
	for i in range(1200):
		await physics_frame

	var live: Dictionary = _capture()
	print("[SaveDiff] captured tick=1200 chambers=%d" % live["chambers"].size())

	var payload: Dictionary = SaveStateBuilder.build_save_payload(
		_main.runtime.chambers, _main.runtime.turrets, _main.runtime.battlefield,
		_main.runtime.bullet_pool, _main.runtime.event_controller,
		_main.game_elapsed_time, false, 5, null,
		_main.runtime.match_config, _main.runtime.match_random, _main.win_check_timer)

	_check_layer("memory", payload, live)
	_check_layer("json", JSON.parse_string(JSON.stringify(payload)), live)
	_check_layer("validated", SaveGameCodec.validate_save_data(JSON.parse_string(JSON.stringify(payload))), live)

	print("[SaveDiff] done checks=%d" % _checks)
	quit(0)


func _check_layer(label: String, data, live: Dictionary) -> void:
	if not (data is Dictionary):
		print("[SaveDiff] %s: payload invalid" % label)
		return
	# 先恢复 live，确保每层都从同一个存档点开始。
	_apply(live["payload"])
	_apply(data)
	var post: Dictionary = _capture()
	var diff: Array = []
	_diff("", live, post, diff)
	if diff.is_empty():
		print("[SaveDiff] %s: NO DIFF" % label)
	else:
		print("[SaveDiff] %s: %d diffs; first=%s" % [label, diff.size(), str(diff[0])])
		for i in range(mini(3, diff.size())):
			print("  %s" % str(diff[i]))
	_checks += 1


func _apply(data: Dictionary) -> void:
	var factions = data.get("factions", [])
	SaveStateApplier.apply_factions(_main.runtime.chambers, _main.runtime.turrets, factions,
		func(_chamber): pass, Callable(self, "_noop"))


func _noop(_fid) -> void:
	pass


func _capture() -> Dictionary:
	var chambers: Array = []
	var ids: Array = _main.runtime.chambers.keys()
	ids.sort()
	for fid in ids:
		var c = _main.runtime.chambers[fid]
		if c == null or not is_instance_valid(c):
			continue
		var balls: Array = []
		for b in c.balls:
			if b == null or not is_instance_valid(b):
				continue
			balls.append({
				"pos": b.position,
				"vel": b.velocity,
				"stay": c.get_ball_stay_time(b),
				"stuck": c.stuck_states.get(b.get_instance_id(), {}).duplicate(true),
			})
		chambers.append({
			"fid": int(fid),
			"pending": int(c.pending_count),
			"locked_remaining": int(c.locked_remaining),
			"is_locked": bool(c.is_locked),
			"jammed": float(c.jammed_time_left),
			"balls": balls,
		})
	var turrets: Array = []
	var tids: Array = _main.runtime.turrets.keys()
	tids.sort()
	for fid in tids:
		var t = _main.runtime.turrets[fid]
		if t == null or not is_instance_valid(t):
			continue
		turrets.append({
			"fid": int(fid),
			"health": int(t.health),
			"burst_remaining": int(t.burst_remaining),
			"burst_total": int(t.burst_total),
			"burst_index": int(t.burst_index),
			"burst_timer": float(t.burst_timer),
			"burst_locked": bool(t.burst_locked),
			"origin": float(t.burst_origin_angle),
			"sweep": float(t.sweep_phase),
			"rotation": float(t.rotation),
		})
	return {
		"chambers": chambers,
		"turrets": turrets,
		"rng": _main.runtime.match_random.serialize_states(),
		"payload": SaveStateBuilder.build_save_payload(
			_main.runtime.chambers, _main.runtime.turrets, _main.runtime.battlefield,
			_main.runtime.bullet_pool, _main.runtime.event_controller,
			_main.game_elapsed_time, false, 5, null,
			_main.runtime.match_config, _main.runtime.match_random, _main.win_check_timer),
	}


func _diff(path: String, a, b, out: Array) -> void:
	if out.size() >= 8:
		return
	if a is Dictionary and b is Dictionary:
		var keys: Array = a.keys()
		for k in b.keys():
			if not keys.has(k):
				keys.append(k)
		keys.sort()
		for k in keys:
			_diff(path + "/" + str(k), a.get(k), b.get(k), out)
		return
	if a is Array and b is Array:
		var n: int = maxi(a.size(), b.size())
		for i in range(n):
			_diff(path + "[%d]" % i, a[i] if i < a.size() else null, b[i] if i < b.size() else null, out)
			if out.size() >= 8:
				return
		return
	if a is float and b is float:
		if absf(float(a) - float(b)) > 0.0000001:
			out.append("%s: %s != %s" % [path, str(a), str(b)])
		return
	if str(a) != str(b):
		out.append("%s: %s != %s" % [path, str(a), str(b)])
