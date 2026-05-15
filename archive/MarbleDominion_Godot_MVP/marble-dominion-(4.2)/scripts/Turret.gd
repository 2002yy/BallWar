extends Node2D
class_name Turret

var faction_id := 0
var battlefield: Battlefield
var bullet_container: Node2D
var turn_speed := 0.8
var turn_timer := 0.0
var spread := 0.16

func setup(fid: int, pos: Vector2, bf: Battlefield, container: Node2D) -> void:
	faction_id = fid
	global_position = pos
	battlefield = bf
	bullet_container = container

func _ready() -> void:
	randomize(); rotation = randf_range(0, TAU); _pick_new_turn_speed(); z_index = 15; queue_redraw()

func _process(delta: float) -> void:
	turn_timer -= delta
	if turn_timer <= 0: _pick_new_turn_speed()
	rotation += turn_speed * delta

func _pick_new_turn_speed() -> void:
	turn_speed = randf_range(-1.6, 1.6)
	turn_timer = randf_range(0.4, 1.6)

func fire_burst(count: int) -> void:
	if battlefield == null or bullet_container == null: return
	count = clampi(count, 1, GameConfig.MAX_PENDING_COUNT)
	for i in range(count):
		var b := Bullet.new()
		var offset := randf_range(-spread, spread)
		if count > 1: offset += lerp(-spread, spread, float(i) / max(1.0, float(count - 1))) * 0.7
		var dir := Vector2.RIGHT.rotated(rotation + offset)
		b.setup(faction_id, global_position + dir * 18, dir, battlefield)
		bullet_container.add_child(b)

func _draw() -> void:
	var c := GameConfig.faction_color(faction_id)
	draw_circle(Vector2.ZERO, GameConfig.TURRET_RADIUS, c)
	draw_circle(Vector2.ZERO, GameConfig.TURRET_RADIUS, Color.BLACK, false, 2)
	draw_rect(Rect2(0, -4, 28, 8), c.lightened(0.2), true)
	draw_rect(Rect2(0, -4, 28, 8), Color.BLACK, false, 1)
