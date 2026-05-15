extends Area2D
class_name Bullet

var faction_id := 0
var direction := Vector2.RIGHT
var speed := GameConfig.BULLET_SPEED
var battlefield: Battlefield
var last_cell := Vector2i(-999, -999)

func setup(fid: int, pos: Vector2, dir: Vector2, bf: Battlefield) -> void:
	faction_id = fid
	global_position = pos
	direction = dir.normalized()
	battlefield = bf

func _ready() -> void:
	var shape := CircleShape2D.new(); shape.radius = GameConfig.BULLET_RADIUS
	var cs := CollisionShape2D.new(); cs.shape = shape; add_child(cs)
	collision_layer = 0; collision_mask = 0; z_index = 20; queue_redraw()

func _physics_process(delta: float) -> void:
	if battlefield == null: queue_free(); return
	global_position += direction * speed * delta
	var cell := battlefield.world_to_cell(global_position)
	if not battlefield.is_inside(cell): queue_free(); return
	if cell == last_cell: return
	last_cell = cell
	var result := battlefield.apply_bullet(cell, faction_id)
	if result == "HIT_ENEMY_CELL" or result == "OUTSIDE": queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, GameConfig.BULLET_RADIUS, GameConfig.faction_color(faction_id))
	draw_circle(Vector2.ZERO, GameConfig.BULLET_RADIUS, Color.BLACK, false, 1)
