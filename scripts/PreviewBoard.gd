extends Node2D
class_name PreviewBoard

@export var board_size: float = 300.0

func _draw() -> void:
	var board_pos: Vector2 = Vector2(-board_size * 0.5, -board_size * 0.5)
	var half: float = board_size * 0.5

	draw_rect(Rect2(board_pos - Vector2(18, 18), Vector2(board_size + 36, board_size + 36)), Color(0.05, 0.06, 0.10, 0.85), true)
	draw_rect(Rect2(board_pos, Vector2(board_size, board_size)), Color(0.12, 0.14, 0.20, 0.95), true)
	draw_rect(Rect2(board_pos, Vector2(half, half)), Color(0.85, 0.18, 0.18), true)
	draw_rect(Rect2(board_pos + Vector2(half, 0), Vector2(half, half)), Color(0.95, 0.85, 0.16), true)
	draw_rect(Rect2(board_pos + Vector2(0, half), Vector2(half, half)), Color(0.20, 0.88, 0.26), true)
	draw_rect(Rect2(board_pos + Vector2(half, half), Vector2(half, half)), Color(0.22, 0.54, 0.96), true)
	draw_rect(Rect2(board_pos, Vector2(board_size, board_size)), Color.BLACK, false, 4.0)
	draw_line(board_pos + Vector2(half, 0), board_pos + Vector2(half, board_size), Color(0, 0, 0, 0.8), 2.0)
	draw_line(board_pos + Vector2(0, half), board_pos + Vector2(board_size, half), Color(0, 0, 0, 0.8), 2.0)

	for i in range(0, 31):
		var p: float = i * (board_size / 30.0)
		draw_line(board_pos + Vector2(p, 0), board_pos + Vector2(p, board_size), Color(0, 0, 0, 0.08), 1.0)
		draw_line(board_pos + Vector2(0, p), board_pos + Vector2(board_size, p), Color(0, 0, 0, 0.08), 1.0)
