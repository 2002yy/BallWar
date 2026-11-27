extends RefCounted

# Turret presentation. Same contract as ChamberRenderer: draw(canvas_item, snapshot).
#
# Draws in the turret's local space, where +X is the barrel direction (the node's
# rotation already points the barrel). Nothing here reads or writes simulation
# state - every value comes in through the snapshot.

const ArtStyle = preload("res://scripts/render/ArtStyle.gd")


static func draw(c: CanvasItem, s: Dictionary) -> void:
	var radius: float = float(s.get("radius", 18.0))
	if bool(s.get("destroyed", false)):
		_draw_wreck(c, s, radius)
		return

	if ArtStyle.slot_style(ArtStyle.SLOT_TURRET) == ArtStyle.MECHANIC:
		_draw_mechanic(c, s, radius)
	else:
		_draw_pinball(c, s, radius)

	_draw_health_bar(c, s, radius)


# ---------------------------------------------------------------- mechanic ---

static func _draw_mechanic(c: CanvasItem, s: Dictionary, r: float) -> void:
	var color: Color = s.get("color", Color.WHITE)
	var low: bool = ArtStyle.low_effect()

	c.draw_circle(Vector2(2.8, 3.4), r * 1.05, Color(0.0, 0.0, 0.0, 0.34))
	_draw_hit_flash(c, s, r)

	# Hexagonal armoured base. A hexagon reads as "built" where a circle reads as
	# "token"; the flat edge facing the barrel gives the cannon something to sit on.
	var outer: PackedVector2Array = _hexagon(r * 1.08, r * 0.16)
	c.draw_colored_polygon(outer, ArtStyle.metal_dark())
	c.draw_polyline(_closed(outer), Color(0.0, 0.0, 0.0, 0.9), 1.6, true)

	var inner: PackedVector2Array = _hexagon(r * 0.86, r * 0.16)
	c.draw_colored_polygon(inner, ArtStyle.metal_mid().lerp(color, 0.22))
	c.draw_polyline(_closed(inner), Color(ArtStyle.metal_light(), 0.55), 1.2, true)

	# Plate seams: short radial cuts from the inner hexagon edge inward.
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + PI / 6.0
		var p0: Vector2 = Vector2.RIGHT.rotated(a) * (r * 0.86)
		var p1: Vector2 = Vector2.RIGHT.rotated(a) * (r * 0.60)
		c.draw_line(p0, p1, Color(0.0, 0.0, 0.0, 0.55), 1.4, true)

	# Corner bolts on the hexagon vertices.
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		var p: Vector2 = Vector2.RIGHT.rotated(a) * (r * 0.98)
		c.draw_circle(p, 1.9, ArtStyle.metal_light())
		c.draw_circle(p + Vector2(0.5, 0.6), 1.0, Color(0.0, 0.0, 0.0, 0.65))

	# Faction energy clamps: two arcs, not a full ring, so it reads as hardware.
	if not low:
		c.draw_arc(Vector2.ZERO, r * 1.02, -0.55, 0.55, 12, Color(color, 0.85), 2.2, true)
		c.draw_arc(Vector2.ZERO, r * 1.02, PI - 0.55, PI + 0.55, 12, Color(color, 0.55), 2.0, true)

	# Core housing and lens.
	var charge: float = clampf(float(s.get("burst_ratio", 0.0)), 0.0, 1.0)
	var core: Color = color
	if bool(s.get("locked", false)):
		core = color.lerp(Color.WHITE, 0.30)
	c.draw_circle(Vector2.ZERO, r * 0.50, Color(0.02, 0.03, 0.045, 0.98))
	c.draw_arc(Vector2.ZERO, r * 0.50, 0.0, TAU, 24, Color(ArtStyle.metal_light(), 0.45), 1.4, true)
	ArtStyle.energy_ring(c, Vector2.ZERO, r * 0.44, core, 0.6 + 0.4 * charge)
	c.draw_circle(Vector2.ZERO, r * 0.26, core.darkened(0.25))
	c.draw_circle(Vector2.ZERO, r * 0.14, Color(core.lightened(0.65), 0.95))
	if not low:
		c.draw_circle(Vector2(-r * 0.06, -r * 0.07), r * 0.06, Color(1.0, 1.0, 1.0, 0.95))

	_draw_barrel(c, color, r, low, charge)
	_draw_muzzle_flash(c, color, r, low, float(s.get("muzzle_flash", 0.0)))


static func _draw_barrel(c: CanvasItem, color: Color, r: float, low: bool, charge: float) -> void:
	# Short, thick cannon with a muzzle block. The previous version was long and
	# thin, which read as a pin rather than a weapon at 18px radius.
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.34, -r * 0.36),
		Vector2(r * 1.30, -r * 0.30),
		Vector2(r * 1.30, r * 0.30),
		Vector2(r * 0.34, r * 0.36),
	])
	ArtStyle.outlined_polygon(c, body, ArtStyle.metal_mid().lerp(color, 0.10).lightened(0.06), Color(0.0, 0.0, 0.0, 0.9), 1.4)
	c.draw_line(Vector2(r * 0.40, -r * 0.26), Vector2(r * 1.26, -r * 0.21), Color(ArtStyle.metal_light(), 0.80), 1.2, true)

	# Muzzle block, wider than the barrel so the tip has weight.
	var block: PackedVector2Array = PackedVector2Array([
		Vector2(r * 1.28, -r * 0.40),
		Vector2(r * 1.62, -r * 0.40),
		Vector2(r * 1.62, r * 0.40),
		Vector2(r * 1.28, r * 0.40),
	])
	ArtStyle.outlined_polygon(c, block, ArtStyle.metal_mid().lerp(color, 0.20), Color(0.0, 0.0, 0.0, 0.9), 1.3)

	# Bore: a dark slot with the energy channel glowing inside it.
	c.draw_rect(Rect2(r * 1.52, -r * 0.16, r * 0.12, r * 0.32), Color(0.01, 0.01, 0.02, 0.98))
	var glow: float = 0.45 + 0.55 * charge
	c.draw_rect(Rect2(r * 1.545, -r * 0.09, r * 0.09, r * 0.18), Color(color.lightened(0.45), glow))
	if low:
		return

	# Barrel vents on both flanks.
	for i in 3:
		var x: float = r * (0.55 + 0.22 * float(i))
		c.draw_line(Vector2(x, -r * 0.30), Vector2(x + r * 0.06, -r * 0.30), Color(0.0, 0.0, 0.0, 0.75), 1.6)
		c.draw_line(Vector2(x, r * 0.30), Vector2(x + r * 0.06, r * 0.30), Color(0.0, 0.0, 0.0, 0.75), 1.6)

	# Recoil collar where the barrel meets the base.
	c.draw_arc(Vector2(r * 0.42, 0.0), r * 0.34, 1.75, 4.53, 10, Color(ArtStyle.metal_light(), 0.7), 2.0, true)


static func _draw_muzzle_flash(c: CanvasItem, color: Color, r: float, low: bool, flash: float) -> void:
	var f: float = clampf(flash, 0.0, 1.0)
	if f <= 0.01:
		return
	var muzzle: Vector2 = Vector2(r * 1.62, 0.0)
	c.draw_circle(muzzle, r * (0.18 + 0.30 * f), Color(color.lightened(0.55), 0.85 * f))
	if low:
		return
	# Three tapered sparks instead of a symmetric star: asymmetric reads as force.
	c.draw_line(muzzle, muzzle + Vector2(r * (0.55 + 0.5 * f), 0.0), Color(1.0, 0.98, 0.86, 0.9 * f), 3.0, true)
	c.draw_line(muzzle, muzzle + Vector2(r * (0.34 + 0.3 * f), -r * 0.22), Color(1.0, 0.92, 0.70, 0.7 * f), 2.0, true)
	c.draw_line(muzzle, muzzle + Vector2(r * (0.34 + 0.3 * f), r * 0.22), Color(1.0, 0.92, 0.70, 0.7 * f), 2.0, true)


static func _hexagon(radius: float, rotation_offset: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 6:
		var a: float = TAU * float(i) / 6.0 + rotation_offset
		pts.append(Vector2.RIGHT.rotated(a) * radius)
	return pts


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out


# ----------------------------------------------------------------- pinball ---

static func _draw_pinball(c: CanvasItem, s: Dictionary, r: float) -> void:
	var color: Color = s.get("color", Color.WHITE)
	var low: bool = ArtStyle.low_effect()

	c.draw_circle(Vector2(3.0, 3.6), r * 1.04, Color(0.0, 0.0, 0.0, 0.26))
	_draw_hit_flash(c, s, r)

	# Chrome rail: bright outer ring with a dark inner cut, like a bezel.
	c.draw_circle(Vector2.ZERO, r * 1.06, Color(0.80, 0.85, 0.92))
	c.draw_circle(Vector2.ZERO, r * 0.99, Color(0.13, 0.16, 0.22))

	# Glass dome.
	c.draw_circle(Vector2.ZERO, r * 0.94, color.lightened(0.10))
	if not low:
		c.draw_arc(Vector2.ZERO, r * 0.94, 1.05, 2.30, 16, Color(1.0, 1.0, 1.0, 0.55), 2.4, true)

	# Candy swirl.
	c.draw_arc(Vector2.ZERO, r * 0.55, 0.4, 3.6, 20, Color(color.darkened(0.30), 0.85), 3.2, true)
	c.draw_arc(Vector2.ZERO, r * 0.30, 3.7, 6.1, 16, Color(color.darkened(0.20), 0.70), 2.6, true)

	# Specular highlight, offset up-left like a real glass bead.
	if not low:
		c.draw_circle(Vector2(-r * 0.34, -r * 0.40), r * 0.22, Color(1.0, 1.0, 1.0, 0.92))
		c.draw_circle(Vector2(-r * 0.28, -r * 0.33), r * 0.10, Color(1.0, 1.0, 1.0, 1.0))

	_draw_pinball_barrel(c, color, r, low)


static func _draw_pinball_barrel(c: CanvasItem, color: Color, r: float, low: bool) -> void:
	var tube: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.35, -r * 0.18),
		Vector2(r * 1.60, -r * 0.13),
		Vector2(r * 1.60, r * 0.13),
		Vector2(r * 0.35, r * 0.18),
	])
	ArtStyle.outlined_polygon(c, tube, Color(0.86, 0.90, 0.96), Color(0.10, 0.13, 0.18), 1.2)
	if not low:
		c.draw_line(Vector2(r * 0.40, -r * 0.11), Vector2(r * 1.54, -r * 0.08), Color(1.0, 1.0, 1.0, 0.9), 1.2, true)
	c.draw_circle(Vector2(r * 1.60, 0.0), r * 0.17, color.lightened(0.25))
	c.draw_circle(Vector2(r * 1.60, 0.0), r * 0.17, Color(0.10, 0.13, 0.18), false, 1.2)


# ------------------------------------------------------------------- wreck ---

static func _draw_wreck(c: CanvasItem, s: Dictionary, r: float) -> void:
	var t: float = float(s.get("destroy_time", -1.0))
	var pulse: float = 0.0 if t < 0.0 else minf(1.0, t / 0.7)

	if t >= 0.0:
		# Impact bloom, then embers. Both fade with the same driver so the effect
		# never outlives the node's own destroy animation window.
		c.draw_circle(Vector2.ZERO, r + 24.0 * pulse, Color(1.0, 0.55, 0.18, 0.30 * (1.0 - pulse)))
		for i in range(8):
			var ang: float = TAU * float(i) / 8.0 + t * 1.2
			c.draw_line(
				Vector2.RIGHT.rotated(ang) * (r * 0.55),
				Vector2.RIGHT.rotated(ang) * (r * 0.55 + 16.0 * (1.0 - pulse) + 10.0),
				Color(1.0, 0.72, 0.20, 0.85 * (1.0 - pulse)), 2.6, true
			)

	c.draw_circle(Vector2.ZERO, r * 1.02, Color(0.10, 0.10, 0.12))
	c.draw_circle(Vector2.ZERO, r * 0.74, Color(0.05, 0.05, 0.06))
	# Torn plating: four broken arc fragments instead of a clean ring.
	for i in 4:
		var a0: float = TAU * float(i) / 4.0 + 0.30
		c.draw_arc(Vector2.ZERO, r * 0.88, a0, a0 + 0.85, 10, Color(0.28, 0.29, 0.32), 3.4, true)
	c.draw_line(Vector2(-r * 0.62, -r * 0.52), Vector2(r * 0.40, r * 0.30), Color(0.0, 0.0, 0.0, 0.8), 3.0, true)
	c.draw_line(Vector2(-r * 0.35, r * 0.58), Vector2(r * 0.58, -r * 0.30), Color(0.0, 0.0, 0.0, 0.8), 2.4, true)


# -------------------------------------------------------------- hit flash ---

# Reads damage_flash straight from the turret's existing state; no extra timer.
static func _draw_hit_flash(c: CanvasItem, s: Dictionary, r: float) -> void:
	var d: float = clampf(float(s.get("damage_flash", 0.0)), 0.0, 1.0)
	if d <= 0.01:
		return
	c.draw_arc(Vector2.ZERO, r * 1.14, 0.0, TAU, 28, Color(1.0, 0.96, 0.90, 0.60 * d), 3.0, true)
	if not ArtStyle.low_effect():
		c.draw_arc(Vector2.ZERO, r * 1.28, 0.0, TAU, 32, Color(1.0, 0.55, 0.35, 0.30 * d), 1.6, true)


# -------------------------------------------------------------- health bar ---

static func _draw_health_bar(c: CanvasItem, s: Dictionary, r: float) -> void:
	var ratio: float = clampf(float(s.get("health_ratio", 1.0)), 0.0, 1.0)
	var w: float = 46.0
	var h: float = 5.0
	var origin: Vector2 = Vector2(-w * 0.5, r + 11.0)

	c.draw_rect(Rect2(origin + Vector2(-1.0, -1.0), Vector2(w + 2.0, h + 2.0)), Color(0.0, 0.0, 0.0, 0.55), true)
	c.draw_rect(Rect2(origin, Vector2(w, h)), Color(0.06, 0.07, 0.09, 0.95), true)

	var fill: Color = Color(0.32, 0.86, 0.42)
	if ratio < 0.35:
		fill = Color(1.0, 0.26, 0.24)
	elif ratio < 0.65:
		fill = Color(1.0, 0.72, 0.16)
	if ratio > 0.0:
		c.draw_rect(Rect2(origin, Vector2(w * ratio, h)), fill, true)
		c.draw_line(origin + Vector2(0.0, 0.5), origin + Vector2(w * ratio, 0.5), Color(1.0, 1.0, 1.0, 0.35), 1.0, true)

	# Quarter ticks so damage is readable without counting pixels.
	for i in range(1, 4):
		var x: float = origin.x + w * float(i) / 4.0
		c.draw_line(Vector2(x, origin.y), Vector2(x, origin.y + h), Color(0.0, 0.0, 0.0, 0.65), 1.0)
