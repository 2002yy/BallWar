extends Node2D
class_name PreviewTurret

@export var turret_color: Color = Color(1, 1, 1, 1)
@export var barrel_angle_deg: float = 45.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, turret_color)
	draw_circle(Vector2.ZERO, 14.0, Color.BLACK, false, 2.0)
	var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(barrel_angle_deg))
	var ortho: Vector2 = Vector2(-dir.y, dir.x)
	var barrel_rect: PackedVector2Array = PackedVector2Array([
		ortho * 3.0,
		dir * 21.0 + ortho * 3.0,
		dir * 21.0 - ortho * 3.0,
		-ortho * 3.0
	])
	draw_colored_polygon(barrel_rect, turret_color.lightened(0.15))
