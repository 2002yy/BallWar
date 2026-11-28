extends RefCounted
class_name BulletCollisionResolver

# Adapted from the C1 prototype on #34. Resolve all contacts in the snapshot
# before recycling anything, so each projectile uses the same tick's state.
var removed_projectiles: int = 0

var _bucket_size: float
var _buckets: Dictionary = {}
var _largest_radius: float

func _init(bucket_size: float) -> void:
	_bucket_size = bucket_size

func resolve(bullets: Array, pool: BulletPool) -> void:
	var max_travel := 0.0
	_largest_radius = 0.0
	_buckets.clear()
	for i in range(bullets.size()):
		var bullet: Bullet = bullets[i]
		var key := _bucket_of(bullet.global_position)
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(i)
		max_travel = maxf(max_travel, bullet.prev_position.distance_to(bullet.global_position))
		_largest_radius = maxf(_largest_radius, bullet.physical_radius)

	var hits := {}
	for i in range(bullets.size()):
		var a: Bullet = bullets[i]
		var finish := a.global_position
		var reach := Vector2.ONE * (a.physical_radius + _largest_radius + max_travel)
		var first := _bucket_of(a.prev_position.min(finish) - reach)
		var last := _bucket_of(a.prev_position.max(finish) + reach)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var bucket = _buckets.get(Vector2i(x, y))
				if bucket == null:
					continue
				for j in bucket:
					if j <= i:
						continue
					var b: Bullet = bullets[j]
					if a.faction_id != b.faction_id and _collides(a, b):
						hits[i] = a
						hits[j] = b

	for bullet in hits.values():
		pool.recycle_bullet(bullet)
	removed_projectiles += hits.size()

func _collides(a: Bullet, b: Bullet) -> bool:
	var start := a.prev_position - b.prev_position
	var finish := a.global_position - b.global_position
	var movement := finish - start
	var length_sq := movement.length_squared()
	var closest := start
	if length_sq > 0.0:
		closest += movement * clampf(-start.dot(movement) / length_sq, 0.0, 1.0)
	var radius_sum := a.physical_radius + b.physical_radius
	return closest.length_squared() <= radius_sum * radius_sum

func _bucket_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _bucket_size), floori(position.y / _bucket_size))
