extends RefCounted
class_name DevBattleTools

enum Goal { TIME, FIRST_SHOT, ACTIVE_BULLETS, NEXT_EVENT, LOW_HEALTH, FIRST_DESTROY, TERRITORY, GAME_OVER }
enum Action { ADD_BALLS, FIRE_BURST, TRIGGER_EVENT, SET_HEALTH, DESTROY_TURRET, DENSE_BULLETS }

var _main: Node
var _goal: int = -1
var _threshold: float
var _faction: int
var _finished_events: int = 0
var _target_event: int


func _init(main: Node) -> void:
	_main = main


func reset() -> void:
	cancel_goal()
	_finished_events = 0


func arm_goal(goal: Goal, threshold: float, faction: int) -> void:
	_goal = goal
	_threshold = threshold
	_faction = -1 if faction == 4 else faction
	_target_event = _finished_events + 1


func record_event() -> void:
	_finished_events += 1


func cancel_goal() -> void:
	_goal = -1


func is_advancing() -> bool:
	return _goal >= 0


func goal_reached() -> bool:
	var runtime = _main.runtime
	match _goal:
		Goal.TIME:
			return _main.game_elapsed_time + 0.000001 >= _threshold
		Goal.FIRST_SHOT:
			return is_instance_valid(runtime.bullet_pool) and runtime.bullet_pool.peak_active_count > 0
		Goal.ACTIVE_BULLETS:
			return is_instance_valid(runtime.bullet_pool) and runtime.bullet_pool.active_bullets.size() >= _threshold
		Goal.NEXT_EVENT:
			return _finished_events >= _target_event
		Goal.LOW_HEALTH, Goal.FIRST_DESTROY:
			for turret in runtime.turrets.values():
				if not is_instance_valid(turret):
					continue
				if _goal == Goal.FIRST_DESTROY and turret.is_destroyed:
					return true
				if _goal == Goal.LOW_HEALTH and (_faction == -1 or _faction == turret.faction_id):
					if turret.max_health > 0 and 100.0 * turret.health / turret.max_health < _threshold:
						return true
		Goal.TERRITORY:
			var field = runtime.battlefield
			if is_instance_valid(field) and field.grid_size > 0:
				var total: int = field.grid_size * field.grid_size
				for faction in field.owner_counts:
					if (_faction == -1 or _faction == int(faction)) and 100.0 * field.owner_counts[faction] / total >= _threshold:
						return true
		Goal.GAME_OVER:
			return _main.is_game_over
	return false


# An empty result indicates the requested operation was unavailable.
func construct(action: Action, faction: int, amount: int) -> String:
	if _main.is_game_over or _main.game_layer == null:
		return ""
	var runtime = _main.runtime
	var turret: Turret = runtime.turrets.get(faction)
	var chamber: ControlChamber = runtime.chambers.get(faction)
	match action:
		Action.ADD_BALLS:
			if not is_instance_valid(chamber) or chamber.is_damaged or chamber.is_locked:
				return ""
			var added: int = mini(maxi(0, amount), GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER - chamber.balls.size())
			for i in range(added):
				chamber.add_control_ball()
			if added > 0:
				return "加入 %d 个控制球" % added
		Action.FIRE_BURST:
			if not is_instance_valid(turret) or not is_instance_valid(chamber) or turret.is_destroyed or turret.burst_remaining > 0:
				return ""
			var count: int = clampi(amount, 1, GameConfig.get_max_pending_count())
			_main._on_chamber_release_requested(faction, count, chamber)
			return "炮台已排入 %d 发" % count
		Action.TRIGGER_EVENT:
			var controller = runtime.event_controller
			if is_instance_valid(controller) and controller.event_roulette_enabled and not controller.is_presenting_event:
				controller._start_event_round()
				if controller.is_presenting_event:
					return "已触发事件转盘，效果按模拟 tick 生效"
		Action.SET_HEALTH, Action.DESTROY_TURRET:
			if not is_instance_valid(turret) or turret.is_destroyed:
				return ""
			var target: int = 0 if action == Action.DESTROY_TURRET else clampi(amount, 0, turret.max_health)
			if target < turret.health:
				turret.take_damage(turret.health - target)
			else:
				turret.health = target
				turret.queue_redraw()
			return "炮塔生命 %d/%d" % [turret.health, turret.max_health]
		Action.DENSE_BULLETS:
			if not is_instance_valid(runtime.bullet_pool) or not is_instance_valid(runtime.battlefield):
				return ""
			var count: int = clampi(amount, 1, GameConfig.get_max_active_bullets())
			if not _spawn_dense_bullets(faction, count):
				return ""
			return "已布置 %d 发，当前在场 %d 发" % [count, runtime.bullet_pool.active_bullets.size()]
	return ""


func _spawn_dense_bullets(faction: int, count: int) -> bool:
	var field: Battlefield = _main.runtime.battlefield
	var pool: BulletPool = _main.runtime.bullet_pool
	var owned_cells: Array[Vector2] = []
	for x in range(field.grid_size):
		for y in range(field.grid_size):
			if field.owners[x][y] == faction:
				owned_cells.append(Vector2(x, y))
	if owned_cells.is_empty():
		return false

	# Start in friendly cells so the stress fixture persists beyond its first tick.
	for i in range(count):
		var cell: Vector2 = owned_cells[i % owned_cells.size()]
		var offset := Vector2(0.3 + (i % 11) / 25.0, 0.3 + (i % 13) / 30.0)
		var direction := Vector2.RIGHT.rotated(TAU * ((i * 137) % 360) / 360.0)
		pool.spawn_bullet(faction, field.to_global((cell + offset) * field.cell_size), direction, field, _main.runtime.turrets)
	return true
