extends RefCounted
class_name GameConfig

const GRID_SIZE = 40
const CELL_SIZE = 13

const BULLET_SPEED = 108.0
const BULLET_RADIUS = 5.0
const BULLET_MAX_LIFETIME = 12.0

const TURRET_RADIUS = 18.0
const TURRET_MAX_HEALTH = 30
const TURRET_HIT_RADIUS = 24.0
const TURRET_HIT_CHECK_INTERVAL = 0.055
const BULLET_DAMAGE = 1

const MAX_PENDING_COUNT = 2048
const MAX_CONTROL_BALLS_PER_CHAMBER = 8
const MAX_ACTIVE_BULLETS = 6000
const BURST_FIRE_INTERVAL = 0.045


static var _quality_name = "中"

static func get_quality_names() -> Array:
    return ["低", "中", "高"]

static func set_quality_by_name(name: String) -> void:
    if name in get_quality_names():
        _quality_name = name
    else:
        _quality_name = "中"

static func get_quality_name() -> String:
    return _quality_name

static func get_max_active_bullets() -> int:
    match _quality_name:
        "低":
            return 1800
        "高":
            return MAX_ACTIVE_BULLETS
        _:
            return 2800

static func get_restore_bullet_limit() -> int:
    match _quality_name:
        "低":
            return 1000
        "高":
            return MAX_ACTIVE_BULLETS
        _:
            return 2600

static func get_restore_per_frame() -> int:
    match _quality_name:
        "低":
            return 80
        "高":
            return 180
        _:
            return 120

static func get_mid_pressure_threshold() -> int:
    match _quality_name:
        "低":
            return 360
        "高":
            return 800
        _:
            return 600

static func get_high_pressure_threshold() -> int:
    match _quality_name:
        "低":
            return 900
        "高":
            return 1800
        _:
            return 1200

static func get_force_simple_threshold() -> int:
    match _quality_name:
        "低":
            return 1200
        "高":
            return 3600
        _:
            return 1800

static func get_normal_trail_points() -> int:
    match _quality_name:
        "低":
            return 2
        "高":
            return 6
        _:
            return 4

static func get_mid_trail_points() -> int:
    return 2

static func get_high_trail_points() -> int:
    return 1

static func get_grid_line_alpha() -> float:
    match _quality_name:
        "低":
            return 0.035
        "高":
            return 0.10
        _:
            return 0.065

static func get_emblem_alpha_mul() -> float:
    match _quality_name:
        "低":
            return 0.35
        "高":
            return 1.0
        _:
            return 0.65


enum Faction { BLUE, RED, GREEN, YELLOW }

static var _palette_name = "经典"
static var _palette_colors = [
    Color(0.20, 0.49, 1.00),
    Color(1.00, 0.30, 0.22),
    Color(0.20, 0.82, 0.34),
    Color(1.00, 0.82, 0.16)
]
static var _palette_names = ["蓝方", "红方", "绿方", "黄方"]
static var _palette_nicknames = ["小蓝", "小红", "小绿", "小黄"]

static func get_palette_names() -> Array:
    return ["经典", "霓虹", "糖果", "暗夜", "薄荷"]

static func set_random_palette() -> void:
    var names = get_palette_names()
    var idx = randi() % names.size()
    set_palette_by_name(names[idx])

static func set_palette_by_name(name: String) -> void:
    _palette_name = name
    match name:
        "霓虹":
            _palette_colors = [
                Color(0.00, 0.93, 1.00),
                Color(1.00, 0.18, 0.62),
                Color(0.52, 1.00, 0.18),
                Color(1.00, 0.84, 0.10)
            ]
            _palette_names = ["青方", "粉方", "荧方", "金方"]
            _palette_nicknames = ["小青", "小粉", "小荧", "小金"]
        "糖果":
            _palette_colors = [
                Color(0.33, 0.73, 1.00),
                Color(1.00, 0.46, 0.52),
                Color(0.36, 0.88, 0.56),
                Color(1.00, 0.77, 0.38)
            ]
            _palette_names = ["莓方", "桃方", "糖方", "蜜方"]
            _palette_nicknames = ["小莓", "小桃", "小糖", "小蜜"]
        "暗夜":
            _palette_colors = [
                Color(0.26, 0.43, 0.95),
                Color(0.85, 0.25, 0.28),
                Color(0.22, 0.66, 0.34),
                Color(0.82, 0.64, 0.18)
            ]
            _palette_names = ["靛方", "赤方", "森方", "铜方"]
            _palette_nicknames = ["小靛", "小赤", "小森", "小铜"]
        "薄荷":
            _palette_colors = [
                Color(0.23, 0.73, 0.95),
                Color(0.93, 0.39, 0.56),
                Color(0.38, 0.89, 0.73),
                Color(0.96, 0.83, 0.41)
            ]
            _palette_names = ["海方", "莓方", "荷方", "杏方"]
            _palette_nicknames = ["小海", "小莓", "小荷", "小杏"]
        _:
            _palette_colors = [
                Color(0.20, 0.49, 1.00),
                Color(1.00, 0.30, 0.22),
                Color(0.20, 0.82, 0.34),
                Color(1.00, 0.82, 0.16)
            ]
            _palette_names = ["蓝方", "红方", "绿方", "黄方"]
            _palette_nicknames = ["小蓝", "小红", "小绿", "小黄"]

static func get_palette_name() -> String:
    return _palette_name

static func faction_color(id: int) -> Color:
    if id >= 0 and id < _palette_colors.size():
        return _palette_colors[id]
    return Color.WHITE

static func faction_name(id: int) -> String:
    if id >= 0 and id < _palette_names.size():
        return _palette_names[id]
    return "未知"

static func faction_nickname(id: int) -> String:
    if id >= 0 and id < _palette_nicknames.size():
        return _palette_nicknames[id]
    return "小球"
