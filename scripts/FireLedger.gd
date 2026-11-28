extends RefCounted
class_name FireLedger

# P2.3 跨 burst 火力记账：按阵营、按弹种累计"特殊弹火力"，整数定点（1 发 = 100 单位）。
# 混合比例是**火力占比**，不是炮弹数量占比；余额不足时火力留在账上，不返还普通弹。
#
# 四个量必须分开：
#   consumed_fire  控制仓释放进来的火力（生产）
#   converted_units 已兑换成炮弹的火力（含还在发射队列里的）
#   fired_units    真正已经发射出去的火力
#   lost_units     已兑换但永远不会发射的火力（取消发射、炮台/控制仓被毁）
# 恒等式：consumed * 100 == converted + remaining  （分配守恒）
#         converted == fired + pending + lost     （兑换守恒）

const UNIT_SCALE: int = 100

var special_units: Dictionary = {}
var standard_units: int = 0
var produced_fire: int = 0
var consumed_fire: int = 0
var converted_units: int = 0
var fired_units: int = 0
var lost_units: int = 0
var last_error: String = ""
var restore_ok: bool = true

func reset() -> void:
	special_units.clear()
	standard_units = 0
	produced_fire = 0
	consumed_fire = 0
	converted_units = 0
	fired_units = 0
	lost_units = 0
	last_error = ""
	restore_ok = true

func allocate(fire: int, shares: Dictionary, ruleset) -> Dictionary:
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
		converted_units += count * cost_units
		volley[type_id] = count

	var standard_cost_units: int = UNIT_SCALE
	var standard_count: int = standard_units / standard_cost_units
	if standard_count > 0:
		standard_units -= standard_count * standard_cost_units
		converted_units += standard_count * standard_cost_units
		volley[WeaponRuleset.BulletType.STANDARD] = standard_count
	return volley

func note_fired(type_id: int, count: int) -> void:
	if count <= 0:
		return
	fired_units += _cost(type_id) * UNIT_SCALE * count

func note_lost(type_id: int, count: int) -> void:
	if count <= 0:
		return
	lost_units += _cost(type_id) * UNIT_SCALE * count

func _cost(type_id: int) -> int:
	return maxi(1, int(WeaponRuleset.DEFAULT_COSTS.get(type_id, 1)))

func pending_units() -> int:
	return maxi(0, converted_units - fired_units - lost_units)

func remaining_units() -> int:
	var total: int = standard_units
	for value in special_units.values():
		total += int(value)
	return total

func remaining_fire() -> float:
	return float(remaining_units()) / float(UNIT_SCALE)

func is_balanced() -> bool:
	var allocation_ok: bool = consumed_fire * UNIT_SCALE == converted_units + remaining_units()
	var conversion_ok: bool = converted_units == fired_units + pending_units() + lost_units
	return allocation_ok and conversion_ok and fired_units <= converted_units

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
		"converted_units": converted_units,
		"fired_units": fired_units,
		"lost_units": lost_units,
	}

func restore(data) -> void:
	reset()
	if not (data is Dictionary):
		restore_ok = false
		last_error = "restore:not_dict"
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
	converted_units = maxi(0, int(data.get("converted_units", data.get("spent_units", 0))))
	fired_units = maxi(0, int(data.get("fired_units", 0)))
	lost_units = maxi(0, int(data.get("lost_units", 0)))
	restore_ok = is_balanced()
	if not restore_ok:
		last_error = "restore:unbalanced"

func debug_line() -> String:
	var parts: Array[String] = []
	var keys: Array = special_units.keys()
	keys.sort()
	for type_id in keys:
		if int(special_units[type_id]) > 0:
			parts.append("t%d=%.2f" % [int(type_id), float(special_units[type_id]) / float(UNIT_SCALE)])
	parts.append("std=%.2f" % (float(standard_units) / float(UNIT_SCALE)))
	return "prod=%d conv=%.1f fired=%.1f pend=%.1f lost=%.1f remain=%s" % [
		produced_fire,
		float(converted_units) / float(UNIT_SCALE),
		float(fired_units) / float(UNIT_SCALE),
		float(pending_units()) / float(UNIT_SCALE),
		float(lost_units) / float(UNIT_SCALE),
		",".join(parts),
	]
