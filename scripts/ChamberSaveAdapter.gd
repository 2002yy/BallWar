extends RefCounted
class_name ChamberSaveAdapter

static func default_state() -> Dictionary:
	return {
		"chamber_pending_count": 1,
		"chamber_locked_remaining": 0,
		"chamber_is_locked": false,
		"chamber_is_damaged": false,
		"chamber_ball_count": 0,
		"chamber_release_ball_index": -1,
		"chamber_jammed_time_left": 0.0,
		"queued_round_modifiers": [],
		"control_balls": [],
	}

static func collect_state(chamber) -> Dictionary:
	var state: Dictionary = default_state()
	if chamber == null or not is_instance_valid(chamber):
		return state

	state["chamber_pending_count"] = chamber.pending_count
	state["chamber_locked_remaining"] = chamber.locked_remaining
	state["chamber_is_locked"] = chamber.is_locked
	state["chamber_is_damaged"] = chamber.is_damaged
	state["chamber_ball_count"] = chamber.get_ball_count()
	state["chamber_release_ball_index"] = SaveGameCodec.get_release_ball_index(chamber)
	state["chamber_jammed_time_left"] = chamber.get_jammed_time_left()
	state["queued_round_modifiers"] = chamber.get_queued_round_modifiers()
	state["control_balls"] = SaveGameCodec.collect_control_ball_states(chamber)
	return state

static func restore_state(state: Dictionary, context: Dictionary) -> Dictionary:
	var restored: Dictionary = default_state()
	var chamber_size: Vector2 = context.get("chamber_size", Vector2.ZERO)
	var default_ball_radius: float = float(context.get("default_ball_radius", 5.4))
	var max_restore_control_balls: int = int(context.get("max_restore_control_balls", SaveGameCodec.MAX_RESTORE_CONTROL_BALLS))
	var max_control_balls: int = int(context.get("max_control_balls", GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER))
	var max_pending_count: int = int(context.get("max_pending_count", GameConfig.get_max_pending_count()))

	restored["chamber_pending_count"] = clampi(int(state.get("chamber_pending_count", 1)), 1, max_pending_count)
	restored["chamber_locked_remaining"] = clampi(int(state.get("chamber_locked_remaining", 0)), 0, max_pending_count)
	restored["chamber_jammed_time_left"] = maxf(0.0, float(state.get("chamber_jammed_time_left", 0.0)))
	restored["chamber_is_locked"] = bool(state.get("chamber_is_locked", false))
	restored["chamber_is_damaged"] = bool(state.get("chamber_is_damaged", false))
	restored["queued_round_modifiers"] = _sanitize_queued_round_modifiers(state.get("queued_round_modifiers", []))

	var control_balls: Array = []
	var raw_control_balls = state.get("control_balls", [])
	if raw_control_balls is Array:
		for i in range(mini(raw_control_balls.size(), max_restore_control_balls)):
			var ball_state = raw_control_balls[i]
			if not (ball_state is Dictionary):
				continue
			control_balls.append(_sanitize_control_ball_state(ball_state as Dictionary, chamber_size, default_ball_radius))
	restored["control_balls"] = control_balls

	restored["chamber_ball_count"] = clampi(int(state.get("chamber_ball_count", 0)), 0, max_control_balls)
	var restored_ball_count: int = control_balls.size() if not control_balls.is_empty() else int(restored["chamber_ball_count"])
	var release_index: int = int(state.get("chamber_release_ball_index", -1))
	restored["chamber_release_ball_index"] = release_index if release_index >= 0 and release_index < restored_ball_count else -1
	return restored

static func _sanitize_queued_round_modifiers(modifiers) -> Array:
	var sanitized: Array = []
	if not (modifiers is Array):
		return sanitized
	for modifier in modifiers:
		if modifier is Dictionary:
			sanitized.append((modifier as Dictionary).duplicate(true))
	return sanitized

static func _sanitize_control_ball_state(ball_state: Dictionary, chamber_size: Vector2, default_ball_radius: float) -> Dictionary:
	var radius: float = clampf(float(ball_state.get("radius", default_ball_radius)), 3.0, 12.0)
	var pos: Vector2 = SaveGameCodec.arr_to_vec2(
		ball_state.get("position", [chamber_size.x * 0.5, 18.0]),
		Vector2(chamber_size.x * 0.5, 18.0)
	)
	pos.x = clampf(pos.x, radius, chamber_size.x - radius)
	pos.y = clampf(pos.y, radius, chamber_size.y - radius)
	var vel: Vector2 = SaveGameCodec.arr_to_vec2(ball_state.get("velocity", [0, 0]), Vector2.ZERO).limit_length(520.0)
	return {
		"radius": radius,
		"position": pos,
		"velocity": vel,
		"stay_time": clampf(float(ball_state.get("stay_time", 0.0)), 0.0, ControlChamber.CONTROL_BALL_MAX_STAY_TIME),
	}
