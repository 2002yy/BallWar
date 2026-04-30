extends Node2D
class_name Bullet

var faction_id = GameConfig.Faction.BLUE
var direction = Vector2.RIGHT
var speed = GameConfig.BULLET_SPEED
var battlefield
var target_turrets = {}
var last_cell = Vector2i(-999, -999)
var age = 0.0
var trail_points = []
var trail_max_points = 8

func setup(new_faction_id: int, new_position: Vector2, new_direction: Vector2, new_battlefield, new_target_turrets = {}) -> void:
    faction_id = new_faction_id
    global_position = new_position
    direction = new_direction.normalized()
    battlefield = new_battlefield
    target_turrets = new_target_turrets

func _ready() -> void:
    z_index = 30
    trail_points.append(global_position)
    queue_redraw()

func _physics_process(delta: float) -> void:
    if battlefield == null:
        queue_free()
        return

    age += delta
    if age >= GameConfig.BULLET_MAX_LIFETIME:
        queue_free()
        return

    var map_size = battlefield.grid_size * battlefield.cell_size
    var next_position = global_position + direction * speed * delta
    var local_position = battlefield.to_local(next_position)
    var bounced = false

    if local_position.x < 0.0:
        local_position.x = 0.0
        direction.x = abs(direction.x)
        bounced = true
    elif local_position.x > map_size:
        local_position.x = map_size
        direction.x = -abs(direction.x)
        bounced = true

    if local_position.y < 0.0:
        local_position.y = 0.0
        direction.y = abs(direction.y)
        bounced = true
    elif local_position.y > map_size:
        local_position.y = map_size
        direction.y = -abs(direction.y)
        bounced = true

    if bounced:
        direction = direction.normalized()

    global_position = battlefield.to_global(local_position)
    trail_points.push_front(global_position)
    while trail_points.size() > trail_max_points:
        trail_points.pop_back()
    queue_redraw()

    if _try_hit_enemy_turret():
        queue_free()
        return

    var cell = battlefield.world_to_cell(global_position)
    if not battlefield.is_inside(cell):
        return

    if cell == last_cell:
        return

    last_cell = cell
    var result = battlefield.apply_bullet(cell, faction_id)
    if result == "HIT_ENEMY_CELL":
        queue_free()

func _try_hit_enemy_turret() -> bool:
    for target_faction_id in target_turrets.keys():
        if target_faction_id == faction_id:
            continue
        var turret = target_turrets[target_faction_id]
        if turret == null:
            continue
        if turret.is_destroyed:
            continue
        if global_position.distance_to(turret.global_position) <= GameConfig.TURRET_HIT_RADIUS:
            turret.take_damage(GameConfig.BULLET_DAMAGE)
            return true
    return false

func _draw() -> void:
    var base = GameConfig.faction_color(faction_id)
    var radius = GameConfig.BULLET_RADIUS

    for i in range(trail_points.size() - 1, -1, -1):
        var world_point = trail_points[i]
        var p = to_local(world_point)
        var alpha = 0.08 + 0.36 * (1.0 - float(i) / maxf(1.0, float(trail_points.size())))
        var trail_r = radius * (0.45 + 0.45 * (1.0 - float(i) / maxf(1.0, float(trail_points.size()))))
        draw_circle(p, trail_r, Color(base.r, base.g, base.b, alpha))

    draw_circle(Vector2(2.8, 2.8), radius + 2.2, Color(0.0, 0.0, 0.0, 0.34))
    draw_circle(Vector2.ZERO, radius + 1.2, Color(0.05, 0.05, 0.05, 0.94))
    draw_circle(Vector2.ZERO, radius, base)
    draw_circle(Vector2(1.8, 1.8), radius * 0.64, base.darkened(0.26))
    draw_circle(Vector2(-2.2, -2.0), radius * 0.30, Color(1.0, 1.0, 1.0, 0.76))
    draw_circle(Vector2.ZERO, radius * 0.25, Color(1.0, 1.0, 1.0, 0.14))
