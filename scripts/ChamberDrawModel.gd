extends RefCounted
class_name ChamberDrawModel

static func build_snapshot(input: Dictionary) -> Dictionary:
	var chamber_size: Vector2 = input.get("chamber_size", Vector2.ZERO)
	var gate_height: float = float(input.get("gate_height", 0.0))
	var gate_multiplier: int = int(input.get("gate_multiplier", 2))
	var faction_color: Color = input.get("faction_color", Color.WHITE)
	var is_damaged: bool = bool(input.get("is_damaged", false))
	var is_locked: bool = bool(input.get("is_locked", false))
	var jammed_time_left: float = maxf(0.0, float(input.get("jammed_time_left", 0.0)))
	var blink: float = 0.5 + 0.5 * sin(float(input.get("status_anim_t", 0.0)) * 6.0)
	var top_h: float = 30.0
	var jammed: bool = jammed_time_left > 0.0

	var shell_color: Color = Color(0.11, 0.13, 0.17, 0.98)
	var border_color: Color = faction_color.lightened(0.12)
	var inner_color: Color = Color(0.17, 0.19, 0.24, 0.98)
	if is_damaged:
		shell_color = Color(0.14, 0.11, 0.11, 1.0)
		border_color = Color(0.86, 0.18, 0.18)
		inner_color = Color(0.10, 0.08, 0.08, 1.0)
	elif jammed:
		shell_color = Color(0.15, 0.11, 0.10, 1.0)
		border_color = Color(1.0, 0.46, 0.16)
		inner_color = Color(0.12, 0.09, 0.09, 1.0)

	var light_a: Color = Color(0.18, 0.22, 0.26)
	var light_b: Color = Color(0.18, 0.22, 0.26)
	if is_damaged:
		light_a = Color(1.0, 0.14, 0.14, 0.55 + 0.35 * blink)
		light_b = Color(0.20, 0.07, 0.07)
	elif jammed:
		light_a = Color(1.0, 0.42, 0.18, 0.58 + 0.26 * blink)
		light_b = Color(1.0, 0.78, 0.18, 0.48 + 0.22 * blink)
	elif is_locked:
		light_a = Color(1.0, 0.82, 0.20, 0.55 + 0.35 * blink)
		light_b = Color(1.0, 0.58, 0.14, 0.48 + 0.28 * blink)
	else:
		light_a = Color(faction_color.r, faction_color.g, faction_color.b, 0.56 + 0.20 * blink)
		light_b = Color(0.26, 1.0, 0.74, 0.28 + 0.12 * blink)

	var progress: float = clampf(float(input.get("game_elapsed_time", 0.0)) / maxf(0.001, float(input.get("gate_ramp_seconds", 1.0))), 0.0, 1.0)
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var release_ratio: float = lerpf(
		float(input.get("gate_start_release_ratio", 0.72)),
		float(input.get("gate_end_release_ratio", 0.30)),
		eased
	)
	var gate_min_ratio: float = float(input.get("gate_min_ratio", 0.28))
	var x2_width: float = chamber_size.x * 0.5
	if not (is_locked or is_damaged or jammed):
		release_ratio = clampf(release_ratio, gate_min_ratio, 1.0 - gate_min_ratio)
		x2_width = chamber_size.x * (1.0 - release_ratio)

	var outer_rect: Rect2 = Rect2(Vector2.ZERO, chamber_size)
	var shell_rect: Rect2 = Rect2(Vector2(5.0, 5.0), chamber_size - Vector2(10.0, 10.0))
	var title_rect: Rect2 = Rect2(Vector2(10.0, 10.0), Vector2(chamber_size.x - 20.0, 22.0))
	var inner_rect: Rect2 = Rect2(
		Vector2(10.0, top_h + 6.0),
		Vector2(chamber_size.x - 20.0, chamber_size.y - top_h - gate_height - 18.0)
	)
	var gate_frame: Rect2 = Rect2(Vector2(8.0, chamber_size.y - gate_height - 8.0), Vector2(chamber_size.x - 16.0, gate_height + 4.0))
	var left_rect: Rect2 = Rect2(
		Vector2(10.0, chamber_size.y - gate_height - 6.0),
		Vector2(maxf(0.0, x2_width - 12.0), gate_height - 4.0)
	)
	var right_rect: Rect2 = Rect2(
		Vector2(x2_width + 2.0, chamber_size.y - gate_height - 6.0),
		Vector2(maxf(0.0, chamber_size.x - x2_width - 12.0), gate_height - 4.0)
	)

	var left_color: Color = Color(0.74, 0.92, 0.22)
	var right_color: Color = Color(1.0, 0.64, 0.16)
	if jammed:
		left_color = Color(0.42, 0.42, 0.42)
		right_color = Color(0.42, 0.42, 0.42)
	elif is_locked:
		left_color = Color(0.42, 0.42, 0.42)
		right_color = Color(0.84, 0.54, 0.14, 0.70 + blink * 0.18)
	elif is_damaged:
		left_color = Color(0.32, 0.18, 0.18)
		right_color = Color(0.32, 0.18, 0.18)

	var left_gate_text: String = "短路" if jammed else ("X" if is_damaged else ("x3" if gate_multiplier == 3 else "x2"))
	var right_gate_text: String = "短路" if jammed else ("X" if is_damaged else "发射")
	var gate_font_size: int = maxi(16, int(round(17.0 / maxf(0.5, float(input.get("scale_x", 1.0))))))

	return {
		"chamber_size": chamber_size,
		"gate_height": gate_height,
		"peg_radius": float(input.get("peg_radius", 0.0)),
		"pegs": input.get("pegs", []),
		"is_damaged": is_damaged,
		"jammed": jammed,
		"blink": blink,
		"outer_rect": outer_rect,
		"shell_rect": shell_rect,
		"title_rect": title_rect,
		"inner_rect": inner_rect,
		"gate_frame": gate_frame,
		"left_rect": left_rect,
		"right_rect": right_rect,
		"shell_color": shell_color,
		"border_color": border_color,
		"inner_color": inner_color,
		"light_a": light_a,
		"light_b": light_b,
		"left_color": left_color,
		"right_color": right_color,
		"left_gate_text": left_gate_text,
		"right_gate_text": right_gate_text,
		"gate_font_size": gate_font_size,
		"x2_width": x2_width,
	}
