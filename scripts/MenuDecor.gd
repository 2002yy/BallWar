extends Node2D

var t = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var board_size = 250.0
	var board_pos = Vector2(-board_size * 0.5, -board_size * 0.5)
	var half = board_size * 0.5

	draw_rect(Rect2(board_pos, Vector2(board_size, board_size)), Color(0.12, 0.14, 0.20, 0.95), true)
	draw_rect(Rect2(board_pos, Vector2(half, half)), GameConfig.faction_color(GameConfig.Faction.RED).darkened(0.20), true)
	draw_rect(Rect2(board_pos + Vector2(half, 0), Vector2(half, half)), GameConfig.faction_color(GameConfig.Faction.BLUE).darkened(0.18), true)
	draw_rect(Rect2(board_pos + Vector2(0, half), Vector2(half, half)), GameConfig.faction_color(GameConfig.Faction.YELLOW).darkened(0.20), true)
	draw_rect(Rect2(board_pos + Vector2(half, half), Vector2(half, half)), GameConfig.faction_color(GameConfig.Faction.GREEN).darkened(0.18), true)
	draw_rect(Rect2(board_pos, Vector2(board_size, board_size)), Color.BLACK, false, 4.0)
	draw_line(board_pos + Vector2(half, 0), board_pos + Vector2(half, board_size), Color(0, 0, 0, 0.8), 2.0)
	draw_line(board_pos + Vector2(0, half), board_pos + Vector2(board_size, half), Color(0, 0, 0, 0.8), 2.0)

	for i in range(0, 26):
		var p = i * (board_size / 25.0)
		draw_line(board_pos + Vector2(p, 0), board_pos + Vector2(p, board_size), Color(0, 0, 0, 0.08), 1.0)
		draw_line(board_pos + Vector2(0, p), board_pos + Vector2(board_size, p), Color(0, 0, 0, 0.08), 1.0)

	_draw_chamber(Vector2(-330, -145), true)
	_draw_chamber(Vector2(170, -145), false)
	_draw_chamber(Vector2(-330, 42), true)
	_draw_chamber(Vector2(170, 42), false)

	_draw_turret(board_pos + Vector2(16, 16), GameConfig.faction_color(GameConfig.Faction.RED), PI * 0.25 + 0.3 * sin(t * 1.1))
	_draw_turret(board_pos + Vector2(board_size - 16, 16), GameConfig.faction_color(GameConfig.Faction.BLUE), PI * 0.75 + 0.3 * sin(t * 1.2 + 1.2))
	_draw_turret(board_pos + Vector2(16, board_size - 16), GameConfig.faction_color(GameConfig.Faction.YELLOW), -PI * 0.25 + 0.3 * sin(t * 1.0 + 2.0))
	_draw_turret(board_pos + Vector2(board_size - 16, board_size - 16), GameConfig.faction_color(GameConfig.Faction.GREEN), PI * 1.25 + 0.3 * sin(t * 1.05 + 3.1))

	var marbles = [
		[Vector2(-70, -28), GameConfig.faction_color(GameConfig.Faction.BLUE), 0.0],
		[Vector2(46, -12), GameConfig.faction_color(GameConfig.Faction.RED), 1.2],
		[Vector2(34, 72), GameConfig.faction_color(GameConfig.Faction.YELLOW), 2.1],
		[Vector2(-48, 92), GameConfig.faction_color(GameConfig.Faction.GREEN), 3.3]
	]
	for entry in marbles:
		var offset = Vector2(12.0 * sin(t * 1.6 + entry[2]), 8.0 * cos(t * 1.2 + entry[2]))
		_draw_marble(entry[0] + offset, entry[1], 10.0)

func _draw_chamber(pos: Vector2, left_mode: bool) -> void:
	var size = Vector2(140, 150)
	draw_rect(Rect2(pos, size), Color(0.04, 0.04, 0.05, 0.97), true)
	draw_rect(Rect2(pos, size), Color(0.28, 0.30, 0.33), false, 3.0)

	for row in range(4):
		for col in range(3):
			var x = pos.x + 28 + col * 34 + (14 if row % 2 == 1 else 0)
			var y = pos.y + 26 + row * 25
			draw_circle(Vector2(x, y), 7.0, Color(0.26, 0.28, 0.32))

	var font = ThemeDB.fallback_font
	draw_string(font, pos + Vector2(52, 97), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 82, Color(1, 1, 1, 0.32))

	if left_mode:
		draw_rect(Rect2(pos + Vector2(0, 120), Vector2(size.x * 0.35, 22)), Color(0.71, 0.98, 0.16), true)
		draw_rect(Rect2(pos + Vector2(size.x * 0.35, 120), Vector2(size.x * 0.65, 22)), Color(1.0, 0.57, 0.02), true)
		draw_string(font, pos + Vector2(18, 138), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		draw_string(font, pos + Vector2(83, 138), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
	else:
		draw_rect(Rect2(pos + Vector2(0, 120), Vector2(size.x * 0.65, 22)), Color(1.0, 0.57, 0.02), true)
		draw_rect(Rect2(pos + Vector2(size.x * 0.65, 120), Vector2(size.x * 0.35, 22)), Color(0.71, 0.98, 0.16), true)
		draw_string(font, pos + Vector2(55, 138), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		draw_string(font, pos + Vector2(100, 138), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)

func _draw_turret(p: Vector2, color: Color, angle: float) -> void:
	draw_circle(p, 13.0, color)
	draw_circle(p, 13.0, Color.BLACK, false, 2.0)
	var dir = Vector2.RIGHT.rotated(angle)
	var ortho = Vector2(-dir.y, dir.x)
	var barrel_rect = PackedVector2Array([
		p + ortho * 3.0,
		p + dir * 21.0 + ortho * 3.0,
		p + dir * 21.0 - ortho * 3.0,
		p - ortho * 3.0
	])
	draw_colored_polygon(barrel_rect, color.lightened(0.15))

func _draw_marble(center: Vector2, color: Color, radius: float) -> void:
	draw_circle(center + Vector2(2, 2), radius + 1.5, Color(0, 0, 0, 0.30))
	draw_circle(center, radius, color)
	draw_circle(center + Vector2(1.4, 1.4), radius * 0.58, color.darkened(0.22))
	draw_circle(center + Vector2(-2.1, -2.1), radius * 0.34, Color(1, 1, 1, 0.72))
