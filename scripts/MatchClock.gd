extends RefCounted
class_name MatchClock

signal step_completed

# The engine schedules more callbacks in debug sessions. The simulation
# still advances by this same amount in each callback.
const TICKS_PER_SECOND: int = 60
const STEP_SECONDS: float = 1.0 / TICKS_PER_SECOND
const SPEEDS: Array[int] = [1, 2, 5, 10, 20]

var speed: int = 1
var ticks: int = 0
var _tree: SceneTree
var _normal_steps: int
var _step_open: bool = false


func _init(tree: SceneTree) -> void:
	_tree = tree
	_normal_steps = Engine.max_physics_steps_per_frame


func set_speed(requested_speed: int) -> void:
	if requested_speed not in SPEEDS:
		return
	speed = requested_speed
	Engine.physics_ticks_per_second = TICKS_PER_SECOND * speed
	Engine.time_scale = float(speed)
	Engine.max_physics_steps_per_frame = maxi(_normal_steps, speed * 2)


func request_step() -> void:
	if _tree.paused and not _tree.physics_frame.is_connected(_step_at_boundary):
		_tree.physics_frame.connect(_step_at_boundary)


func cancel_step() -> void:
	if _tree.physics_frame.is_connected(_step_at_boundary):
		_tree.physics_frame.disconnect(_step_at_boundary)
	if _step_open:
		_tree.paused = true
		_step_open = false


func reset() -> void:
	cancel_step()
	set_speed(1)
	ticks = 0


func _step_at_boundary() -> void:
	# physics_frame is emitted before gameplay nodes tick, even while paused.
	if _step_open:
		cancel_step()
		step_completed.emit()
	else:
		_step_open = true
		_tree.paused = false
