extends Node2D
class_name Battlefield

signal scores_changed(counts)

var grid_size: int = GameConfig.GRID_SIZE
var cell_size: int = GameConfig.CELL_SIZE
var owners: Array = []

func configure(new_grid_size: int) -> void:
	grid_size = new_grid_size
	match grid_size:
		20:
			cell_size = 22
		30:
			cell_size = 16
		40:
			cell_size = 13
		50:
			cell_size = 11
		_:
			cell_size = GameConfig.CELL_SIZE

func _ready() -> void:
	reset_quadrants()
	queue_redraw()
	scores_changed.emit(count_cells_by_team())

func reset_quadrants() -> void:
	owners.clear()
	var half_grid: int = grid_size >> 1
	for x in range(grid_size):
		var col: Array = []
		for y in range(grid_size):
			var f: int = GameConfig.Faction.BLUE
			if x >= half_grid and y < half_grid:
				f = GameConfig.Faction.RED
			elif x < half_grid and y >= half_grid:
				f = GameConfig.Faction.GREEN
			elif x >= half_grid and y >= half_grid:
				f = GameConfig.Faction.YELLOW
			col.append(f)
		owners.append(col)

func world_to_cell(world_position: Vector2) -> Vector2i:
	var lp: Vector2 = to_local(world_position)
	return Vector2i(floori(lp.x / float(cell_size)), floori(lp.y / float(cell_size)))

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size

func apply_bullet(cell: Vector2i, faction_id: int) -> String:
	if not is_inside(cell):
		return "OUTSIDE"
	var old: int = owners[cell.x][cell.y]
	if old == faction_id:
		return "SAME_CELL"
	owners[cell.x][cell.y] = faction_id
	queue_redraw()
	scores_changed.emit(count_cells_by_team())
	return "HIT_ENEMY_CELL"

func count_cells_by_team() -> Dictionary:
	var counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}
	for x in range(grid_size):
		for y in range(grid_size):
			counts[owners[x][y]] += 1
	return counts

func _draw() -> void:
	var size: float = grid_size * cell_size
	var half_size: float = size * 0.5

	for x in range(grid_size):
		for y in range(grid_size):
			var c: Color = GameConfig.faction_color(owners[x][y]).darkened(0.08)
			c.a = 0.94
			draw_rect(Rect2(x * cell_size, y * cell_size, cell_size, cell_size), c, true)

	_draw_emblems(size)

	draw_line(Vector2(half_size, 0), Vector2(half_size, size), Color.BLACK, 2)
	draw_line(Vector2(0, half_size), Vector2(size, half_size), Color.BLACK, 2)
	draw_rect(Rect2(0, 0, size, size), Color(0, 0, 0, 0.95), false, 4)

	for i in range(grid_size + 1):
		var p: float = i * cell_size
		draw_line(Vector2(p, 0), Vector2(p, size), Color(0, 0, 0, 0.10), 1)
		draw_line(Vector2(0, p), Vector2(size, p), Color(0, 0, 0, 0.10), 1)

func _draw_emblems(size: float) -> void:
	var q: float = size * 0.25
	var r: float = size * 0.145
	_draw_blue_emblem(Vector2(q, q), r)
	_draw_red_emblem(Vector2(size - q, q), r)
	_draw_green_emblem(Vector2(q, size - q), r)
	_draw_yellow_emblem(Vector2(size - q, size - q), r)

func _draw_blue_emblem(center: Vector2, radius: float) -> void:
	var c: Color = Color(1, 1, 1, 0.11)
	draw_circle(center, radius, c)
	draw_circle(center + Vector2(radius * 0.25, 0), radius * 0.82, Color(0, 0, 0, 0.06))
	draw_arc(center, radius * 1.15, 0.2, TAU - 0.2, 40, Color(1, 1, 1, 0.07), 4.0)

func _draw_red_emblem(center: Vector2, radius: float) -> void:
	var c: Color = Color(1, 1, 1, 0.11)
	draw_circle(center, radius * 0.78, c)
	draw_circle(center + Vector2(-radius * 0.25, -radius * 0.10), radius * 0.14, Color(0, 0, 0, 0.12))
	draw_circle(center + Vector2(radius * 0.25, -radius * 0.10), radius * 0.14, Color(0, 0, 0, 0.12))
	var jaw: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius * 0.42, radius * 0.12),
		center + Vector2(radius * 0.42, radius * 0.12),
		center + Vector2(radius * 0.28, radius * 0.52),
		center + Vector2(-radius * 0.28, radius * 0.52)
	])
	draw_colored_polygon(jaw, c)

func _draw_green_emblem(center: Vector2, radius: float) -> void:
	var c: Color = Color(1, 1, 1, 0.11)
	draw_circle(center, radius * 0.12, c)
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		draw_line(center, center + Vector2.RIGHT.rotated(ang) * radius * 0.72, c, 3.0)
	draw_arc(center, radius * 0.86, 0, TAU, 40, Color(1, 1, 1, 0.09), 4.0)

func _draw_yellow_emblem(center: Vector2, radius: float) -> void:
	var c: Color = Color(1, 1, 1, 0.11)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var rr: float = radius if i % 2 == 0 else radius * 0.45
		var ang: float = -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(center + Vector2.RIGHT.rotated(ang) * rr)
	draw_colored_polygon(pts, c)
