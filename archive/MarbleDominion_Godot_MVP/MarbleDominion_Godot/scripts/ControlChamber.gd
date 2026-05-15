extends Node2D
class_name ControlChamber

signal release_requested(faction_id: int, bullet_count: int)

var faction_id := 0
var pending_count := 1
var chamber_size := Vector2(150, 190)
var ball: ControlBall
var gravity := 420.0
var pegs: Array[Vector2] = []
var peg_radius := 8.0
var info_label: Label

func setup(fid: int, pos: Vector2) -> void:
	faction_id = fid; global_position = pos

func _ready() -> void:
	randomize(); _create_pegs(); _create_ball(); _create_gates(); _create_label(); queue_redraw()

func _create_pegs() -> void:
	pegs.clear()
	for row in range(4):
		for col in range(3):
			var x := 38.0 + col * 36.0 + (18.0 if row % 2 == 1 else 0.0)
			var y := 46.0 + row * 28.0
			pegs.append(Vector2(x, y))

func _create_ball() -> void:
	ball = ControlBall.new(); add_child(ball); relaunch_control_ball()

func _create_gates() -> void:
	var x2 := Gate.new(); x2.setup("MULTIPLY_X2", "x2", Vector2(54,28)); x2.position = Vector2(chamber_size.x * 0.28, chamber_size.y - 18); x2.gate_entered.connect(_on_gate_entered); add_child(x2)
	var r := Gate.new(); r.setup("RELEASE_R", "R", Vector2(54,28)); r.position = Vector2(chamber_size.x * 0.72, chamber_size.y - 18); r.gate_entered.connect(_on_gate_entered); add_child(r)

func _create_label() -> void:
	info_label = Label.new(); info_label.position = Vector2(4, -24); info_label.add_theme_font_size_override("font_size", 12); add_child(info_label); _update_label()

func relaunch_control_ball() -> void:
	if ball == null: return
	ball.setup(faction_id, Vector2(randf_range(28, chamber_size.x - 28), 18), Vector2(randf_range(-80,80), randf_range(20,80)))

func _physics_process(delta: float) -> void:
	if ball == null: return
	ball.velocity.y += gravity * delta
	ball.position += ball.velocity * delta
	if ball.position.x < ball.radius:
		ball.position.x = ball.radius; ball.velocity.x = abs(ball.velocity.x) * 0.92
	elif ball.position.x > chamber_size.x - ball.radius:
		ball.position.x = chamber_size.x - ball.radius; ball.velocity.x = -abs(ball.velocity.x) * 0.92
	if ball.position.y < ball.radius:
		ball.position.y = ball.radius; ball.velocity.y = abs(ball.velocity.y) * 0.9
	for peg in pegs:
		var off := ball.position - peg
		var dist := off.length()
		var min_dist := peg_radius + ball.radius
		if dist > 0.01 and dist < min_dist:
			var n := off / dist
			ball.position = peg + n * min_dist
			ball.velocity = ball.velocity.bounce(n) * 0.86 + Vector2(randf_range(-25,25), randf_range(-12,12))
	if ball.position.y > chamber_size.y + 30:
		relaunch_control_ball()

func _on_gate_entered(gate_type: String) -> void:
	if gate_type == "MULTIPLY_X2":
		pending_count = clampi(pending_count * 2, 1, GameConfig.MAX_PENDING_COUNT)
		_update_label(); relaunch_control_ball()
	elif gate_type == "RELEASE_R":
		release_requested.emit(faction_id, pending_count)
		pending_count = 1
		_update_label(); relaunch_control_ball()

func _update_label() -> void:
	if info_label: info_label.text = "%s pending: %d" % [GameConfig.faction_name(faction_id), pending_count]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, chamber_size), Color(0.96,0.96,0.96,0.95), true)
	draw_rect(Rect2(Vector2.ZERO, chamber_size), GameConfig.faction_color(faction_id), false, 3)
	for peg in pegs:
		draw_circle(peg, peg_radius, Color(0.18,0.18,0.18))
		draw_circle(peg, peg_radius * 0.45, Color(0.9,0.9,0.9))
