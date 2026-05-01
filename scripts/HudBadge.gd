extends Control
class_name HudBadge

var accent_color: Color = Color(1.0, 0.78, 0.22)

func _ready() -> void:
    custom_minimum_size = Vector2(34, 34)

func _draw() -> void:
    var center: Vector2 = size * 0.5
    var r: float = min(size.x, size.y) * 0.42
    var points: PackedVector2Array = PackedVector2Array()
    for i in range(6):
        var ang: float = TAU * float(i) / 6.0 - PI * 0.5
        points.append(center + Vector2.RIGHT.rotated(ang) * r)
    draw_colored_polygon(points, Color(0.09, 0.10, 0.14, 0.98))
    draw_polyline(points, Color(accent_color.r, accent_color.g, accent_color.b, 0.9), 2.4, true)
    draw_circle(center, r * 0.56, accent_color)
    draw_circle(center, r * 0.34, Color(0.12, 0.14, 0.18, 0.95))
    draw_line(center + Vector2(-r * 0.75, 0), center + Vector2(r * 0.75, 0), Color(1,1,1,0.18), 1.6)
    draw_line(center + Vector2(0, -r * 0.75), center + Vector2(0, r * 0.75), Color(1,1,1,0.18), 1.6)
    draw_circle(center + Vector2(-r * 0.18, -r * 0.18), r * 0.12, Color(1.0, 1.0, 1.0, 0.36))
