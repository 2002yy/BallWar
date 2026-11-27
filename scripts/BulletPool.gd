extends Node2D
class_name BulletPool

var inactive_bullets: Array = []
var inactive_ids: Dictionary = {}
var active_bullets: Array = []
var active_bullet_indices: Dictionary = {}
var active_spawn_order: Array[int] = []
var active_spawn_cursor: int = 0
var peak_active_count: int = 0
var visual_pressure_update_timer: float = 0.0
var trail_layer
var tracked_turrets: Dictionary = {}
var tracked_queue_by_faction: Dictionary = {}
var tracked_queue_total: int = 0
var bullet_trail_segments: Dictionary = {}
var trail_segments_total: int = 0
var perf_elapsed: float = 0.0
var spawned_bullets_this_second: int = 0
var spawned_bullets_per_second: int = 0
var recycled_bullets_this_second: int = 0
var recycled_bullets_per_second: int = 0
var expired_bullets_this_second: int = 0
var expired_bullets_per_second: int = 0
var last_visual_profile: Dictionary = {
	"simple_draw": false,
	"reduce_visual_effects": false,
	"trail_points": 0,
	"trail_pressure_level": "none",
	"trail_pressure_severity": 0,
	"trail_degrade_reason": "none",
}

# P1 互撞开关：默认关闭，经典规则完全不变。
# 开启后由本节点统一推进所有炮弹（移动 → 碰撞 → 结算 → 回收），
# 每颗弹不再各自完整执行 _physics_process。
var collision_enabled: bool = false
var collision_reverse_order: bool = false
var collision_resolver = BulletCollisionResolver.new()
var collision_stats: Dictionary = {}
var collision_total_hits: int = 0
var total_spawned: int = 0
var next_spawn_serial: int = 1
var battlefield = null
var _step_scratch: Array = []

const VISUAL_PRESSURE_UPDATE_INTERVAL: float = 0.35
const PRIORITY: Dictionary = {
	"none": 0,
	"queue_high": 1,
	"active_bullets_high": 2,
	"trail_redraw_high": 3,
	"trail_segments_high": 4,
	"fps_low": 5,
}
const ACTIVE_SPAWN_ORDER_COMPACT_CURSOR_THRESHOLD: int = 256

func _ready() -> void:
	collision_enabled = _env_flag("BALLWAR_BULLET_COLLISION", false)
	collision_reverse_order = _env_string("BALLWAR_COLLISION_ORDER", "forward") == "reverse"
	collision_resolver.configure(float(GameConfig.CELL_SIZE), _env_int("BALLWAR_COLLISION_BUCKET_CELLS", BulletCollisionResolver.DEFAULT_BUCKET_CELLS))
	set_physics_process(collision_enabled)

func _physics_process(delta: float) -> void:
	if not collision_enabled:
		return
	step_controlled(delta)

func step_controlled(delta: float) -> void:
	# 唯一的执行顺序：全部移动 → 统一碰撞 → 统一结算（炮台/领土）→ 回收。
	_step_scratch.clear()
	for bullet in active_bullets:
		if bullet != null and is_instance_valid(bullet) and bullet.is_active:
			_step_scratch.append(bullet)

	for bullet in _step_scratch:
		if bullet.is_active:
			bullet.advance_tick(delta)

	collision_resolver.resolve(_step_scratch, self, delta)
	collision_stats = collision_resolver.last_stats.duplicate()
	collision_total_hits = collision_resolver.total_hits

	if collision_reverse_order:
		for index in range(_step_scratch.size() - 1, -1, -1):
			var bullet = _step_scratch[index]
			if bullet != null and is_instance_valid(bullet) and bullet.is_active:
				bullet.resolve_tick()
	else:
		for bullet in _step_scratch:
			if bullet != null and is_instance_valid(bullet) and bullet.is_active:
				bullet.resolve_tick()

func set_battlefield(value) -> void:
	battlefield = value
	collision_resolver.configure(_cell_size(), _env_int("BALLWAR_COLLISION_BUCKET_CELLS", collision_resolver.bucket_cells))

func set_collision_enabled(value: bool) -> void:
	collision_enabled = value
	set_physics_process(value)
	for bullet in active_bullets:
		if bullet != null and is_instance_valid(bullet):
			bullet.set_controlled(value)

func set_collision_bucket_cells(cells: int) -> void:
	collision_resolver.configure(_cell_size(), cells)

func get_collision_stats() -> Dictionary:
	var stats: Dictionary = collision_stats.duplicate()
	stats["enabled"] = collision_enabled
	stats["total_hits"] = collision_total_hits
	stats["total_spawned"] = total_spawned
	stats["bucket_size"] = collision_resolver.bucket_size
	stats["bucket_cells"] = collision_resolver.bucket_cells
	return stats

func _cell_size() -> float:
	if battlefield != null and is_instance_valid(battlefield):
		return float(battlefield.cell_size)
	return float(GameConfig.CELL_SIZE)

func _env_flag(name: String, fallback: bool) -> bool:
	var raw: String = OS.get_environment(name).strip_edges().to_lower()
	if raw == "":
		return fallback
	return raw == "1" or raw == "true" or raw == "yes" or raw == "on"

func _env_int(name: String, fallback: int) -> int:
	var raw: String = OS.get_environment(name).strip_edges()
	if raw == "" or not raw.is_valid_int():
		return fallback
	return int(raw)

func _env_string(name: String, fallback: String) -> String:
	var raw: String = OS.get_environment(name).strip_edges()
	return raw if raw != "" else fallback

func _process(delta: float) -> void:
	visual_pressure_update_timer -= delta
	if visual_pressure_update_timer <= 0.0:
		visual_pressure_update_timer = VISUAL_PRESSURE_UPDATE_INTERVAL
		update_visual_pressure()

	perf_elapsed += delta
	if perf_elapsed >= 1.0:
		spawned_bullets_per_second = spawned_bullets_this_second
		recycled_bullets_per_second = recycled_bullets_this_second
		expired_bullets_per_second = expired_bullets_this_second
		spawned_bullets_this_second = 0
		recycled_bullets_this_second = 0
		expired_bullets_this_second = 0
		perf_elapsed = 0.0

func set_trail_layer(new_trail_layer) -> void:
	trail_layer = new_trail_layer
	if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("setup"):
		trail_layer.setup(self )

func set_tracked_turrets(turret_map: Dictionary) -> void:
	_disconnect_tracked_turrets()
	tracked_turrets = turret_map
	tracked_queue_by_faction.clear()
	tracked_queue_total = 0
	for faction_id in tracked_turrets.keys():
		var turret = tracked_turrets[faction_id]
		if turret == null or not is_instance_valid(turret):
			continue
		tracked_queue_by_faction[faction_id] = int(turret.get("burst_remaining"))
		tracked_queue_total += int(tracked_queue_by_faction[faction_id])
		var progress_callable: Callable = Callable(self, "_on_tracked_turret_burst_progress")
		if not turret.burst_progress.is_connected(progress_callable):
			turret.burst_progress.connect(progress_callable)

func spawn_bullet(faction_id: int, pos: Vector2, dir: Vector2, battlefield, target_turrets: Dictionary = {}):
	var max_active: int = GameConfig.get_max_active_bullets()
	while active_bullets.size() >= max_active and active_bullets.size() > 0:
		var oldest_bullet = _get_oldest_active_bullet()
		if oldest_bullet == null:
			prune_invalid_bullets()
			oldest_bullet = _get_oldest_active_bullet()
		if oldest_bullet == null:
			break
		recycle_bullet(oldest_bullet)

	var bullet = _obtain_bullet_with_visual_profile()
	bullet.setup(faction_id, pos, dir, battlefield, target_turrets)
	bullet.activate()
	return _finalize_spawned_bullet(bullet)

func spawn_bullet_from_state(state: Dictionary, battlefield, target_turrets: Dictionary = {}):
	var max_active: int = GameConfig.get_max_active_bullets()
	while active_bullets.size() >= max_active and active_bullets.size() > 0:
		var oldest_bullet = _get_oldest_active_bullet()
		if oldest_bullet == null:
			prune_invalid_bullets()
			oldest_bullet = _get_oldest_active_bullet()
		if oldest_bullet == null:
			break
		recycle_bullet(oldest_bullet)

	var bullet = _obtain_bullet_with_visual_profile()
	bullet.restore_from_state(state, battlefield, target_turrets)
	bullet.activate()
	return _finalize_spawned_bullet(bullet)

func update_visual_pressure() -> void:
	var visual_profile: Dictionary = _resolve_visual_profile(active_bullets.size())
	last_visual_profile = visual_profile.duplicate(true)
	var use_simple_draw: bool = bool(visual_profile.get("simple_draw", false))
	var use_reduced_effects: bool = bool(visual_profile.get("reduce_visual_effects", false))
	var trail_points: int = int(visual_profile.get("trail_points", GameConfig.get_normal_trail_points()))

	for bullet in active_bullets:
		if bullet != null and is_instance_valid(bullet) and bullet.is_active:
			bullet.configure_visuals(use_simple_draw, use_reduced_effects, trail_points)

func recycle_bullet(bullet) -> void:
	if bullet == null:
		return
	_remove_active_bullet_fast(bullet)
	_unregister_active_bullet(bullet)
	var bullet_id: int = bullet.get_instance_id()
	if not inactive_ids.has(bullet_id):
		inactive_bullets.append(bullet)
		inactive_ids[bullet_id] = true
	recycled_bullets_this_second += 1
	bullet.deactivate()
	if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("request_trail_redraw"):
		trail_layer.request_trail_redraw()

func clear_active() -> void:
	var copy: Array = active_bullets.duplicate()
	for bullet in copy:
		recycle_bullet(bullet)

func get_active_bullets() -> Array:
	var result: Array = []
	for bullet in active_bullets:
		if bullet != null and is_instance_valid(bullet) and bullet.is_active:
			result.append(bullet)
	return result

func prune_invalid_bullets() -> void:
	var removed_any: bool = false
	for i in range(active_bullets.size() - 1, -1, -1):
		var b = active_bullets[i]
		if b == null or not is_instance_valid(b) or not b.is_active:
			_remove_active_bullet_at(i)
			removed_any = true
	if removed_any:
		_rebuild_active_bullet_indices()
	_compact_active_spawn_order()

func get_active_count() -> int:
	return active_bullets.size()

func get_peak_active_count() -> int:
	return peak_active_count

func reset_stats() -> void:
	peak_active_count = 0
	collision_resolver.reset_stats()
	collision_stats = {}
	collision_total_hits = 0

func get_tracked_queue_total() -> int:
	return tracked_queue_total

func estimate_trail_segments() -> int:
	return trail_segments_total

func get_debug_metrics() -> Dictionary:
	var visual_profile: Dictionary = _get_current_visual_profile()
	return {
		"active_bullets": get_active_count(),
		"tracked_queue_total": get_tracked_queue_total(),
		"spawned_bullets_per_second": spawned_bullets_per_second,
		"recycled_bullets_per_second": recycled_bullets_per_second,
		"expired_bullets_per_second": expired_bullets_per_second,
		"trail_segments_estimate": estimate_trail_segments(),
		"trail_pressure_level": str(visual_profile.get("trail_pressure_level", "none")),
		"trail_pressure_severity": int(visual_profile.get("trail_pressure_severity", 0)),
		"trail_budget_active": int(visual_profile.get("trail_points", GameConfig.get_normal_trail_points())) > 0,
		"trail_degrade_reason": str(visual_profile.get("trail_degrade_reason", "none")),
		"current_fps": floori(Engine.get_frames_per_second()),
		"draw_calls": _read_draw_calls_monitor(),
		"visible_canvas_items_estimate": _estimate_visible_canvas_items(),
	}

func notify_bullet_expired() -> void:
	expired_bullets_this_second += 1

func notify_bullet_trail_changed(bullet, new_segments: int) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	var bullet_id: int = bullet.get_instance_id()
	var previous_segments: int = int(bullet_trail_segments.get(bullet_id, 0))
	var next_segments: int = maxi(0, new_segments)
	if previous_segments == next_segments:
		return
	trail_segments_total += next_segments - previous_segments
	if next_segments <= 0:
		bullet_trail_segments.erase(bullet_id)
	else:
		bullet_trail_segments[bullet_id] = next_segments

func get_trail_pressure_state() -> Dictionary:
	return _get_current_visual_profile().duplicate(true)

func _get_current_visual_profile() -> Dictionary:
	if last_visual_profile.is_empty():
		last_visual_profile = _resolve_visual_profile(active_bullets.size())
	return last_visual_profile

func _resolve_visual_profile(active_count: int) -> Dictionary:
	var fps: int = floori(Engine.get_frames_per_second())
	var queue_total: int = get_tracked_queue_total()
	var trail_segments: int = estimate_trail_segments()
	var trail_redraws: int = 0
	if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("get_debug_metrics"):
		trail_redraws = int(trail_layer.get_debug_metrics().get("redraw_calls_per_second", 0))

	var severity: int = 0
	var reason: String = "none"

	if active_count >= GameConfig.get_force_simple_threshold():
		severity = 3
		reason = _prefer_reason(reason, "active_bullets_high", 3, severity)
	elif active_count >= GameConfig.get_high_pressure_threshold():
		severity = maxi(severity, 2)
		reason = _prefer_reason(reason, "active_bullets_high", 2, severity)
	elif active_count >= GameConfig.get_mid_pressure_threshold():
		severity = maxi(severity, 1)
		reason = _prefer_reason(reason, "active_bullets_high", 1, severity)

	if queue_total >= 1500:
		severity = maxi(severity, 3)
		reason = _prefer_reason(reason, "queue_high", 3, severity)
	elif queue_total >= 1000:
		severity = maxi(severity, 2)
		reason = _prefer_reason(reason, "queue_high", 2, severity)
	elif queue_total >= 500:
		severity = maxi(severity, 1)
		reason = _prefer_reason(reason, "queue_high", 1, severity)

	if trail_segments >= GameConfig.get_trail_extreme_segments_threshold():
		severity = maxi(severity, 3)
		reason = _prefer_reason(reason, "trail_segments_high", 3, severity)
	elif trail_segments >= GameConfig.get_trail_high_segments_threshold():
		severity = maxi(severity, 2)
		reason = _prefer_reason(reason, "trail_segments_high", 2, severity)
	elif trail_segments >= GameConfig.get_trail_mid_segments_threshold():
		severity = maxi(severity, 1)
		reason = _prefer_reason(reason, "trail_segments_high", 1, severity)

	if fps > 0:
		if fps < GameConfig.get_trail_extreme_fps_threshold():
			severity = maxi(severity, 3)
			reason = _prefer_reason(reason, "fps_low", 3, severity)
		elif fps < GameConfig.get_trail_high_fps_threshold():
			severity = maxi(severity, 2)
			reason = _prefer_reason(reason, "fps_low", 2, severity)
		elif fps < GameConfig.get_trail_mid_fps_threshold():
			severity = maxi(severity, 1)
			reason = _prefer_reason(reason, "fps_low", 1, severity)

	if trail_redraws >= GameConfig.get_trail_extreme_redraws_threshold():
		severity = maxi(severity, 3)
		reason = _prefer_reason(reason, "trail_redraw_high", 3, severity)
	elif trail_redraws >= GameConfig.get_trail_high_redraws_threshold():
		severity = maxi(severity, 2)
		reason = _prefer_reason(reason, "trail_redraw_high", 2, severity)
	elif trail_redraws >= GameConfig.get_trail_mid_redraws_threshold():
		severity = maxi(severity, 1)
		reason = _prefer_reason(reason, "trail_redraw_high", 1, severity)

	var trail_points: int = GameConfig.get_normal_trail_points()
	var use_reduced_effects: bool = severity >= 1
	var use_simple_draw: bool = severity >= 3 or active_count >= GameConfig.get_force_simple_threshold()
	match severity:
		3:
			trail_points = 0
		2:
			trail_points = GameConfig.get_high_trail_points()
		1:
			trail_points = GameConfig.get_mid_trail_points()
		_:
			if active_count >= GameConfig.get_high_pressure_threshold():
				trail_points = GameConfig.get_high_trail_points()
			elif active_count >= GameConfig.get_mid_pressure_threshold():
				trail_points = GameConfig.get_mid_trail_points()

	return {
		"simple_draw": use_simple_draw,
		"reduce_visual_effects": use_reduced_effects,
		"trail_points": maxi(trail_points, 0),
		"trail_pressure_level": _severity_to_level(severity),
		"trail_pressure_severity": severity,
		"trail_degrade_reason": reason,
	}

func _severity_to_level(severity: int) -> String:
	match severity:
		3:
			return "extreme"
		2:
			return "high"
		1:
			return "mid"
		_:
			return "none"

func _read_draw_calls_monitor() -> int:
	for monitor_name in ["RENDER_TOTAL_DRAW_CALLS_IN_FRAME", "RENDER_TOTAL_PRIMITIVES_IN_FRAME"]:
		var monitor_value = _try_get_performance_monitor(monitor_name)
		if monitor_value != null:
			return int(monitor_value)
	return -1

func _try_get_performance_monitor(constant_name: String):
	if not ClassDB.class_has_integer_constant("Performance", constant_name):
		return null
	var monitor_id: int = ClassDB.class_get_integer_constant("Performance", constant_name)
	return Performance.get_monitor(monitor_id)

func _estimate_visible_canvas_items() -> int:
	return get_active_count() + estimate_trail_segments()

func _disconnect_tracked_turrets() -> void:
	var progress_callable: Callable = Callable(self, "_on_tracked_turret_burst_progress")
	for turret in tracked_turrets.values():
		if turret == null or not is_instance_valid(turret):
			continue
		if turret.burst_progress.is_connected(progress_callable):
			turret.burst_progress.disconnect(progress_callable)

func _on_tracked_turret_burst_progress(faction_id, remaining) -> void:
	var previous_remaining: int = int(tracked_queue_by_faction.get(faction_id, 0))
	var next_remaining: int = maxi(0, int(remaining))
	if previous_remaining == next_remaining:
		return
	tracked_queue_total += next_remaining - previous_remaining
	tracked_queue_by_faction[faction_id] = next_remaining

func _register_active_bullet(bullet) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	var current_segments: int = 0
	if bullet.has_method("get_trail_segment_count"):
		current_segments = int(bullet.get_trail_segment_count())
	else:
		current_segments = maxi(0, bullet.trail_points.size() - 1)
	notify_bullet_trail_changed(bullet, current_segments)

func _unregister_active_bullet(bullet) -> void:
	if bullet == null:
		return
	notify_bullet_trail_changed(bullet, 0)

func _obtain_bullet_with_visual_profile():
	var bullet
	if inactive_bullets.size() > 0:
		bullet = inactive_bullets.pop_back()
		inactive_ids.erase(bullet.get_instance_id())
	else:
		bullet = Bullet.new()
		bullet.pool = self
		add_child(bullet)

	var visual_profile: Dictionary = _resolve_visual_profile(active_bullets.size())
	last_visual_profile = visual_profile.duplicate(true)
	bullet.pool = self
	if bullet.has_method("set_trail_layer"):
		bullet.set_trail_layer(trail_layer)
	bullet.simple_draw = bool(visual_profile.get("simple_draw", false))
	bullet.reduce_visual_effects = bool(visual_profile.get("reduce_visual_effects", false))
	bullet.trail_max_points = int(visual_profile.get("trail_points", GameConfig.get_normal_trail_points()))
	bullet.set_controlled(collision_enabled)
	return bullet

func _finalize_spawned_bullet(bullet):
	var bullet_id: int = bullet.get_instance_id()
	bullet.spawn_serial = next_spawn_serial
	next_spawn_serial += 1
	total_spawned += 1
	active_bullet_indices[bullet_id] = active_bullets.size()
	active_bullets.append(bullet)
	active_spawn_order.append(bullet_id)
	peak_active_count = maxi(peak_active_count, active_bullets.size())
	_register_active_bullet(bullet)
	spawned_bullets_this_second += 1
	if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("request_trail_redraw"):
		trail_layer.request_trail_redraw()
	return bullet

func _remove_active_bullet_fast(bullet) -> bool:
	if bullet == null or not is_instance_valid(bullet):
		return false
	var bullet_id: int = bullet.get_instance_id()
	if not active_bullet_indices.has(bullet_id):
		return false
	var idx: int = int(active_bullet_indices[bullet_id])
	_remove_active_bullet_at(idx)
	return true

func _remove_active_bullet_at(idx: int) -> void:
	if idx < 0 or idx >= active_bullets.size():
		return
	var last_idx: int = active_bullets.size() - 1
	var removed_bullet = active_bullets[idx]
	var removed_bullet_id: int = removed_bullet.get_instance_id() if removed_bullet != null and is_instance_valid(removed_bullet) else -1
	if idx != last_idx:
		var last_bullet = active_bullets[last_idx]
		active_bullets[idx] = last_bullet
		if last_bullet != null and is_instance_valid(last_bullet):
			active_bullet_indices[last_bullet.get_instance_id()] = idx
	active_bullets.pop_back()
	if removed_bullet_id >= 0:
		active_bullet_indices.erase(removed_bullet_id)
	if active_bullets.is_empty():
		active_spawn_order.clear()
		active_spawn_cursor = 0
	elif active_spawn_cursor >= ACTIVE_SPAWN_ORDER_COMPACT_CURSOR_THRESHOLD:
		_compact_active_spawn_order()

func _get_oldest_active_bullet():
	while active_spawn_cursor < active_spawn_order.size():
		var bullet_id: int = int(active_spawn_order[active_spawn_cursor])
		var idx: int = int(active_bullet_indices.get(bullet_id, -1))
		if idx < 0 or idx >= active_bullets.size():
			active_spawn_cursor += 1
			continue
		var bullet = active_bullets[idx]
		if bullet == null or not is_instance_valid(bullet):
			active_spawn_cursor += 1
			continue
		if bullet.get_instance_id() != bullet_id or not bullet.is_active:
			active_spawn_cursor += 1
			continue
		return bullet
	return null

func _compact_active_spawn_order() -> void:
	if active_spawn_order.is_empty():
		active_spawn_cursor = 0
		return
	if active_spawn_cursor <= 0:
		return
	var compacted: Array[int] = []
	for i in range(active_spawn_cursor, active_spawn_order.size()):
		var bullet_id: int = int(active_spawn_order[i])
		if active_bullet_indices.has(bullet_id):
			compacted.append(bullet_id)
	active_spawn_order = compacted
	active_spawn_cursor = 0

func _rebuild_active_bullet_indices() -> void:
	active_bullet_indices.clear()
	for i in range(active_bullets.size()):
		var bullet = active_bullets[i]
		if bullet == null or not is_instance_valid(bullet):
			continue
		active_bullet_indices[bullet.get_instance_id()] = i

func _prefer_reason(current_reason: String, candidate_reason: String, candidate_severity: int, new_severity: int) -> String:
	if candidate_severity < new_severity and current_reason != "none":
		return current_reason
	if candidate_severity > 0 and PRIORITY.get(candidate_reason, 0) >= int(PRIORITY.get(current_reason, 0)):
		return candidate_reason
	return current_reason

func get_pressure_level() -> String:
	var level: String = str(_get_current_visual_profile().get("trail_pressure_level", "none"))
	match level:
		"extreme":
			return "极高"
		"high":
			return "高"
		"mid":
			return "中"
		_:
			return "低"
