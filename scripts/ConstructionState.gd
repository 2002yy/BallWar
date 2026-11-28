extends RefCounted
class_name ConstructionState

const COST: int = 50
const CAPACITY: int = 400

var targets: Dictionary = {}
var _balances: Dictionary = {}

func balance(faction: int) -> int:
	return _balances.get(faction, 0)

func convert_pending(pending: int, faction: int) -> int:
	var stored := balance(faction)
	@warning_ignore("integer_division")
	var converted := mini(pending / 4, CAPACITY - stored)
	_balances[faction] = stored + converted
	return pending - converted

func auxiliary_slot(faction: int) -> int:
	return faction + GameConfig.Faction.size()

func auxiliary_cell(faction: int, grid_size: int) -> Vector2i:
	var inset := mini(5, (grid_size >> 1) - 1)
	var far := grid_size - 1 - inset
	return Vector2i(far if faction == GameConfig.Faction.RED or faction == GameConfig.Faction.YELLOW else inset,
		far if faction == GameConfig.Faction.GREEN or faction == GameConfig.Faction.YELLOW else inset)

func live_turret(slot: int) -> Turret:
	var turret: Turret = targets.get(slot)
	return turret if is_instance_valid(turret) and not turret.is_destroyed else null

func select_turret(faction: int, previous: Turret = null) -> Turret:
	var primary := live_turret(faction)
	var auxiliary := live_turret(auxiliary_slot(faction))
	if auxiliary != null and (primary == null or previous == primary):
		return auxiliary
	return primary

func add_auxiliary(faction: int, turret: Turret) -> void:
	_balances[faction] = balance(faction) - COST
	targets[auxiliary_slot(faction)] = turret
