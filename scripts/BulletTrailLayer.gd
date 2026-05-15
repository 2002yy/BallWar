extends Node2D
class_name BulletTrailLayer

var bullet_pool
var redraw_timer: float = 0.0
var force_redraw: bool = true
var perf_elapsed: float = 0.0
var redraw_calls_this_second: int = 0
var redraw_calls_per_second: int = 0
var last_pressure_level: String = "none"
var last_trail_budget: int = 0
var last_degrade_reason: String = "none"

const LOW_TRAIL_REDRAW_INTERVAL: float = 0.024

func setup(new_bullet_pool) -> void:
	bullet_pool = new_bullet_pool
	force_redraw = true
	queue_redraw()

func request_trail_redraw() -> void:
	if _get_pressure_severity() >= 3:
		return
	force_redraw = true

func _process(delta: float) -> void:
	if bullet_pool == null or not is_instance_valid(bullet_pool):
		return

	_update_pressure_cache()
	redraw_timer -= delta
	if force_redraw or redraw_timer <= 0.0:
		redraw_timer = _current_redraw_interval()
		force_redraw = false
		queue_redraw()

	perf_elapsed += delta
	if perf_elapsed >= 1.0:
		redraw_calls_per_second = redraw_calls_this_second
		redraw_calls_this_second = 0
		perf_elapsed = 0.0

func _current_redraw_interval() -> float:
	var severity: int = _get_pressure_severity()
	match severity:
		3:
			return GameConfig.get_trail_redraw_interval_extreme()
		2:
			return GameConfig.get_trail_redraw_interval_high()
		1:
			return GameConfig.get_trail_redraw_interval_mid()
		_:
			return LOW_TRAIL_REDRAW_INTERVAL

func _draw() -> void:
	if bullet_pool == null or not is_instance_valid(bullet_pool):
		return

	_update_pressure_cache()
	redraw_calls_this_second += 1
	var severity: int = _get_pressure_severity()
	if severity >= 3:
		return
	var bullet_step: int = 1
	if severity >= 2:
		bullet_step = 3
	elif severity >= 1:
		bullet_step = 2

	var bullet_index: int = 0
	for bullet in bullet_pool.active_bullets:
		bullet_index += 1
		if bullet == null or not is_instance_valid(bullet):
			continue
		if not bullet.is_active:
			continue
		if bullet.simple_draw or bullet.trail_max_points <= 0:
			continue
		if bullet_step > 1 and (bullet_index % bullet_step) != 0:
			continue

		var trail_count: int = bullet.trail_points.size()
		if trail_count < 2:
			continue

		var base: Color = GameConfig.faction_color(bullet.faction_id)
		var radius: float = GameConfig.BULLET_RADIUS
		if bullet.has_method("get_visual_radius"):
			radius = float(bullet.get_visual_radius())

		var alpha_mul: float = 0.70 if bullet.reduce_visual_effects else 1.0
		_draw_single_trail(bullet.trail_points, base, radius, alpha_mul, severity, bullet.reduce_visual_effects)

func _draw_single_trail(points: Array, base: Color, radius: float, alpha_mul: float, severity: int, reduced: bool) -> void:
	var trail_count: int = points.size()
	var line_step: int = 1
	var point_step: int = 1
	match severity:
		3:
			line_step = 4
			point_step = 4
		2:
			line_step = 3
			point_step = 3
		1:
			line_step = 2
			point_step = 2
		_:
			line_step = 2 if reduced else 1
			point_step = 2 if reduced or trail_count >= 10 else 1

	for i in range(trail_count - 1, 0, -line_step):
		var p1_world: Vector2 = points[i]
		var next_index: int = maxi(i - line_step, 0)
		var p2_world: Vector2 = points[next_index]
		var p1: Vector2 = to_local(p1_world)
		var p2: Vector2 = to_local(p2_world)
		var t_line: float = 1.0 - float(i) / maxf(1.0, float(trail_count))
		var line_alpha: float = (0.12 + 0.40 * t_line) * alpha_mul
		var line_width: float = radius * (0.80 + 0.72 * t_line)
		draw_line(p1, p2, Color(base.r, base.g, base.b, line_alpha), line_width)

	for i in range(trail_count - 1, -1, -point_step):
		var world_point: Vector2 = points[i]
		var point: Vector2 = to_local(world_point)
		var t: float = 1.0 - float(i) / maxf(1.0, float(trail_count))
		var alpha: float = (0.15 + 0.66 * t) * alpha_mul
		var trail_r: float = radius * (0.78 + 0.92 * t)
		draw_circle(point, trail_r, Color(base.r, base.g, base.b, alpha))
		if severity <= 0 and not reduced and trail_count >= 5 and i % 2 == 0:
			draw_circle(point, trail_r * 0.48, Color(1.0, 1.0, 1.0, alpha * 0.18))

func get_debug_metrics() -> Dictionary:
	return {
		"redraw_calls_per_second": redraw_calls_per_second,
		"current_redraw_interval": _current_redraw_interval(),
		"trail_pressure_level": last_pressure_level,
		"trail_budget_active": last_trail_budget,
		"trail_degrade_reason": last_degrade_reason,
	}

func _update_pressure_cache() -> void:
	if bullet_pool == null or not is_instance_valid(bullet_pool):
		last_pressure_level = "none"
		last_trail_budget = 0
		last_degrade_reason = "none"
		return
	if bullet_pool.has_method("get_trail_pressure_state"):
		var state: Dictionary = bullet_pool.get_trail_pressure_state()
		last_pressure_level = str(state.get("trail_pressure_level", "none"))
		last_trail_budget = int(state.get("trail_points", 0))
		last_degrade_reason = str(state.get("trail_degrade_reason", "none"))

func _get_pressure_severity() -> int:
	match last_pressure_level:
		"extreme":
			return 3
		"high":
			return 2
		"mid":
			return 1
		_:
			return 0
