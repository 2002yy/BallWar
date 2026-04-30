extends Node2D
class_name ControlChamber

signal release_requested(faction_id, bullet_count, chamber)
signal ball_count_changed(faction_id, count)

var faction_id = GameConfig.Faction.BLUE
var pending_count = 1
var chamber_size = Vector2(160, 206)
var balls = []
var gravity = 420.0
var pegs = []
var peg_radius = 8.0
var name_label
var count_label
var ball_label
var state_label
var gate_height = 34.0
var is_damaged = false
var is_locked = false
var damage_anim_t = 0.0

func setup(new_faction_id: int, new_position: Vector2) -> void:
    faction_id = new_faction_id
    global_position = new_position

func _ready() -> void:
    randomize()
    _create_pegs()
    add_control_ball()
    _create_gates()
    _create_labels()
    queue_redraw()

func _process(delta: float) -> void:
    if is_damaged:
        damage_anim_t += delta
        queue_redraw()
    elif count_label != null:
        count_label.scale = Vector2.ONE * (1.0 + 0.03 * sin(Time.get_ticks_msec() / 280.0))

func _create_pegs() -> void:
    pegs.clear()
    for row in range(4):
        for col in range(3):
            var x = 42.0 + col * 38.0 + (18.0 if row % 2 == 1 else 0.0)
            var y = 54.0 + row * 31.0
            pegs.append(Vector2(x, y))

func add_control_ball() -> bool:
    if is_damaged or is_locked:
        return false
    if balls.size() >= GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
        return false
    var ball = ControlBall.new()
    add_child(ball)
    balls.append(ball)
    _relaunch_control_ball(ball)
    ball_count_changed.emit(faction_id, balls.size())
    _update_label()
    return true

func get_ball_count() -> int:
    return balls.size()

func _create_gates() -> void:
    var half_width = chamber_size.x * 0.5
    var gate_size = Vector2(half_width, gate_height)
    var gate_y = chamber_size.y - gate_height * 0.5

    var x2_gate = Gate.new()
    x2_gate.setup("MULTIPLY_X2", "x2", gate_size)
    x2_gate.position = Vector2(half_width * 0.5, gate_y)
    add_child(x2_gate)

    var release_gate = Gate.new()
    release_gate.setup("RELEASE_R", "发射", gate_size)
    release_gate.position = Vector2(half_width * 1.5, gate_y)
    add_child(release_gate)

func _create_labels() -> void:
    name_label = Label.new()
    name_label.position = Vector2(-12, -56)
    name_label.size = Vector2(chamber_size.x + 24.0, 28.0)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 21)
    name_label.add_theme_color_override("font_color", Color.WHITE)
    name_label.add_theme_color_override("font_outline_color", Color.BLACK)
    name_label.add_theme_constant_override("outline_size", 4)
    add_child(name_label)

    state_label = Label.new()
    state_label.position = Vector2(4, 8)
    state_label.size = Vector2(chamber_size.x - 8.0, 22.0)
    state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    state_label.add_theme_font_size_override("font_size", 16)
    state_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
    state_label.add_theme_color_override("font_outline_color", Color.BLACK)
    state_label.add_theme_constant_override("outline_size", 3)
    add_child(state_label)

    count_label = Label.new()
    count_label.position = Vector2(0, 66)
    count_label.size = Vector2(chamber_size.x, 76)
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count_label.add_theme_font_size_override("font_size", 78)
    count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
    count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.60))
    count_label.add_theme_constant_override("outline_size", 4)
    add_child(count_label)

    ball_label = Label.new()
    ball_label.position = Vector2(0, 176)
    ball_label.size = Vector2(chamber_size.x, 22.0)
    ball_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ball_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ball_label.add_theme_font_size_override("font_size", 20)
    ball_label.add_theme_color_override("font_color", Color.WHITE)
    ball_label.add_theme_color_override("font_outline_color", Color.BLACK)
    ball_label.add_theme_constant_override("outline_size", 4)
    add_child(ball_label)

    _update_label()

func _relaunch_control_ball(ball) -> void:
    if ball == null:
        return
    var start_x = randf_range(30.0, chamber_size.x - 30.0)
    ball.setup(
        faction_id,
        Vector2(start_x, 20.0),
        Vector2(randf_range(-85.0, 85.0), randf_range(20.0, 88.0))
    )

func _physics_process(delta: float) -> void:
    if is_damaged or is_locked:
        return

    for ball in balls:
        if ball == null:
            continue

        ball.velocity.y += gravity * delta
        ball.position += ball.velocity * delta

        if ball.position.x < ball.radius:
            ball.position.x = ball.radius
            ball.velocity.x = abs(ball.velocity.x) * 0.92
        elif ball.position.x > chamber_size.x - ball.radius:
            ball.position.x = chamber_size.x - ball.radius
            ball.velocity.x = -abs(ball.velocity.x) * 0.92

        if ball.position.y < ball.radius:
            ball.position.y = ball.radius
            ball.velocity.y = abs(ball.velocity.y) * 0.9

        for peg in pegs:
            var offset = ball.position - peg
            var dist = offset.length()
            var min_dist = peg_radius + ball.radius
            if dist > 0.01 and dist < min_dist:
                var normal = offset / dist
                ball.position = peg + normal * min_dist
                ball.velocity = ball.velocity.bounce(normal) * 0.86
                ball.velocity += Vector2(randf_range(-25.0, 25.0), randf_range(-12.0, 12.0))

        if ball.position.y >= chamber_size.y - ball.radius:
            if ball.position.x < chamber_size.x * 0.5:
                _on_gate_entered("MULTIPLY_X2", ball)
            else:
                _on_gate_entered("RELEASE_R", ball)

func _on_gate_entered(gate_type: String, ball) -> void:
    if is_damaged or is_locked:
        return

    if gate_type == "MULTIPLY_X2":
        pending_count = clampi(pending_count * 2, 1, GameConfig.MAX_PENDING_COUNT)
        _update_label()
        _relaunch_control_ball(ball)
    elif gate_type == "RELEASE_R":
        is_locked = true
        _update_label()
        release_requested.emit(faction_id, pending_count, self)

func set_locked(locked: bool) -> void:
    if is_damaged:
        return
    is_locked = locked
    if not is_locked:
        pending_count = 1
        for ball in balls:
            _relaunch_control_ball(ball)
    _update_label()

func set_damaged() -> void:
    if is_damaged:
        return
    is_damaged = true
    pending_count = 0
    is_locked = false
    for ball in balls:
        if ball != null:
            ball.queue_free()
    balls.clear()
    ball_count_changed.emit(faction_id, 0)
    _update_label()
    queue_redraw()

func _update_label() -> void:
    if name_label == null:
        return

    name_label.text = GameConfig.faction_nickname(faction_id)

    if is_damaged:
        state_label.text = "控制台损坏"
        count_label.text = "×"
        ball_label.text = "球 0"
        name_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.48))
        return

    name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.82))
    count_label.text = str(pending_count)

    if is_locked:
        state_label.text = "锁定中"
    else:
        state_label.text = "待发射"

    ball_label.text = "球 %d" % balls.size()

func _draw() -> void:
    var base_color = Color(0.96, 0.96, 0.96, 0.96)
    var border_color = GameConfig.faction_color(faction_id)

    if is_damaged:
        base_color = Color(0.22, 0.22, 0.22, 0.95)
        border_color = Color(0.78, 0.12, 0.12)

    draw_rect(Rect2(Vector2.ZERO, chamber_size), base_color, true)
    draw_rect(Rect2(Vector2.ZERO, chamber_size), border_color, false, 3)
    draw_line(Vector2(chamber_size.x * 0.5, chamber_size.y - gate_height), Vector2(chamber_size.x * 0.5, chamber_size.y), Color.BLACK, 2)

    for peg in pegs:
        var peg_color = Color(0.18, 0.18, 0.18)
        if is_damaged:
            peg_color = Color(0.08, 0.08, 0.08)
        draw_circle(peg, peg_radius, peg_color)
        draw_circle(peg, peg_radius * 0.45, Color(0.9, 0.9, 0.9, 0.55))

    if is_locked and not is_damaged:
        draw_rect(Rect2(Vector2(6, 6), chamber_size - Vector2(12, 48)), Color(0.10, 0.16, 0.30, 0.08), true)

    if is_damaged:
        var pulse = 0.35 + 0.25 * sin(damage_anim_t * 8.0)
        draw_line(Vector2(12, 18), Vector2(chamber_size.x - 12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_line(Vector2(chamber_size.x - 12, 18), Vector2(12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_rect(Rect2(Vector2(5, 5), chamber_size - Vector2(10, 10)), Color(1.0, 0.0, 0.0, pulse), false, 4.0)
