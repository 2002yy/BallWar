extends RefCounted
class_name ChamberState

var pending_count: int = 1
var is_locked: bool = false
var locked_remaining: int = 0
var jammed_time_left: float = 0.0
var queued_round_modifiers: Array = []


func reset(initial_pending: int = 1) -> void:
	pending_count = maxi(1, initial_pending)
	is_locked = false
	locked_remaining = 0
	jammed_time_left = 0.0
	queued_round_modifiers.clear()


func is_jammed() -> bool:
	return jammed_time_left > 0.0


func tick(delta: float) -> bool:
	if jammed_time_left > 0.0:
		jammed_time_left = maxf(0.0, jammed_time_left - delta)
		return true
	return false


func apply_pending_bonus(amount: int, max_pending: int) -> int:
	if amount <= 0:
		return 0
	var before := pending_count
	pending_count = clampi(pending_count + amount, 1, max_pending)
	return pending_count - before


func apply_pending_multiplier(multiplier: int, max_pending: int) -> int:
	if multiplier <= 1:
		return pending_count
	var before := pending_count
	pending_count = clampi(pending_count * multiplier, 1, max_pending)
	return pending_count - before


func queue_next_round_modifier(modifier: Dictionary) -> void:
	queued_round_modifiers.append(modifier.duplicate(true))


func apply_queued_modifiers(max_pending: int) -> void:
	if queued_round_modifiers.is_empty():
		return
	var modifiers: Array = queued_round_modifiers.duplicate(true)
	queued_round_modifiers.clear()
	for modifier in modifiers:
		if not (modifier is Dictionary):
			continue
		var md: Dictionary = modifier
		var mtype: String = str(md.get("type", ""))
		if mtype == "bonus_10":
			apply_pending_bonus(int(md.get("amount", 10)), max_pending)
		elif mtype == "x2" or mtype == "x3":
			apply_pending_multiplier(int(md.get("multiplier", 1)), max_pending)


func apply_jam(duration: float) -> void:
	jammed_time_left = maxf(jammed_time_left, duration)


func lock(count: int) -> void:
	is_locked = true
	locked_remaining = count


func unlock(next_pending: int) -> void:
	is_locked = false
	pending_count = maxi(1, next_pending)
	locked_remaining = 0


func export_save_state() -> Dictionary:
	return {
		"pending_count": pending_count,
		"is_locked": is_locked,
		"locked_remaining": locked_remaining,
		"jammed_time_left": jammed_time_left,
		"queued_round_modifiers": queued_round_modifiers.duplicate(true),
	}


func import_save_state(data: Dictionary) -> void:
	pending_count = clampi(int(data.get("pending_count", 1)), 1, 9999)
	is_locked = bool(data.get("is_locked", false))
	locked_remaining = clampi(int(data.get("locked_remaining", 0)), 0, 9999)
	jammed_time_left = maxf(0.0, float(data.get("jammed_time_left", 0.0)))
	queued_round_modifiers.clear()
	for modifier in data.get("queued_round_modifiers", []):
		if modifier is Dictionary:
			queued_round_modifiers.append((modifier as Dictionary).duplicate(true))
