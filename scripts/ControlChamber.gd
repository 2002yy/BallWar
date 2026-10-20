extends Node2D
class_name ControlChamber

const ChamberBallPhysicsScript = preload("res://scripts/ChamberBallPhysics.gd")
const ChamberDrawModelScript = preload("res://scripts/ChamberDrawModel.gd")
const ChamberRendererScript = preload("res://scripts/ChamberRenderer.gd")
const ChamberSaveAdapterScript = preload("res://scripts/ChamberSaveAdapter.gd")

signal release_requested(faction_id, bullet_count, chamber)
signal ball_count_changed(faction_id, count)

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
const MAX_RESTORE_CONTROL_BALLS: int = 8

var faction_id: int = GameConfig.Faction.BLUE
var pending_count: int = 1
var locked_remaining: int = 0
var chamber_state: ChamberState = ChamberState.new()

func _sync_shadow_fields() -> void:
	pending_count = chamber_state.pending_count
	is_locked = chamber_state.is_locked
	locked_remaining = chamber_state.locked_remaining
	jammed_time_left = chamber_state.jammed_time_left
	queued_round_modifiers = chamber_state.queued_round_modifiers

func _sync_state_from_shadow() -> void:
	chamber_state.pending_count = pending_count
	chamber_state.is_locked = is_locked
	chamber_state.locked_remaining = locked_remaining
	chamber_state.jammed_time_left = jammed_time_left

var chamber_size: Vector2 = Vector2(
	PEG_RADIUS + PEG_SPACING_X * 3.0,
	CHAMBER_HEIGHT
)

var balls: Array = []
var release_ball = null
var linked_turret = null
var gravity: float = 420.0
var pegs: Array = []
var peg_collision_radii: Array = []
var peg_radius: float = PEG_RADIUS
var stuck_states: Dictionary = {}
var ball_stay_times: Dictionary = {}
var jammed_time_left: float = 0.0
var queued_round_modifiers: Array = []

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
const LOCKED_REDRAW_INTERVAL: float = 0.080
const DAMAGED_REDRAW_INTERVAL: float = 0.080

func setup(new_faction_id: int, new_position: Vector2) -> void:
	faction_id = new_faction_id
	global_position = new_position

func set_linked_turret(turret) -> void:
	linked_turret = turret

func _ready() -> void:
	_create_pegs()
	_create_labels()
	_add_initial_control_ball_silent()
	_update_label()
	_force_visual_redraw()

func _process(delta: float) -> void:
	status_anim_t += delta

	if chamber_state.tick(delta):
		jammed_time_left = chamber_state.jammed_time_left
		if not chamber_state.is_jammed():
			_update_label()
			_force_visual_redraw()

	if is_damaged:
		damage_anim_t += delta

	if count_label != null:
		var pulse_amp: float = 0.06
		if jammed_time_left > 0.0:
			pulse_amp = 0.14
		elif is_locked:
			pulse_amp = 0.10
		elif is_damaged:
			pulse_amp = 0.04
		count_label.modulate = Color(1, 1, 1, 0.26 + pulse_amp * absf(sin(Time.get_ticks_msec() / 220.0)))

	if ball_label != null:
		if is_damaged:
			ball_label.modulate = Color(1.0, 0.66, 0.66, 0.95)
		elif jammed_time_left > 0.0:
			var jam_a: float = 0.80 + 0.20 * sin(status_anim_t * 8.0)
			ball_label.modulate = Color(1.0, 0.72, 0.40, jam_a)
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
	elif jammed_time_left > 0.0 or is_locked:
		visual_redraw_timer = LOCKED_REDRAW_INTERVAL
	else:
		visual_redraw_timer = NORMAL_REDRAW_INTERVAL
	queue_redraw()

func _create_pegs() -> void:
	pegs.clear()
	peg_collision_radii.clear()

	var row_counts: Array = [3, 4, 3, 4, 3, 4]
	var side_center_x: float = PEG_RADIUS * FOUR_ROW_EMBED_RATIO
	var centered_three_start_x: float = (chamber_size.x - PEG_SPACING_X * 2.0) * 0.5

	for row_index in range(row_counts.size()):
		var count: int = row_counts[row_index]
		var y: float = TOP_Y + float(row_index) * PEG_SPACING_Y
		var start_x: float = side_center_x if count == 4 else centered_three_start_x

		for i in range(count):
			var peg_position: Vector2 = Vector2(start_x + float(i) * PEG_SPACING_X, y)
			pegs.append(peg_position)
			peg_collision_radii.append(_effective_peg_radius(peg_position))

func add_control_ball() -> bool:
	return _add_control_ball_internal(true)

func _add_initial_control_ball_silent() -> void:
	_add_control_ball_internal(false)

func _add_control_ball_internal(should_emit_ball_count_signal: bool) -> bool:
	if is_damaged or is_locked:
		return false
	if balls.size() >= GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
		return false

	var ball = ControlBall.new()
	ball.radius = CONTROL_BALL_RADIUS
	add_child(ball)
	balls.append(ball)
	_relaunch_control_ball(ball)
	if should_emit_ball_count_signal:
		ball_count_changed.emit(faction_id, balls.size())
		_update_label()
	return true

func get_ball_count() -> int:
	return balls.size()

func apply_pending_bonus(amount: int) -> void:
	if is_damaged:
		return
	_sync_state_from_shadow()
	chamber_state.apply_pending_bonus(amount, GameConfig.get_max_pending_count())
	pending_count = chamber_state.pending_count
	_update_label()
	_force_visual_redraw()

func apply_pending_multiplier(multiplier: int) -> void:
	if is_damaged:
		return
	_sync_state_from_shadow()
	chamber_state.apply_pending_multiplier(multiplier, GameConfig.get_max_pending_count())
	pending_count = chamber_state.pending_count
	_update_label()
	_force_visual_redraw()

func add_control_ball_from_event() -> void:
	if is_damaged:
		return
	if balls.size() < GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
		add_control_ball()
	else:
		apply_pending_bonus(10)

func apply_jammed(duration: float) -> void:
	if is_damaged:
		return
	chamber_state.apply_jam(duration)
	jammed_time_left = chamber_state.jammed_time_left
	_update_label()
	_force_visual_redraw()

func get_jammed_time_left() -> float:
	return jammed_time_left

func is_jammed() -> bool:
	return jammed_time_left > 0.0

func get_pending_count() -> int:
	return pending_count

func get_queued_modifier_count() -> int:
	return chamber_state.queued_round_modifiers.size()

func set_jammed_time_left(value: float) -> void:
	jammed_time_left = maxf(0.0, value)
	_update_label()
	_force_visual_redraw()

func queue_next_round_modifier(modifier: Dictionary) -> void:
	chamber_state.queue_next_round_modifier(modifier)
	queued_round_modifiers = chamber_state.queued_round_modifiers
	_update_label()

func get_queued_round_modifiers() -> Array:
	return chamber_state.queued_round_modifiers.duplicate(true)

func collect_state() -> Dictionary:
	return ChamberSaveAdapterScript.collect_state(self)

func set_queued_round_modifiers(modifiers: Array) -> void:
	chamber_state.queued_round_modifiers.clear()
	for modifier in modifiers:
		if modifier is Dictionary:
			chamber_state.queued_round_modifiers.append((modifier as Dictionary).duplicate(true))
	queued_round_modifiers = chamber_state.queued_round_modifiers
	_update_label()

func cancel_current_burst_with_refund(ratio: float) -> void:
	if is_damaged:
		return
	_sync_state_from_shadow()

	var remaining: int = 0
	if linked_turret != null and is_instance_valid(linked_turret) and linked_turret.has_method("cancel_burst"):
		remaining = int(linked_turret.cancel_burst())

	if not chamber_state.is_locked and remaining <= 0:
		return

	chamber_state.unlock(maxi(1, floori(float(remaining) * ratio)))
	pending_count = chamber_state.pending_count
	is_locked = false
	locked_remaining = 0
	if release_ball != null and is_instance_valid(release_ball):
		_relaunch_control_ball(release_ball)
	release_ball = null
	_update_label()
	_force_visual_redraw()

func _apply_queued_round_modifiers() -> void:
	var had_modifiers: bool = not chamber_state.queued_round_modifiers.is_empty()
	if not had_modifiers:
		return
	chamber_state.apply_queued_modifiers(GameConfig.get_max_pending_count())
	pending_count = chamber_state.pending_count
	queued_round_modifiers = chamber_state.queued_round_modifiers
	if had_modifiers:
		_update_label()

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
	count_label.scale = Vector2.ONE
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

func _is_side_embedded_peg(peg: Vector2) -> bool:
	return peg.x <= PEG_RADIUS * 0.75 or peg.x >= chamber_size.x - PEG_RADIUS * 0.75

func _effective_peg_radius(peg: Vector2) -> float:
	if _is_side_embedded_peg(peg):
		return peg_radius * 0.50
	return peg_radius

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

func _clear_control_balls() -> void:
	for ball in balls:
		if ball != null and is_instance_valid(ball):
			ball.queue_free()
	balls.clear()
	stuck_states.clear()
	ball_stay_times.clear()
	release_ball = null

func restore_from_state(state: Dictionary) -> void:
	_clear_control_balls()
	is_damaged = false
	damage_anim_t = 0.0

	var restored_state: Dictionary = ChamberSaveAdapterScript.restore_state(state, {
		"chamber_size": chamber_size,
		"default_ball_radius": CONTROL_BALL_RADIUS,
		"max_restore_control_balls": MAX_RESTORE_CONTROL_BALLS,
		"max_control_balls": GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER,
		"max_pending_count": GameConfig.get_max_pending_count(),
	})

	chamber_state.reset(1)
	chamber_state.pending_count = int(restored_state.get("chamber_pending_count", 1))
	chamber_state.locked_remaining = int(restored_state.get("chamber_locked_remaining", 0))
	chamber_state.jammed_time_left = float(restored_state.get("chamber_jammed_time_left", 0.0))
	chamber_state.queued_round_modifiers.clear()
	for modifier in restored_state.get("queued_round_modifiers", []):
		if modifier is Dictionary:
			chamber_state.queued_round_modifiers.append((modifier as Dictionary).duplicate(true))

	if bool(restored_state.get("chamber_is_damaged", false)):
		set_damaged()
		return

	_sync_shadow_fields()

	var saved_balls = restored_state.get("control_balls", [])
	if saved_balls is Array and saved_balls.size() > 0:
		for i in range(saved_balls.size()):
			var ball_state = saved_balls[i]
			if not (ball_state is Dictionary):
				continue
			var ball = ControlBall.new()
			ball.radius = float(ball_state.get("radius", CONTROL_BALL_RADIUS))
			var pos: Vector2 = ball_state.get("position", Vector2(chamber_size.x * 0.5, 18.0))
			var vel: Vector2 = ball_state.get("velocity", Vector2.ZERO)
			ball.setup(faction_id, pos, vel)
			add_child(ball)
			balls.append(ball)
			_reset_stuck_state(ball)
			set_ball_stay_time(ball, float(ball_state.get("stay_time", 0.0)))
	else:
		var ball_count: int = int(restored_state.get("chamber_ball_count", 0))
		for i in range(ball_count):
			add_control_ball()

	var release_index: int = int(restored_state.get("chamber_release_ball_index", -1))
	if release_index >= 0 and release_index < balls.size():
		release_ball = balls[release_index]

	chamber_state.is_locked = bool(restored_state.get("chamber_is_locked", false))
	_sync_shadow_fields()
	ball_count_changed.emit(faction_id, balls.size())
	_update_label()
	_force_visual_redraw()

func _physics_process(delta: float) -> void:
	if is_damaged or is_locked:
		return

	var x2_width: float = _current_x2_width()
	var physics_input: Dictionary = {
		"gravity": gravity,
		"pegs": pegs,
		"peg_collision_radii": peg_collision_radii,
		"chamber_size": chamber_size,
		"gate_x": x2_width,
		"gate_divider_width": GATE_DIVIDER_WIDTH,
		"gate_height": gate_height,
		"gate_divider_rise": GATE_DIVIDER_RISE,
		"jammed": jammed_time_left > 0.0,
		"stuck_move_eps": STUCK_MOVE_EPS,
		"stuck_speed_eps": STUCK_SPEED_EPS,
		"stuck_time_limit": STUCK_TIME_LIMIT,
		"wall_stuck_margin": WALL_STUCK_MARGIN,
		"wall_stuck_y_eps": WALL_STUCK_Y_EPS,
		"control_ball_max_stay_time": CONTROL_BALL_MAX_STAY_TIME,
	}

	for ball in balls:
		if ball == null:
			continue
		var ball_id: int = ball.get_instance_id()
		var step_result: Dictionary = ChamberBallPhysicsScript.step_ball(
			ball,
			delta,
			physics_input,
			stuck_states.get(ball_id, {}),
			float(ball_stay_times.get(ball_id, 0.0))
		)
		var ball_state_update: Dictionary = step_result.get("ball_state_update", {})
		ball.position = ball_state_update.get("position", ball.position)
		ball.velocity = ball_state_update.get("velocity", ball.velocity)
		stuck_states[ball_id] = ball_state_update.get("stuck_state", stuck_states.get(ball_id, {}))
		ball_stay_times[ball_id] = float(ball_state_update.get("stay_time", ball_stay_times.get(ball_id, 0.0)))

		if bool(step_result.get("relaunch_request", false)):
			_relaunch_control_ball(ball)
			continue

		var gate_result: String = str(step_result.get("gate_result", ChamberBallPhysicsScript.GATE_RESULT_NONE))
		match gate_result:
			ChamberBallPhysicsScript.GATE_RESULT_LEFT:
				_on_left_gate(ball)
			ChamberBallPhysicsScript.GATE_RESULT_RIGHT:
				_on_right_gate(ball)
				break
			_:
				pass

func _on_left_gate(ball) -> void:
	pending_count = clampi(pending_count * GameConfig.get_gate_multiplier(), 1, GameConfig.get_max_pending_count())
	_update_label()
	_relaunch_control_ball(ball)

func _on_right_gate(ball) -> void:
	if is_locked or jammed_time_left > 0.0:
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

	if locked:
		chamber_state.is_locked = true
	else:
		chamber_state.unlock(1)
		chamber_state.apply_queued_modifiers(GameConfig.get_max_pending_count())

	is_locked = chamber_state.is_locked
	pending_count = chamber_state.pending_count
	locked_remaining = chamber_state.locked_remaining

	if not is_locked:
		if release_ball != null and is_instance_valid(release_ball):
			_relaunch_control_ball(release_ball)
		release_ball = null

	_update_label()
	_force_visual_redraw()

func set_damaged() -> void:
	if is_damaged:
		return
	is_damaged = true
	chamber_state.reset(0)
	_sync_shadow_fields()
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
		count_label.text = "X"
		ball_label.text = "\u4ed3\u5ba4\u635f\u574f"
		return

	if jammed_time_left > 0.0:
		count_label.text = str(pending_count)
		ball_label.text = "\u5361\u963b %ds" % ceili(jammed_time_left)
		return

	if is_locked:
		count_label.text = str(locked_remaining)
		ball_label.text = "\u9501\u5b9a\u4e2d"
	else:
		count_label.text = str(pending_count)
		ball_label.text = "\u5f85\u547d \u00b7 %d\u7403" % balls.size()

func set_game_elapsed_time(value: float) -> void:
	game_elapsed_time = maxf(0.0, value)

func _current_progress() -> float:
	return clampf(game_elapsed_time / GATE_RAMP_SECONDS, 0.0, 1.0)

func _current_release_ratio() -> float:
	var progress: float = _current_progress()
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	return lerpf(GATE_START_RELEASE_RATIO, GATE_END_RELEASE_RATIO, eased)

func _current_x2_width() -> float:
	if is_locked or is_damaged or jammed_time_left > 0.0:
		return chamber_size.x * 0.5
	var release_ratio: float = clampf(_current_release_ratio(), GATE_MIN_RATIO, 1.0 - GATE_MIN_RATIO)
	var x2_ratio: float = 1.0 - release_ratio
	return chamber_size.x * x2_ratio

func _build_draw_snapshot() -> Dictionary:
	return ChamberDrawModelScript.build_snapshot({
		"faction_color": GameConfig.faction_color(faction_id),
		"chamber_size": chamber_size,
		"gate_height": gate_height,
		"peg_radius": peg_radius,
		"pegs": pegs,
		"is_damaged": is_damaged,
		"is_locked": is_locked,
		"jammed_time_left": jammed_time_left,
		"status_anim_t": status_anim_t,
		"game_elapsed_time": game_elapsed_time,
		"gate_multiplier": GameConfig.get_gate_multiplier(),
		"scale_x": scale.x,
		"gate_ramp_seconds": GATE_RAMP_SECONDS,
		"gate_start_release_ratio": GATE_START_RELEASE_RATIO,
		"gate_end_release_ratio": GATE_END_RELEASE_RATIO,
		"gate_min_ratio": GATE_MIN_RATIO,
	})

func _draw() -> void:
	ChamberRendererScript.draw(self, _build_draw_snapshot())
