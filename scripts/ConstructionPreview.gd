extends Node2D
class_name ConstructionPreview

var cell := Vector2i(-1, -1)
var cell_size: int
var issue: String

func show_cell(next_cell: Vector2i, next_issue: String) -> void:
	cell = next_cell
	issue = next_issue
	visible = true
	queue_redraw()

func _draw() -> void:
	var origin := Vector2(cell) * cell_size
	var square := Rect2(origin, Vector2.ONE * cell_size)
	var color := Color(0.47, 1.0, 0.68) if issue.is_empty() else Color(1.0, 0.43, 0.44)
	draw_rect(square, Color(color, 0.32))
	draw_rect(square, color, false, 2.0)
	draw_arc(square.get_center(), GameConfig.TURRET_RADIUS, 0.0, TAU, 32, color, 2.0, true)

	var text := "可建造" if issue.is_empty() else issue
	var font := ThemeDB.fallback_font
	var font_size := 14
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var field := get_parent() as Battlefield
	var field_width := float(field.grid_size * cell_size)
	var label_x := clampf(square.get_center().x - text_width / 2.0, 5.0, field_width - text_width - 5.0)
	var label_y := square.position.y - 8.0 if square.position.y >= 28.0 else square.end.y + 18.0
	draw_rect(Rect2(Vector2(label_x - 4.0, label_y - 14.0), Vector2(text_width + 8.0, 19.0)), Color(0.04, 0.07, 0.10, 0.95))
	draw_string(font, Vector2(label_x, label_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
