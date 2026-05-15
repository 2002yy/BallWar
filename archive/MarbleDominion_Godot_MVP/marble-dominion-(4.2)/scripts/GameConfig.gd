extends RefCounted
class_name GameConfig

const GRID_SIZE := 40
const CELL_SIZE := 12
const BATTLEFIELD_ORIGIN := Vector2(360, 160)
const BULLET_SPEED := 260.0
const BULLET_RADIUS := 4.0
const TURRET_RADIUS := 16.0
const MAX_PENDING_COUNT := 64

enum Faction { BLUE, RED, GREEN, YELLOW }

static func faction_color(id: int) -> Color:
	match id:
		Faction.BLUE: return Color(0.18, 0.42, 1.0)
		Faction.RED: return Color(1.0, 0.18, 0.18)
		Faction.GREEN: return Color(0.16, 0.78, 0.28)
		Faction.YELLOW: return Color(1.0, 0.78, 0.12)
		_: return Color.WHITE

static func faction_name(id: int) -> String:
	match id:
		Faction.BLUE: return "Blue"
		Faction.RED: return "Red"
		Faction.GREEN: return "Green"
		Faction.YELLOW: return "Yellow"
		_: return "Unknown"
