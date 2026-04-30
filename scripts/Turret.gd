extends Node2D
class_name Turret

signal destroyed(faction_id)
signal burst_lock_changed(faction_id, locked)

var faction_id = GameConfig.Faction.BLUE
var battlefield
var bullet_container
var all_turrets = {}

var sweep_phase = 0.0
var sweep_speed = 0.95
var center_angle = 0.0
var sweep_amplitude = PI * 0.25

var max_health = GameConfig.TURRET_MAX_HEALTH
var health = GameConfig.TURRET_MAX_HEALTH
var is_destroyed = false
var damage_flash = 0.0

var burst_remaining = 0
var burst_interval = GameConfig.BURST_FIRE_INTERVAL
var burst_timer = 0.0
var burst_locked = false

func setup(new_faction_id: int, new_position: Vector2, new_battlefield, new_bullet_container) -> void:
	faction_id = new_faction_id
	global_position = new_position
	battlefield = new_battlefield
	bullet_container = new_bullet_container

func set_all_turrets(turret_map: Dictionary) -> void:
	all_turrets = turret_map

func _ready() -> void:
	randomize()
	center_angle = _inward_center_angle()
	sweep_phase = randf_range(0.0, TAU)
	rotation = center_angle
	z_index = 15
	queue_redraw()

func _process(delta: float) -> void:
	if not is_destroyed:
		sweep_phase += delta * sweep_speed
		rotation = center_angle + sin(sweep_phase) * sweep_amplitude

	if burst_remaining > 0 and not is_destroyed:
		burst_timer -= delta
		if burst_timer <= 0.0:
			_spawn_bullet()
			burst_remaining -= 1
			if burst_remaining > 0:
				burst_timer = burst_interval
			else:
				_set_burst_locked(false)

	if damage_flash > 0.0:
		damage_flash = maxf(0.0, damage_flash - delta * 3.0)
		queue_redraw()

func _inward_center_angle() -> float:
	match faction_id:
		GameConfig.Faction.BLUE:
			return PI * 0.25
		GameConfig.Faction.RED:
			return PI * 0.75
		GameConfig.Faction.GREEN:
			return -PI * 0.25
		GameConfig.Faction.YELLOW:
			return PI * 1.25
		_:
			return 0.0

func fire_burst(count: int) -> void:
	if is_destroyed:
		return
	if battlefield == null or bullet_container == null:
		return
	if burst_remaining > 0:
		return

	burst_remaining = clampi(count, 1, GameConfig.MAX_PENDING_COUNT)
	burst_interval = clampf(GameConfig.BURST_FIRE_INTERVAL, 0.04, 0.12)
	burst_timer = 0.0
	_set_burst_locked(true)

func _set_burst_locked(locked: bool) -> void:
	if burst_locked == locked:
		return
	burst_locked = locked
	burst_lock_changed.emit(faction_id, locked)

func _spawn_bullet() -> void:
	var bullet = Bullet.new()
	var shot_direction = Vector2.RIGHT.rotated(rotation + randf_range(-0.03, 0.03))
	var spawn_position = global_position + shot_direction * 21.0 + Vector2.RIGHT.rotated(rotation + PI * 0.5) * sin(sweep_phase * 2.0) * 1.5
	bullet.setup(faction_id, spawn_position, shot_direction, battlefield, all_turrets)
	bullet_container.add_child(bullet)

func take_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = max(0, health - amount)
	damage_flash = 1.0
	queue_redraw()
	if health <= 0:
		_destroy()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	burst_remaining = 0
	_set_burst_locked(false)
	destroyed.emit(faction_id)
	queue_redraw()

func _draw() -> void:
	var color = GameConfig.faction_color(faction_id)
	if is_destroyed:
		color = Color(0.28, 0.28, 0.28)

	if damage_flash > 0.0:
		draw_circle(Vector2.ZERO, GameConfig.TURRET_RADIUS + 7.0, Color(1.0, 1.0, 1.0, 0.38 * damage_flash))

	draw_circle(Vector2(2.4, 2.6), GameConfig.TURRET_RADIUS + 1.0, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2.ZERO, GameConfig.TURRET_RADIUS, color)
	draw_circle(Vector2(-4.0, -4.0), GameConfig.TURRET_RADIUS * 0.34, Color(1.0, 1.0, 1.0, 0.46))
	draw_circle(Vector2.ZERO, GameConfig.TURRET_RADIUS, Color.BLACK, false, 2.2)

	if not is_destroyed:
		var barrel_poly = PackedVector2Array([
			Vector2(2, -5),
			Vector2(31, -5),
			Vector2(34, -1),
			Vector2(34, 1),
			Vector2(31, 5),
			Vector2(2, 5)
		])
		draw_colored_polygon(barrel_poly, color.lightened(0.14))
		draw_polyline(barrel_poly, Color.BLACK, 1.4, true)
		draw_circle(Vector2(4, 0), 5.5, color.darkened(0.15))
		draw_circle(Vector2(4, 0), 5.5, Color.BLACK, false, 1.2)
	else:
		draw_line(Vector2(-12, -12), Vector2(12, 12), Color.BLACK, 4.0)
		draw_line(Vector2(-12, 12), Vector2(12, -12), Color.BLACK, 4.0)

	var bar_w = 48.0
	var bar_h = 6.0
	var bar_pos = Vector2(-bar_w * 0.5, GameConfig.TURRET_RADIUS + 10.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.02, 0.02, 0.02, 0.9), true)
	var ratio = float(health) / float(max_health)
	var hp_color = Color(0.25, 1.0, 0.25)
	if ratio < 0.35:
		hp_color = Color(1.0, 0.18, 0.18)
	elif ratio < 0.65:
		hp_color = Color(1.0, 0.75, 0.12)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), hp_color, true)
