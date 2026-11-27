extends RefCounted
class_name PresentationEvents

# One-way fan-out from simulation to presentation.
#
# Simulation code (Turret, ControlChamber, ...) owns its own signals. Main - the
# composition root - relays them here as normalised events. Audio, and any future
# effects or HUD feedback, subscribe to this object instead of digging into
# simulation nodes.
#
# Hard rule: presentation consumes simulation, never the other way round. Every
# method here returns void and carries no state that the simulation can read; the
# counters below exist only so a test can assert that an event actually fired
# (audio can legitimately drop a sound because of throttling or muting, so audio
# play counts are not evidence that the game emitted the event).
#
# Extending this for future ammo or map mechanics means adding a signal and a
# relay, not a new subsystem. Nothing here should be prepared before the mechanic
# that raises it exists.

# `count` is the firepower value the chamber released, NOT the number of bullets
# that will leave the turret: since the P0 volley allocation, one release can be
# split across ammo types. Presentation must not care - it is one sound per
# release - but anything reading the payload as a shot count would be wrong from
# the moment ammo types actually fire.
signal released(faction_id: int, count: int)
signal damaged(faction_id: int, amount: int)
signal destroyed(faction_id: int)
signal ball_landed(faction_id: int, ball_count: int)
signal multiplier_applied(faction_id: int, multiplier: int, pending: int)

var counts: Dictionary = {}


func emit_released(faction_id: int, count: int) -> void:
	_count("released")
	released.emit(faction_id, count)


func emit_damaged(faction_id: int, amount: int) -> void:
	_count("damaged")
	damaged.emit(faction_id, amount)


func emit_destroyed(faction_id: int) -> void:
	_count("destroyed")
	destroyed.emit(faction_id)


func emit_ball_landed(faction_id: int, ball_count: int) -> void:
	_count("ball_landed")
	ball_landed.emit(faction_id, ball_count)


func emit_multiplier_applied(faction_id: int, multiplier: int, pending: int) -> void:
	_count("multiplier_applied")
	multiplier_applied.emit(faction_id, multiplier, pending)


func _count(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func snapshot() -> Dictionary:
	return counts.duplicate()


func reset_counts() -> void:
	counts.clear()
