extends RefCounted
class_name SaveGameCodec

const SAVE_MAJOR_PREFIX: String = "1.9"
const CURRENT_SAVE_VERSION: String = "1.9.34"
const MAX_RESTORE_CONTROL_BALLS: int = 8

static func get_current_save_version() -> String:
    return CURRENT_SAVE_VERSION

static func is_supported_save_version(version: String) -> bool:
    return str(version).begins_with(SAVE_MAJOR_PREFIX)

static func vec2_to_arr(v: Vector2) -> Array:
    return [v.x, v.y]

static func arr_to_vec2(value, default_value: Vector2 = Vector2.ZERO) -> Vector2:
    if value is Array and value.size() >= 2:
        return Vector2(float(value[0]), float(value[1]))
    return default_value

static func vec2i_to_arr(v: Vector2i) -> Array:
    return [v.x, v.y]

static func arr_to_vec2i(value, default_value: Vector2i = Vector2i(-999, -999)) -> Vector2i:
    if value is Array and value.size() >= 2:
        return Vector2i(int(value[0]), int(value[1]))
    return default_value

static func get_release_ball_index(chamber) -> int:
    if chamber == null or chamber.release_ball == null:
        return -1
    for i in range(chamber.balls.size()):
        if chamber.balls[i] == chamber.release_ball:
            return i
    return -1

static func collect_control_ball_states(chamber) -> Array:
    var result: Array = []
    if chamber == null:
        return result

    for ball in chamber.balls:
        if ball == null or not is_instance_valid(ball):
            continue
        result.append({
            "position": vec2_to_arr(ball.position),
            "velocity": vec2_to_arr(ball.velocity),
            "radius": ball.radius,
            "stay_time": chamber.get_ball_stay_time(ball),
        })
    return result

static func collect_bullet_states(bullet_container) -> Array:
    var result: Array = []
    if bullet_container == null:
        return result

    var source_bullets: Array = bullet_container.get_active_bullets() if bullet_container.has_method("get_active_bullets") else bullet_container.get_children()
    for node in source_bullets:
        if node is Bullet and node.is_active:
            var trail: Array = []
            for point in node.trail_points:
                trail.append(vec2_to_arr(point))
            result.append({
                "faction_id": node.faction_id,
                "position": vec2_to_arr(node.global_position),
                "direction": vec2_to_arr(node.direction),
                "age": node.age,
                "last_cell": vec2i_to_arr(node.last_cell),
                "trail_points": trail,
            })
    return result

static func validate_save_data(data: Dictionary) -> Dictionary:
    var clean: Dictionary = data.duplicate(true)

    clean["grid_size"] = LayoutProfiles.sanitize_grid_size(clean.get("grid_size", 40))

    var version: String = str(clean.get("save_version", ""))
    if version == "" or not version.begins_with(SAVE_MAJOR_PREFIX):
        clean["_invalid_reason"] = "存档版本不兼容：%s" % version
        return clean

    if not (str(clean.get("quality_name", "中")) in GameConfig.get_quality_names()):
        clean["quality_name"] = "中"

    if not (str(clean.get("game_mode_name", GameConfig.GAME_MODE_BASIC)) in GameConfig.get_game_mode_names()):
        clean["game_mode_name"] = GameConfig.GAME_MODE_BASIC
    clean["time_limit_minutes"] = clampi(int(clean.get("time_limit_minutes", GameConfig.DEFAULT_TIMED_MODE_MINUTES)), GameConfig.TIMED_MODE_MIN_MINUTES, GameConfig.TIMED_MODE_MAX_MINUTES)

    var owners = clean.get("owners", [])
    var grid_size: int = int(clean["grid_size"])
    var owners_ok: bool = owners is Array and owners.size() == grid_size
    if owners_ok:
        for x in range(grid_size):
            if not (owners[x] is Array) or owners[x].size() < grid_size:
                owners_ok = false
                break
    if not owners_ok:
        clean.erase("owners")

    var bullets = clean.get("bullets", [])
    if bullets is Array:
        clean["bullets"] = bullets.slice(0, mini(bullets.size(), GameConfig.get_restore_bullet_limit()))
    else:
        clean["bullets"] = []

    var event_state = clean.get("event_state", {})
    if event_state is Dictionary:
        clean["event_state"] = {
            "event_roulette_enabled": bool(event_state.get("event_roulette_enabled", true)),
            "next_event_time_left": maxf(0.0, float(event_state.get("next_event_time_left", 0.0))),
            "current_event_interval": maxf(0.0, float(event_state.get("current_event_interval", 0.0))),
            "last_event_faction": clampi(int(event_state.get("last_event_faction", -1)), -1, 3),
            "last_event_effect": str(event_state.get("last_event_effect", "")),
            "reroll_count": clampi(int(event_state.get("reroll_count", 0)), 0, 2),
        }
    else:
        clean["event_state"] = {}

    var factions = clean.get("factions", [])
    var fixed_factions: Array = []
    if factions is Array:
        for state in factions:
            if not (state is Dictionary):
                continue
            var fixed = state.duplicate(true)
            fixed["faction_id"] = clampi(int(fixed.get("faction_id", 0)), 0, 3)
            fixed["chamber_pending_count"] = clampi(int(fixed.get("chamber_pending_count", 1)), 1, GameConfig.get_max_pending_count())
            fixed["chamber_locked_remaining"] = clampi(int(fixed.get("chamber_locked_remaining", 0)), 0, GameConfig.get_max_pending_count())
            fixed["chamber_jammed_time_left"] = maxf(0.0, float(fixed.get("chamber_jammed_time_left", 0.0)))
            fixed["turret_burst_remaining"] = clampi(int(fixed.get("turret_burst_remaining", 0)), 0, GameConfig.get_max_pending_count())
            fixed["turret_burst_total"] = clampi(int(fixed.get("turret_burst_total", 0)), 0, GameConfig.get_max_pending_count())
            fixed["turret_burst_index"] = clampi(int(fixed.get("turret_burst_index", 0)), 0, GameConfig.get_max_pending_count())

            var queued_modifiers = fixed.get("queued_round_modifiers", [])
            if queued_modifiers is Array:
                fixed["queued_round_modifiers"] = queued_modifiers
            else:
                fixed["queued_round_modifiers"] = []

            var control_balls = fixed.get("control_balls", [])
            if control_balls is Array:
                fixed["control_balls"] = control_balls.slice(0, mini(control_balls.size(), MAX_RESTORE_CONTROL_BALLS))
            else:
                fixed["control_balls"] = []

            fixed_factions.append(fixed)
    clean["factions"] = fixed_factions
    return clean
