extends Node2D
class_name PreviewChassis

# 主菜单预览的机身：把四控制仓、四炮台和中央棋盘拴成**一台**机器。
#
# 为什么需要它：只调整坐标的话，棋盘和各部件仍然是"摆在一起的五件东西"，
# 中间的空隙读作背景而不是机体。参考图里这台机器的统一感来自一圈连续的
# 机架 —— 控制仓装在机架内侧的托架上、炮台坐在机架四角、棋盘沉在机架正中
# 的沉孔里。所以这里画的是那圈机架本身。
#
# 布局（本节点原点 = 机身中心，向上为 -y）：
#   机身       x -336..336   y -270..270   672×540，切角 26
#   棋盘       x -170..170   y -170..170   340×340，沉在 ±182 的沉孔里
#   左上/左下仓 x -286..-202  右上/右下仓 x 202..286
#   上仓 y -210..-20        下仓 y 20..210   每块 84×190
#   炮台中心   (±146, ±146) 半径 26，骑在四象限角上
#   上/下仪表带 y ±215..±270，左/右散热带 x ±296..±326
#
# 这些导出的几何量必须和 PreviewScene.tscn 里的节点坐标一致，
# 改一处就要一起改 —— 它们描述的是同一台机器。
#
# 注意：本节点**不能**设负的 z_index。CanvasItem 的 z_index 是全局排序，
# 设成 -10 会被排在 MechStage 的底板之前，整块机架就被那层底板盖掉了。
# 靠"在 PreviewScene 里排第一个"就够了：同一父节点下先入树先绘制。
#
# 全部 draw_*，无 Shader、无贴图，不读写任何玩法状态。

const BODY := Color("#101c28")
const BODY_HI := Color("#1b2d3e")
const BODY_LO := Color("#080e14")
const EDGE := Color("#2a3e51")
const EDGE_HI := Color("#4a6a89")
const GOLD := Color("#e8b63c")
const CYAN := Color("#4fd6e8")
const FACTION_COLORS := [
	Color(0.85, 0.18, 0.18),
	Color(0.95, 0.85, 0.16),
	Color(0.20, 0.88, 0.26),
	Color(0.22, 0.54, 0.96),
]

@export var machine_size: Vector2 = Vector2(672.0, 540.0)
@export var corner_cut: float = 26.0
# 棋盘沉孔外沿（棋盘 340 的半宽 170 + 沉孔 12）
@export var board_recess_half: float = 182.0
# 控制仓内缘 / 外缘的 x
@export var chamber_inner_x: float = 202.0
@export var chamber_outer_x: float = 286.0
# 控制仓上下两段的 y 范围（上段顶端 / 下段底端）
@export var chamber_top_y: float = -210.0
@export var chamber_bottom_y: float = 210.0
@export var chamber_height: float = 190.0


func _draw() -> void:
	if machine_size.x < 40.0 or machine_size.y < 40.0:
		return

	var body := Rect2(-machine_size * 0.5, machine_size)
	var cut: float = minf(corner_cut, minf(body.size.x, body.size.y) * 0.25)
	var plate: PackedVector2Array = _chamfer(body, cut)

	# 底板比监控窗底色亮一档，机架的"实体"才立得住。
	draw_colored_polygon(plate, BODY)
	draw_colored_polygon(
		_chamfer(Rect2(body.position, Vector2(body.size.x, 34.0)), minf(cut, 34.0)),
		BODY_HI
	)
	draw_polyline(_closed(plate), EDGE_HI, 2.5, true)
	draw_polyline(_closed(_chamfer(body.grow(-9.0), cut * 0.84)), EDGE, 1.5, true)
	draw_polyline(_closed(_chamfer(body.grow(-17.0), cut * 0.70)), BODY_LO, 1.0, true)

	_draw_vents(1.0)
	_draw_vents(-1.0)
	_draw_board_lip()
	_draw_chamber_mounts()
	_draw_instrument_bands()
	_draw_bolts(body, cut)


func _chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	var c: float = clampf(cut, 0.0, minf(r.size.x, r.size.y) * 0.5)
	return PackedVector2Array([
		Vector2(r.position.x + c, r.position.y),
		Vector2(r.position.x + r.size.x - c, r.position.y),
		Vector2(r.position.x + r.size.x, r.position.y + c),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y - c),
		Vector2(r.position.x + r.size.x - c, r.position.y + r.size.y),
		Vector2(r.position.x + c, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y - c),
		Vector2(r.position.x, r.position.y + c),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _draw_vents(side: float) -> void:
	# 机身左右外框的散热槽：七道短横线，填满控制仓到机框之间那 50px。
	var x0: float = side * (chamber_outer_x + 12.0)
	var x1: float = side * (machine_size.x * 0.5 - 14.0)
	var y: float = -102.0
	for i in range(7):
		draw_line(Vector2(x0, y), Vector2(x1, y), Color("#1b2b3a"), 4.0, true)
		draw_line(Vector2(x0, y - 1.4), Vector2(x1, y - 1.4), Color(EDGE_HI, 0.45), 1.0, true)
		y += 34.0


func _draw_board_lip() -> void:
	# 棋盘沉孔的凸沿：比棋盘自己的沉孔大一圈，露出一道 9px 的机架边。
	var lip_half: float = board_recess_half + 9.0
	var lip := Rect2(Vector2(-lip_half, -lip_half), Vector2(lip_half, lip_half) * 2.0)
	draw_rect(lip, BODY_HI, true)
	draw_rect(lip, EDGE_HI, false, 2.0)
	draw_rect(lip.grow(-4.0), Color("#060b10"), true)
	draw_rect(lip.grow(-4.0), Color("#1b2b3a"), false, 1.5)
	# 凸沿内侧四角的小加强筋：炮台就坐在这四个角上。
	var inner: float = board_recess_half + 4.5
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * inner, sy * inner)
			draw_line(corner, corner + Vector2(-sx * 26.0, 0.0), Color(EDGE_HI, 0.75), 2.5, true)
			draw_line(corner, corner + Vector2(0.0, -sy * 26.0), Color(EDGE_HI, 0.75), 2.5, true)
			draw_circle(corner, 3.0, Color("#3d566d"))


func _draw_chamber_mounts() -> void:
	# 四个控制仓各配一块托板 + 一条出料槽。托板比胶囊大一圈，读作"焊在机架上"；
	# 出料槽从托板内缘斜插进棋盘沉孔，说明球从控制仓进战场的路径。
	for side in [-1.0, 1.0]:
		for anchor in [chamber_top_y, chamber_bottom_y]:
			var y0: float = anchor if anchor < 0.0 else anchor - chamber_height
			var y1: float = y0 + chamber_height
			var mid: float = (y0 + y1) * 0.5
			var inner: float = side * chamber_inner_x
			var outer: float = side * chamber_outer_x
			var bracket := Rect2(
				Vector2(minf(inner, outer) - 6.0, y0 - 6.0),
				Vector2(absf(outer - inner) + 12.0, (y1 - y0) + 12.0)
			)
			draw_rect(bracket, Color("#1c2c3a"), true)
			draw_rect(bracket, EDGE, false, 1.5)
			draw_rect(bracket.grow(-3.0), Color("#0c141c"), true)
			# 托板上下各两颗铆钉，让控制仓看起来是被"装"上去的。
			for bx in [bracket.position.x + 9.0, bracket.position.x + bracket.size.x - 9.0]:
				draw_circle(Vector2(bx, bracket.position.y + 9.0), 2.2, EDGE_HI)
				draw_circle(Vector2(bx, bracket.position.y + bracket.size.y - 9.0), 2.2, EDGE_HI)
			_draw_chute(side, mid)


func _draw_chute(side: float, cy: float) -> void:
	var x_out: float = side * chamber_inner_x
	var x_in: float = side * (board_recess_half - 3.0)
	var quad := PackedVector2Array([
		Vector2(x_out, cy - 18.0),
		Vector2(x_in, cy - 10.0),
		Vector2(x_in, cy + 10.0),
		Vector2(x_out, cy + 18.0),
	])
	draw_colored_polygon(quad, Color("#1d2c3b"))
	draw_polyline(_closed(quad), EDGE_HI, 1.6, true)

	# 箭头朝棋盘：侧边为 -1（左）时朝 +x，反之朝 -x。
	var dir_x: float = -side
	var tip := Vector2(x_in + dir_x * 9.0, cy)
	draw_polyline(PackedVector2Array([
		Vector2(tip.x - dir_x * 7.0, cy - 6.0),
		tip,
		Vector2(tip.x - dir_x * 7.0, cy + 6.0),
	]), Color(GOLD, 0.9), 2.4, true)


func _draw_instrument_bands() -> void:
	# 上下两条仪表带：机身高度从 452 提到 540 之后，棋盘上下各多出 100px，
	# 不填东西就会变成两块黑。这里做成机台的仪表面板，参考图里也是这么处理的。
	var top_y: float = -machine_size.y * 0.5
	var bot_y: float = machine_size.y * 0.5

	_draw_deck(Rect2(Vector2(-246.0, top_y + 12.0), Vector2(492.0, 40.0)), true)
	_draw_deck(Rect2(Vector2(-246.0, bot_y - 52.0), Vector2(492.0, 40.0)), false)

	# 上沿/下沿金色能量条：机身"通着电"的唯一暖色，位置对称，压住整块构图。
	draw_line(Vector2(-176.0, top_y + 7.0), Vector2(176.0, top_y + 7.0), Color(GOLD, 0.9), 2.5, true)
	draw_line(Vector2(-120.0, bot_y - 7.0), Vector2(120.0, bot_y - 7.0), Color(GOLD, 0.9), 3.0, true)
	draw_line(Vector2(-46.0, bot_y - 12.0), Vector2(46.0, bot_y - 12.0), Color(GOLD, 0.45), 2.0, true)


func _draw_deck(deck: Rect2, is_top: bool) -> void:
	draw_rect(deck, Color("#0a121a"), true)
	draw_rect(deck, EDGE, false, 1.5)
	draw_line(deck.position, deck.position + Vector2(deck.size.x, 0.0), Color(EDGE_HI, 0.5), 1.0)

	var cy: float = deck.position.y + deck.size.y * 0.5
	if is_top:
		# 上仪表带：三段小刻度 + 中央铭牌 + 两颗青灯。
		for i in range(9):
			var x: float = deck.position.x + 18.0 + float(i) * 12.0
			var h: float = 8.0 if i % 3 == 0 else 4.0
			draw_line(Vector2(x, cy - h), Vector2(x, cy + h), Color(EDGE_HI, 0.65), 1.5, true)
		var nameplate := Rect2(Vector2(-62.0, deck.position.y + 7.0), Vector2(124.0, 26.0))
		draw_rect(nameplate, Color("#152230"), true)
		draw_rect(nameplate, Color(GOLD, 0.5), false, 1.0)
		for i in range(4):
			var x: float = -36.0 + float(i) * 24.0
			draw_rect(Rect2(Vector2(x - 5.0, cy - 2.0), Vector2(10.0, 4.0)), Color(GOLD, 0.6 if i < 2 else 0.22), true)
		for i in range(2):
			var p := Vector2(deck.position.x + deck.size.x - 34.0 - float(i) * 22.0, cy)
			draw_circle(p, 6.0, Color(CYAN, 0.10))
			draw_circle(p, 3.0, CYAN if i == 0 else Color("#2f4658"))
	else:
		# 下仪表带：四阵营状态灯 + 一排档位刻线。
		for i in range(4):
			var p := Vector2(-150.0 + float(i) * 100.0, cy)
			draw_circle(p, 9.0, Color(FACTION_COLORS[i], 0.14))
			draw_circle(p, 5.0, FACTION_COLORS[i])
			draw_circle(p + Vector2(-1.4, -1.6), 1.8, Color(1, 1, 1, 0.65))
		for i in range(10):
			var x: float = 96.0 + float(i) * 14.0
			draw_line(Vector2(x, cy - 5.0), Vector2(x, cy + 5.0), Color(EDGE_HI, 0.45), 1.5, true)


func _draw_bolts(body: Rect2, cut: float) -> void:
	var pad: float = cut * 0.46
	var pts: Array = [
		Vector2(body.position.x + pad, body.position.y + pad),
		Vector2(body.position.x + body.size.x - pad, body.position.y + pad),
		Vector2(body.position.x + pad, body.position.y + body.size.y - pad),
		Vector2(body.position.x + body.size.x - pad, body.position.y + body.size.y - pad),
	]
	for p in pts:
		draw_circle(p, 7.0, Color("#1a2833"))
		draw_circle(p, 4.0, Color("#3d566d"))
		draw_circle(p + Vector2(-1.2, -1.2), 1.6, Color("#7b9cb8"))
