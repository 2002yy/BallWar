extends RefCounted
class_name ReserveEconomy

const CAPACITY: int = 400
const CONVERSION_DIVISOR: int = 4
const ADD_BALL_COST: int = 100
const LUCKY_BLAST_COST: int = 200
const LUCKY_BLAST_RADIUS: int = 3
const LUCKY_BLAST_SEED_SALT: int = 0x4c55434b59424c41

var _balances: Dictionary = {}
var _blast_random := RandomNumberGenerator.new()

func _init(match_seed: int) -> void:
	if match_seed < 0:
		_blast_random.randomize()
	else:
		_blast_random.seed = match_seed ^ LUCKY_BLAST_SEED_SALT

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
	return _try_purchase(chamber.faction_id, ADD_BALL_COST, chamber.add_control_ball) > 0

func try_buy_lucky_blast(faction_id: int, battlefield: Battlefield) -> int:
	return _try_purchase(faction_id, LUCKY_BLAST_COST, _apply_lucky_blast.bind(faction_id, battlefield))

func _try_purchase(faction_id: int, cost: int, apply_effect: Callable) -> int:
	var stored := balance(faction_id)
	if stored < cost:
		return 0
	# Update the balance before the chamber emits ball_count_changed.
	_balances[faction_id] = stored - cost
	var applied := int(apply_effect.call())
	if applied == 0:
		_balances[faction_id] = stored
	return applied

func _apply_lucky_blast(faction_id: int, battlefield: Battlefield) -> int:
	var enemy_cells: Array[Vector2i] = []
	for x in range(battlefield.grid_size):
		for y in range(battlefield.grid_size):
			if battlefield.owners[x][y] != faction_id:
				enemy_cells.append(Vector2i(x, y))
	if enemy_cells.is_empty():
		return 0

	var center := enemy_cells[_blast_random.randi_range(0, enemy_cells.size() - 1)]
	var changed := 0
	for dx in range(-LUCKY_BLAST_RADIUS, LUCKY_BLAST_RADIUS + 1):
		for dy in range(-LUCKY_BLAST_RADIUS, LUCKY_BLAST_RADIUS + 1):
			if dx * dx + dy * dy <= LUCKY_BLAST_RADIUS * LUCKY_BLAST_RADIUS:
				changed += int(battlefield.claim_cell(center + Vector2i(dx, dy), faction_id))
	return changed
