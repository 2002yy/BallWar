extends RefCounted
class_name FireLedger

# P2.3 跨 burst 火力记账：按阵营、按弹种累计"特殊弹火力"，整数定点（1 发 = 100 单位）。
# 混合比例是**火力占比**，不是炮弹数量占比；余额不足时火力留在账上，不返还普通弹。
# 生产火力守恒：consumed * 100 == spent + remaining + lost。

const UNIT_SCALE: int = 100

var special_units: Dictionary = {}
var standard_units: int = 0
var produced_fire: int = 0
var consumed_fire: int = 0
var spent_units: int = 0
var lost_units: int = 0
var last_error: String = ""

func reset() -> void:
	special_units.clear()
	standard_units = 0
	produced_fire = 0
	consumed_fire = 0
	spent_units = 0
	lost_units = 0
	last_error = ""

func allocate(fire: int, shares: Dictionary, ruleset) -> Dictionary:
	# 返回 {type_id: 发数}。fire 是本次释放的火力（整数），按 shares 的百分比分配到
	# 各弹种账户；不足一发的余额留在账户里，等下一次释放继续累计。
	last_error = ""
	var granted: int = maxi(0, int(fire))
	if granted <= 0:
		return {}
	produced_fire += granted
	consumed_fire += granted

	var clean_shares: Dictionary = {}
	var total_percent: int = 0
	for key in shares:
		var type_id: int = int(key)
		var percent: int = clampi(int(shares[key]), 0, 100)
		if percent <= 0:
			continue
		if ruleset == null or not ruleset.is_unlocked(type_id):
			last_error = "unlocked:%d" % type_id
			clean_shares.clear()
			total_percent = 0
			break
		if ruleset.cost_of(type_id) <= 0:
			last_error = "cost:%d" % type_id
			clean_shares.clear()
			total_percent = 0
			break
		clean_shares[type_id] = percent
		total_percent += percent

	if total_percent > 100:
		# 明确拒绝，不按枚举顺序隐式偏向：整批火力回到普通弹，并记录错误。
		last_error = "shares_sum:%d" % total_percent
		clean_shares.clear()
		total_percent = 0

	var keys: Array = clean_shares.keys()
	keys.sort()
	for type_id in keys:
		var percent: int = int(clean_shares[type_id])
		special_units[type_id] = int(special_units.get(type_id, 0)) + granted * percent
	standard_units += granted * (100 - total_percent)

	return _convert(ruleset)

func _convert(ruleset) -> Dictionary:
	var volley: Dictionary = {}
	if ruleset == null:
		return volley
	var keys: Array = special_units.keys()
	keys.sort()
	for type_id in keys:
		var cost_units: int = ruleset.cost_of(type_id) * UNIT_SCALE
		if cost_units <= 0:
			continue
		var balance: int = int(special_units.get(type_id, 0))
		var count: int = balance / cost_units
		if count <= 0:
			continue
		special_units[type_id] = balance - count * cost_units
		spent_units += count * cost_units
		volley[type_id] = count

	var standard_cost_units: int = UNIT_SCALE
	var standard_count: int = standard_units / standard_cost_units
	if standard_count > 0:
		standard_units -= standard_count * standard_cost_units
		spent_units += standard_count * standard_cost_units
		volley[WeaponRuleset.BulletType.STANDARD] = standard_count
	return volley

func remaining_units() -> int:
	var total: int = standard_units
	for value in special_units.values():
		total += int(value)
	return total

func remaining_fire() -> float:
	return float(remaining_units()) / float(UNIT_SCALE)

func is_balanced() -> bool:
	return consumed_fire * UNIT_SCALE == spent_units + remaining_units() + lost_units

func snapshot() -> Dictionary:
	var special: Array = []
	var keys: Array = special_units.keys()
	keys.sort()
	for type_id in keys:
		special.append([int(type_id), int(special_units[type_id])])
	return {
		"special": special,
		"standard": standard_units,
		"produced_fire": produced_fire,
		"consumed_fire": consumed_fire,
		"spent_units": spent_units,
		"lost_units": lost_units,
	}

func restore(data) -> void:
	reset()
	if not (data is Dictionary):
		return
	var special = data.get("special", [])
	if special is Array:
		for entry in special:
			if not (entry is Array) or entry.size() < 2:
				continue
			var type_id: int = clampi(int(entry[0]), 0, WeaponRuleset.BulletType.HOMING)
			var units: int = maxi(0, int(entry[1]))
			if units > 0:
				special_units[type_id] = units
	standard_units = maxi(0, int(data.get("standard", 0)))
	produced_fire = maxi(0, int(data.get("produced_fire", 0)))
	consumed_fire = maxi(0, int(data.get("consumed_fire", 0)))
	spent_units = maxi(0, int(data.get("spent_units", 0)))
	lost_units = maxi(0, int(data.get("lost_units", 0)))

func debug_line() -> String:
	var parts: Array[String] = []
	var keys: Array = special_units.keys()
	keys.sort()
	for type_id in keys:
		if int(special_units[type_id]) > 0:
			parts.append("t%d=%.2f" % [int(type_id), float(special_units[type_id]) / float(UNIT_SCALE)])
	parts.append("std=%.2f" % (float(standard_units) / float(UNIT_SCALE)))
	return "produced=%d spent=%d remain=%s" % [produced_fire, spent_units / UNIT_SCALE, ",".join(parts)]
