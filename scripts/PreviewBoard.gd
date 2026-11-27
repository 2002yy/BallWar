extends Node2D
class_name PreviewBoard

# 主菜单预览用的静态棋盘：四象限底色 + 40×40 网格 + 内嵌沉孔 + 玻璃反光。
#
# 它不读任何模拟数据 —— 主菜单没有对局，这里画的是一张"已开机待命"的战场面板，
# 不是伪造的战况。真正的动态战况由对局里的 Battlefield 渲染，两者互不影响。
#
# 全部走 draw_*，没有 Shader、没有贴图。

const FACTION_RED := Color(0.85, 0.18, 0.18)
const FACTION_YELLOW := Color(0.95, 0.85, 0.16)
const FACTION_GREEN := Color(0.20, 0.88, 0.26)
const FACTION_BLUE := Color(0.22, 0.54, 0.96)

@export var board_size: float = 340.0
@export var grid_cells: int = 40
# 棋盘外一圈沉孔宽度：让它看起来是嵌进机身，而不是贴在机身上。
@export var recess: float = 12.0


func _draw() -> void:
	if board_size <= 8.0:
		return

	var half: float = board_size * 0.5
	var board := Rect2(Vector2(-half, -half), Vector2(board_size, board_size))

	_draw_well(board)
	_draw_quadrants(board)
	_draw_grid(board)
	_draw_frontier(board)
	_draw_sheen(board)
	draw_rect(board, Color("#0a1015"), false, 3.0)


func _draw_well(board: Rect2) -> void:
	# 沉孔：外深内更深的双层，加上缘暗线做单向光的内阴影。
	var well := Rect2(
		board.position - Vector2(recess, recess),
		board.size + Vector2(recess, recess) * 2.0
	)
	draw_rect(well, Color("#070c12"), true)
	draw_rect(board.grow(4.0), Color("#0d151d"), true)
	draw_line(well.position, well.position + Vector2(well.size.x, 0.0), Color(0, 0, 0, 0.85), 5.0)
	draw_line(well.position, well.position + Vector2(0.0, well.size.y), Color(0, 0, 0, 0.62), 4.0)
	draw_line(
		Vector2(well.position.x, well.position.y + well.size.y),
		Vector2(well.position.x + well.size.x, well.position.y + well.size.y),
		Color(0.35, 0.52, 0.68, 0.28), 1.5
	)


func _draw_quadrants(board: Rect2) -> void:
	var half: float = board.size.x * 0.5
	draw_rect(Rect2(board.position, Vector2(half, half)), FACTION_RED, true)
	draw_rect(Rect2(board.position + Vector2(half, 0.0), Vector2(half, half)), FACTION_YELLOW, true)
	draw_rect(Rect2(board.position + Vector2(0.0, half), Vector2(half, half)), FACTION_GREEN, true)
	draw_rect(Rect2(board.position + Vector2(half, half), Vector2(half, half)), FACTION_BLUE, true)


func _draw_grid(board: Rect2) -> void:
	# 40×40 网格。线太密会糊成一片，所以压到 10% 黑，只在近处读得出格感。
	var cells: int = maxi(grid_cells, 1)
	var step: float = board.size.x / float(cells)
	for i in range(1, cells):
		var p: float = float(i) * step
		draw_line(
			board.position + Vector2(p, 0.0),
			board.position + Vector2(p, board.size.y),
			Color(0, 0, 0, 0.10), 1.0
		)
		draw_line(
			board.position + Vector2(0.0, p),
			board.position + Vector2(board.size.x, p),
			Color(0, 0, 0, 0.10), 1.0
		)


func _draw_frontier(board: Rect2) -> void:
	# 势力边界：中线加粗，并在每象限外缘压一道亮边，把四个色块读成"四块领地"。
	var half: float = board.size.x * 0.5
	var mid_v: float = board.position.x + half
	var mid_h: float = board.position.y + half
	draw_line(Vector2(mid_v, board.position.y), Vector2(mid_v, board.position.y + board.size.y), Color(0, 0, 0, 0.82), 2.0)
	draw_line(Vector2(board.position.x, mid_h), Vector2(board.position.x + board.size.x, mid_h), Color(0, 0, 0, 0.82), 2.0)

	var edges: Array = [
		[Rect2(board.position, Vector2(half, half)), FACTION_RED],
		[Rect2(board.position + Vector2(half, 0.0), Vector2(half, half)), FACTION_YELLOW],
		[Rect2(board.position + Vector2(0.0, half), Vector2(half, half)), FACTION_GREEN],
		[Rect2(board.position + Vector2(half, half), Vector2(half, half)), FACTION_BLUE],
	]
	for entry in edges:
		var r: Rect2 = entry[0]
		var c: Color = entry[1]
		draw_rect(r.grow(-1.0), Color(c.lightened(0.45), 0.55), false, 1.5)


func _draw_sheen(board: Rect2) -> void:
	# 玻璃反光：一条对角斜带，不用横向色带 —— 横带会在四个象限中间留下一道
	# 生硬的接缝，读起来像"数据没画完"，而不是反光。
	var w: float = board.size.x
	var h: float = board.size.y
	var band := PackedVector2Array([
		board.position + Vector2(0.0, h * 0.10),
		board.position + Vector2(w * 0.10, 0.0),
		board.position + Vector2(w, h * 0.90),
		board.position + Vector2(w * 0.90, h),
	])
	draw_colored_polygon(band, Color(1.0, 1.0, 1.0, 0.045))
	# 四角压暗：把视线往中心收。
	var half: float = board.size.x * 0.5
	for i in range(2):
		var corner_size: float = half * (0.5 - float(i) * 0.22)
		draw_rect(Rect2(board.position, Vector2(corner_size, corner_size)), Color(0, 0, 0, 0.05), true)
		draw_rect(Rect2(board.position + Vector2(w - corner_size, 0.0), Vector2(corner_size, corner_size)), Color(0, 0, 0, 0.05), true)
		draw_rect(Rect2(board.position + Vector2(0.0, h - corner_size), Vector2(corner_size, corner_size)), Color(0, 0, 0, 0.05), true)
		draw_rect(Rect2(board.position + Vector2(w - corner_size, h - corner_size), Vector2(corner_size, corner_size)), Color(0, 0, 0, 0.05), true)
