extends Node2D
class_name Bullet

# Presentation only; see scripts/render/BulletRenderer.gd.
const BulletRendererScript = preload("res://scripts/render/BulletRenderer.gd")

const MAX_RESTORE_TRAIL_POINTS: int = 3

var faction_id: int = GameConfig.Faction.BLUE
var direction: Vector2 = Vector2.RIGHT
var speed = GameConfig.BULLET_SPEED
var battlefield
var target_turrets = {}
var last_cell = Vector2i(-999, -999)
var age = 0.0
var trail_points = []
var trail_max_points = 8
var pool
var trail_layer
var _cached_map_size: float = 0.0
var is_active: bool = false
var simple_draw: bool = false
var reduce_visual_effects: bool = false
var turret_hit_check_timer: float = 0.0
var trail_sample_timer: float = 0.0
var last_trail_position: Vector2 = Vector2.INF

# P1 弹属性（默认 = 普通弹 = 现有行为）。物理半径与渲染半径分开：
# physical_radius 参与碰撞，_visual_radius() 只影响绘制。
var type_id: int = 0
var cost: int = 1
var mass: float = 1.0
var energy: int = 1
var damage: int = GameConfig.BULLET_DAMAGE
var physical_radius: float = GameConfig.BULLET_RADIUS
var spawn_serial: int = 0
var prev_position: Vector2 = Vector2.ZERO
# P2 特殊弹：默认值等价于普通弹。max_enemy_captures = -1 表示无限穿透。
var max_enemy_captures: int = 1
var enemy_captures_done: int = 0
var explosion_radius: int = 0
var explosion_cells: int = 0
# 由 BulletPool 统一推进（互撞模式）；为 false 时每颗弹自己走 _physics_process。
var controlled: bool = false

# 一次 tick 的待结算事件：先移动，再碰撞，最后结算，避免各自完整执行。
var _pending_despawn: bool = false
var _pending_expired: bool = false
var _pending_cell: Vector2i = Vector2i(-999, -999)
var _pending_has_cell: bool = false
var _pending_turret = null

func apply_standard_profile() -> void:
	type_id = WeaponRuleset.BulletType.STANDARD
	cost = 1
	speed = GameConfig.BULLET_SPEED
	physical_radius = GameConfig.BULLET_RADIUS
	mass = 1.0
	energy = 1
	damage = GameConfig.BULLET_DAMAGE
	max_enemy_captures = 1
	enemy_captures_done = 0
	explosion_radius = 0
	explosion_cells = 0

func apply_type_profile(new_type: int, pierce_captures: int, blast_radius: int) -> void:
	# 速度/半径/伤害/碰撞规则在这一批保持一致，只改"越境后能占几格"。
	apply_standard_profile()
	type_id = new_type
	match new_type:
		WeaponRuleset.BulletType.PIERCING:
			max_enemy_captures = pierce_captures
		WeaponRuleset.BulletType.EXPLOSIVE:
			max_enemy_captures = 0
			explosion_radius = maxi(0, blast_radius)
		_:
			max_enemy_captures = 1

func set_controlled(value: bool) -> void:
	controlled = value
	if is_active:
		set_physics_process(not value)


func get_trail_segment_count() -> int:
	return maxi(0, trail_points.size() - 1)

func setup(new_faction_id: int, new_position: Vector2, new_direction: Vector2, new_battlefield, new_target_turrets = {}) -> void:
	var previous_segments: int = get_trail_segment_count()
	faction_id = new_faction_id
	global_position = new_position
	direction = new_direction.normalized()
	if direction.length() <= 0.001:
		direction = Vector2.RIGHT
	battlefield = new_battlefield
	if battlefield != null:
		_cached_map_size = float(battlefield.grid_size) * float(battlefield.cell_size)
	target_turrets = new_target_turrets
	apply_standard_profile()
	prev_position = new_position
	last_cell = Vector2i(-999, -999)
	age = 0.0
	turret_hit_check_timer = randf_range(0.0, GameConfig.TURRET_HIT_CHECK_INTERVAL)
	trail_sample_timer = 0.0
	last_trail_position = global_position
	trail_points.clear()
	if not simple_draw and trail_max_points > 0:
		trail_points.append(global_position)
	_notify_trail_segments_if_needed(previous_segments)
	_request_trail_redraw()
	queue_redraw()

func set_trail_layer(new_trail_layer) -> void:
	trail_layer = new_trail_layer

func get_visual_radius() -> float:
	return _visual_radius()

func _ready() -> void:
	z_index = 30
	visible = false
	set_process(false)
	set_physics_process(false)
	queue_redraw()

func activate() -> void:
	is_active = true
	visible = true
	set_process(true)
	set_physics_process(not controlled)
	z_index = 30

func deactivate() -> void:
	var previous_segments: int = get_trail_segment_count()
	is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)
	_reset_pending()
	battlefield = null
	target_turrets = {}
	trail_points.clear()
	_notify_trail_segments_if_needed(previous_segments)
	_request_trail_redraw()

func _request_trail_redraw() -> void:
	if trail_layer == null or not is_instance_valid(trail_layer):
		return
	if trail_layer.has_method("mark_bullet_dirty"):
		trail_layer.mark_bullet_dirty(self)
	elif trail_layer.has_method("request_trail_redraw"):
		trail_layer.request_trail_redraw()

func _notify_trail_segments_if_needed(previous_segments: int) -> void:
	var current_segments: int = get_trail_segment_count()
	if current_segments == previous_segments:
		return
	if pool != null and is_instance_valid(pool) and pool.has_method("notify_bullet_trail_changed"):
		pool.notify_bullet_trail_changed(self, current_segments)

func replace_trail_points(points: Array) -> void:
	var previous_segments: int = get_trail_segment_count()
	trail_points.clear()
	for point in points:
		if point is Vector2:
			trail_points.append(point)
	if trail_points.is_empty():
		trail_points.append(global_position)
	last_trail_position = trail_points[0] if trail_points.size() > 0 else global_position
	_notify_trail_segments_if_needed(previous_segments)
	_request_trail_redraw()
	queue_redraw()

func restore_from_state(state: Dictionary, new_battlefield, new_target_turrets = {}) -> void:
	var restored_faction_id: int = clampi(int(state.get("faction_id", 0)), 0, 3)
	var stored_position: Vector2 = SaveGameCodec.arr_to_vec2(state.get("position", [0, 0]), Vector2.ZERO)
	var has_battlefield_space: bool = is_instance_valid(new_battlefield) and state.get("position_space") == SaveGameCodec.BULLET_BATTLEFIELD_SPACE
	var restored_position: Vector2 = new_battlefield.to_global(stored_position) if has_battlefield_space else stored_position
	var restored_direction: Vector2 = SaveGameCodec.arr_to_vec2(state.get("direction", [1, 0]), Vector2.RIGHT).normalized()
	if restored_direction.length() <= 0.001:
		restored_direction = Vector2.RIGHT

	setup(restored_faction_id, restored_position, restored_direction, new_battlefield, new_target_turrets)
	var restored_type: int = clampi(int(state.get("type_id", WeaponRuleset.BulletType.STANDARD)), 0, WeaponRuleset.BulletType.HOMING)
	var pierce_captures: int = int(pool.piercing_captures) if pool != null and is_instance_valid(pool) else 1
	var blast_radius: int = int(pool.explosion_radius) if pool != null and is_instance_valid(pool) else 0
	apply_type_profile(restored_type, pierce_captures, blast_radius)
	enemy_captures_done = maxi(0, int(state.get("enemy_captures_done", 0)))
	age = clampf(float(state.get("age", 0.0)), 0.0, GameConfig.BULLET_MAX_LIFETIME)
	last_cell = SaveGameCodec.arr_to_vec2i(state.get("last_cell", [-999, -999]))

	var restored_trail_points: Array = []
	var trail = state.get("trail_points", [])
	if trail is Array and trail.size() > 0:
		var trail_count: int = mini(trail.size(), MAX_RESTORE_TRAIL_POINTS)
		for i in range(trail_count):
			var point: Vector2 = SaveGameCodec.arr_to_vec2(trail[i], stored_position)
			restored_trail_points.append(new_battlefield.to_global(point) if has_battlefield_space else point)
	else:
		restored_trail_points.append(global_position)
	replace_trail_points(restored_trail_points)

func _despawn() -> void:
	if pool != null and is_instance_valid(pool):
		pool.recycle_bullet(self)
	else:
		queue_free()

func _physics_process(delta: float) -> void:
	# 经典路径：每颗弹自己完成 移动 → 炮台/领土结算。
	# 互撞模式由 BulletPool.step_controlled() 统一调用 advance_tick() + resolve_tick()。
	if controlled:
		return
	advance_tick(delta)
	resolve_tick()

func advance_tick(delta: float) -> void:
	if not is_active:
		return
	_reset_pending()
	prev_position = global_position

	if battlefield == null:
		_pending_despawn = true
		return

	age += delta
	if age >= GameConfig.BULLET_MAX_LIFETIME:
		_pending_expired = true
		return

	var map_size: float = _cached_map_size
	if map_size <= 0.0 and battlefield != null:
		map_size = float(battlefield.grid_size) * float(battlefield.cell_size)
	var next_position = global_position + direction * speed * delta
	var local_position = battlefield.to_local(next_position)
	var bounced = false

	if local_position.x < 0.0:
		local_position.x = 0.0
		direction.x = abs(direction.x)
		bounced = true
	elif local_position.x > map_size:
		local_position.x = map_size
		direction.x = -abs(direction.x)
		bounced = true

	if local_position.y < 0.0:
		local_position.y = 0.0
		direction.y = abs(direction.y)
		bounced = true
	elif local_position.y > map_size:
		local_position.y = map_size
		direction.y = -abs(direction.y)
		bounced = true

	if bounced:
		direction = _stabilize_bounce_direction(direction).normalized()

	global_position = battlefield.to_global(local_position)
	_update_visual_trace(delta)

	turret_hit_check_timer -= delta
	if turret_hit_check_timer <= 0.0:
		turret_hit_check_timer = GameConfig.TURRET_HIT_CHECK_INTERVAL
		_pending_turret = _find_hittable_turret()

	var cell = battlefield.world_to_cell(global_position)
	if not battlefield.is_inside(cell):
		return

	if cell == last_cell:
		return

	last_cell = cell
	_pending_cell = cell
	_pending_has_cell = true

func resolve_tick() -> void:
	if not is_active:
		return
	if _pending_despawn:
		_despawn()
		return
	if _pending_expired:
		if pool != null and is_instance_valid(pool) and pool.has_method("notify_bullet_expired"):
			pool.notify_bullet_expired()
		_despawn()
		return
	if _pending_turret != null:
		# 炮台可能在同一 tick 内已被先结算的弹摧毁。
		if is_instance_valid(_pending_turret) and not _pending_turret.is_destroyed:
			_pending_turret.take_damage(damage)
		_despawn()
		return
	if _pending_has_cell:
		var result = battlefield.apply_bullet(_pending_cell, faction_id)
		if result == "HIT_ENEMY_CELL":
			enemy_captures_done += 1
			if explosion_radius > 0:
				_explode(_pending_cell)
				_despawn()
				return
			if max_enemy_captures >= 0 and enemy_captures_done >= max_enemy_captures:
				_despawn()

func _explode(center: Vector2i) -> void:
	# 方形半径：r=1 → 3×3（最多 9 格），与设计文档的"最多 9 格"一致。
	# 边界裁剪；已属己方的格不重复计数；同一颗弹只结算一次。
	var captured: int = 0
	for offset_x in range(-explosion_radius, explosion_radius + 1):
		for offset_y in range(-explosion_radius, explosion_radius + 1):
			var cell: Vector2i = center + Vector2i(offset_x, offset_y)
			if not battlefield.is_inside(cell):
				continue
			if int(battlefield.owners[cell.x][cell.y]) == faction_id:
				continue
			battlefield.apply_bullet(cell, faction_id)
			captured += 1
	explosion_cells = captured

func _reset_pending() -> void:
	_pending_despawn = false
	_pending_expired = false
	_pending_has_cell = false
	_pending_turret = null


func _stabilize_bounce_direction(raw_direction: Vector2) -> Vector2:
	# v1.9.28：防止正上/正下/正左/正右方向在边界之间无限来回弹。
	# 初始发射仍然严格跟随炮管方向；只有碰到战场边界后，才给近轴向弹道一点切向分量。
	var fixed_direction: Vector2 = raw_direction
	var tangent_min: float = 0.115
	if absf(fixed_direction.x) < tangent_min:
		fixed_direction.x = _bounce_tangent_sign() * tangent_min
	if absf(fixed_direction.y) < tangent_min:
		fixed_direction.y = _bounce_tangent_sign() * tangent_min
	return fixed_direction

func _bounce_tangent_sign() -> float:
	# 用阵营和当前寿命做一个确定性符号，避免每次随机导致轨迹抖动。
	var board_position: Vector2 = battlefield.to_local(global_position) if is_instance_valid(battlefield) else global_position
	var seed_value: int = int(age * 1000.0) + faction_id * 37 + int(board_position.x + board_position.y)
	return -1.0 if seed_value % 2 == 0 else 1.0

func configure_visuals(new_simple_draw: bool, new_reduce_visual_effects: bool, new_trail_max_points: int) -> void:
	var previous_segments: int = get_trail_segment_count()
	var changed: bool = simple_draw != new_simple_draw or reduce_visual_effects != new_reduce_visual_effects or trail_max_points != new_trail_max_points
	simple_draw = new_simple_draw
	reduce_visual_effects = new_reduce_visual_effects
	trail_max_points = maxi(0, new_trail_max_points)

	if simple_draw or trail_max_points <= 0:
		if trail_points.size() > 0:
			trail_points.clear()
			_request_trail_redraw()
			changed = true
	else:
		while trail_points.size() > trail_max_points:
			trail_points.pop_back()
			changed = true
		if trail_points.size() == 0:
			trail_points.append(global_position)
			last_trail_position = global_position
			_request_trail_redraw()
			changed = true

	if changed:
		_notify_trail_segments_if_needed(previous_segments)
		queue_redraw()

func _trail_sample_interval() -> float:
	# v1.9.28：拖尾继续增强。
	# 高画质/正常状态更接近每帧采样，中低画质也提高连续度；高压状态仍保留保护。
	if simple_draw:
		return 9999.0
	if reduce_visual_effects:
		return 0.075
	if trail_max_points >= 12:
		return 0.022
	if trail_max_points >= 8:
		return 0.028
	if trail_max_points >= 5:
		return 0.036
	return 0.050

func _trail_min_distance_sq() -> float:
	var radius: float = _visual_radius()
	if reduce_visual_effects:
		return radius * radius * 0.65
	return radius * radius * 0.14

func _update_visual_trace(delta: float) -> void:
	var previous_segments: int = get_trail_segment_count()
	if simple_draw or trail_max_points <= 0:
		if trail_points.size() > 0:
			trail_points.clear()
			_notify_trail_segments_if_needed(previous_segments)
			_request_trail_redraw()
		return

	trail_sample_timer -= delta
	if trail_sample_timer > 0.0:
		return

	if last_trail_position != Vector2.INF and global_position.distance_squared_to(last_trail_position) < _trail_min_distance_sq():
		return

	trail_sample_timer = _trail_sample_interval()
	trail_points.push_front(global_position)
	last_trail_position = global_position
	while trail_points.size() > trail_max_points:
		trail_points.pop_back()
	_notify_trail_segments_if_needed(previous_segments)
	_request_trail_redraw()

func _find_hittable_turret():
	for target_faction_id in target_turrets:
		if target_faction_id == faction_id:
			continue
		var turret = target_turrets[target_faction_id]
		if turret == null:
			continue
		if turret.is_destroyed:
			continue
		# 物理半径参与命中：普通弹半径 = BULLET_RADIUS，判定圈与原版完全一致。
		var hit_radius: float = GameConfig.TURRET_HIT_RADIUS + (physical_radius - GameConfig.BULLET_RADIUS)
		if global_position.distance_squared_to(turret.global_position) <= hit_radius * hit_radius:
			return turret
	return null

func _try_hit_enemy_turret() -> bool:
	# 旧接口：立即结算炮台伤害并返回是否命中。保留给坐标/命中探针直接调用。
	var turret = _find_hittable_turret()
	if turret == null:
		return false
	turret.take_damage(damage)
	return true

func _visual_radius() -> float:
	if battlefield != null:
		return minf(physical_radius, float(battlefield.cell_size) * 0.42)
	return physical_radius

func _draw() -> void:
	BulletRendererScript.draw(self, {
		"color": GameConfig.faction_color(faction_id),
		"radius": _visual_radius(),
		"simple": simple_draw,
		"reduce": reduce_visual_effects,
	})
