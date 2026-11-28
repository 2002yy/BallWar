extends RefCounted
class_name FortressTerrain

const CONTACT_OFFSET: float = 0.01
const MAX_REFLECTIONS: int = 4
const WALL_HEALTH: int = 3

var wall_rects: Array[Rect2] = []
var wall_cells: Dictionary = {}
var wall_health: Dictionary = {}
var breakable: bool
var _cell_size: int

func _init(grid_size: int, cell_size: int, walls_breakable: bool = false) -> void:
	breakable = walls_breakable
	_cell_size = cell_size
	var center := grid_size >> 1
	var gap := clampi(ceili(28.0 / cell_size), 2, center - 2)
	for x in [center - gap - 2, center + gap]:
		for y in [center - gap - 2, center + gap]:
			var wall := Rect2(x * cell_size, y * cell_size, 2 * cell_size, 2 * cell_size)
			wall_rects.append(wall)
			if breakable:
				wall_health[wall] = WALL_HEALTH
			for dx in range(2):
				for dy in range(2):
					wall_cells[Vector2i(x + dx, y + dy)] = true

func first_wall_hit(start: Vector2, movement: Vector2) -> Rect2:
	var first_wall := Rect2()
	var first_entry := INF
	for wall in wall_rects:
		var entry := _wall_entry(start, movement, wall).x
		if entry < first_entry:
			first_entry = entry
			first_wall = wall
	return first_wall

# Returns the newly available cells if this hit destroys the wall.
func damage_wall(wall: Rect2, damage: int) -> Array[Vector2i]:
	var opened: Array[Vector2i] = []
	wall_health[wall] -= damage
	if wall_health[wall] > 0:
		return opened
	wall_health.erase(wall)
	wall_rects.erase(wall)
	var origin := Vector2i(wall.position / _cell_size)
	var size := Vector2i(wall.size / _cell_size)
	for dx in range(size.x):
		for dy in range(size.y):
			var cell := origin + Vector2i(dx, dy)
			wall_cells.erase(cell)
			opened.append(cell)
	return opened

func has_turret_clearance(position: Vector2, distance: float) -> bool:
	for wall in wall_rects:
		var nearest := position.clamp(wall.position, wall.end)
		if nearest.distance_squared_to(position) <= distance * distance:
			return false
	return true

func reflect_motion(start: Vector2, movement: Vector2) -> Vector4:
	var position := start
	var remaining := movement
	var heading := movement.normalized()
	for attempt in range(MAX_REFLECTIONS):
		var closest := Vector3(INF, 0, 0)
		for wall in wall_rects:
			var hit := _wall_entry(position, remaining, wall)
			if hit.x < closest.x:
				closest = hit
		if not is_finite(closest.x):
			position += remaining
			break
		var normal := Vector2(closest.y, closest.z)
		position += remaining * closest.x + normal * CONTACT_OFFSET
		var flip := Vector2(-1.0 if normal.x != 0 else 1.0, -1.0 if normal.y != 0 else 1.0)
		remaining *= flip * (1.0 - closest.x)
		heading *= flip
	return Vector4(position.x, position.y, heading.x, heading.y)

# The first component is the entry fraction. The others identify the hit face.
func _wall_entry(start: Vector2, movement: Vector2, wall: Rect2) -> Vector3:
	var entry := -INF
	var exit := INF
	var normal := Vector2.ZERO
	for axis in range(2):
		if is_zero_approx(movement[axis]):
			if start[axis] < wall.position[axis] or start[axis] > wall.end[axis]:
				return Vector3(INF, 0, 0)
			continue
		var first := (wall.position[axis] - start[axis]) / movement[axis]
		var second := (wall.end[axis] - start[axis]) / movement[axis]
		var axis_entry := minf(first, second)
		exit = minf(exit, maxf(first, second))
		if axis_entry > entry and not is_equal_approx(axis_entry, entry):
			entry = axis_entry
			normal = Vector2.ZERO
			normal[axis] = -signf(movement[axis])
		elif is_equal_approx(axis_entry, entry):
			normal[axis] = -signf(movement[axis])
	if entry < 0.0 or entry > 1.0 or entry > exit:
		return Vector3(INF, 0, 0)
	return Vector3(entry, normal.x, normal.y)
