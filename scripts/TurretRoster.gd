extends RefCounted
class_name TurretRoster

# In-flight projectiles share this dictionary, so additions are visible to them.
var by_id: Dictionary = {}
var _turret_ids_by_faction: Dictionary = {}
var _next_id: int = 1

func register(turret: Turret) -> int:
	if by_id.get(turret.turret_id) == turret:
		return turret.turret_id
	var turret_id := _next_id
	_next_id += 1
	turret.turret_id = turret_id
	by_id[turret_id] = turret
	var members: Array = _turret_ids_by_faction.get(turret.faction_id, [])
	members.append(turret_id)
	_turret_ids_by_faction[turret.faction_id] = members
	return turret_id

func live_turret(turret_id: int) -> Turret:
	var turret: Turret = by_id.get(turret_id)
	return turret if is_instance_valid(turret) and not turret.is_destroyed else null

func next_live_turret(faction_id: int, after_id: int = 0) -> Turret:
	var members: Array = _turret_ids_by_faction.get(faction_id, [])
	var previous_index := members.find(after_id)
	for offset in range(1, members.size() + 1):
		var index := (previous_index + offset) % members.size()
		var turret := live_turret(members[index])
		if turret != null:
			return turret
	return null
