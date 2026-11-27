extends RefCounted

# Visual style table. Presentation only: nothing here may feed back into
# damage, movement, collision, multipliers, win conditions or economy.
#
# Two candidate directions are shipped so they can be compared in-engine:
#   MECHANIC 机械能量风  armour plates, energy core, tapered barrel (primary)
#   PINBALL  精致弹珠机风 glass, chrome, toy-like highlights (contrast sample)
#
# Selection is a display setting. For batch 1 it is resolved from, in order:
#   1. BALLWAR_ART_STYLE environment variable (capture rig / QA)
#   2. the value passed to set_style() by the settings UI (wired later)
#   3. MECHANIC

const MECHANIC: String = "mechanic"
const PINBALL: String = "pinball"

static var _style: String = ""
static var _low_effect: bool = false


# Per-slot style. The hybrid ruling is "C as the overall base, B as the battle
# mechanical language", so style is resolved PER OBJECT, not globally:
#   turret  -> MECHANIC  armour, energy core, barrel structure
#   bullet  -> PINBALL   bright material, glass highlight, clear trajectory
#   chamber -> PINBALL   precision pinball structure (mechanical frame added later)
#   hud     -> console   military console, never a pinball panel
# BALLWAR_ART_STYLE forces every slot to one style; that is for A/B comparison
# capture runs only, not for shipping.
const SLOT_TURRET: String = "turret"
const SLOT_BULLET: String = "bullet"
const SLOT_CHAMBER: String = "chamber"

const _SLOT_DEFAULTS := {
	"turret": MECHANIC,
	"bullet": PINBALL,
	"chamber": PINBALL,
}

static var _forced: String = ""


static func _env_forced() -> String:
	var env: String = OS.get_environment("BALLWAR_ART_STYLE").strip_edges()
	if env == MECHANIC:
		return MECHANIC
	if env == PINBALL or env == "candy":
		return PINBALL
	return ""


static func slot_style(slot: String) -> String:
	var forced: String = _forced if _forced != "" else _env_forced()
	if forced != "":
		return forced
	return String(_SLOT_DEFAULTS.get(slot, PINBALL))


static func set_forced_style(id: String) -> void:
	_forced = PINBALL if id == PINBALL else (MECHANIC if id == MECHANIC else "")


static func show_battlefield_emblems() -> bool:
	# Large translucent faction emblems sit on top of territory and units and are
	# the single biggest hierarchy problem on the battle screen; off by default.
	return false


static func low_effect() -> bool:
	return _low_effect


static func set_low_effect(value: bool) -> void:
	_low_effect = value


# Shared metal/glass ramp. Kept in one place so both styles stay recognisably
# part of the same game instead of drifting into two different products.
static func metal_dark() -> Color:
	return Color(0.09, 0.11, 0.15)

static func metal_mid() -> Color:
	return Color(0.19, 0.22, 0.28)

static func metal_light() -> Color:
	return Color(0.42, 0.47, 0.55)

static func void_bg() -> Color:
	return Color(0.035, 0.045, 0.06)


# A cheap energy bloom: one low-alpha fill plus two thin stroke rings.
# Filled stacked circles are avoided on purpose - they cost fill rate and
# stack up fast with 4 turrets, 4 chambers and hundreds of bullets on screen.
static func energy_ring(c: CanvasItem, center: Vector2, radius: float, color: Color, strength: float) -> void:
	if strength <= 0.01:
		return
	if _low_effect:
		c.draw_arc(center, radius, 0.0, TAU, 24, Color(color, 0.55), 1.2, true)
		return
	c.draw_circle(center, radius * 0.55, Color(color, 0.10 * strength))
	c.draw_arc(center, radius * 0.72, 0.0, TAU, 28, Color(color, 0.30 * strength), 1.0, true)
	c.draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.45 * strength), 1.4, true)


static func outlined_polygon(c: CanvasItem, points: PackedVector2Array, fill: Color, edge: Color, edge_width: float) -> void:
	c.draw_colored_polygon(points, fill)
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	c.draw_polyline(closed, edge, edge_width, true)


# Armour plates as arcs with gaps: reads as machined metal without any texture.
static func segmented_ring(c: CanvasItem, center: Vector2, radius: float, width: float, segments: int, color: Color, gap_ratio: float) -> void:
	var step: float = TAU / float(maxi(1, segments))
	var gap: float = step * clampf(gap_ratio, 0.0, 0.8)
	for i in segments:
		var a0: float = step * float(i) + gap * 0.5
		c.draw_arc(center, radius, a0, a0 + step - gap, 8, color, width, true)
