extends RefCounted

# Bullet presentation. Same contract as the other renderers: draw(canvas_item, snapshot).
#
# Bullets are the highest-count object in the game (pool caps at 6000), so the
# budget here is deliberately tight: at most five primitives per bullet, and the
# `simple` path stays a single filled circle. Anything that reads as "material"
# has to come from the arrangement of those few shapes, not from more layers.

const ArtStyle = preload("res://scripts/render/ArtStyle.gd")


static func draw(c: CanvasItem, s: Dictionary) -> void:
	var color: Color = s.get("color", Color.WHITE)
	var radius: float = float(s.get("radius", 5.0))

	if bool(s.get("simple", false)):
		c.draw_circle(Vector2.ZERO, radius, color)
		return

	var reduce: bool = bool(s.get("reduce", false)) or ArtStyle.low_effect()
	if ArtStyle.is_mechanic():
		_mechanic(c, color, radius, reduce)
	else:
		_pinball(c, color, radius, reduce)


static func _mechanic(c: CanvasItem, color: Color, r: float, reduce: bool) -> void:
	# Dark casing, then the energy payload inside it.
	if not reduce:
		c.draw_circle(Vector2(1.4, 1.6), r + 1.1, Color(0.0, 0.0, 0.0, 0.26))
	c.draw_circle(Vector2.ZERO, r + 0.9, Color(0.07, 0.08, 0.11, 0.95))
	c.draw_circle(Vector2.ZERO, r, color)
	if reduce:
		return
	# Rim light on the lower-right edge reads as a lit sphere, not a flat dot.
	# (A dark crescent disc was tried first and spilled outside the body at this
	# radius, which looked like a blob rather than shading.)
	c.draw_arc(Vector2.ZERO, r * 0.62, 2.35, 5.05, 10, Color(color.lightened(0.55), 0.75), 1.1, true)
	# Specular.
	c.draw_circle(Vector2(-r * 0.34, -r * 0.36), r * 0.30, Color(1.0, 1.0, 1.0, 0.88))


static func _pinball(c: CanvasItem, color: Color, r: float, reduce: bool) -> void:
	c.draw_circle(Vector2.ZERO, r + 1.0, Color(0.10, 0.12, 0.16, 0.9))
	c.draw_circle(Vector2.ZERO, r, color.lightened(0.12))
	if reduce:
		return
	c.draw_arc(Vector2.ZERO, r * 0.80, 0.55, 3.30, 12, Color(1.0, 1.0, 1.0, 0.55), 1.2, true)
	c.draw_circle(Vector2(-r * 0.30, -r * 0.34), r * 0.34, Color(1.0, 1.0, 1.0, 0.95))
	c.draw_circle(Vector2(r * 0.26, r * 0.30), r * 0.20, Color(color.darkened(0.35), 0.65))
