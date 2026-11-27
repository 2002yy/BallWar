extends Control

# 战场预览台的外框：监控窗式切削框 + 四角锁扣 + 表头分隔 + 底部刻度。
#
# 它画在 PreviewContainer 下面（同一父节点、先入树），所以中间那块留给
# 真实战场预览，只有外圈这层是画出来的。这样"右侧 70% 是真实动态战场"
# 不会被一张静态美术图顶替 —— 静态的只有框。
#
# 表头的文字不在这里画：标题和副标是场景里的原生 Label，由 StartMenu 按
# 布局摆放。这里只负责分隔线、色标和刻度，避免"文字位置有两个来源"。
#
# header_height / footer_height / side_pad 由 StartMenu 从 LayoutCoordinator
# 的 start_menu_layout 写进来，保证"框画在哪"和"预览放在哪"只有一个来源。
#
# 纯展示层：不读也不写任何玩法状态。

const MechThemeScript = preload("res://scripts/ui/MechTheme.gd")

@export var corner_cut: float = 16.0
@export var header_height: float = 34.0
@export var footer_height: float = 12.0
@export var side_pad: float = 10.0


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


func _window_rect() -> Rect2:
	return Rect2(
		Vector2(side_pad, header_height),
		Vector2(size.x - side_pad * 2.0, size.y - header_height - footer_height)
	)


func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return

	var stage := Rect2(Vector2.ZERO, size)
	var cut: float = minf(corner_cut, minf(size.x, size.y) * 0.2)
	var plate: PackedVector2Array = _chamfer_rect(stage, cut)

	draw_colored_polygon(plate, Color("#070d13"))
	_draw_scanlines()
	draw_polyline(_closed(plate), MechThemeScript.EDGE, 2.0, true)
	draw_polyline(_closed(_chamfer_rect(stage.grow(-7.0), cut * 0.8)), MechThemeScript.EDGE_LO, 1.0, true)

	var window := _window_rect()
	_draw_header_rule(window)
	_draw_brackets(window)
	_draw_footer(window)


func _draw_scanlines() -> void:
	# 空域扫掠线：只在预览窗的空余处能看见，读作 CRT 监控窗，不干扰战场。
	var window := _window_rect()
	var y: float = window.position.y + 4.0
	while y < window.position.y + window.size.y:
		draw_line(
			Vector2(window.position.x, y),
			Vector2(window.position.x + window.size.x, y),
			Color(MechThemeScript.CYAN, 0.026), 1.0
		)
		y += 6.0


func _draw_header_rule(window: Rect2) -> void:
	# 表头下缘：整条暗线 + 左端一段金色。金色段就是标题的"下划线"，
	# 让标题区自己成立，不需要再画一个框。
	var y: float = header_height - 1.0
	draw_line(Vector2(window.position.x - 4.0, y), Vector2(window.position.x + window.size.x + 4.0, y),
		Color(MechThemeScript.EDGE, 0.95), 1.0, true)
	draw_line(Vector2(window.position.x - 4.0, y), Vector2(window.position.x + minf(148.0, window.size.x * 0.4), y),
		Color(MechThemeScript.GOLD, 0.9), 2.0, true)

	# 右上角三格"窗口刻度"，读作机器上的档位标记。
	var right: float = window.position.x + window.size.x + 2.0
	for i in range(3):
		var x: float = right - 4.0 - float(i) * 11.0
		draw_rect(Rect2(Vector2(x - 6.0, 12.0), Vector2(6.0, 6.0)),
			Color(MechThemeScript.EDGE_HI, 0.75 if i == 0 else 0.4), true)


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


func _draw_footer(window: Rect2) -> void:
	# 底部刻度条：每 1/12 一格，每三格加长。给下面那条通栏状态条一个过渡。
	if footer_height < 6.0:
		return
	var y: float = window.position.y + window.size.y + 3.0
	draw_line(
		Vector2(window.position.x, y),
		Vector2(window.position.x + window.size.x, y),
		Color(MechThemeScript.EDGE, 0.9), 1.0, true
	)
	var ticks: int = 12
	var steps: float = float(ticks)
	for i in range(ticks + 1):
		var tx: float = window.position.x + window.size.x * float(i) / steps
		var long: bool = i % 3 == 0
		draw_line(
			Vector2(tx, y + 1.0),
			Vector2(tx, y + (5.0 if long else 3.0)),
			Color(MechThemeScript.EDGE_HI, 0.7 if long else 0.32), 1.0, true
		)
