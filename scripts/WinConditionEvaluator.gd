extends RefCounted
class_name WinConditionEvaluator

const GameConfig = preload("res://scripts/GameConfig.gd")

static func _result(ended: bool, winner: int, draw: bool, sub_text: String, reason: String) -> Dictionary:
	return {"ended": ended, "winner": winner, "draw": draw, "sub_text": sub_text, "reason": reason}

static func evaluate_basic(turrets: Dictionary) -> Dictionary:
	var alive_ids: Array = []
	for faction_id in turrets.keys():
		var turret = turrets[faction_id]
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			alive_ids.append(faction_id)

	if alive_ids.size() == 1:
		return _result(true, int(alive_ids[0]), false, "终局", "basic")
	if alive_ids.size() == 0:
		return _result(true, -1, true, "终局", "basic")
	return _result(false, -1, false, "", "basic")

static func evaluate_occupation(owner_counts: Dictionary, total_cells: int, target_percent: int) -> Dictionary:
	var best_id: int = -1
	var best_count: int = -1
	var tied: bool = false
	var total: int = 0
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var count: int = int(owner_counts.get(faction_id, 0))
		total += count
		if count > best_count:
			best_count = count
			best_id = int(faction_id)
			tied = false
		elif count == best_count:
			tied = true

	if total <= 0 or tied:
		return _result(false, -1, false, "", "occupation")

	if total_cells <= 0:
		total_cells = total

	if best_count * 100 >= total_cells * target_percent:
		return _result(true, best_id, false, "占领达成", "occupation")
	return _result(false, -1, false, "", "occupation")

static func evaluate_timed(owner_counts: Dictionary, time_expired: bool) -> Dictionary:
	if not time_expired:
		return _result(false, -1, false, "", "timed")

	var best_id: int = -1
	var best_count: int = -1
	var tied: bool = false
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var count: int = int(owner_counts.get(faction_id, 0))
		if count > best_count:
			best_count = count
			best_id = int(faction_id)
			tied = false
		elif count == best_count:
			tied = true
	if tied or best_id == -1:
		return _result(true, -1, true, "时间到", "timed")
	return _result(true, best_id, false, "时间到", "timed")

static func evaluate(mode_name: String, turrets: Dictionary, owner_counts: Dictionary, total_cells: int, time_expired: bool) -> Dictionary:
	match mode_name:
		GameConfig.GAME_MODE_BASIC:
			return evaluate_basic(turrets)
		GameConfig.GAME_MODE_OCCUPATION:
			return evaluate_occupation(owner_counts, maxi(total_cells, 1), GameConfig.get_occupation_target_percent())
		GameConfig.GAME_MODE_TIMED:
			return evaluate_timed(owner_counts, time_expired)
		GameConfig.GAME_MODE_WILD:
			return evaluate_basic(turrets)
	return _result(false, -1, false, "", "")
