extends Control

# 主菜单外壳：深蓝钢底板 + 直角切削 + 螺栓 + 能源灯。
#
# 为什么不是 StyleBoxFlat：StyleBoxFlat 的 corner_radius 只能做圆角，
# 做不出机械外壳的 45° 直角切削。这台机器的视觉语言靠切削和螺栓立住，
# 所以轮廓必须自己画。仍然没有 Shader —— 全部是 draw_colored_polygon /
# draw_polyline / draw_circle 这些原生绘制。
#
# 纯展示层：不读也不写任何玩法状态。

const MechThemeScript = preload("res://scripts/ui/MechTheme.gd")

@export var corner_cut: float = 30.0
@export var inset: float = 3.0
@export var show_lamps: bool = true
@export var show_hazard: bool = true
@export var show_vents: bool = true


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
	if size.x < 8.0 or size.y < 8.0:
		return

	var outer := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	var cut: float = minf(corner_cut, minf(outer.size.x, outer.size.y) * 0.28)
	var plate: PackedVector2Array = _chamfer_rect(outer, cut)

	# 底板：两层平涂假装出"上表面 / 侧面厚度"，不用渐变。
	draw_colored_polygon(plate, MechThemeScript.PLATE)
	draw_colored_polygon(
		_chamfer_rect(Rect2(outer.position, Vector2(outer.size.x, 46.0)), minf(cut, 46.0)),
		MechThemeScript.PLATE_HI
	)

	# 外轮廓 + 内发丝线，形成双线钢边。
	draw_polyline(_closed(plate), MechThemeScript.EDGE, 2.0, true)
	draw_polyline(_closed(_chamfer_rect(outer.grow(-7.0), cut * 0.86)), MechThemeScript.EDGE_LO, 1.0, true)

	# 顶部金色能量条：只有一条，压在钢边内侧，作为"通电"提示。
	var bar_y: float = outer.position.y + 46.0
	draw_line(
		Vector2(outer.position.x + cut + 14.0, bar_y),
		Vector2(outer.position.x + outer.size.x - cut - 14.0, bar_y),
		Color(MechThemeScript.GOLD, 0.85), 2.0, true
	)
	draw_line(
		Vector2(outer.position.x + cut + 14.0, bar_y + 3.0),
		Vector2(outer.position.x + outer.size.x - cut - 14.0, bar_y + 3.0),
		Color(MechThemeScript.GOLD_LO, 0.35), 1.0, true
	)

	_draw_bolts(outer, cut)
	if show_lamps:
		_draw_lamps(outer)
	if show_vents:
		_draw_vents(outer, cut)
	if show_hazard:
		_draw_hazard(outer)


func _draw_bolts(outer: Rect2, cut: float) -> void:
	var pad: float = cut * 0.5
	var pts: Array = [
		Vector2(outer.position.x + pad, outer.position.y + pad),
		Vector2(outer.position.x + outer.size.x - pad, outer.position.y + pad),
		Vector2(outer.position.x + pad, outer.position.y + outer.size.y - pad),
		Vector2(outer.position.x + outer.size.x - pad, outer.position.y + outer.size.y - pad),
	]
	for p in pts:
		draw_circle(p, 6.0, Color("#22323f"))
		draw_circle(p, 3.2, Color("#3d566d"))
		draw_circle(p + Vector2(-1.0, -1.0), 1.4, Color("#5d7d97"))


func _draw_lamps(outer: Rect2) -> void:
	# 三颗能源灯：外壳右上角。第三颗用青色高亮，读作"在线"。
	var base := Vector2(outer.position.x + outer.size.x - 34.0, outer.position.y + 22.0)
	for i in range(3):
		var p: Vector2 = base + Vector2(-i * 16.0, 0.0)
		var lit: bool = i == 0
		var core: Color = MechThemeScript.CYAN if lit else Color("#2f4658")
		draw_circle(p, 5.0, Color(MechThemeScript.CYAN, 0.10 if lit else 0.0))
		draw_circle(p, 3.0, core)
		draw_circle(p + Vector2(-0.8, -0.8), 1.2, Color(1, 1, 1, 0.55 if lit else 0.15))


func _draw_vents(outer: Rect2, cut: float) -> void:
	# 左上角的散热格栅：六道短竖线，纯装饰，给"机器"一个可读的细节密度。
	var x0: float = outer.position.x + cut + 10.0
	var y0: float = outer.position.y + 17.0
	for i in range(6):
		var x: float = x0 + i * 9.0
		draw_line(Vector2(x, y0), Vector2(x, y0 + 13.0), Color("#1e2f3d"), 3.0, true)


func _draw_hazard(outer: Rect2) -> void:
	# 左下角警示斜纹：四条平行四边形，压到 30% 不透明度，只做质感不抢视线。
	var base := Vector2(outer.position.x + 26.0, outer.position.y + outer.size.y - 14.0)
	for i in range(4):
		var x: float = base.x + i * 18.0
		var quad := PackedVector2Array([
			Vector2(x, base.y),
			Vector2(x + 7.0, base.y),
			Vector2(x + 14.0, base.y - 9.0),
			Vector2(x + 7.0, base.y - 9.0),
		])
		draw_colored_polygon(quad, Color(MechThemeScript.GOLD, 0.30))
