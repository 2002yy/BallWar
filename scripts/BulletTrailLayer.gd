extends Node2D
class_name BulletTrailLayer

var bullet_pool
var redraw_timer: float = 0.0
var force_redraw: bool = true

const LOW_TRAIL_REDRAW_INTERVAL: float = 0.016
const MID_TRAIL_REDRAW_INTERVAL: float = 0.024
const HIGH_TRAIL_REDRAW_INTERVAL: float = 0.040
const EXTREME_TRAIL_REDRAW_INTERVAL: float = 0.060

func setup(new_bullet_pool) -> void:
    bullet_pool = new_bullet_pool
    force_redraw = true
    queue_redraw()

func request_trail_redraw() -> void:
    force_redraw = true

func _process(delta: float) -> void:
    if bullet_pool == null or not is_instance_valid(bullet_pool):
        return

    redraw_timer -= delta
    if force_redraw or redraw_timer <= 0.0:
        redraw_timer = _current_redraw_interval()
        force_redraw = false
        queue_redraw()

func _current_redraw_interval() -> float:
    if bullet_pool == null or not is_instance_valid(bullet_pool) or not bullet_pool.has_method("get_active_count"):
        return MID_TRAIL_REDRAW_INTERVAL

    var active_count: int = int(bullet_pool.get_active_count())
    if active_count >= GameConfig.get_force_simple_threshold():
        return EXTREME_TRAIL_REDRAW_INTERVAL
    if active_count >= GameConfig.get_high_pressure_threshold():
        return HIGH_TRAIL_REDRAW_INTERVAL
    if active_count >= GameConfig.get_mid_pressure_threshold():
        return MID_TRAIL_REDRAW_INTERVAL
    return LOW_TRAIL_REDRAW_INTERVAL

func _draw() -> void:
    if bullet_pool == null or not is_instance_valid(bullet_pool):
        return

    for bullet in bullet_pool.active_bullets:
        if bullet == null or not is_instance_valid(bullet):
            continue
        if not bullet.is_active:
            continue
        if bullet.simple_draw or bullet.trail_max_points <= 0:
            continue

        var trail_count: int = bullet.trail_points.size()
        if trail_count < 2:
            continue

        var base: Color = GameConfig.faction_color(bullet.faction_id)
        var radius: float = GameConfig.BULLET_RADIUS
        if bullet.has_method("get_visual_radius"):
            radius = float(bullet.get_visual_radius())

        var alpha_mul: float = 0.70 if bullet.reduce_visual_effects else 1.0
        _draw_single_trail(bullet.trail_points, base, radius, alpha_mul, bullet.reduce_visual_effects)

func _draw_single_trail(points: Array, base: Color, radius: float, alpha_mul: float, reduced: bool) -> void:
    var trail_count: int = points.size()

    for i in range(trail_count - 1, 0, -1):
        var p1_world: Vector2 = points[i]
        var p2_world: Vector2 = points[i - 1]
        var p1: Vector2 = to_local(p1_world)
        var p2: Vector2 = to_local(p2_world)
        var t_line: float = 1.0 - float(i) / maxf(1.0, float(trail_count))
        var line_alpha: float = (0.12 + 0.40 * t_line) * alpha_mul
        var line_width: float = radius * (0.80 + 0.72 * t_line)
        draw_line(p1, p2, Color(base.r, base.g, base.b, line_alpha), line_width)

    for i in range(trail_count - 1, -1, -1):
        var world_point: Vector2 = points[i]
        var point: Vector2 = to_local(world_point)
        var t: float = 1.0 - float(i) / maxf(1.0, float(trail_count))
        var alpha: float = (0.15 + 0.66 * t) * alpha_mul
        var trail_r: float = radius * (0.78 + 0.92 * t)
        draw_circle(point, trail_r, Color(base.r, base.g, base.b, alpha))
        if not reduced and trail_count >= 5 and i % 2 == 0:
            draw_circle(point, trail_r * 0.48, Color(1.0, 1.0, 1.0, alpha * 0.18))
