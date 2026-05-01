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
const GATE_DIVIDER_WIDTH: float = 5.0
const GATE_DIVIDER_RISE: float = 16.0
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
const CONTROL_BALL_MAX_STAY_TIME: float = 14.0

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
var ball_stay_times: Dictionary = {}

var name_label
var count_label
var ball_label
var is_damaged: bool = false
var is_locked: bool = false
var damage_anim_t: float = 0.0
var gate_height: float = GATE_HEIGHT
var game_elapsed_time: float = 0.0
var status_anim_t: float = 0.0
var visual_redraw_timer: float = 0.0

const NORMAL_REDRAW_INTERVAL: float = 0.25
const LOCKED_REDRAW_INTERVAL: float = 0.050
const DAMAGED_REDRAW_INTERVAL: float = 0.080

func setup(new_faction_id: int, new_position: Vector2) -> void:
    faction_id = new_faction_id
    global_position = new_position

func _ready() -> void:
    randomize()
    _create_pegs()
    add_control_ball()
    _create_labels()
    _force_visual_redraw()

func _process(delta: float) -> void:
    status_anim_t += delta

    if is_damaged:
        damage_anim_t += delta

    if count_label != null:
        var pulse_amp: float = 0.028
        if is_locked:
            pulse_amp = 0.050
        elif is_damaged:
            pulse_amp = 0.018
        count_label.scale = Vector2.ONE * (1.0 + pulse_amp * sin(Time.get_ticks_msec() / 220.0))

    if ball_label != null:
        if is_damaged:
            ball_label.modulate = Color(1.0, 0.66, 0.66, 0.95)
        elif is_locked:
            var a: float = 0.78 + 0.22 * sin(status_anim_t * 6.0)
            ball_label.modulate = Color(1.0, 0.86, 0.52, a)
        else:
            ball_label.modulate = Color(0.92, 0.96, 1.0, 0.98)

    _update_visual_redraw(delta)

func _force_visual_redraw() -> void:
    visual_redraw_timer = 0.0
    queue_redraw()

func _update_visual_redraw(delta: float) -> void:
    visual_redraw_timer -= delta
    if visual_redraw_timer > 0.0:
        return

    if is_damaged:
        visual_redraw_timer = DAMAGED_REDRAW_INTERVAL
    elif is_locked:
        visual_redraw_timer = LOCKED_REDRAW_INTERVAL
    else:
        visual_redraw_timer = NORMAL_REDRAW_INTERVAL
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
    _reset_ball_stay_time(ball)
    _reset_ball_stay_time(ball)

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
    var id: int = ball.get_instance_id()
    stuck_states[id] = {
        "pos": ball.position,
        "y": ball.position.y,
        "time": 0.0
    }
    if not ball_stay_times.has(id):
        ball_stay_times[id] = 0.0

func get_ball_stay_time(ball) -> float:
    if ball == null:
        return 0.0
    return float(ball_stay_times.get(ball.get_instance_id(), 0.0))

func set_ball_stay_time(ball, value: float) -> void:
    if ball == null:
        return
    ball_stay_times[ball.get_instance_id()] = clampf(value, 0.0, CONTROL_BALL_MAX_STAY_TIME)

func _reset_ball_stay_time(ball) -> void:
    if ball == null:
        return
    ball_stay_times[ball.get_instance_id()] = 0.0

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

func _handle_gate_divider_collision(ball, x2_width: float) -> void:
    # 底部 x2 / 发射交界处的窄挡板。
    # 视觉上仍是原来的分界线，但物理上会把小球推向左右任意一侧，避免“正好落在线上”的模糊情况。
    var half_width: float = GATE_DIVIDER_WIDTH * 0.5
    var top_y: float = chamber_size.y - gate_height - GATE_DIVIDER_RISE
    var bottom_y: float = chamber_size.y

    if ball.position.y + ball.radius < top_y or ball.position.y - ball.radius > bottom_y:
        return

    if absf(ball.position.x - x2_width) <= ball.radius + half_width:
        if ball.position.x < x2_width:
            ball.position.x = x2_width - half_width - ball.radius
            ball.velocity.x = -abs(ball.velocity.x) * 0.82 - 20.0
        else:
            ball.position.x = x2_width + half_width + ball.radius
            ball.velocity.x = abs(ball.velocity.x) * 0.82 + 20.0
        ball.velocity.y *= 0.94

func _update_ball_stay_time(ball, delta: float) -> void:
    if ball == null:
        return
    var id: int = ball.get_instance_id()
    var stay_time: float = float(ball_stay_times.get(id, 0.0)) + delta
    if stay_time >= CONTROL_BALL_MAX_STAY_TIME:
        _relaunch_control_ball(ball)
        return
    ball_stay_times[id] = stay_time

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
        _handle_gate_divider_collision(ball, x2_width)
        _clamp_ball_to_walls(ball)
        _update_stuck_state(ball, delta)
        _update_ball_stay_time(ball, delta)

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
    _force_visual_redraw()
    release_requested.emit(faction_id, pending_count, self)

func start_locked(count: int) -> void:
    locked_remaining = maxi(0, count)
    is_locked = true
    _update_label()
    _force_visual_redraw()

func update_locked_remaining(remaining: int) -> void:
    locked_remaining = maxi(0, remaining)
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
    _force_visual_redraw()

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
    ball_stay_times.clear()
    ball_count_changed.emit(faction_id, 0)
    _update_label()
    _force_visual_redraw()

func _update_label() -> void:
    if name_label == null:
        return

    name_label.text = GameConfig.faction_nickname(faction_id)
    name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.80))

    if is_damaged:
        count_label.text = "×"
        ball_label.text = "系统离线"
        return

    if is_locked:
        count_label.text = str(locked_remaining)
        ball_label.text = "能量输出"
    else:
        count_label.text = str(pending_count)
        ball_label.text = "待命 · %d球" % balls.size()

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
    var faction_color: Color = GameConfig.faction_color(faction_id)
    var shell_color: Color = Color(0.11, 0.13, 0.17, 0.98)
    var border_color: Color = faction_color.lightened(0.12)
    var inner_color: Color = Color(0.17, 0.19, 0.24, 0.98)
    var top_h: float = 30.0
    var blink: float = 0.5 + 0.5 * sin(status_anim_t * 6.0)
    var energy_glow: float = 0.22 + 0.12 * sin(status_anim_t * 4.2)

    if is_damaged:
        shell_color = Color(0.14, 0.11, 0.11, 1.0)
        border_color = Color(0.86, 0.18, 0.18)
        inner_color = Color(0.10, 0.08, 0.08, 1.0)

    var outer_rect: Rect2 = Rect2(Vector2.ZERO, chamber_size)
    var shell_rect: Rect2 = Rect2(Vector2(5.0, 5.0), chamber_size - Vector2(10.0, 10.0))
    var title_rect: Rect2 = Rect2(Vector2(10.0, 10.0), Vector2(chamber_size.x - 20.0, 22.0))
    var inner_rect: Rect2 = Rect2(Vector2(10.0, top_h + 6.0), Vector2(chamber_size.x - 20.0, chamber_size.y - top_h - gate_height - 18.0))

    draw_rect(outer_rect, Color(0.0, 0.0, 0.0, 0.22), true)
    draw_rect(outer_rect, shell_color, true)
    draw_rect(shell_rect, Color(0.04, 0.05, 0.07, 0.98), true)
    draw_rect(title_rect, Color(border_color.r, border_color.g, border_color.b, 0.14), true)
    draw_rect(inner_rect, inner_color, true)
    draw_rect(outer_rect, border_color, false, 3.0)
    draw_rect(Rect2(Vector2(4.0, 4.0), chamber_size - Vector2(8.0, 8.0)), Color(border_color.r, border_color.g, border_color.b, 0.16), false, 1.5)

    # 顶部状态灯 + 组件化机械细节
    for rivet in [Vector2(11, 11), Vector2(chamber_size.x - 11, 11), Vector2(11, chamber_size.y - 11), Vector2(chamber_size.x - 11, chamber_size.y - 11)]:
        draw_circle(rivet, 3.0, Color(0.22, 0.24, 0.28))
        draw_circle(rivet + Vector2(-0.8, -0.8), 1.0, Color(1.0, 1.0, 1.0, 0.18))

    var light_a: Color = Color(0.18, 0.22, 0.26)
    var light_b: Color = Color(0.18, 0.22, 0.26)
    if is_damaged:
        light_a = Color(1.0, 0.14, 0.14, 0.55 + 0.35 * blink)
        light_b = Color(0.20, 0.07, 0.07)
    elif is_locked:
        light_a = Color(1.0, 0.82, 0.20, 0.55 + 0.35 * blink)
        light_b = Color(1.0, 0.58, 0.14, 0.48 + 0.28 * blink)
    else:
        light_a = Color(faction_color.r, faction_color.g, faction_color.b, 0.56 + 0.20 * blink)
        light_b = Color(0.26, 1.0, 0.74, 0.28 + 0.12 * blink)

    for idx in range(2):
        var pos_x: float = chamber_size.x - 28.0 + float(idx) * 10.0
        var c: Color = light_a if idx == 0 else light_b
        draw_circle(Vector2(pos_x, 21.0), 4.2, Color(c.r, c.g, c.b, 0.18))
        draw_circle(Vector2(pos_x, 21.0), 2.8, c)

    # 内腔增加轻微扫描感
    if not is_damaged:
        for i in range(5):
            var y: float = inner_rect.position.y + 14.0 + float(i) * 18.0
            draw_line(Vector2(inner_rect.position.x + 5.0, y), Vector2(inner_rect.end.x - 5.0, y), Color(1.0, 1.0, 1.0, 0.025), 1.0)

    for peg in pegs:
        var pcolor: Color = Color(0.40, 0.42, 0.48)
        if is_damaged:
            pcolor = Color(0.18, 0.11, 0.11)
        var glow: Color = Color(border_color.r, border_color.g, border_color.b, 0.12 + blink * 0.05)
        if is_damaged:
            glow = Color(1.0, 0.18, 0.18, 0.12 + blink * 0.08)
        draw_circle(peg, peg_radius + 3.0, glow)
        draw_circle(peg, peg_radius, pcolor)
        draw_circle(peg + Vector2(-1.0, -1.0), peg_radius * 0.42, Color(1.0, 1.0, 1.0, 0.56))

    var x2_width: float = _current_x2_width()
    var gate_frame: Rect2 = Rect2(Vector2(8.0, chamber_size.y - gate_height - 8.0), Vector2(chamber_size.x - 16.0, gate_height + 4.0))
    draw_rect(gate_frame, Color(0.08, 0.09, 0.11, 0.98), true)
    draw_rect(gate_frame, Color(0.0, 0.0, 0.0, 0.76), false, 2.0)

    var left_rect: Rect2 = Rect2(Vector2(10.0, chamber_size.y - gate_height - 6.0), Vector2(maxf(0.0, x2_width - 12.0), gate_height - 4.0))
    var right_rect: Rect2 = Rect2(Vector2(x2_width + 2.0, chamber_size.y - gate_height - 6.0), Vector2(maxf(0.0, chamber_size.x - x2_width - 12.0), gate_height - 4.0))
    var left_color: Color = Color(0.74, 0.92, 0.22)
    var right_color: Color = Color(1.0, 0.64, 0.16)

    if is_locked:
        left_color = Color(0.42, 0.42, 0.42)
        right_color = Color(0.84, 0.54, 0.14, 0.70 + blink * 0.18)
    elif is_damaged:
        left_color = Color(0.32, 0.18, 0.18)
        right_color = Color(0.32, 0.18, 0.18)

    draw_rect(left_rect, left_color, true)
    draw_rect(right_rect, right_color, true)
    draw_rect(Rect2(left_rect.position, Vector2(left_rect.size.x, maxf(4.0, left_rect.size.y * 0.38))), Color(1.0, 1.0, 1.0, 0.12), true)
    draw_rect(Rect2(right_rect.position, Vector2(right_rect.size.x, maxf(4.0, right_rect.size.y * 0.38))), Color(1.0, 1.0, 1.0, 0.12), true)
    draw_rect(left_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.2)
    draw_rect(right_rect, Color(0.0, 0.0, 0.0, 0.55), false, 1.2)

    var divider_rect: Rect2 = Rect2(Vector2(x2_width - GATE_DIVIDER_WIDTH * 0.5, chamber_size.y - gate_height - GATE_DIVIDER_RISE), Vector2(GATE_DIVIDER_WIDTH, gate_height + GATE_DIVIDER_RISE))
    draw_rect(divider_rect, Color(0.18, 0.18, 0.20, 0.98), true)
    draw_rect(divider_rect, Color(0.0, 0.0, 0.0, 0.85), false, 1.2)

    # 发射态特效：发射口更亮 + 能量扫动
    if is_locked and not is_damaged:
        draw_rect(right_rect.grow(3.0), Color(1.0, 0.64, 0.16, energy_glow * 0.48), false, 2.0)
        for i in range(3):
            var bx: float = right_rect.position.x + 10.0 + float(i) * 14.0
            draw_line(Vector2(bx, right_rect.position.y - 12.0), Vector2(bx + 4.0, right_rect.position.y + 2.0), Color(1.0, 0.80, 0.28, 0.36 + 0.22 * blink), 2.0)
        var shutter: Rect2 = Rect2(Vector2(9.0, chamber_size.y - gate_height - 10.0), Vector2(chamber_size.x - 18.0, gate_height + 6.0))
        draw_rect(shutter, Color(0.16, 0.16, 0.18, 0.42), true)
        for i in range(7):
            var sx: float = 8.0 + float(i) * 18.0
            draw_line(Vector2(sx, chamber_size.y - gate_height - 10.0), Vector2(sx + 20.0, chamber_size.y - 2.0), Color(1.0, 1.0, 1.0, 0.08), 2.0)
        draw_rect(Rect2(Vector2(12.0, chamber_size.y - gate_height - 18.0), Vector2(chamber_size.x - 24.0, 8.0)), Color(0.22, 0.22, 0.24, 0.98), true)
        for j in range(3):
            var lx: float = chamber_size.x * 0.5 - 24.0 + float(j) * 18.0
            draw_circle(Vector2(lx, chamber_size.y - gate_height - 14.0), 3.4, Color(1.0, 0.82, 0.22, 0.55 + 0.35 * blink))
    elif not is_damaged:
        draw_rect(left_rect.grow(2.0), Color(0.74, 0.92, 0.22, 0.08), false, 1.0)
        draw_rect(right_rect.grow(2.0), Color(1.0, 0.64, 0.16, 0.08), false, 1.0)

    var font = ThemeDB.fallback_font
    draw_string(font, Vector2(maxf(6.0, x2_width * 0.5 - 13.0), chamber_size.y - 13), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.BLACK)
    draw_string(font, Vector2(x2_width + maxf(4.0, (chamber_size.x - x2_width) * 0.5 - 16.0), chamber_size.y - 13), "发射", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)

    if is_damaged:
        var pulse: float = 0.30 + 0.30 * sin(damage_anim_t * 8.0)
        draw_line(Vector2(14, 22), Vector2(chamber_size.x - 16, chamber_size.y - 52), Color(1.0, 0.12, 0.12, 0.90), 4.4)
        draw_line(Vector2(chamber_size.x - 18, 26), Vector2(22, chamber_size.y - 76), Color(1.0, 0.12, 0.12, 0.72), 3.0)
        draw_rect(Rect2(Vector2(5, 5), chamber_size - Vector2(10, 10)), Color(1.0, 0.0, 0.0, pulse), false, 3.0)
        for c in range(4):
            var crack_x: float = 22.0 + float(c) * 26.0
            draw_line(Vector2(crack_x, 40.0), Vector2(crack_x + 7.0, 53.0), Color(0.03, 0.01, 0.01, 0.92), 2.0)
