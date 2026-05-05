extends Node2D
class_name PreviewChamber

@export var left_mode: bool = true
@export var chamber_size: Vector2 = Vector2(140.0, 176.0)
@export var left_label: String = "x2"
@export var right_label: String = "发射"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, chamber_size), Color(0.04, 0.04, 0.05, 0.97), true)
	draw_rect(Rect2(Vector2.ZERO, chamber_size), Color(0.28, 0.30, 0.33), false, 3.0)

	var peg_points: Array = [
		Vector2(33, 28), Vector2(67, 28), Vector2(101, 28),
		Vector2(18, 54), Vector2(52, 54), Vector2(86, 54), Vector2(120, 54),
		Vector2(33, 80), Vector2(67, 80), Vector2(101, 80),
		Vector2(18, 106), Vector2(52, 106), Vector2(86, 106), Vector2(120, 106),
		Vector2(33, 132), Vector2(67, 132), Vector2(101, 132),
		Vector2(18, 158), Vector2(52, 158), Vector2(86, 158), Vector2(120, 158)
	]
	for p in peg_points:
		draw_circle(p, 6.4, Color(0.26, 0.28, 0.32))

	var font = ThemeDB.fallback_font
	draw_string(font, Vector2(50, 106), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 82, Color(1, 1, 1, 0.32))

	var footer_left_text: String = left_label if left_mode else right_label
	var footer_right_text: String = right_label if left_mode else left_label
	draw_rect(Rect2(Vector2(0, 150), Vector2(chamber_size.x * 0.5, 26)), Color(0.76, 1.0, 0.18) if left_mode else Color(1.0, 0.57, 0.02), true)
	draw_rect(Rect2(Vector2(chamber_size.x * 0.5, 150), Vector2(chamber_size.x * 0.5, 26)), Color(1.0, 0.57, 0.02) if left_mode else Color(0.76, 1.0, 0.18), true)
	_draw_footer_text(font, Rect2(Vector2(0, 150), Vector2(chamber_size.x * 0.5, 26)), footer_left_text)
	_draw_footer_text(font, Rect2(Vector2(chamber_size.x * 0.5, 150), Vector2(chamber_size.x * 0.5, 26)), footer_right_text)

func _draw_footer_text(font, rect: Rect2, text_value: String) -> void:
	draw_string(font, Vector2(rect.position.x, rect.position.y + 19.0), text_value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 16, Color.BLACK)
