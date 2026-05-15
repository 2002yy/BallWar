extends Node2D
class_name Battlefield

signal scores_changed(counts: Dictionary)

var grid_size := GameConfig.GRID_SIZE
var cell_size := GameConfig.CELL_SIZE
var owners: Array = []

func _ready() -> void:
	reset_quadrants()
	queue_redraw()
	scores_changed.emit(count_cells_by_team())

func reset_quadrants() -> void:
	owners.clear()
	for x in range(grid_size):
		var col: Array = []
		for y in range(grid_size):
			var f := GameConfig.Faction.BLUE
			if x >= grid_size / 2 and y < grid_size / 2: f = GameConfig.Faction.RED
			elif x < grid_size / 2 and y >= grid_size / 2: f = GameConfig.Faction.GREEN
			elif x >= grid_size / 2 and y >= grid_size / 2: f = GameConfig.Faction.YELLOW
			col.append(f)
		owners.append(col)

func world_to_cell(world_position: Vector2) -> Vector2i:
	var lp := to_local(world_position)
	return Vector2i(floori(lp.x / cell_size), floori(lp.y / cell_size))

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size and cell.y < grid_size

func apply_bullet(cell: Vector2i, faction_id: int) -> String:
	if not is_inside(cell): return "OUTSIDE"
	var old: int = owners[cell.x][cell.y]
	if old == faction_id: return "SAME_CELL"
	owners[cell.x][cell.y] = faction_id
	queue_redraw()
	scores_changed.emit(count_cells_by_team())
	return "HIT_ENEMY_CELL"

func count_cells_by_team() -> Dictionary:
	var counts := {0:0, 1:0, 2:0, 3:0}
	for x in range(grid_size):
		for y in range(grid_size):
			counts[owners[x][y]] += 1
	return counts

func _draw() -> void:
	var size := grid_size * cell_size
	for x in range(grid_size):
		for y in range(grid_size):
			var c := GameConfig.faction_color(owners[x][y]); c.a = 0.88
			draw_rect(Rect2(x * cell_size, y * cell_size, cell_size, cell_size), c, true)
	draw_line(Vector2(size/2,0), Vector2(size/2,size), Color.BLACK, 2)
	draw_line(Vector2(0,size/2), Vector2(size,size/2), Color.BLACK, 2)
	draw_rect(Rect2(0,0,size,size), Color.BLACK, false, 3)
	for i in range(grid_size + 1):
		var p := i * cell_size
		draw_line(Vector2(p,0), Vector2(p,size), Color(0,0,0,0.12), 1)
		draw_line(Vector2(0,p), Vector2(size,p), Color(0,0,0,0.12), 1)
