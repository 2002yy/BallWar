extends RefCounted
class_name ChamberBallPhysics

const GATE_RESULT_NONE: String = "none"
const GATE_RESULT_LEFT: String = "left"
const GATE_RESULT_RIGHT: String = "right"
const GATE_RESULT_JAMMED_FLOOR: String = "jammed_floor"

static func step_ball(ball, delta: float, physics_input: Dictionary, stuck_state: Dictionary, stay_time: float) -> Dictionary:
	var chamber_size: Vector2 = physics_input.get("chamber_size", Vector2.ZERO)
	var pegs: Array = physics_input.get("pegs", [])
	var peg_collision_radii: Array = physics_input.get("peg_collision_radii", [])
	var gravity: float = float(physics_input.get("gravity", 0.0))
	var gate_x: float = float(physics_input.get("gate_x", chamber_size.x * 0.5))
	var jammed: bool = bool(physics_input.get("jammed", false))
	var gate_divider_width: float = float(physics_input.get("gate_divider_width", 0.0))
	var gate_height: float = float(physics_input.get("gate_height", 0.0))
	var gate_divider_rise: float = float(physics_input.get("gate_divider_rise", 0.0))

	var next_position: Vector2 = ball.position
	var next_velocity: Vector2 = ball.velocity
	next_velocity.y += gravity * delta
	next_position += next_velocity * delta

	var clamped: Dictionary = _clamp_ball_to_walls(next_position, next_velocity, ball.radius, chamber_size)
	next_position = clamped["position"]
	next_velocity = clamped["velocity"]

	for peg_index in range(pegs.size()):
		var peg: Vector2 = pegs[peg_index]
		var peg_collision_radius: float = float(peg_collision_radii[peg_index]) if peg_index < peg_collision_radii.size() else 0.0
		var collision: Dictionary = _resolve_peg_collision(next_position, next_velocity, ball.radius, peg, peg_collision_radius)
		next_position = collision["position"]
		next_velocity = collision["velocity"]

	clamped = _clamp_ball_to_walls(next_position, next_velocity, ball.radius, chamber_size)
	next_position = clamped["position"]
	next_velocity = clamped["velocity"]

	var divider_collision: Dictionary = _handle_gate_divider_collision(
		next_position,
		next_velocity,
		ball.radius,
		chamber_size,
		gate_x,
		gate_divider_width,
		gate_height,
		gate_divider_rise
	)
	next_position = divider_collision["position"]
	next_velocity = divider_collision["velocity"]

	clamped = _clamp_ball_to_walls(next_position, next_velocity, ball.radius, chamber_size)
	next_position = clamped["position"]
	next_velocity = clamped["velocity"]

	var updated_stuck_state: Dictionary = _update_stuck_state(next_position, next_velocity, ball.radius, chamber_size, stuck_state, delta, physics_input)
	next_position = updated_stuck_state["position"]
	next_velocity = updated_stuck_state["velocity"]

	var next_stay_time: float = clampf(stay_time + delta, 0.0, float(physics_input.get("control_ball_max_stay_time", stay_time + delta)))
	var relaunch_request: bool = next_stay_time >= float(physics_input.get("control_ball_max_stay_time", next_stay_time + 1.0))
	var gate_result: String = GATE_RESULT_NONE

	if not relaunch_request and next_position.y >= chamber_size.y - ball.radius:
		if jammed:
			var jammed_floor: Dictionary = _on_jammed_floor(next_position, next_velocity, ball.radius, chamber_size)
			next_position = jammed_floor["position"]
			next_velocity = jammed_floor["velocity"]
			gate_result = GATE_RESULT_JAMMED_FLOOR
		elif next_position.x < gate_x:
			gate_result = GATE_RESULT_LEFT
		else:
			gate_result = GATE_RESULT_RIGHT

	return {
		"gate_result": gate_result,
		"relaunch_request": relaunch_request,
		"ball_state_update": {
			"position": next_position,
			"velocity": next_velocity,
			"stuck_state": updated_stuck_state["state"],
			"stay_time": 0.0 if relaunch_request else next_stay_time,
		},
	}

static func _clamp_ball_to_walls(position: Vector2, velocity: Vector2, radius: float, chamber_size: Vector2) -> Dictionary:
	var next_position: Vector2 = position
	var next_velocity: Vector2 = velocity

	if next_position.x < radius:
		next_position.x = radius
		next_velocity.x = abs(next_velocity.x) * 0.92
	elif next_position.x > chamber_size.x - radius:
		next_position.x = chamber_size.x - radius
		next_velocity.x = -abs(next_velocity.x) * 0.92

	if next_position.y < radius:
		next_position.y = radius
		next_velocity.y = abs(next_velocity.y) * 0.90

	return {
		"position": next_position,
		"velocity": next_velocity,
	}

static func _resolve_peg_collision(position: Vector2, velocity: Vector2, radius: float, peg: Vector2, peg_collision_radius: float) -> Dictionary:
	var next_position: Vector2 = position
	var next_velocity: Vector2 = velocity
	var min_dist: float = peg_collision_radius + radius
	if absf(next_position.x - peg.x) >= min_dist or absf(next_position.y - peg.y) >= min_dist:
		return {
			"position": next_position,
			"velocity": next_velocity,
		}

	var offset: Vector2 = next_position - peg
	var dist_sq: float = offset.length_squared()
	var min_dist_sq: float = min_dist * min_dist
	if dist_sq > 0.0001 and dist_sq < min_dist_sq:
		var dist: float = sqrt(dist_sq)
		var normal: Vector2 = offset / dist
		next_position = peg + normal * min_dist
		next_velocity = next_velocity.bounce(normal) * 0.86
		next_velocity += Vector2(randf_range(-22.0, 22.0), randf_range(-10.0, 10.0))

	return {
		"position": next_position,
		"velocity": next_velocity,
	}

static func _handle_gate_divider_collision(position: Vector2, velocity: Vector2, radius: float, chamber_size: Vector2, gate_x: float, gate_divider_width: float, gate_height: float, gate_divider_rise: float) -> Dictionary:
	var next_position: Vector2 = position
	var next_velocity: Vector2 = velocity
	var half_width: float = gate_divider_width * 0.5
	var top_y: float = chamber_size.y - gate_height - gate_divider_rise
	var bottom_y: float = chamber_size.y

	if next_position.y + radius < top_y or next_position.y - radius > bottom_y:
		return {
			"position": next_position,
			"velocity": next_velocity,
		}

	if absf(next_position.x - gate_x) <= radius + half_width:
		if next_position.x < gate_x:
			next_position.x = gate_x - half_width - radius
			next_velocity.x = -abs(next_velocity.x) * 0.82 - 20.0
		else:
			next_position.x = gate_x + half_width + radius
			next_velocity.x = abs(next_velocity.x) * 0.82 + 20.0
		next_velocity.y *= 0.94

	return {
		"position": next_position,
		"velocity": next_velocity,
	}

static func _update_stuck_state(position: Vector2, velocity: Vector2, radius: float, chamber_size: Vector2, stuck_state: Dictionary, delta: float, physics_input: Dictionary) -> Dictionary:
	var state: Dictionary = stuck_state.duplicate(true)
	if state.is_empty():
		state = {
			"pos": position,
			"y": position.y,
			"time": 0.0,
		}

	var last_pos: Vector2 = state.get("pos", position)
	var last_y: float = float(state.get("y", position.y))
	var stuck_time: float = float(state.get("time", 0.0))
	var moved: float = position.distance_to(last_pos)
	var y_progress: float = position.y - last_y
	var near_wall: bool = position.x <= radius + float(physics_input.get("wall_stuck_margin", 0.0)) or position.x >= chamber_size.x - radius - float(physics_input.get("wall_stuck_margin", 0.0))

	var low_speed_stuck: bool = moved < float(physics_input.get("stuck_move_eps", 0.0)) and velocity.length() < float(physics_input.get("stuck_speed_eps", 0.0))
	var wall_jitter_stuck: bool = near_wall and y_progress < float(physics_input.get("wall_stuck_y_eps", 0.0)) and velocity.y < float(physics_input.get("stuck_speed_eps", 0.0)) * 1.8

	var next_position: Vector2 = position
	var next_velocity: Vector2 = velocity
	if low_speed_stuck or wall_jitter_stuck:
		stuck_time += delta
	else:
		stuck_time = 0.0
		last_pos = next_position
		last_y = next_position.y

	if stuck_time >= float(physics_input.get("stuck_time_limit", 0.0)):
		next_position.x = clampf(next_position.x + randf_range(-7.0, 7.0), radius, chamber_size.x - radius)
		next_velocity = Vector2(randf_range(-105.0, 105.0), randf_range(-80.0, -18.0))
		stuck_time = 0.0
		last_pos = next_position
		last_y = next_position.y

	state["pos"] = last_pos
	state["y"] = last_y
	state["time"] = stuck_time
	return {
		"position": next_position,
		"velocity": next_velocity,
		"state": state,
	}

static func _on_jammed_floor(position: Vector2, velocity: Vector2, radius: float, chamber_size: Vector2) -> Dictionary:
	var next_position: Vector2 = position
	var next_velocity: Vector2 = velocity
	next_position.y = chamber_size.y - radius - 2.0
	next_velocity.y = -abs(next_velocity.y) * 0.78 - 36.0
	next_velocity.x += randf_range(-36.0, 36.0)
	return {
		"position": next_position,
		"velocity": next_velocity,
	}
