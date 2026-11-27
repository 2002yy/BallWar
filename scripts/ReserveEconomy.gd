extends RefCounted
class_name ReserveEconomy

const CAPACITY: int = 400
const CONVERSION_DIVISOR: int = 4
const ADD_BALL_COST: int = 100

var _balances: Dictionary = {}

func balance(faction_id: int) -> int:
	return _balances.get(faction_id, 0)

func convert_pending(firepower: int, faction_id: int) -> int:
	var stored := balance(faction_id)
	@warning_ignore("integer_division")
	var converted := mini(firepower / CONVERSION_DIVISOR, CAPACITY - stored)
	if converted > 0:
		_balances[faction_id] = stored + converted
	return firepower - maxi(0, converted)

func try_buy_control_ball(chamber: ControlChamber) -> bool:
	if chamber.is_jammed():
		return false
	var faction_id := chamber.faction_id
	var stored := balance(faction_id)
	if stored < ADD_BALL_COST:
		return false
	# Update the balance before the chamber emits ball_count_changed.
	_balances[faction_id] = stored - ADD_BALL_COST
	if chamber.add_control_ball():
		return true
	_balances[faction_id] = stored
	return false
