extends Area2D
class_name ControlBall

var velocity = Vector2.ZERO
var radius = 5.8
var faction_id = 0

func setup(fid: int, pos: Vector2, vel: Vector2) -> void:
    faction_id = fid
    position = pos
    velocity = vel

func _ready() -> void:
    var shape = CircleShape2D.new()
    shape.radius = radius
    var cs = CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)
    z_index = 12
    queue_redraw()

func _draw() -> void:
    var c = GameConfig.faction_color(faction_id)
    draw_circle(Vector2(1.6, 1.8), radius + 1.4, Color(0, 0, 0, 0.25))
    draw_circle(Vector2.ZERO, radius + 0.8, Color(0.03, 0.03, 0.03, 0.85))
    draw_circle(Vector2.ZERO, radius, c.lightened(0.08))
    draw_circle(Vector2(1.0, 1.0), radius * 0.62, c.darkened(0.18))
    draw_circle(Vector2(-1.7, -1.7), radius * 0.30, Color(1, 1, 1, 0.80))
