extends SceneTree

const BLUE := GameConfig.Faction.BLUE
const RED := GameConfig.Faction.RED

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestAssert.new()
	var main = load("res://scenes/Main.tscn").instantiate()
	main.match_seed = 7341
	root.add_child(main)
	main.audio_manager.set_enabled(false)
	main._start_game(40, true, false)
	var pool: BulletPool = main.runtime.bullet_pool
	t.eq(pool.collision_resolver, null, "classic continues to use independent projectiles")
	t.that(not pool.is_physics_processing(), "classic does not schedule the collision phase")

	main.collision_lab_enabled = true
	main._start_game(40, true, false)
	var field: Battlefield = main.runtime.battlefield
	pool = main.runtime.bullet_pool
	t.eq(main.runtime.match_config.weapon_ruleset_id, WeaponRuleset.COLLISION_LAB_ID, "the match selects the experimental ruleset")
	t.that(not main._save_game_progress().ok, "experimental games cannot write normal saves")
	var initial_counts := field.count_cells_by_team()

	main._launch_collision_duel()
	t.eq(pool.get_active_count(), 16, "the experiment starts with eight standard shots on each side")
	var starting_shot: Bullet = pool.get_active_bullets()[0]
	t.that(not starting_shot.is_physics_processing(), "pool-owned bullets cannot run their own step")
	pool._physics_process(0.5)
	t.that(is_equal_approx(starting_shot.age, MatchClock.STEP_SECONDS), "pool ignores engine delta and advances one fixed step")
	for step in range(45):
		pool._physics_process(MatchClock.STEP_SECONDS)
	t.eq(pool.get_active_count(), 0, "the 8v8 projectiles cancel before crossing into rival territory")
	t.eq(pool.collision_resolver.removed_projectiles, 16, "all sixteen removals came from collisions")
	t.eq(field.count_cells_by_team(), initial_counts, "intercepted shots do not capture tiles")

	# Across two buckets at tick end. The projectiles touch midway through the step.
	var a := _spawn(pool, field, BLUE, Vector2(75, 75), Vector2.RIGHT)
	var b := _spawn(pool, field, RED, Vector2(108, 75), Vector2.LEFT)
	a.speed = 2400.0
	b.speed = 2400.0
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.eq(pool.collision_resolver.removed_projectiles, 18, "a swept crossing between endpoints cancels both fast test shots")

	# Initially touching, then finishing in buckets two apart at standard speed.
	a = _spawn(pool, field, BLUE, Vector2(66.7, 79), Vector2.LEFT)
	b = _spawn(pool, field, RED, Vector2(76.3, 79), Vector2.RIGHT)
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.eq(pool.collision_resolver.removed_projectiles, 20, "search includes both shot travel and physical radii across buckets")

	var first := _spawn(pool, field, BLUE, Vector2(78, 80), Vector2.RIGHT)
	var second := _spawn(pool, field, BLUE, Vector2(78, 84), Vector2.RIGHT)
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(first.is_active and second.is_active, "same-faction projectiles pass through one another")
	var opposite := _spawn(pool, field, RED, Vector2(85, 82), Vector2.LEFT)
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(not first.is_active and not second.is_active and not opposite.is_active, "all simultaneous enemy contacts are removed")
	t.eq(pool.collision_resolver.removed_projectiles, 23, "simultaneous removal counts each projectile only once")
	t.eq(field.count_cells_by_team(), initial_counts, "the removed enemy shot cannot capture the landing tile")
	t.eq(pool.inactive_bullets.size(), 16, "reused projectiles return once to the pool")

	main.queue_free()
	await process_frame
	t.report("ProjectileCollisionTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _spawn(pool: BulletPool, field: Battlefield, faction: int, position: Vector2, direction: Vector2) -> Bullet:
	return pool.spawn_bullet(faction, field.to_global(position), direction, field)
