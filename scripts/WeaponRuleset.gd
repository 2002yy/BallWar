extends RefCounted
class_name WeaponRuleset

# 弹种与火力成本。常规对局只解锁普通弹：
# 一个类型必须在 unlocked_types 里，才可能被 allocate() 产出。
# 数值来自 docs/design/BULLET_AND_MAP_SYSTEMS.md §3.2，属原型参数，未实测。
enum BulletType {
	STANDARD,
	VELOCITY,
	PIERCING,
	HEAVY,
	EXPLOSIVE,
	CLUSTER,
	INTERCEPTOR,
	HOMING,
}

const CLASSIC_ID: String = "standard"
const COLLISION_LAB_ID: String = "collision_lab"
const VELOCITY_LAB_ID: String = "velocity_lab"
const KNOWN_IDS: Array[String] = [CLASSIC_ID, COLLISION_LAB_ID, VELOCITY_LAB_ID]

const DEFAULT_COSTS: Dictionary = {
	BulletType.STANDARD: 1,
	BulletType.VELOCITY: 2,
	BulletType.PIERCING: 5,
	BulletType.HEAVY: 10,
	BulletType.EXPLOSIVE: 10,
	BulletType.CLUSTER: 6,
	BulletType.INTERCEPTOR: 4,
	BulletType.HOMING: 6,
}

var projectile_collision: bool = false
var default_shares: Dictionary = {}
var unlocked_types: Array[int] = [BulletType.STANDARD]
var costs: Dictionary = DEFAULT_COSTS.duplicate()

static func classic() -> WeaponRuleset:
	return WeaponRuleset.new()

static func for_id(ruleset_id: String) -> WeaponRuleset:
	var ruleset := WeaponRuleset.new()
	ruleset.projectile_collision = ruleset_id in [COLLISION_LAB_ID, VELOCITY_LAB_ID]
	if ruleset_id == VELOCITY_LAB_ID:
		ruleset.unlocked_types.append(BulletType.VELOCITY)
		ruleset.default_shares[BulletType.VELOCITY] = 100
	return ruleset

static func with_unlocked(types: Array) -> WeaponRuleset:
	# 普通弹不可关闭：它是所有分配结果的兜底，也是实验对照组。
	var ruleset := WeaponRuleset.new()
	ruleset.unlocked_types = [BulletType.STANDARD]
	for type_value in types:
		var type_id: int = int(type_value)
		if type_id == BulletType.STANDARD:
			continue
		if ruleset.costs.has(type_id) and not ruleset.unlocked_types.has(type_id):
			ruleset.unlocked_types.append(type_id)
	ruleset.unlocked_types.sort()
	return ruleset

static func total_shots(volley: Dictionary) -> int:
	var total: int = 0
	for count in volley.values():
		total += int(count)
	return total

func is_unlocked(type_id: int) -> bool:
	return unlocked_types.has(type_id)

func cost_of(type_id: int) -> int:
	return maxi(1, int(costs.get(type_id, DEFAULT_COSTS[BulletType.STANDARD])))

func allocate(fire: int, shares: Dictionary = {}) -> Dictionary:
	# 确定性整数分配（docs/design/BULLET_AND_MAP_SYSTEMS.md §4.3）：
	#   每个特殊弹种分到 floor(fire * pct / 100) 点火力，再按自身成本换成发数；
	#   没花完的火力全部回到普通弹。没有随机、没有浮点、同一输入同一输出。
	# shares 里未解锁的类型直接忽略；pct 合计超过 100 时按枚举顺序先到先得。
	var total_fire: int = maxi(0, fire)
	var remaining: int = total_fire
	var result: Dictionary = {}
	for type_id in unlocked_types:
		if type_id == BulletType.STANDARD:
			continue
		var percent: int = clampi(int(shares.get(type_id, 0)), 0, 100)
		if percent <= 0:
			continue
		var budget: int = mini(remaining, total_fire * percent / 100)
		var cost: int = cost_of(type_id)
		var count: int = budget / cost
		if count <= 0:
			continue
		result[type_id] = count
		remaining -= count * cost
	if remaining > 0:
		result[BulletType.STANDARD] = remaining / cost_of(BulletType.STANDARD)
	return result
