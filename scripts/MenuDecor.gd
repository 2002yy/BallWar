extends Node2D

var t: float = 0.0

func _ready() -> void:
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    t += delta
    queue_redraw()

func _draw() -> void:
    var board_size: float = 300.0
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

    _draw_chamber(Vector2(-378, -170), true)
    _draw_chamber(Vector2(208, -170), false)
    _draw_chamber(Vector2(-378, 88), true)
    _draw_chamber(Vector2(208, 88), false)

    _draw_turret(board_pos + Vector2(18, 18), Color(0.85, 0.18, 0.18), PI * 0.25 + 0.28 * sin(t * 1.1))
    _draw_turret(board_pos + Vector2(board_size - 18, 18), Color(0.95, 0.85, 0.16), PI * 0.75 + 0.28 * sin(t * 1.2 + 1.2))
    _draw_turret(board_pos + Vector2(18, board_size - 18), Color(0.20, 0.88, 0.26), -PI * 0.25 + 0.28 * sin(t * 1.0 + 2.0))
    _draw_turret(board_pos + Vector2(board_size - 18, board_size - 18), Color(0.22, 0.54, 0.96), PI * 1.25 + 0.28 * sin(t * 1.05 + 3.1))

func _draw_chamber(pos: Vector2, left_mode: bool) -> void:
    var size: Vector2 = Vector2(156, 176)
    draw_rect(Rect2(pos, size), Color(0.04, 0.04, 0.05, 0.97), true)
    draw_rect(Rect2(pos, size), Color(0.28, 0.30, 0.33), false, 3.0)

    var row_counts: Array = [3, 4, 5, 4, 3]
    var margin_x: float = 22.0
    var usable_width: float = size.x - margin_x * 2.0
    for row_index in range(row_counts.size()):
        var count: int = row_counts[row_index]
        var y: float = pos.y + 28.0 + row_index * 28.0
        var step: float = 0.0
        if count > 1:
            step = usable_width / float(count - 1)
        for i in range(count):
            draw_circle(Vector2(pos.x + margin_x + step * i, y), 6.5, Color(0.26, 0.28, 0.32))

    var font = ThemeDB.fallback_font
    draw_string(font, pos + Vector2(56, 106), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 82, Color(1, 1, 1, 0.32))

    if left_mode:
        draw_rect(Rect2(pos + Vector2(0, 150), Vector2(size.x * 0.5, 26)), Color(0.76, 1.0, 0.18), true)
        draw_rect(Rect2(pos + Vector2(size.x * 0.5, 150), Vector2(size.x * 0.5, 26)), Color(1.0, 0.57, 0.02), true)
        draw_string(font, pos + Vector2(22, 169), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
        draw_string(font, pos + Vector2(94, 169), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
    else:
        draw_rect(Rect2(pos + Vector2(0, 150), Vector2(size.x * 0.5, 26)), Color(1.0, 0.57, 0.02), true)
        draw_rect(Rect2(pos + Vector2(size.x * 0.5, 150), Vector2(size.x * 0.5, 26)), Color(0.76, 1.0, 0.18), true)
        draw_string(font, pos + Vector2(24, 169), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
        draw_string(font, pos + Vector2(98, 169), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)

func _draw_turret(p: Vector2, color: Color, angle: float) -> void:
    draw_circle(p, 14.0, color)
    draw_circle(p, 14.0, Color.BLACK, false, 2.0)
    var dir: Vector2 = Vector2.RIGHT.rotated(angle)
    var ortho: Vector2 = Vector2(-dir.y, dir.x)
    var barrel_rect: PackedVector2Array = PackedVector2Array([
        p + ortho * 3.0,
        p + dir * 21.0 + ortho * 3.0,
        p + dir * 21.0 - ortho * 3.0,
        p - ortho * 3.0
    ])
    draw_colored_polygon(barrel_rect, color.lightened(0.15))
