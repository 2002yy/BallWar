extends Node2D
class_name PreviewTurret

# 主菜单预览用的炮台：金属外壳 + 阵营色环 + 发光核心 + 锥形炮管。
#
# 旧版只是一个 14px 的圆点加一根方条，在 340px 的棋盘上读不出"炮台"。
# 现在按参考图做成三层同心结构：钢壳 / 阵营环 / 核心，再补炮口与螺栓。
#
# 全部 draw_*，无 Shader、无贴图。不读写任何玩法状态。

const SHELL := Color("#182430")
const SHELL_HI := Color("#3e5b76")
const SHELL_LO := Color("#0b131b")

@export var turret_color: Color = Color(1, 1, 1, 1)
@export var barrel_angle_deg: float = 45.0
@export var radius: float = 26.0
@export var show_bolts: bool = true


func _draw() -> void:
	if radius <= 2.0:
		return

	var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(barrel_angle_deg))
	var ortho: Vector2 = Vector2(-dir.y, dir.x)

	_draw_barrel(dir, ortho)
	# 投影：外壳下缘一道暗弧，把炮台从棋盘上"抬"起来
	draw_circle(Vector2(1.5, 3.0), radius, Color(0, 0, 0, 0.34))
	draw_circle(Vector2.ZERO, radius, SHELL)
	draw_arc(Vector2.ZERO, radius - 1.2, 0.0, TAU, 40, SHELL_HI, 2.2, true)
	draw_arc(Vector2.ZERO, radius - 4.0, PI * 0.15, PI * 0.85, 24, SHELL_LO, 2.0, true)

	# 阵营色环：压暗一档，让核心还能再亮一层
	draw_circle(Vector2.ZERO, radius * 0.72, turret_color.darkened(0.42))
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 36, turret_color.lightened(0.25), 1.4, true)

	# 核心：本体 + 左上高光 + 中心销
	draw_circle(Vector2.ZERO, radius * 0.46, turret_color)
	draw_circle(Vector2(-radius * 0.10, -radius * 0.12), radius * 0.30, turret_color.lightened(0.30))
	draw_circle(Vector2(-radius * 0.14, -radius * 0.18), radius * 0.12, Color(1, 1, 1, 0.55))
	draw_circle(Vector2.ZERO, radius * 0.10, Color(0.04, 0.06, 0.09, 0.85))

	if show_bolts:
		for i in range(3):
			var a: float = PI * 0.5 + TAU * float(i) / 3.0
			var p: Vector2 = Vector2(cos(a), sin(a)) * (radius * 0.86)
			draw_circle(p, 2.0, SHELL_LO)
			draw_circle(p, 1.1, SHELL_HI)


func _draw_barrel(dir: Vector2, ortho: Vector2) -> void:
	# 锥形炮管：根部宽、口部略窄，末端补一个炮口环。
	# 长度必须明显超过外壳半径，否则被 r=26 的钢壳吃掉，只剩一个小点。
	var root: float = radius * 0.30
	var tip: float = radius * 1.85
	var w0: float = radius * 0.34
	var w1: float = radius * 0.24
	var poly := PackedVector2Array([
		dir * root + ortho * w0,
		dir * tip + ortho * w1,
		dir * tip - ortho * w1,
		dir * root - ortho * w0,
	])
	draw_colored_polygon(poly, turret_color.darkened(0.28))
	draw_line(dir * root + ortho * w0, dir * tip + ortho * w1, turret_color.lightened(0.35), 1.2, true)
	draw_circle(dir * tip, w1 * 1.15, turret_color.darkened(0.55))
	draw_circle(dir * tip, w1 * 0.72, turret_color)
