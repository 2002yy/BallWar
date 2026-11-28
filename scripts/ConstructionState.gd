extends RefCounted
class_name ConstructionState

const COST: int = 50
const CAPACITY: int = 400

var _balances: Dictionary = {}
var _auxiliary_ids: Dictionary = {}

func balance(faction: int) -> int:
	return _balances.get(faction, 0)

func convert_pending(pending: int, faction: int) -> int:
	var stored := balance(faction)
	@warning_ignore("integer_division")
	var converted := mini(pending / 4, CAPACITY - stored)
	_balances[faction] = stored + converted
	return pending - converted

func auxiliary_id(faction: int) -> int:
	return _auxiliary_ids.get(faction, 0)

func auxiliary_cell(faction: int, grid_size: int) -> Vector2i:
	var inset := mini(5, (grid_size >> 1) - 1)
	var far := grid_size - 1 - inset
	return Vector2i(far if faction == GameConfig.Faction.RED or faction == GameConfig.Faction.YELLOW else inset,
		far if faction == GameConfig.Faction.GREEN or faction == GameConfig.Faction.YELLOW else inset)

func record_auxiliary(faction: int, turret_id: int) -> void:
	_balances[faction] = balance(faction) - COST
	_auxiliary_ids[faction] = turret_id
