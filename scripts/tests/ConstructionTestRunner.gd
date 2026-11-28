extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const BLUE := GameConfig.Faction.BLUE
const RED := GameConfig.Faction.RED

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestAssert.new()
	var main := MainScript.new()
	main.match_seed = 7341
	root.add_child(main)
	main.audio_manager.set_enabled(false)
	var path := main._get_save_path(main.selected_save_slot)
	var starting_hash := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	main._start_game(40, true, true, false, ReserveEconomy.PricePreset.STANDARD, 0, true)
	var state: ConstructionState = main.runtime.construction
	var field: Battlefield = main.runtime.battlefield
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	var primary: Turret = main.runtime.turrets[BLUE]
	var build_button: EnergyButton = main._ui_runtime_ref("add_ball_buttons", {})[BLUE]
	t.that(build_button.disabled, "starting construction balance is insufficient")
	t.eq(chamber._build_draw_snapshot().resource_gate_label, "建", "construction gate is labelled")
	t.that(not main._try_build_auxiliary(BLUE), "cannot build without materials")
	chamber.pending_count = 200
	var divider := chamber._reserve_gate_x(chamber._current_x2_width())
	_land(chamber, lerpf(divider, chamber.chamber_size.x, 0.5))
	t.eq(state.balance(BLUE), 50, "construction gate converts 25 percent")
	t.eq(chamber.pending_count, 150, "only the converted portion is removed")
	t.eq(state.balance(RED), 0, "materials are faction-specific")
	t.that(not build_button.disabled, "50 materials enables the build button")

	var site := state.auxiliary_cell(BLUE, field.grid_size)
	field.claim_cell(site, RED)
	t.that(not main._try_build_auxiliary(BLUE), "enemy-owned site rejects construction")
	t.eq(state.balance(BLUE), 50, "failed placement does not debit materials")
	field.claim_cell(site, BLUE)
	var enemy := Bullet.new()
	var ally := Bullet.new()
	enemy.setup(RED, Vector2.ZERO, Vector2.RIGHT, field, state.targets)
	ally.setup(BLUE, Vector2.ZERO, Vector2.RIGHT, field, state.targets)
	build_button.pressed.emit()
	var auxiliary: Turret = state.live_turret(state.auxiliary_slot(BLUE))
	t.that(auxiliary != null, "existing build button creates the auxiliary")
	t.eq(field.world_to_cell(auxiliary.global_position), site, "auxiliary shares the battlefield coordinate system")
	t.eq(state.balance(BLUE), 0, "successful build charges exactly 50")
	t.eq(auxiliary.health * 2, primary.health, "auxiliary starts at half main health")
	state.convert_pending(200, BLUE)
	t.that(not main._try_build_auxiliary(BLUE), "cannot exceed one auxiliary")
	t.eq(state.balance(BLUE), 50, "duplicate build does not charge")
	enemy.global_position = auxiliary.global_position
	ally.global_position = auxiliary.global_position
	t.that(not ally._try_hit_enemy_turret(), "same faction projectiles ignore auxiliary slots")
	var health := auxiliary.health
	t.that(enemy._try_hit_enemy_turret(), "an already created enemy projectile sees the new auxiliary")
	t.eq(auxiliary.health, health - GameConfig.BULLET_DAMAGE, "projectile damage reaches the auxiliary")
	enemy.free()
	ally.free()

	var fire_lane := lerpf(chamber._current_x2_width(), chamber.chamber_size.x, 0.25)
	_land(chamber, fire_lane)
	t.eq(auxiliary.burst_remaining, 150, "auxiliary takes the first volley")
	t.eq(primary.burst_remaining, 0, "shared volley is not duplicated")
	t.eq(main.runtime.bullet_pool.get_tracked_queue_total(), 150, "queue tracks the active auxiliary separately")
	auxiliary.cancel_burst()
	chamber.pending_count = 5
	_land(chamber, fire_lane)
	t.eq(primary.burst_remaining, 5, "the next volley rotates back to the main tower")
	primary.cancel_burst()
	chamber.pending_count = 7
	_land(chamber, fire_lane)
	t.eq(chamber.locked_remaining, 7, "the shared chamber starts with the routed volley count")
	primary.take_damage(primary.health)
	t.that(not chamber.is_damaged and chamber.is_locked, "losing the idle primary leaves the in-flight auxiliary order intact")
	t.eq(chamber.locked_remaining, 7, "idle tower destruction does not overwrite active progress")
	t.eq(main.runtime.bullet_pool.get_tracked_queue_total(), 7, "idle tower destruction does not drain the active queue")
	t.eq(main.runtime.turrets[BLUE], auxiliary, "survivor becomes the faction representative")
	auxiliary.cancel_burst()
	chamber.pending_count = 3
	_land(chamber, fire_lane)
	t.eq(auxiliary.burst_remaining, 3, "the surviving tower can fire again")
	auxiliary.take_damage(auxiliary.health)
	t.that(chamber.is_damaged, "only the last destroyed tower eliminates its faction")
	for faction in [GameConfig.Faction.RED, GameConfig.Faction.GREEN]:
		var opponent: Turret = main.runtime.turrets[faction]
		opponent.take_damage(opponent.health)
	t.that(main.is_game_over, "game ends when one faction remains")
	t.that(not main._save_game_progress().ok, "construction experiment cannot save to an ordinary slot")
	t.eq(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "", starting_hash, "ordinary slot stays intact")

	main.queue_free()
	await process_frame
	t.report("ConstructionTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _land(chamber: ControlChamber, x: float) -> void:
	var ball: ControlBall = chamber.balls[0]
	ball.position = Vector2(x, chamber.chamber_size.y - ball.radius - 1.0)
	ball.velocity = Vector2(0, 120)
	chamber._physics_process(1.0 / 60.0)
