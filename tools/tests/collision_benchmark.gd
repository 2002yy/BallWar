extends SceneTree

# P1 互撞性能原型（不是 CI runner，不进 test.yml）：
#   godot --headless --path . --script res://tools/tests/collision_benchmark.gd
#
# 只测"分桶 + 配对 + 回收"这一段，不含炮弹移动与绘制。
# 分布：均匀 / 战线密集 / 极端聚集；规模：600 / 1800 / 2800。
# 另外验证：跨桶命中、重复配对、高速扫掠、同阵营穿过。

const GRID_SIZE: int = 40
const ITERATIONS: int = 30
const BUCKET_CELLS: int = 1
const SEED_VALUE: int = 20261128

var _rng := RandomNumberGenerator.new()
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[CollisionBench] grid=%d iterations=%d bucket_cells=%d" % [GRID_SIZE, ITERATIONS, BUCKET_CELLS])
	_rng.seed = SEED_VALUE
	_run_matrix()
	_run_bucket_comparison()
	_run_correctness_probes()
	print("[CollisionBench] failures=%d" % _failures)
	quit(0 if _failures == 0 else 1)

func _run_matrix() -> void:
	for bullet_count in [600, 1800, 2800]:
		for scenario in ["uniform", "front", "extreme"]:
			var positions: Array = _make_positions(scenario, bullet_count)
			_measure(scenario, bullet_count, positions, BUCKET_CELLS)

func _run_bucket_comparison() -> void:
	var positions: Array = _make_positions("uniform", 1800)
	_measure("uniform", 1800, positions, 2)

func _make_positions(scenario: String, count: int) -> Array:
	var positions: Array = []
	for i in range(count):
		match scenario:
			"front":
				positions.append(Vector2(40.0 + _rng.randf() * 440.0, 252.0 + _rng.randf() * 16.0))
			"extreme":
				positions.append(Vector2(232.0 + _rng.randf() * 72.0, 224.0 + _rng.randf() * 72.0))
			_:
				positions.append(Vector2(_rng.randf() * 520.0, _rng.randf() * 520.0))
	return positions

func _measure(scenario: String, count: int, positions: Array, bucket_cells: int) -> void:
	var battlefield := Battlefield.new()
	battlefield.configure(GRID_SIZE)
	battlefield.reset_quadrants()

	var pool := BulletPool.new()
	pool.set_battlefield(battlefield)
	pool.collision_enabled = true
	pool.collision_resolver.configure(float(battlefield.cell_size), bucket_cells)

	var build_usec: Array[float] = []
	var scan_usec: Array[float] = []
	var recycle_usec: Array[float] = []
	var total_usec: Array[float] = []
	var pairs: int = 0
	var checks: int = 0
	var hits: int = 0
	var buckets: int = 0
	var max_bucket: int = 0
	var search_radius: int = 1

	for iteration in range(ITERATIONS):
		pool.clear_active()
		while pool.get_active_count() < count:
			var index: int = pool.get_active_count()
			var position: Vector2 = positions[index]
			var faction: int = index % 4
			var direction: Vector2 = Vector2.RIGHT if index % 2 == 0 else Vector2.LEFT
			var bullet = pool.spawn_bullet(faction, position, direction, battlefield, {})
			bullet.prev_position = position
			bullet.set_physics_process(false)

		var t0: int = Time.get_ticks_usec()
		pool.collision_resolver.build_index(pool.active_bullets, 1.0 / 60.0)
		var t1: int = Time.get_ticks_usec()
		var detected: Dictionary = pool.collision_resolver.find_hits(pool.active_bullets)
		var t2: int = Time.get_ticks_usec()
		for bullet_id in detected:
			var hit_bullet = detected[bullet_id]
			if hit_bullet != null and is_instance_valid(hit_bullet) and hit_bullet.is_active:
				pool.recycle_bullet(hit_bullet)
		var t3: int = Time.get_ticks_usec()

		var stats: Dictionary = pool.collision_resolver.last_stats
		if iteration == 0:
			pairs = int(stats["bucket_pairs"])
			checks = int(stats["distance_checks"])
			hits = int(stats["hits"])
			buckets = int(stats["buckets"])
			max_bucket = int(stats["max_bucket"])
			search_radius = int(stats.get("search_radius", 1))
		build_usec.append(float(t1 - t0))
		scan_usec.append(float(t2 - t1))
		recycle_usec.append(float(t3 - t2))
		total_usec.append(float(t3 - t0))

	pool.clear_active()
	pool.free()
	battlefield.free()

	print("[CollisionBench] n=%d scenario=%s bucket_cells=%d buckets=%d max_bucket=%d search_radius=%d pairs=%d checks=%d hits=%d build_p50=%.2fms build_p95=%.2fms detect_p50=%.2fms detect_p95=%.2fms recycle_p50=%.2fms total_p50=%.2fms total_p95=%.2fms total_p99=%.2fms" % [
		count, scenario, bucket_cells, buckets, max_bucket, search_radius,
		pairs, checks, hits,
		_percentile(build_usec, 0.50) / 1000.0,
		_percentile(build_usec, 0.95) / 1000.0,
		_percentile(scan_usec, 0.50) / 1000.0,
		_percentile(scan_usec, 0.95) / 1000.0,
		_percentile(recycle_usec, 0.50) / 1000.0,
		_percentile(total_usec, 0.50) / 1000.0,
		_percentile(total_usec, 0.95) / 1000.0,
		_percentile(total_usec, 0.99) / 1000.0,
	])

func _run_correctness_probes() -> void:
	_probe_cross_bucket()
	_probe_pair_dedup()
	_probe_swept_high_speed()
	_probe_same_faction_passes()

func _probe_cross_bucket() -> void:
	var battlefield := Battlefield.new()
	battlefield.configure(GRID_SIZE)
	battlefield.reset_quadrants()
	var pool := BulletPool.new()
	pool.set_battlefield(battlefield)
	pool.collision_enabled = true
	pool.collision_resolver.configure(float(battlefield.cell_size), 1)
	var left = pool.spawn_bullet(0, Vector2(12.5, 100.0), Vector2.RIGHT, battlefield, {})
	var right = pool.spawn_bullet(1, Vector2(13.5, 100.0), Vector2.LEFT, battlefield, {})
	left.prev_position = left.global_position
	right.prev_position = right.global_position
	var hits: int = pool.collision_resolver.resolve(pool.active_bullets, pool, 1.0 / 60.0)
	_expect(hits == 2, "cross-bucket: two bullets 1px apart across a bucket edge must collide (hits=%d)" % hits)
	pool.free()
	battlefield.free()

func _probe_pair_dedup() -> void:
	var battlefield := Battlefield.new()
	battlefield.configure(GRID_SIZE)
	battlefield.reset_quadrants()
	var pool := BulletPool.new()
	pool.set_battlefield(battlefield)
	pool.collision_enabled = true
	pool.collision_resolver.configure(float(battlefield.cell_size), 1)
	for faction in range(4):
		var bullet = pool.spawn_bullet(faction, Vector2(100.0 + float(faction), 100.0), Vector2.RIGHT, battlefield, {})
		bullet.prev_position = bullet.global_position
	pool.collision_resolver.resolve(pool.active_bullets, pool, 1.0 / 60.0)
	var stats: Dictionary = pool.collision_resolver.last_stats
	_expect(int(stats["bucket_pairs"]) == 6, "pair dedup: 4 bullets must produce 6 pairs once (pairs=%d)" % int(stats["bucket_pairs"]))
	_expect(int(stats["hits"]) == 4, "pair dedup: all four bullets are removed (hits=%d)" % int(stats["hits"]))
	pool.free()
	battlefield.free()

func _probe_swept_high_speed() -> void:
	var battlefield := Battlefield.new()
	battlefield.configure(GRID_SIZE)
	battlefield.reset_quadrants()
	var pool := BulletPool.new()
	pool.set_battlefield(battlefield)
	pool.collision_enabled = true
	pool.collision_resolver.configure(float(battlefield.cell_size), 1)
	var a = pool.spawn_bullet(0, Vector2(100.0, 100.0), Vector2.RIGHT, battlefield, {})
	var b = pool.spawn_bullet(1, Vector2(140.0, 100.0), Vector2.LEFT, battlefield, {})
	# 16.7× 基准速度：一步各自移动 30px，两端点相距 20px 且已经交错，
	# 端点判定必然漏判，只有扫掠检测能抓到。当前弹种远达不到这个速度。
	a.speed = 1800.0
	b.speed = 1800.0
	a.prev_position = a.global_position
	b.prev_position = b.global_position
	a.advance_tick(1.0 / 60.0)
	b.advance_tick(1.0 / 60.0)
	# 一步跨过 24px，两端点都不在 10px 接触圈内；只有扫掠检测能抓到。
	var hits: int = pool.collision_resolver.resolve(pool.active_bullets, pool, 1.0 / 60.0)
	_expect(hits == 2, "swept: 1800px/s head-on pass-through must be detected (hits=%d)" % hits)
	pool.free()
	battlefield.free()

func _probe_same_faction_passes() -> void:
	var battlefield := Battlefield.new()
	battlefield.configure(GRID_SIZE)
	battlefield.reset_quadrants()
	var pool := BulletPool.new()
	pool.set_battlefield(battlefield)
	pool.collision_enabled = true
	pool.collision_resolver.configure(float(battlefield.cell_size), 1)
	var a = pool.spawn_bullet(0, Vector2(100.0, 100.0), Vector2.RIGHT, battlefield, {})
	var b = pool.spawn_bullet(0, Vector2(104.0, 100.0), Vector2.LEFT, battlefield, {})
	a.prev_position = a.global_position
	b.prev_position = b.global_position
	var hits: int = pool.collision_resolver.resolve(pool.active_bullets, pool, 1.0 / 60.0)
	_expect(hits == 0, "same faction: bullets pass through (hits=%d)" % hits)
	pool.free()
	battlefield.free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[CollisionBench] PASS %s" % message)
	else:
		_failures += 1
		printerr("[CollisionBench] FAIL %s" % message)

func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(int(round(ratio * float(sorted.size() - 1))), 0, sorted.size() - 1)
	return sorted[index]
