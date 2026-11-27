extends Node2D
class_name BoardChassis

# Full-screen mechanical chassis behind the board. Presentation only.
#
# Cost model: the whole chassis is a static set of draw commands issued once per
# resize. Node2D keeps them cached, so the per-frame cost is the same as any
# static sprite. Nothing here scales with bullet count, and nothing here is
# rebuilt per frame - the earlier plan to draw the chassis from scratch every
# frame would have cost more than the entire board.
#
# It is deliberately NOT a picture of the concept art: the layout comes from the
# real geometry (battlefield rect, chamber rects) so it frames whatever the
# board actually is at this grid size.

const BASE_TOP := Color(0.055, 0.070, 0.095)
const BASE_BOTTOM := Color(0.028, 0.036, 0.052)
const PANEL := Color(0.085, 0.102, 0.132)
const PANEL_HI := Color(0.135, 0.158, 0.196)
const EDGE := Color(0.30, 0.36, 0.45)
const EDGE_DIM := Color(0.16, 0.20, 0.26)
const ACCENT := Color(0.36, 0.62, 0.86)

var _size: Vector2 = Vector2.ZERO
var _board: Rect2 = Rect2()
var _chambers: Array = []
var _low: bool = false


func setup(size: Vector2, board_rect: Rect2, chamber_rects: Array, low_effect: bool = false) -> void:
	if size == _size and board_rect == _board and chamber_rects == _chambers and low_effect == _low:
		return
	_size = size
	_board = board_rect
	_chambers = chamber_rects.duplicate()
	_low = low_effect
	queue_redraw()


func _draw() -> void:
	if _size.x <= 1.0 or _size.y <= 1.0:
		return
	_draw_base()
	if not _low:
		_draw_side_rails()
		_draw_board_recess()
		_draw_hud_docks()
	else:
		_draw_board_recess_flat()


func _draw_base() -> void:
	# Vertical ramp made of a handful of bands: cheap, static, and enough to stop
	# the background reading as flat black.
	var bands: int = 14
	var h: float = _size.y / float(bands)
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		draw_rect(Rect2(0.0, h * float(i), _size.x, h + 1.0), BASE_TOP.lerp(BASE_BOTTOM, t))
	# Faint horizontal scan lines every 48 px: texture without a texture file.
	if _low:
		return
	var y: float = 0.0
	while y < _size.y:
		draw_line(Vector2(0.0, y), Vector2(_size.x, y), Color(1.0, 1.0, 1.0, 0.014), 1.0)
		y += 48.0


func _draw_side_rails() -> void:
	# Two vertical armour strips in the margins. They give the controls something
	# to sit on instead of leaving the buttons floating on black.
	var rail_w: float = clampf(_board.position.x - 18.0, 0.0, 320.0)
	if rail_w < 40.0:
		return
	for side in 2:
		var x: float = 0.0 if side == 0 else _size.x - rail_w
		draw_rect(Rect2(x, 0.0, rail_w, _size.y), Color(PANEL, 0.55))
		# Inner lit edge facing the board.
		var edge_x: float = x + rail_w - 2.0 if side == 0 else x
		draw_line(Vector2(edge_x, 96.0), Vector2(edge_x, _size.y - 56.0), Color(EDGE, 0.55), 2.0)
		# Heat vents: short parallel slits, evenly spaced down the strip.
		var vents: int = 5
		var top: float = 120.0
		var span: float = _size.y - 200.0
		for i in vents:
			var vy: float = top + span * (float(i) + 0.5) / float(vents)
			var vw: float = minf(rail_w * 0.42, 54.0)
			var vx: float = x + (rail_w - vw) * 0.5
			draw_rect(Rect2(vx, vy, vw, 7.0), Color(0.03, 0.04, 0.055, 0.85))
			draw_line(Vector2(vx, vy - 1.0), Vector2(vx + vw, vy - 1.0), Color(EDGE_DIM, 0.7), 1.0)


func _draw_board_recess() -> void:
	# Machinery ring around the battlefield: recessed plate, lit inner lip,
	# corner brackets. The board itself stays the brightest large area.
	var outer: Rect2 = _board.grow(14.0)
	draw_rect(outer, Color(0.045, 0.058, 0.078))
	draw_rect(outer, Color(EDGE_DIM, 0.9), false, 2.0)
	draw_rect(_board.grow(4.0), Color(BASE_BOTTOM), false, 2.0)
	draw_rect(_board.grow(2.0), Color(EDGE, 0.55), false, 1.0)

	# Corner brackets on the recess.
	var len: float = minf(46.0, outer.size.x * 0.10)
	var fat: float = 3.0
	var corners: Array = [
		[outer.position, Vector2(1, 1)],
		[Vector2(outer.end.x, outer.position.y), Vector2(-1, 1)],
		[Vector2(outer.position.x, outer.end.y), Vector2(1, -1)],
		[outer.end, Vector2(-1, -1)],
	]
	for c in corners:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		draw_line(p, p + Vector2(len * d.x, 0.0), Color(ACCENT, 0.75), fat)
		draw_line(p, p + Vector2(0.0, len * d.y), Color(ACCENT, 0.75), fat)

	# Bolts at the recess corners.
	for c in corners:
		var p: Vector2 = c[0] + Vector2(-c[1].x, -c[1].y) * 9.0
		draw_circle(p, 2.6, EDGE)
		draw_circle(p + Vector2(0.6, 0.8), 1.2, Color(0.0, 0.0, 0.0, 0.6))


func _draw_board_recess_flat() -> void:
	draw_rect(_board.grow(14.0), Color(0.045, 0.058, 0.078))
	draw_rect(_board.grow(4.0), Color(BASE_BOTTOM), false, 2.0)


func _draw_hud_docks() -> void:
	# Thin dock strips under the top bar and above the bottom bar so the HUD
	# reads as mounted hardware rather than text on the background.
	draw_rect(Rect2(0.0, 0.0, _size.x, 96.0), Color(PANEL, 0.45))
	draw_line(Vector2(0.0, 96.0), Vector2(_size.x, 96.0), Color(EDGE_DIM, 0.9), 2.0)
	var by: float = _size.y - 56.0
	draw_rect(Rect2(0.0, by, _size.x, 56.0), Color(PANEL, 0.45))
	draw_line(Vector2(0.0, by), Vector2(_size.x, by), Color(EDGE_DIM, 0.9), 2.0)
