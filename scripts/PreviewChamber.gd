extends Node2D
class_name PreviewChamber

# 主菜单预览用的控制仓：玻璃胶囊 + 金属上下盖 + 阵营弹珠。
#
# 旧版是一个黑方框 + 22 个圆点（钉子）+ 两个写着 "x2 / 发射" 的色块，
# 在 84px 宽的位置上既读不出"控制仓"，文字也糊成一团。
# 现在按参考图改成竖立玻璃管：上盖进料、管身是带圆头的透明胶囊、看得见弹珠、
# 下盖出料。纯 draw_*，无 Shader、无贴图。
#
# 节点原点 = 胶囊左上角，和旧版一致（chamber_size 就是整块占地）。
# 不读写任何玩法状态。

const GLASS := Color(0.45, 0.72, 0.95, 0.17)
const GLASS_RIM := Color(0.62, 0.86, 1.0, 0.62)
const GLASS_HI := Color(1.0, 1.0, 1.0, 0.20)
const CAP := Color("#2a3d50")
const CAP_HI := Color("#527596")
const CAP_LO := Color("#0d151d")

# 弹珠位置沿管身铺开，靠颜色差异区分阵营；不随机，保证每次截图一致。
const BALL_SPOTS := [
	Vector2(0.32, 0.16),
	Vector2(0.68, 0.32),
	Vector2(0.30, 0.56),
	Vector2(0.66, 0.74),
]

@export var left_mode: bool = true
@export var chamber_size: Vector2 = Vector2(84.0, 190.0)
# 阵营 ID 由 PreviewScene 从 LayoutCoordinator.corner_factions() 注入；
# 颜色在绘制时实时取 GameConfig.faction_color()，不缓存、不硬编码。
@export var faction_id: int = 0
@export var ball_count: int = 4


func _draw() -> void:
	if chamber_size.x <= 6.0 or chamber_size.y <= 20.0:
		return

	var cap_h: float = 16.0
	var w: float = chamber_size.x
	var h: float = chamber_size.y
	var glass := Rect2(Vector2(2.0, cap_h), Vector2(w - 4.0, h - cap_h * 2.0))

	_draw_cap(Rect2(Vector2(0.0, 0.0), Vector2(w, cap_h)), true)
	_draw_glass(glass)
	_draw_balls(glass)
	_draw_cap(Rect2(Vector2(0.0, h - cap_h), Vector2(w, cap_h)), false)


func _capsule_points(glass: Rect2) -> PackedVector2Array:
	# 圆头胶囊：上半圆 + 两条直边 + 下半圆。用十段折线近似，足够在 84px 上读圆。
	var r: float = glass.size.x * 0.5
	var top_c := Vector2(glass.position.x + r, glass.position.y + r)
	var bot_c := Vector2(glass.position.x + r, glass.position.y + glass.size.y - r)
	var pts := PackedVector2Array()
	for i in range(11):
		var a: float = PI + PI * float(i) / 10.0
		pts.append(top_c + Vector2(cos(a), sin(a)) * r)
	for i in range(11):
		var a: float = 0.0 + PI * float(i) / 10.0
		pts.append(bot_c + Vector2(cos(a), sin(a)) * r)
	return pts


func _draw_cap(cap: Rect2, is_top: bool) -> void:
	draw_rect(cap, CAP, true)
	# 上盖顶面亮一档，下盖底面亮一档：两面都受光，读作"金属厚盖"
	var face: Rect2
	if is_top:
		face = Rect2(cap.position, Vector2(cap.size.x, 4.0))
	else:
		face = Rect2(cap.position + Vector2(0.0, cap.size.y - 4.0), Vector2(cap.size.x, 4.0))
	draw_rect(face, CAP_HI, true)
	draw_rect(cap, CAP_LO, false, 1.0)
	for x in [9.0, chamber_size.x - 9.0]:
		draw_circle(Vector2(x, cap.position.y + cap.size.y * 0.5), 2.4, CAP_LO)
		draw_circle(Vector2(x - 0.6, cap.position.y + cap.size.y * 0.5 - 0.6), 1.2, CAP_HI)


func _draw_glass(glass: Rect2) -> void:
	var capsule: PackedVector2Array = _capsule_points(glass)
	draw_colored_polygon(capsule, GLASS)
	draw_polyline(_closed(capsule), GLASS_RIM, 1.6, true)

	# 竖向高光：两道细白线偏左，玻璃管才有圆柱感。
	var r: float = glass.size.x * 0.5
	var y0: float = glass.position.y + r + 4.0
	var y1: float = glass.position.y + glass.size.y - r - 4.0
	draw_line(Vector2(glass.position.x + 8.0, y0), Vector2(glass.position.x + 8.0, y1), GLASS_HI, 3.0)
	draw_line(Vector2(glass.position.x + 13.0, y0 + 6.0), Vector2(glass.position.x + 13.0, y1 - 6.0), Color(1, 1, 1, 0.08), 1.5)
	# 底部积料的暗影，让弹珠有"落在一个容器里"的重量。
	draw_rect(
		Rect2(glass.position + Vector2(4.0, glass.size.y - r - 14.0), Vector2(glass.size.x - 8.0, 12.0)),
		Color(0, 0, 0, 0.16), true
	)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _draw_balls(glass: Rect2) -> void:
	var faction_color: Color = GameConfig.faction_color(faction_id)
	var count: int = clampi(ball_count, 0, BALL_SPOTS.size())
	var r: float = minf(glass.size.x * 0.105, glass.size.y * 0.052)
	var r_glass: float = glass.size.x * 0.5
	for i in range(count):
		var spot: Vector2 = BALL_SPOTS[i]
		# 只把弹珠放进胶囊的直筒段，避免球飘在圆弧外。
		var y: float = glass.position.y + r_glass + (glass.size.y - r_glass * 2.0) * spot.y
		var p: Vector2 = glass.position + Vector2(glass.size.x * spot.x, y - glass.position.y)
		draw_circle(p + Vector2(0.0, 1.4), r, Color(0, 0, 0, 0.48))
		draw_circle(p, r, faction_color)
		draw_circle(p + Vector2(-r * 0.30, -r * 0.34), r * 0.55, faction_color.lightened(0.34))
		draw_circle(p + Vector2(-r * 0.38, -r * 0.42), r * 0.24, Color(1, 1, 1, 0.78))
