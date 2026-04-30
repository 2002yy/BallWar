extends Node2D
class_name ControlChamber

signal release_requested(faction_id, bullet_count, chamber)
signal ball_count_changed(faction_id, count)

# v1.9.5 稳定性收口版：
# 1) 阵营名移入控制仓内部顶部；
# 2) 3-4-3-4-3-4 保留；
# 3) 4 行两侧 peg 视觉半嵌入墙体；
# 4) 3 行居中，保证 peg 与墙之间的可通行距离大于控制球半径；
# 5) 增加小球防卡检测。
const CONTROL_BALL_RADIUS: float = 5.4
const PEG_RADIUS: float = 7.0
const PEG_SPACING_X: float = 36.0
const PEG_SPACING_Y: float = 34.0

const FOUR_ROW_EMBED_RATIO: float = 0.5
const CHAMBER_HEIGHT: float = 286.0
const GATE_HEIGHT: float = 36.0
const TOP_Y: float = 44.0

const GATE_RAMP_SECONDS: float = 300.0
const GATE_START_RELEASE_RATIO: float = 0.72
const GATE_END_RELEASE_RATIO: float = 0.30
const GATE_MIN_RATIO: float = 0.28

const STUCK_MOVE_EPS: float = 0.35
const STUCK_SPEED_EPS: float = 18.0
const STUCK_TIME_LIMIT: float = 0.80
const WALL_STUCK_MARGIN: float = 5.0
const WALL_STUCK_Y_EPS: float = 0.55

var faction_id: int = GameConfig.Faction.BLUE
var pending_count: int = 1
var locked_remaining: int = 0

# 宽度由 4 行的半嵌入规则反推：
# 左右侧 peg 圆心距墙 = PEG_RADIUS * 0.5；
# 四列之间有 3 个 PEG_SPACING_X。
var chamber_size: Vector2 = Vector2(
    PEG_RADIUS + PEG_SPACING_X * 3.0,
    CHAMBER_HEIGHT
)

var balls: Array = []
var release_ball = null
var gravity: float = 420.0
var pegs: Array = []
var peg_radius: float = PEG_RADIUS
var stuck_states: Dictionary = {}

var name_label
var count_label
var ball_label
var is_damaged: bool = false
var is_locked: bool = false
var damage_anim_t: float = 0.0
var gate_height: float = GATE_HEIGHT
var game_elapsed_time: float = 0.0

func setup(new_faction_id: int, new_position: Vector2) -> void:
    faction_id = new_faction_id
    global_position = new_position

func _ready() -> void:
    randomize()
    _create_pegs()
    add_control_ball()
    _create_labels()
    queue_redraw()

func _process(delta: float) -> void:
    if is_damaged:
        damage_anim_t += delta
        queue_redraw()
    elif count_label != null:
        count_label.scale = Vector2.ONE * (1.0 + 0.035 * sin(Time.get_ticks_msec() / 250.0))

    if not is_damaged:
        queue_redraw()

func _create_pegs() -> void:
    pegs.clear()

    var row_counts: Array = [3, 4, 3, 4, 3, 4]
    var side_center_x: float = PEG_RADIUS * FOUR_ROW_EMBED_RATIO
    var centered_three_start_x: float = (chamber_size.x - PEG_SPACING_X * 2.0) * 0.5

    for row_index in range(row_counts.size()):
        var count: int = row_counts[row_index]
        var y: float = TOP_Y + float(row_index) * PEG_SPACING_Y
        var start_x: float

        if count == 4:
            # 两侧 peg 视觉上一半嵌入墙体。
            start_x = side_center_x
        else:
            # 3 行居中，左右墙距离都足够小球通过，避免被墙夹住。
            start_x = centered_three_start_x

        for i in range(count):
            pegs.append(Vector2(start_x + float(i) * PEG_SPACING_X, y))

func add_control_ball() -> bool:
    if is_damaged or is_locked:
        return false
    if balls.size() >= GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
        return false

    var ball = ControlBall.new()
    ball.radius = CONTROL_BALL_RADIUS
    add_child(ball)
    balls.append(ball)
    _relaunch_control_ball(ball)
    ball_count_changed.emit(faction_id, balls.size())
    _update_label()
    return true

func get_ball_count() -> int:
    return balls.size()

func _create_labels() -> void:
    name_label = Label.new()
    name_label.position = Vector2(0, 4)
    name_label.size = Vector2(chamber_size.x, 24)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
    name_label.add_theme_font_size_override("font_size", 17)
    name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.72))
    name_label.add_theme_color_override("font_outline_color", Color.BLACK)
    name_label.add_theme_constant_override("outline_size", 3)
    add_child(name_label)

    count_label = Label.new()
    count_label.position = Vector2(0, 116)
    count_label.size = Vector2(chamber_size.x, 88)
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
    count_label.add_theme_font_size_override("font_size", 76)
    count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
    count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.60))
    count_label.add_theme_constant_override("outline_size", 4)
    add_child(count_label)

    ball_label = Label.new()
    ball_label.position = Vector2(0, chamber_size.y - gate_height - 24.0)
    ball_label.size = Vector2(chamber_size.x, 22)
    ball_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    ball_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
    ball_label.add_theme_font_size_override("font_size", 17)
    ball_label.add_theme_color_override("font_color", Color.WHITE)
    ball_label.add_theme_color_override("font_outline_color", Color.BLACK)
    ball_label.add_theme_constant_override("outline_size", 3)
    add_child(ball_label)

    _update_label()

func _relaunch_control_ball(ball) -> void:
    if ball == null:
        return
    ball.radius = CONTROL_BALL_RADIUS
    var start_x: float = randf_range(18.0, chamber_size.x - 18.0)
    ball.setup(faction_id, Vector2(start_x, 18.0), Vector2(randf_range(-54.0, 54.0), randf_range(24.0, 82.0)))
    _reset_stuck_state(ball)

func _is_side_embedded_peg(peg: Vector2) -> bool:
    return peg.x <= PEG_RADIUS * 0.75 or peg.x >= chamber_size.x - PEG_RADIUS * 0.75

func _effective_peg_radius(peg: Vector2) -> float:
    # 侧边半嵌入 peg 保留视觉，但弱化碰撞，避免墙 + peg 夹住小球。
    if _is_side_embedded_peg(peg):
        return peg_radius * 0.50
    return peg_radius

func _clamp_ball_to_walls(ball) -> void:
    if ball.position.x < ball.radius:
        ball.position.x = ball.radius
        ball.velocity.x = abs(ball.velocity.x) * 0.92
    elif ball.position.x > chamber_size.x - ball.radius:
        ball.position.x = chamber_size.x - ball.radius
        ball.velocity.x = -abs(ball.velocity.x) * 0.92

    if ball.position.y < ball.radius:
        ball.position.y = ball.radius
        ball.velocity.y = abs(ball.velocity.y) * 0.90

func _reset_stuck_state(ball) -> void:
    if ball == null:
        return
    stuck_states[ball.get_instance_id()] = {
        "pos": ball.position,
        "y": ball.position.y,
        "time": 0.0
    }

func _update_stuck_state(ball, delta: float) -> void:
    if ball == null:
        return

    var id: int = ball.get_instance_id()
    if not stuck_states.has(id):
        _reset_stuck_state(ball)
        return

    var state: Dictionary = stuck_states[id]
    var last_pos: Vector2 = state.get("pos", ball.position)
    var last_y: float = float(state.get("y", ball.position.y))
    var stuck_time: float = float(state.get("time", 0.0))
    var moved: float = ball.position.distance_to(last_pos)
    var y_progress: float = ball.position.y - last_y
    var near_wall: bool = ball.position.x <= ball.radius + WALL_STUCK_MARGIN or ball.position.x >= chamber_size.x - ball.radius - WALL_STUCK_MARGIN

    # 普通低速卡住：几乎不动 + 速度很低。
    # 墙边抖动卡住：靠墙并且 y 几乎没有向下推进，即使 x 方向有细碎抖动也算卡。
    var low_speed_stuck: bool = moved < STUCK_MOVE_EPS and ball.velocity.length() < STUCK_SPEED_EPS
    var wall_jitter_stuck: bool = near_wall and y_progress < WALL_STUCK_Y_EPS and ball.velocity.y < STUCK_SPEED_EPS * 1.8

    if low_speed_stuck or wall_jitter_stuck:
        stuck_time += delta
    else:
        stuck_time = 0.0
        last_pos = ball.position
        last_y = ball.position.y

    if stuck_time >= STUCK_TIME_LIMIT:
        ball.position.x = clampf(ball.position.x + randf_range(-7.0, 7.0), ball.radius, chamber_size.x - ball.radius)
        ball.velocity = Vector2(randf_range(-105.0, 105.0), randf_range(-80.0, -18.0))
        stuck_time = 0.0
        last_pos = ball.position
        last_y = ball.position.y

    state["pos"] = last_pos
    state["y"] = last_y
    state["time"] = stuck_time
    stuck_states[id] = state

func _physics_process(delta: float) -> void:
    if is_damaged or is_locked:
        return

    var x2_width: float = _current_x2_width()

    for ball in balls:
        if ball == null:
            continue

        ball.velocity.y += gravity * delta
        ball.position += ball.velocity * delta

        _clamp_ball_to_walls(ball)

        for peg in pegs:
            var offset: Vector2 = ball.position - peg
            var dist: float = offset.length()
            var min_dist: float = _effective_peg_radius(peg) + ball.radius
            if dist > 0.01 and dist < min_dist:
                var normal: Vector2 = offset / dist
                ball.position = peg + normal * min_dist
                ball.velocity = ball.velocity.bounce(normal) * 0.86
                ball.velocity += Vector2(randf_range(-22.0, 22.0), randf_range(-10.0, 10.0))

        _clamp_ball_to_walls(ball)
        _update_stuck_state(ball, delta)

        if ball.position.y >= chamber_size.y - ball.radius:
            if ball.position.x < x2_width:
                _on_left_gate(ball)
            else:
                _on_right_gate(ball)
                break

func _on_left_gate(ball) -> void:
    pending_count = clampi(pending_count * 2, 1, GameConfig.MAX_PENDING_COUNT)
    _update_label()
    _relaunch_control_ball(ball)

func _on_right_gate(ball) -> void:
    if is_locked:
        return

    release_ball = ball
    locked_remaining = pending_count
    is_locked = true
    _update_label()
    release_requested.emit(faction_id, pending_count, self)

func start_locked(count: int) -> void:
    locked_remaining = max(0, count)
    is_locked = true
    _update_label()

func update_locked_remaining(remaining: int) -> void:
    locked_remaining = max(0, remaining)
    _update_label()

func set_locked(locked: bool) -> void:
    if is_damaged:
        return

    is_locked = locked

    if not is_locked:
        pending_count = 1
        locked_remaining = 0

        if release_ball != null and is_instance_valid(release_ball):
            _relaunch_control_ball(release_ball)
        release_ball = null

    _update_label()

func set_damaged() -> void:
    if is_damaged:
        return
    is_damaged = true
    pending_count = 0
    locked_remaining = 0
    is_locked = false
    release_ball = null
    for ball in balls:
        if ball != null:
            ball.queue_free()
    balls.clear()
    stuck_states.clear()
    ball_count_changed.emit(faction_id, 0)
    _update_label()
    queue_redraw()

func _update_label() -> void:
    if name_label == null:
        return

    name_label.text = GameConfig.faction_nickname(faction_id)
    name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.72))

    if is_damaged:
        count_label.text = "×"
        ball_label.text = "球 0"
        return

    if is_locked:
        count_label.text = str(locked_remaining)
    else:
        count_label.text = str(pending_count)

    ball_label.text = "球 %d" % balls.size()

func set_game_elapsed_time(value: float) -> void:
    game_elapsed_time = maxf(0.0, value)

func _current_progress() -> float:
    return clampf(game_elapsed_time / GATE_RAMP_SECONDS, 0.0, 1.0)

func _current_release_ratio() -> float:
    var progress: float = _current_progress()
    var eased: float = progress * progress * (3.0 - 2.0 * progress)
    return lerpf(GATE_START_RELEASE_RATIO, GATE_END_RELEASE_RATIO, eased)

func _current_x2_width() -> float:
    if is_locked or is_damaged:
        return chamber_size.x * 0.5
    var release_ratio: float = clampf(_current_release_ratio(), GATE_MIN_RATIO, 1.0 - GATE_MIN_RATIO)
    var x2_ratio: float = 1.0 - release_ratio
    return chamber_size.x * x2_ratio

func _draw() -> void:
    var base_color: Color = Color(0.96, 0.96, 0.96, 0.96)
    var border_color: Color = GameConfig.faction_color(faction_id)
    if is_damaged:
        base_color = Color(0.22, 0.22, 0.22, 0.95)
        border_color = Color(0.78, 0.12, 0.12)

    draw_rect(Rect2(Vector2.ZERO, chamber_size), base_color, true)
    draw_rect(Rect2(Vector2.ZERO, Vector2(chamber_size.x, 30.0)), Color(border_color.r, border_color.g, border_color.b, 0.13), true)
    draw_rect(Rect2(Vector2.ZERO, chamber_size), border_color, false, 3)

    for peg in pegs:
        var peg_color: Color = Color(0.20, 0.20, 0.20)
        if is_damaged:
            peg_color = Color(0.08, 0.08, 0.08)
        draw_circle(peg, peg_radius, peg_color)
        draw_circle(peg, peg_radius * 0.45, Color(0.9, 0.9, 0.9, 0.55))

    var x2_width: float = _current_x2_width()
    var left_rect: Rect2 = Rect2(Vector2(0, chamber_size.y - gate_height), Vector2(x2_width, gate_height))
    var right_rect: Rect2 = Rect2(Vector2(x2_width, chamber_size.y - gate_height), Vector2(chamber_size.x - x2_width, gate_height))
    var left_color: Color = Color(0.78, 0.95, 0.23)
    var right_color: Color = Color(1.0, 0.67, 0.16)

    if is_locked or is_damaged:
        left_color = Color(0.55, 0.55, 0.55)
        right_color = Color(0.45, 0.45, 0.45)

    draw_rect(left_rect, left_color, true)
    draw_rect(right_rect, right_color, true)
    draw_rect(Rect2(Vector2.ZERO, chamber_size), Color.BLACK, false, 2)
    draw_line(Vector2(x2_width, chamber_size.y - gate_height), Vector2(x2_width, chamber_size.y), Color.BLACK, 2)

    var font = ThemeDB.fallback_font
    draw_string(font, Vector2(maxf(6.0, x2_width * 0.5 - 13.0), chamber_size.y - 11), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.BLACK)
    draw_string(font, Vector2(x2_width + maxf(4.0, (chamber_size.x - x2_width) * 0.5 - 16.0), chamber_size.y - 11), "发射", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)

    if is_locked and not is_damaged:
        draw_rect(Rect2(Vector2(0, chamber_size.y - gate_height), Vector2(chamber_size.x, gate_height)), Color(0.1, 0.1, 0.1, 0.28), true)

    if is_damaged:
        var pulse: float = 0.35 + 0.25 * sin(damage_anim_t * 8.0)
        draw_line(Vector2(12, 18), Vector2(chamber_size.x - 12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_line(Vector2(chamber_size.x - 12, 18), Vector2(12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_rect(Rect2(Vector2(5, 5), chamber_size - Vector2(10, 10)), Color(1.0, 0.0, 0.0, pulse), false, 4.0)
