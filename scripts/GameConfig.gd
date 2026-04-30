extends RefCounted
class_name GameConfig

const GRID_SIZE = 40
const CELL_SIZE = 12

const BULLET_SPEED = 122.0
const BULLET_RADIUS = 7.0
const BULLET_MAX_LIFETIME = 12.0

const TURRET_RADIUS = 18.0
const TURRET_MAX_HEALTH = 30
const TURRET_HIT_RADIUS = 24.0
const BULLET_DAMAGE = 1

const MAX_PENDING_COUNT = 64
const MAX_CONTROL_BALLS_PER_CHAMBER = 8

const BURST_FIRE_INTERVAL = 0.08

enum Faction { BLUE, RED, GREEN, YELLOW }

static func faction_color(id: int) -> Color:
    match id:
        Faction.BLUE:
            return Color(0.20, 0.49, 1.00)
        Faction.RED:
            return Color(1.00, 0.30, 0.22)
        Faction.GREEN:
            return Color(0.20, 0.82, 0.34)
        Faction.YELLOW:
            return Color(1.00, 0.82, 0.16)
        _:
            return Color.WHITE

static func faction_name(id: int) -> String:
    match id:
        Faction.BLUE:
            return "蓝方"
        Faction.RED:
            return "红方"
        Faction.GREEN:
            return "绿方"
        Faction.YELLOW:
            return "黄方"
        _:
            return "未知"

static func faction_nickname(id: int) -> String:
    match id:
        Faction.BLUE:
            return "小蓝"
        Faction.RED:
            return "小红"
        Faction.GREEN:
            return "小绿"
        Faction.YELLOW:
            return "小黄"
        _:
            return "小球"
