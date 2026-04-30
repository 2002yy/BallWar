extends Node2D
class_name BulletPool

const SIMPLE_TRAIL_THRESHOLD: int = 900
const NORMAL_TRAIL_POINTS: int = 8
const SIMPLE_TRAIL_POINTS: int = 3

var inactive_bullets: Array = []
var active_bullets: Array = []

func spawn_bullet(faction_id: int, pos: Vector2, dir: Vector2, battlefield, target_turrets: Dictionary = {}) -> Bullet:
    var bullet: Bullet
    if inactive_bullets.size() > 0:
        bullet = inactive_bullets.pop_back()
    else:
        bullet = Bullet.new()
        bullet.pool = self
        add_child(bullet)

    bullet.pool = self
    bullet.trail_max_points = SIMPLE_TRAIL_POINTS if active_bullets.size() >= SIMPLE_TRAIL_THRESHOLD else NORMAL_TRAIL_POINTS
    bullet.setup(faction_id, pos, dir, battlefield, target_turrets)
    bullet.activate()
    active_bullets.append(bullet)
    return bullet

func recycle_bullet(bullet: Bullet) -> void:
    if bullet == null:
        return
    var idx: int = active_bullets.find(bullet)
    if idx >= 0:
        active_bullets.remove_at(idx)
    if inactive_bullets.find(bullet) < 0:
        inactive_bullets.append(bullet)
    bullet.deactivate()

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
    return get_active_bullets().size()
