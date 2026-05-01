extends Node2D
class_name BulletPool

var inactive_bullets: Array = []
var active_bullets: Array = []
var visual_pressure_update_timer: float = 0.0
var trail_layer
const VISUAL_PRESSURE_UPDATE_INTERVAL: float = 0.25

func _process(delta: float) -> void:
    visual_pressure_update_timer -= delta
    if visual_pressure_update_timer <= 0.0:
        visual_pressure_update_timer = VISUAL_PRESSURE_UPDATE_INTERVAL
        update_visual_pressure()

func set_trail_layer(new_trail_layer) -> void:
    trail_layer = new_trail_layer
    if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("setup"):
        trail_layer.setup(self)

func spawn_bullet(faction_id: int, pos: Vector2, dir: Vector2, battlefield, target_turrets: Dictionary = {}) -> Bullet:
    # 性能保护阀：
    # 低压力：完整拖尾；
    # 中压力：拖尾减少；
    # 高压力：拖尾极简；
    # 极高压力：简化绘制，并回收最老子弹防止无限堆节点。
    var max_active: int = GameConfig.get_max_active_bullets()
    while active_bullets.size() >= max_active and active_bullets.size() > 0:
        recycle_bullet(active_bullets[0])

    var bullet: Bullet
    if inactive_bullets.size() > 0:
        bullet = inactive_bullets.pop_back()
    else:
        bullet = Bullet.new()
        bullet.pool = self
        add_child(bullet)

    var active_count: int = active_bullets.size()
    bullet.pool = self
    if bullet.has_method("set_trail_layer"):
        bullet.set_trail_layer(trail_layer)
    bullet.simple_draw = active_count >= GameConfig.get_force_simple_threshold()
    bullet.reduce_visual_effects = active_count >= GameConfig.get_high_pressure_threshold()

    if active_count >= GameConfig.get_high_pressure_threshold():
        bullet.trail_max_points = GameConfig.get_high_trail_points()
    elif active_count >= GameConfig.get_mid_pressure_threshold():
        bullet.trail_max_points = GameConfig.get_mid_trail_points()
    else:
        bullet.trail_max_points = GameConfig.get_normal_trail_points()

    bullet.setup(faction_id, pos, dir, battlefield, target_turrets)
    bullet.activate()
    active_bullets.append(bullet)
    if trail_layer != null and is_instance_valid(trail_layer) and trail_layer.has_method("request_trail_redraw"):
        trail_layer.request_trail_redraw()
    return bullet

func update_visual_pressure() -> void:
    var active_count: int = active_bullets.size()
    var use_simple_draw: bool = active_count >= GameConfig.get_force_simple_threshold()
    var use_reduced_effects: bool = active_count >= GameConfig.get_high_pressure_threshold()
    var trail_points: int = GameConfig.get_normal_trail_points()

    if active_count >= GameConfig.get_high_pressure_threshold():
        trail_points = GameConfig.get_high_trail_points()
    elif active_count >= GameConfig.get_mid_pressure_threshold():
        trail_points = GameConfig.get_mid_trail_points()

    for bullet in active_bullets:
        if bullet != null and is_instance_valid(bullet) and bullet.is_active:
            bullet.configure_visuals(use_simple_draw, use_reduced_effects, trail_points)

func recycle_bullet(bullet: Bullet) -> void:
    if bullet == null:
        return
    var idx: int = active_bullets.find(bullet)
    if idx >= 0:
        active_bullets.remove_at(idx)
    if inactive_bullets.find(bullet) < 0:
        inactive_bullets.append(bullet)
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

func get_active_count() -> int:
    return active_bullets.size()

func get_pressure_level() -> String:
    var active_count: int = active_bullets.size()
    if active_count >= GameConfig.get_force_simple_threshold():
        return "极高"
    if active_count >= GameConfig.get_high_pressure_threshold():
        return "高"
    if active_count >= GameConfig.get_mid_pressure_threshold():
        return "中"
    return "低"
