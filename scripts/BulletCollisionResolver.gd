extends RefCounted
class_name BulletCollisionResolver

# P1-C1 空间分桶互撞：只处理"不同阵营的炮弹相互抵消"。
# 同阵营穿过（不检测），领土/炮台/边界仍由 Bullet 自己按原规则结算。
#
# 顺序契约：调用方先让所有弹 advance_tick()，再调用 resolve()，最后 resolve_tick()。
# 命中是同时判定的：本 tick 所有命中对先收集，再统一回收，避免"先结算谁"的偏差。

const DEFAULT_BUCKET_CELLS: int = 1

var bucket_size: float = 13.0
var bucket_cells: int = DEFAULT_BUCKET_CELLS
var last_stats: Dictionary = {}
var total_hits: int = 0
var total_bucket_pairs: int = 0
var total_distance_checks: int = 0
var total_near_misses: int = 0
var track_near_misses: bool = false

var _buckets: Dictionary = {}
var _max_travel: float = 0.0

func configure(cell_size: float, cells: int = DEFAULT_BUCKET_CELLS) -> void:
	bucket_cells = maxi(1, cells)
	bucket_size = maxf(cell_size * float(bucket_cells), 4.0)

func reset_stats() -> void:
	total_hits = 0
	total_bucket_pairs = 0
	total_distance_checks = 0
	total_near_misses = 0
	last_stats = {}

func resolve(bullets: Array, pool, delta: float) -> int:
	build_index(bullets, delta)
	return scan_and_resolve(bullets, pool)

func build_index(bullets: Array, delta: float) -> void:
	_buckets.clear()
	_max_travel = 0.0
	last_stats = {
		"bullet_count": 0,
		"buckets": 0,
		"max_bucket": 0,
		"bucket_pairs": 0,
		"faction_skips": 0,
		"distance_checks": 0,
		"hits": 0,
		"search_radius": 1,
	}

	for i in range(bullets.size()):
		var bullet = bullets[i]
		if not _alive(bullet):
			continue
		last_stats["bullet_count"] = int(last_stats["bullet_count"]) + 1
		_max_travel = maxf(_max_travel, bullet.speed * delta)
		var key: Vector2i = _bucket_of(bullet.global_position)
		var bucket = _buckets.get(key)
		if bucket == null:
			bucket = []
			_buckets[key] = bucket
		bucket.append(i)

	last_stats["buckets"] = _buckets.size()
	for key in _buckets:
		last_stats["max_bucket"] = maxi(int(last_stats["max_bucket"]), _buckets[key].size())
	# 一步内的相向位移可能超过一个桶：搜索半径随相对位移放大。
	# 普通速度下恒为 1（3×3 邻域），高速时自动扩大，避免跨桶漏判。
	var search_radius: int = maxi(1, ceili((_max_travel * 2.0) / bucket_size))
	last_stats["search_radius"] = search_radius

func scan_and_resolve(bullets: Array, pool) -> int:
	var hits: Dictionary = find_hits(bullets)
	# 同时回收：先收全，再删，顺序不影响结果。
	for bullet_id in hits:
		var bullet = hits[bullet_id]
		if _alive(bullet):
			pool.recycle_bullet(bullet)
	total_hits += hits.size()
	return hits.size()

func find_hits(bullets: Array) -> Dictionary:
	var hits: Dictionary = {}
	var radius: int = int(last_stats.get("search_radius", 1))
	for i in range(bullets.size()):
		var a = bullets[i]
		if not _alive(a):
			continue
		var key: Vector2i = _bucket_of(a.global_position)
		for offset_x in range(-radius, radius + 1):
			for offset_y in range(-radius, radius + 1):
				var bucket = _buckets.get(key + Vector2i(offset_x, offset_y))
				if bucket == null:
					continue
				for j in bucket:
					if j <= i:
						continue
					var b = bullets[j]
					if not _alive(b):
						continue
					last_stats["bucket_pairs"] = int(last_stats["bucket_pairs"]) + 1
					total_bucket_pairs += 1
					if a.faction_id == b.faction_id:
						last_stats["faction_skips"] = int(last_stats["faction_skips"]) + 1
						continue
					last_stats["distance_checks"] = int(last_stats["distance_checks"]) + 1
					total_distance_checks += 1
					if _collides(a, b):
						hits[a.get_instance_id()] = a
						hits[b.get_instance_id()] = b
					elif track_near_misses and _near(a, b):
						total_near_misses += 1

	last_stats["hits"] = hits.size()
	return hits

func _collides(a, b) -> bool:
	var radius_sum: float = a.physical_radius + b.physical_radius
	var rel_now: Vector2 = a.global_position - b.global_position
	var dist_sq: float = rel_now.length_squared()
	if dist_sq <= radius_sum * radius_sum:
		return true
	# 相对位移不足以穿越接触圆时，端点判定已经足够；普通弹永远走这里。
	var reach: float = radius_sum + _max_travel * 2.0
	if dist_sq > reach * reach:
		return false
	var rel_prev: Vector2 = a.prev_position - b.prev_position
	return _segment_point_distance_sq(rel_prev, rel_now, Vector2.ZERO) <= radius_sum * radius_sum

func _near(a, b) -> bool:
	# 实验指标：两颗敌弹是否曾接近到 3 倍接触距离（未命中）。
	var reach: float = (a.physical_radius + b.physical_radius) * 3.0
	return a.global_position.distance_squared_to(b.global_position) <= reach * reach

func _segment_point_distance_sq(start: Vector2, end: Vector2, point: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.000001:
		return start.distance_squared_to(point)
	var t: float = clampf((point - start).dot(segment) / length_sq, 0.0, 1.0)
	return (start + segment * t).distance_squared_to(point)

func _bucket_of(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / bucket_size), floori(position.y / bucket_size))

func _alive(bullet) -> bool:
	return bullet != null and is_instance_valid(bullet) and bullet.is_active
