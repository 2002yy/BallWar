extends RefCounted
class_name BulletRestoreQueue

# Owns only the transient backlog/cursor. Main owns runtime spawning and lifecycle.
var _states: Array = []
var _next_index: int = 0

func reset() -> void:
	_states.clear()
	_next_index = 0

func load_states(states, restore_limit: int) -> void:
	reset()
	if not (states is Array):
		return
	var restore_count: int = mini(states.size(), restore_limit)
	for i in range(restore_count):
		if states[i] is Dictionary:
			_states.append(states[i])

func pending_count() -> int:
	return _states.size() - _next_index

func take_batch(per_frame: int) -> Array:
	var batch: Array = []
	var end_index: int = mini(_next_index + per_frame, _states.size())
	for i in range(_next_index, end_index):
		batch.append(_states[i])
	_next_index = end_index
	if _next_index >= _states.size():
		reset()
	return batch
