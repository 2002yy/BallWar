extends RefCounted
class_name ChamberRenderer

static func draw(canvas_item: CanvasItem, snapshot: Dictionary) -> void:
	var chamber_size: Vector2 = snapshot.get("chamber_size", Vector2.ZERO)
	var gate_height: float = float(snapshot.get("gate_height", 0.0))
	var peg_radius: float = float(snapshot.get("peg_radius", 0.0))
	var pegs: Array = snapshot.get("pegs", [])
	var is_damaged: bool = bool(snapshot.get("is_damaged", false))
	var jammed: bool = bool(snapshot.get("jammed", false))
	var blink: float = float(snapshot.get("blink", 0.0))

	var outer_rect: Rect2 = snapshot.get("outer_rect", Rect2())
	var shell_rect: Rect2 = snapshot.get("shell_rect", Rect2())
	var title_rect: Rect2 = snapshot.get("title_rect", Rect2())
	var inner_rect: Rect2 = snapshot.get("inner_rect", Rect2())
	var gate_frame: Rect2 = snapshot.get("gate_frame", Rect2())
	var left_rect: Rect2 = snapshot.get("left_rect", Rect2())
	var right_rect: Rect2 = snapshot.get("right_rect", Rect2())

	var shell_color: Color = snapshot.get("shell_color", Color.WHITE)
	var border_color: Color = snapshot.get("border_color", Color.WHITE)
	var inner_color: Color = snapshot.get("inner_color", Color.WHITE)
	var light_a: Color = snapshot.get("light_a", Color.WHITE)
	var light_b: Color = snapshot.get("light_b", Color.WHITE)
	var left_color: Color = snapshot.get("left_color", Color.WHITE)
	var right_color: Color = snapshot.get("right_color", Color.WHITE)
	var left_gate_text: String = str(snapshot.get("left_gate_text", ""))
	var right_gate_text: String = str(snapshot.get("right_gate_text", ""))
	var gate_font_size: int = int(snapshot.get("gate_font_size", 16))

	canvas_item.draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.22), true)
	canvas_item.draw_rect(outer_rect, shell_color, true)
	canvas_item.draw_rect(shell_rect, Color(0.04, 0.05, 0.07, 0.98), true)
	canvas_item.draw_rect(title_rect, Color(border_color.r, border_color.g, border_color.b, 0.14), true)
	canvas_item.draw_rect(inner_rect, inner_color, true)
	canvas_item.draw_rect(outer_rect, border_color, false, 3.0)
	canvas_item.draw_rect(Rect2(Vector2(4.0, 4.0), chamber_size - Vector2(8.0, 8.0)), Color(border_color.r, border_color.g, border_color.b, 0.16), false, 1.5)

	for rivet in [Vector2(11, 11), Vector2(chamber_size.x - 11, 11), Vector2(11, chamber_size.y - 11), Vector2(chamber_size.x - 11, chamber_size.y - 11)]:
		canvas_item.draw_circle(rivet, 3.0, Color(0.22, 0.24, 0.28))
		canvas_item.draw_circle(rivet + Vector2(-0.8, -0.8), 1.0, Color(1.0, 1.0, 1.0, 0.18))

	for idx in range(2):
		var pos_x: float = chamber_size.x - 28.0 + float(idx) * 10.0
		var c: Color = light_a if idx == 0 else light_b
		canvas_item.draw_circle(Vector2(pos_x, 21.0), 4.2, Color(c.r, c.g, c.b, 0.18))
		canvas_item.draw_circle(Vector2(pos_x, 21.0), 2.8, c)

	if not is_damaged:
		for i in range(5):
			var y: float = inner_rect.position.y + 14.0 + float(i) * 18.0
			canvas_item.draw_line(
				Vector2(inner_rect.position.x + 5.0, y),
				Vector2(inner_rect.end.x - 5.0, y),
				Color(1.0, 1.0, 1.0, 0.025),
				1.0
			)

	for peg in pegs:
		var pcolor: Color = Color(0.40, 0.42, 0.48)
		if is_damaged:
			pcolor = Color(0.18, 0.11, 0.11)
		var glow: Color = Color(border_color.r, border_color.g, border_color.b, 0.12 + blink * 0.05)
		if is_damaged:
			glow = Color(1.0, 0.18, 0.18, 0.12 + blink * 0.08)
		canvas_item.draw_circle(peg, peg_radius + 3.0, glow)
		canvas_item.draw_circle(peg, peg_radius, pcolor)
		canvas_item.draw_circle(peg + Vector2(-1.0, -1.0), peg_radius * 0.42, Color(1.0, 1.0, 1.0, 0.56))

	canvas_item.draw_rect(gate_frame, Color(0.08, 0.09, 0.11, 0.98), true)
	canvas_item.draw_rect(gate_frame, Color(0.0, 0.0, 0.0, 0.76), false, 2.0)
	canvas_item.draw_rect(left_rect, left_color, true)
	canvas_item.draw_rect(right_rect, right_color, true)
	canvas_item.draw_rect(Rect2(left_rect.position, Vector2(left_rect.size.x, maxf(4.0, left_rect.size.y * 0.38))), Color(1.0, 1.0, 1.0, 0.12), true)
	canvas_item.draw_rect(Rect2(right_rect.position, Vector2(right_rect.size.x, maxf(4.0, right_rect.size.y * 0.38))), Color(1.0, 1.0, 1.0, 0.12), true)
	canvas_item.draw_rect(left_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.2)
	canvas_item.draw_rect(right_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.2)

	var gate_font = ThemeDB.fallback_font
	if left_rect.size.x > 18.0:
		var left_baseline: float = round(left_rect.position.y + left_rect.size.y * 0.68)
		canvas_item.draw_string_outline(
			gate_font,
			Vector2(round(left_rect.position.x), left_baseline),
			left_gate_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			round(left_rect.size.x),
			gate_font_size,
			2,
			Color(0.0, 0.0, 0.0, 0.9)
		)
		canvas_item.draw_string(
			gate_font,
			Vector2(round(left_rect.position.x), left_baseline),
			left_gate_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			round(left_rect.size.x),
			gate_font_size,
			Color(0.06, 0.08, 0.10, 0.95)
		)
	if right_rect.size.x > 18.0:
		var right_baseline: float = round(right_rect.position.y + right_rect.size.y * 0.68)
		canvas_item.draw_string_outline(
			gate_font,
			Vector2(round(right_rect.position.x), right_baseline),
			right_gate_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			round(right_rect.size.x),
			gate_font_size,
			2,
			Color(0.0, 0.0, 0.0, 0.9)
		)
		canvas_item.draw_string(
			gate_font,
			Vector2(round(right_rect.position.x), right_baseline),
			right_gate_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			round(right_rect.size.x),
			gate_font_size,
			Color(0.06, 0.08, 0.10, 0.95)
		)

	if jammed:
		for i in range(8):
			var start_x: float = 12.0 + float(i) * 18.0
			canvas_item.draw_line(
				Vector2(start_x, chamber_size.y - gate_height - 10.0),
				Vector2(start_x + 18.0, chamber_size.y - 8.0),
				Color(1.0, 0.42, 0.16, 0.28),
				2.0
			)
