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

	_check_velocity(main, t)
	main.queue_free()
	await process_frame
	t.report("ProjectileCollisionTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _check_velocity(main, t: TestAssert) -> void:
	main.velocity_lab_enabled = true
	main._start_game(40, true, false)
	var field: Battlefield = main.runtime.battlefield
	var pool: BulletPool = main.runtime.bullet_pool
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	var turret: Turret = main.runtime.turrets[BLUE]
	var velocity := WeaponRuleset.BulletType.VELOCITY
	var standard := WeaponRuleset.BulletType.STANDARD
	t.eq(main.runtime.match_config.weapon_ruleset_id, WeaponRuleset.VELOCITY_LAB_ID, "the launch selects the velocity ruleset")
	t.eq(main._build_volley(5), {velocity: 2, standard: 1}, "five firepower buys two velocity and one standard shot")
	t.eq(main._build_volley(1), {standard: 1}, "a single point still produces standard ammunition")

	# Land a real control ball in the release gate, then manually step the turret.
	chamber.pending_count = 5
	var control: ControlBall = chamber.balls[0]
	var release_x := lerpf(chamber._current_x2_width(), chamber.chamber_size.x, 0.25)
	control.position = Vector2(release_x, chamber.chamber_size.y - control.radius - 1.0)
	control.velocity = Vector2(0, 120)
	chamber._physics_process(MatchClock.STEP_SECONDS)
	t.eq(chamber.locked_remaining, 3, "the chamber lock reports physical shots")
	t.eq(turret.remaining_firepower(), 5, "initial burst stores its full firepower value")
	turret._physics_process(MatchClock.STEP_SECONDS)
	t.eq(turret.remaining_firepower(), 4, "one ordinary shot spends one point")
	chamber.cancel_current_burst_with_refund(0.5)
	t.eq(chamber.pending_count, 2, "a jam refunds half the unspent firepower")
	t.eq(turret.burst_remaining, 0, "cancel clears the typed queue")

	main._on_chamber_release_requested(BLUE, 5, chamber)
	for step in range(8):
		turret._physics_process(MatchClock.STEP_SECONDS)
	var rounds: Array = pool.get_active_bullets()
	var types: Array = []
	for bullet in rounds:
		types.append(bullet.type_id)
	t.eq(types, [standard, standard, velocity, velocity], "normal turret fire creates the paid projectile types in stable order")
	t.that(not chamber.is_locked, "the normal burst unlocks the chamber after its three shots")
	pool.clear_active()

	var fast: Bullet = _spawn(pool, field, BLUE, Vector2(258, 91), Vector2.RIGHT, velocity)
	t.eq([fast.speed, fast.physical_radius, fast.turret_damage], [324.0, 3.0, 2], "fast projectile uses the lab profile")
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(fast.is_active and fast.capture_budget == 1, "the first enemy tile spends one of two captures")
	for step in range(3):
		pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(not fast.is_active, "the second capture consumes the velocity projectile")
	t.eq([field.owners[20][7], field.owners[21][7]], [BLUE, BLUE], "the shot captures successive enemy tiles")
	var reused := _spawn(pool, field, BLUE, Vector2(253, 189), Vector2.RIGHT)
	t.eq(reused, fast, "the pool reuses the previously fired velocity projectile")
	t.eq([reused.type_id, reused.speed, reused.physical_radius, reused.capture_budget, reused.turret_damage, reused.collision_mass],
		[standard, GameConfig.BULLET_SPEED, GameConfig.BULLET_RADIUS, 1, GameConfig.BULLET_DAMAGE, 1.0], "reuse resets every projectile property")
	var light: Bullet = _spawn(pool, field, RED, Vector2(267, 189), Vector2.LEFT, velocity)
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(reused.is_active and not light.is_active, "a normal projectile intercepts a lighter velocity projectile and survives")
	pool.clear_active()

	var left: Bullet = _spawn(pool, field, BLUE, Vector2(257, 201), Vector2.RIGHT, velocity)
	var right: Bullet = _spawn(pool, field, RED, Vector2(263, 206.9), Vector2.LEFT, velocity)
	pool._physics_process(MatchClock.STEP_SECONDS)
	t.that(not left.is_active and not right.is_active, "swept grazing velocity shots cancel even though both endpoints miss")

	var target: Turret = main.runtime.turrets[RED]
	var health := target.health
	var attacker: Bullet = pool.spawn_bullet(BLUE, target.global_position, Vector2.LEFT, field, {RED: target}, velocity)
	t.that(attacker._try_hit_enemy_turret(), "a velocity projectile can hit a turret")
	t.eq(target.health, health - 2, "the fast round deals two damage")

func _spawn(pool: BulletPool, field: Battlefield, faction: int, position: Vector2, direction: Vector2, type_id: int = WeaponRuleset.BulletType.STANDARD) -> Bullet:
	return pool.spawn_bullet(faction, field.to_global(position), direction, field, {}, type_id)
