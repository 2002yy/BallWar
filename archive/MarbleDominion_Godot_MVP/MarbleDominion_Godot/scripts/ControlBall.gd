extends Area2D
class_name ControlBall

var velocity := Vector2.ZERO
var radius := 6.0
var faction_id := 0

func setup(fid: int, pos: Vector2, vel: Vector2) -> void:
	faction_id = fid; position = pos; velocity = vel

func _ready() -> void:
	var shape := CircleShape2D.new(); shape.radius = radius
	var cs := CollisionShape2D.new(); cs.shape = shape; add_child(cs)
	z_index = 12; queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, GameConfig.faction_color(faction_id).lightened(0.1))
	draw_circle(Vector2.ZERO, radius, Color.BLACK, false, 1)
