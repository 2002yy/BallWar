extends Node2D
class_name ControlChamber

signal release_requested(faction_id, bullet_count, chamber)
signal ball_count_changed(faction_id, count)

var faction_id: int = GameConfig.Faction.BLUE
var pending_count: int = 1
var locked_remaining: int = 0
var chamber_size: Vector2 = Vector2(168, 214)
var balls: Array = []
var gravity: float = 420.0
var pegs: Array = []
var peg_radius: float = 7.2
var name_label
var count_label
var ball_label
var is_damaged: bool = false
var is_locked: bool = false
var damage_anim_t: float = 0.0
var gate_height: float = 34.0

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

func _create_pegs() -> void:
    pegs.clear()
    var row_counts: Array = [3, 4, 5, 4, 3]
    var top_y: float = 38.0
    var row_gap: float = 31.0
    var margin_x: float = 24.0
    var usable_width: float = chamber_size.x - margin_x * 2.0
    for row_index in range(row_counts.size()):
        var count: int = row_counts[row_index]
        var y: float = top_y + row_index * row_gap
        if count == 1:
            pegs.append(Vector2(chamber_size.x * 0.5, y))
            continue
        var step: float = usable_width / float(count - 1)
        for i in range(count):
            pegs.append(Vector2(margin_x + step * i, y))

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

func _create_labels() -> void:
    name_label = Label.new()
    name_label.position = Vector2(-10, -56)
    name_label.size = Vector2(chamber_size.x + 20.0, 28.0)
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", 22)
    name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.72))
    name_label.add_theme_color_override("font_outline_color", Color.BLACK)
    name_label.add_theme_constant_override("outline_size", 4)
    add_child(name_label)

    count_label = Label.new()
    count_label.position = Vector2(0, 74)
    count_label.size = Vector2(chamber_size.x, 82)
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count_label.add_theme_font_size_override("font_size", 80)
    count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.28))
    count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.60))
    count_label.add_theme_constant_override("outline_size", 4)
    add_child(count_label)

    ball_label = Label.new()
    ball_label.position = Vector2(0, 183)
    ball_label.size = Vector2(chamber_size.x, 24)
    ball_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ball_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    ball_label.add_theme_font_size_override("font_size", 20)
    ball_label.add_theme_color_override("font_color", Color.WHITE)
    ball_label.add_theme_color_override("font_outline_color", Color.BLACK)
    ball_label.add_theme_constant_override("outline_size", 3)
    add_child(ball_label)

    _update_label()

func _relaunch_control_ball(ball) -> void:
    if ball == null:
        return
    var start_x: float = randf_range(34.0, chamber_size.x - 34.0)
    ball.setup(faction_id, Vector2(start_x, 18.0), Vector2(randf_range(-60.0, 60.0), randf_range(24.0, 82.0)))

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
            ball.velocity.y = abs(ball.velocity.y) * 0.90

        for peg in pegs:
            var offset: Vector2 = ball.position - peg
            var dist: float = offset.length()
            var min_dist: float = peg_radius + ball.radius
            if dist > 0.01 and dist < min_dist:
                var normal: Vector2 = offset / dist
                ball.position = peg + normal * min_dist
                ball.velocity = ball.velocity.bounce(normal) * 0.86
                ball.velocity += Vector2(randf_range(-22.0, 22.0), randf_range(-10.0, 10.0))

        if ball.position.y >= chamber_size.y - ball.radius:
            if ball.position.x < chamber_size.x * 0.5:
                _on_left_gate(ball)
            else:
                _on_right_gate(ball)

func _on_left_gate(ball) -> void:
    pending_count = clampi(pending_count * 2, 1, GameConfig.MAX_PENDING_COUNT)
    _update_label()
    _relaunch_control_ball(ball)

func _on_right_gate(ball) -> void:
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
        for ball in balls:
            _relaunch_control_ball(ball)
    _update_label()

func set_damaged() -> void:
    if is_damaged:
        return
    is_damaged = true
    pending_count = 0
    locked_remaining = 0
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

func _draw() -> void:
    var base_color: Color = Color(0.96, 0.96, 0.96, 0.96)
    var border_color: Color = GameConfig.faction_color(faction_id)
    if is_damaged:
        base_color = Color(0.22, 0.22, 0.22, 0.95)
        border_color = Color(0.78, 0.12, 0.12)

    draw_rect(Rect2(Vector2.ZERO, chamber_size), base_color, true)
    draw_rect(Rect2(Vector2.ZERO, chamber_size), border_color, false, 3)

    for peg in pegs:
        var peg_color: Color = Color(0.20, 0.20, 0.20)
        if is_damaged:
            peg_color = Color(0.08, 0.08, 0.08)
        draw_circle(peg, peg_radius, peg_color)
        draw_circle(peg, peg_radius * 0.45, Color(0.9, 0.9, 0.9, 0.55))

    var left_rect: Rect2 = Rect2(Vector2(0, chamber_size.y - gate_height), Vector2(chamber_size.x * 0.5, gate_height))
    var right_rect: Rect2 = Rect2(Vector2(chamber_size.x * 0.5, chamber_size.y - gate_height), Vector2(chamber_size.x * 0.5, gate_height))
    var left_color: Color = Color(0.78, 0.95, 0.23)
    var right_color: Color = Color(1.0, 0.67, 0.16)

    if is_locked or is_damaged:
        left_color = Color(0.55, 0.55, 0.55)
        right_color = Color(0.45, 0.45, 0.45)

    draw_rect(left_rect, left_color, true)
    draw_rect(right_rect, right_color, true)
    draw_rect(Rect2(Vector2.ZERO, chamber_size), Color.BLACK, false, 2)
    draw_line(Vector2(chamber_size.x * 0.5, chamber_size.y - gate_height), Vector2(chamber_size.x * 0.5, chamber_size.y), Color.BLACK, 2)

    var font = ThemeDB.fallback_font
    draw_string(font, Vector2(28, chamber_size.y - 11), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.BLACK)
    draw_string(font, Vector2(chamber_size.x * 0.5 + 22, chamber_size.y - 11), "发射", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.BLACK)

    if is_locked and not is_damaged:
        draw_rect(Rect2(Vector2(0, chamber_size.y - gate_height), Vector2(chamber_size.x, gate_height)), Color(0.1, 0.1, 0.1, 0.28), true)

    if is_damaged:
        var pulse: float = 0.35 + 0.25 * sin(damage_anim_t * 8.0)
        draw_line(Vector2(12, 18), Vector2(chamber_size.x - 12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_line(Vector2(chamber_size.x - 12, 18), Vector2(12, chamber_size.y - 48), Color(1.0, 0.0, 0.0, 0.85), 5.0)
        draw_rect(Rect2(Vector2(5, 5), chamber_size - Vector2(10, 10)), Color(1.0, 0.0, 0.0, pulse), false, 4.0)
