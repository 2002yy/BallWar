extends Control

# 战场预览台的外框：监控窗式切削框 + 四角锁扣 + 阵营色标 + 底部刻度条。
#
# 它画在 PreviewContainer 下面（同一父节点、先入树），所以中间那块留给
# 真实战场预览，只有外圈这层是画出来的。这样"右侧 70% 是真实动态战场"
# 不会被一张静态美术图顶替 —— 静态的只有框。
#
# header_height / footer_height / side_pad 由 StartMenu 从 LayoutCoordinator
# 的 start_menu_layout 写进来，保证"框画在哪"和"预览放在哪"只有一个来源，
# 不会两边各写一套数字然后慢慢漂移。
#
# 纯展示层：不读也不写任何玩法状态。

const MechThemeScript = preload("res://scripts/ui/MechTheme.gd")

@export var corner_cut: float = 18.0
@export var header_height: float = 36.0
@export var footer_height: float = 32.0
@export var side_pad: float = 16.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _chamfer_rect(r: Rect2, cut: float) -> PackedVector2Array:
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


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return

	var stage := Rect2(Vector2.ZERO, size)
	var cut: float = minf(corner_cut, minf(size.x, size.y) * 0.2)
	var plate: PackedVector2Array = _chamfer_rect(stage, cut)

	draw_colored_polygon(plate, Color("#070d13"))
	_draw_scanlines(cut)
	draw_polyline(_closed(plate), MechThemeScript.EDGE, 2.0, true)
	draw_polyline(_closed(_chamfer_rect(stage.grow(-6.0), cut * 0.8)), MechThemeScript.EDGE_LO, 1.0, true)

	var window := _window_rect()
	_draw_brackets(window)
	_draw_header(window)
	_draw_footer(window)


func _window_rect() -> Rect2:
	return Rect2(
		Vector2(side_pad, header_height),
		Vector2(size.x - side_pad * 2.0, size.y - header_height - footer_height)
	)


func _draw_scanlines(cut: float) -> void:
	# 空域扫掠线：只在预览窗的空余处能看见，读作 CRT 监控窗，不干扰战场。
	var window := _window_rect()
	var y: float = window.position.y + 4.0
	while y < window.position.y + window.size.y:
		draw_line(
			Vector2(window.position.x, y),
			Vector2(window.position.x + window.size.x, y),
			Color(MechThemeScript.CYAN, 0.030), 1.0
		)
		y += 6.0


func _draw_brackets(window: Rect2) -> void:
	# 四角锁扣：L 形双线，青色。这是"取景框"的语言，比整圈描边更省视噪。
	var arm: float = minf(30.0, minf(window.size.x, window.size.y) * 0.18)
	var thick: float = 2.0
	var corners: Array = [
		[window.position, Vector2(1, 1)],
		[Vector2(window.position.x + window.size.x, window.position.y), Vector2(-1, 1)],
		[Vector2(window.position.x, window.position.y + window.size.y), Vector2(1, -1)],
		[Vector2(window.position.x + window.size.x, window.position.y + window.size.y), Vector2(-1, -1)],
	]
	for entry in corners:
		var origin: Vector2 = entry[0]
		var dir: Vector2 = entry[1]
		var col := Color(MechThemeScript.CYAN, 0.55)
		draw_line(origin, origin + Vector2(arm * dir.x, 0.0), col, thick, true)
		draw_line(origin, origin + Vector2(0.0, arm * dir.y), col, thick, true)
		draw_line(
			origin + Vector2(0.0, 5.0 * dir.y),
			origin + Vector2(arm * 0.6 * dir.x, 5.0 * dir.y),
			Color(MechThemeScript.CYAN, 0.20), 1.0, true
		)


func _draw_header(window: Rect2) -> void:
	# 阵营色标：和 PreviewScene 里四个炮台的颜色一一对应，让观众先认出这是
	# 四阵营战场，而不是一块抽象方块。
	var colors: Array = [
		MechThemeScript.FACTION_RED,
		MechThemeScript.FACTION_YELLOW,
		MechThemeScript.FACTION_GREEN,
		MechThemeScript.FACTION_BLUE,
	]
	var x: float = window.position.x + 4.0
	var y: float = header_height * 0.5
	for c in colors:
		draw_rect(Rect2(Vector2(x, y - 4.0), Vector2(9.0, 9.0)), c, true)
		draw_rect(Rect2(Vector2(x, y - 4.0), Vector2(9.0, 9.0)), Color(0, 0, 0, 0.55), false, 1.0)
		x += 15.0

	# 右侧状态刻线：三短一长，读作"信号在线"，纯装饰。
	var right: float = window.position.x + window.size.x - 4.0
	draw_line(Vector2(right - 54.0, y), Vector2(right - 20.0, y), Color(MechThemeScript.CYAN, 0.45), 2.0, true)
	draw_line(Vector2(right - 14.0, y), Vector2(right, y), Color(MechThemeScript.GOLD, 0.55), 2.0, true)


func _draw_footer(window: Rect2) -> void:
	var y: float = window.position.y + window.size.y + 8.0
	draw_line(
		Vector2(window.position.x, y),
		Vector2(window.position.x + window.size.x, y),
		Color(MechThemeScript.EDGE, 0.9), 1.0, true
	)
	# 刻度：每 1/12 一格，中间几格加长。给底部留一条"仪表盘"的底噪。
	var ticks: int = 12
	for i in range(ticks + 1):
		var tx: float = window.position.x + window.size.x * float(i) / float(ticks)
		var long: bool = i % 3 == 0
		draw_line(
			Vector2(tx, y + 2.0),
			Vector2(tx, y + (9.0 if long else 5.0)),
			Color(MechThemeScript.EDGE_HI, 0.7 if long else 0.35), 1.0, true
		)
