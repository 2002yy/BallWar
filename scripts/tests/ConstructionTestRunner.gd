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
	var roster: TurretRoster = main.runtime.turret_roster
	var field: Battlefield = main.runtime.battlefield
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	var primary: Turret = main.runtime.turrets[BLUE]
	t.neq(primary.turret_id, primary.faction_id, "tower identity is separate from faction")
	t.eq(roster.by_id.size(), 4, "all main towers have unique identities")
	t.eq(roster.by_id[primary.turret_id], primary, "tower is indexed by its own identity")
	var build_button: EnergyButton = main._ui_runtime_ref("add_ball_buttons", {})[BLUE]
	var site := Vector2i(9, 8)
	t.eq(main.get_node("MainBackground").mouse_filter, Control.MOUSE_FILTER_IGNORE, "decorative background leaves the board pickable")
	t.that(build_button.disabled, "starting construction balance is insufficient")
	t.eq(chamber._build_draw_snapshot().resource_gate_label, "建", "construction gate is labelled")
	t.that(not main._try_build_auxiliary(BLUE, site), "cannot build without materials")
	chamber.pending_count = 200
	var divider := chamber._reserve_gate_x(chamber._current_x2_width())
	_land(chamber, lerpf(divider, chamber.chamber_size.x, 0.5))
	t.eq(state.balance(BLUE), 50, "construction gate converts 25 percent")
	t.eq(chamber.pending_count, 150, "only the converted portion is removed")
	t.eq(state.balance(RED), 0, "materials are faction-specific")
	t.that(not build_button.disabled, "50 materials enables the build button")

	build_button.pressed.emit()
	t.eq(state.balance(BLUE), 50, "opening placement does not spend materials")
	t.eq(main._construction_preview.cell, state.auxiliary_cell(BLUE, field.grid_size), "opening placement shows the suggested cell")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	main._unhandled_input(escape)
	t.eq(main._construction_preview, null, "Escape clears the preview without building")
	t.eq(state.balance(BLUE), 50, "cancelling does not spend materials")
	build_button.pressed.emit()
	t.that(not main._try_build_auxiliary(BLUE, Vector2i(-1, 8)), "off-board build is rejected")
	var primary_cell := field.world_to_cell(primary.global_position)
	t.eq(main._construction_site_issue(BLUE, primary_cell), "太靠近炮塔", "occupied area is marked unavailable")
	# The board presentation is scaled and translated independently of simulation.
	main.board_root.transform = Transform2D(0.0, Vector2(1.45, 1.45), 0.0, Vector2(91, 47))
	var motion := InputEventMouseMotion.new()
	motion.position = _screen_cell(field, site)
	main._unhandled_input(motion)
	t.eq(main._construction_preview.cell, site, "hover maps the scaled screen point to the intended cell")
	t.eq(main._construction_preview.issue, "", "owned and clear site previews as allowed")
	field.claim_cell(site, RED)
	field.flush_score_emit()
	t.eq(main._construction_preview.issue, "非己方领土", "preview revalidates when a cell is captured")
	var click := InputEventMouseButton.new()
	click.position = motion.position
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main._unhandled_input(click)
	t.eq(state.auxiliary_id(BLUE), 0, "enemy-owned site rejects confirmation")
	t.eq(state.balance(BLUE), 50, "failed placement does not debit materials")
	field.claim_cell(site, BLUE)
	var enemy := Bullet.new()
	var ally := Bullet.new()
	enemy.setup(RED, Vector2.ZERO, Vector2.RIGHT, field, roster.by_id)
	ally.setup(BLUE, Vector2.ZERO, Vector2.RIGHT, field, roster.by_id)
	var tap := InputEventScreenTouch.new()
	tap.position = motion.position
	tap.pressed = true
	main._unhandled_input(tap)
	t.eq(state.balance(BLUE), 50, "first touch only selects the cell")
	main._unhandled_input(tap)
	var auxiliary: Turret = roster.live_turret(state.auxiliary_id(BLUE))
	t.that(auxiliary != null, "second touch confirms construction")
	t.eq(auxiliary.faction_id, primary.faction_id, "both towers belong to the same faction")
	t.gt(auxiliary.turret_id, primary.turret_id, "auxiliary receives a distinct tower identity")
	t.eq(main._construction_preview, null, "successful build clears the preview")
	t.eq(field.world_to_cell(auxiliary.global_position), site, "auxiliary is placed at the chosen non-default cell")
	t.eq(state.balance(BLUE), 0, "successful build charges exactly 50")
	t.eq(auxiliary.health * 2, primary.health, "auxiliary starts at half main health")
	state.convert_pending(200, BLUE)
	t.that(not main._try_build_auxiliary(BLUE, site + Vector2i(2, 2)), "cannot exceed one auxiliary")
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
	t.eq(main.runtime.bullet_pool.tracked_queue_by_slot[auxiliary.turret_id], 150, "queue stores the auxiliary demand under its identity")
	t.eq(main.runtime.bullet_pool.tracked_queue_by_slot[primary.turret_id], 0, "main tower queue stays independent")
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
	t.eq(roster.by_id[primary.turret_id], primary, "promotion does not rewrite the destroyed tower identity")
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

	main._start_game(40, true, false, false, ReserveEconomy.PricePreset.STANDARD, 0, true)
	var new_roster: TurretRoster = main.runtime.turret_roster
	t.neq(new_roster, roster, "a fresh match has its own roster")
	t.eq(new_roster.by_id.size(), 4, "new match keeps no old auxiliary IDs")
	state = main.runtime.construction
	chamber = main.runtime.chambers[BLUE]
	primary = main.runtime.turrets[BLUE]
	state.convert_pending(200, BLUE)
	t.that(main._try_build_auxiliary(BLUE, site), "new match can deploy an auxiliary")
	auxiliary = new_roster.live_turret(state.auxiliary_id(BLUE))
	chamber.pending_count = 6
	_land(chamber, fire_lane)
	auxiliary.cancel_burst()
	chamber.pending_count = 9
	_land(chamber, fire_lane)
	t.eq(primary.burst_remaining, 9, "main tower is firing when hit")
	primary.take_damage(primary.health)
	t.that(not chamber.is_locked and not chamber.is_damaged, "active tower loss unlocks the surviving faction")
	t.eq(main.runtime.bullet_pool.get_tracked_queue_total(), 0, "undelivered shots are discarded with the destroyed tower")
	chamber.pending_count = 4
	_land(chamber, fire_lane)
	t.eq(auxiliary.burst_remaining, 4, "the survivor fires a fresh volley without inheriting the old queue")
	t.eq(new_roster.live_turret(primary.turret_id), null, "destroyed identity is excluded from live selection")

	_check_neutral_facility(main, t, site)
	main.queue_free()
	await process_frame
	t.report("ConstructionTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _screen_cell(field: Battlefield, cell: Vector2i) -> Vector2:
	return field.get_global_transform_with_canvas() * ((Vector2(cell) + Vector2(0.5, 0.5)) * field.cell_size)

func _check_neutral_facility(main, t: TestAssert, site: Vector2i) -> void:
	main.facility_lab_enabled = true
	main._start_game(40, true, false, false, ReserveEconomy.PricePreset.STANDARD, 0, true)
	var field: Battlefield = main.runtime.battlefield
	var roster: TurretRoster = main.runtime.turret_roster
	var state: ConstructionState = main.runtime.construction
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	var primary: Turret = main.runtime.turrets[BLUE]
	var neutral := roster.next_live_turret(Turret.NEUTRAL_FACTION)
	var neutral_id := neutral.turret_id
	var neutral_health := neutral.health
	t.eq(main.runtime.turrets.size(), 4, "neutral tower is not an extra faction")
	t.eq(field.to_local(neutral.global_position), Vector2.ONE * field.grid_size * field.cell_size * 0.5, "neutral tower starts at the geometric center")
	state.convert_pending(200, BLUE)
	t.that(main._try_build_auxiliary(BLUE, site), "the facility match still permits regular construction")
	var auxiliary := roster.live_turret(state.auxiliary_id(BLUE))
	var red_turret: Turret = main.runtime.turrets[RED]
	red_turret.take_damage(red_turret.health)
	var stray := Bullet.new()
	stray.setup(RED, neutral.global_position, Vector2.RIGHT, field, roster.by_id)
	t.that(not stray._try_hit_enemy_turret(), "a projectile from an eliminated faction cannot claim the tower")
	t.eq(neutral.faction_id, Turret.NEUTRAL_FACTION, "unclaimed tower remains neutral")
	var claimant := Bullet.new()
	claimant.setup(BLUE, neutral.global_position, Vector2.RIGHT, field, roster.by_id)
	t.that(claimant._try_hit_enemy_turret(), "a live faction claims the tower through the projectile path")
	t.eq(neutral.faction_id, BLUE, "neutral tower joins the attacking faction")
	t.eq(neutral.turret_id, neutral_id, "capture keeps the tower identity")
	t.eq(neutral.health, neutral_health, "the capture hit does not damage the tower")
	var cell := field.world_to_cell(neutral.global_position)
	t.eq(field.owners[cell.x][cell.y], BLUE, "capture marks the installation tile for the new owner")
	t.eq(roster.next_live_turret(Turret.NEUTRAL_FACTION), null, "the neutral roster is now empty")
	t.that(not claimant._try_hit_enemy_turret(), "friendly projectiles skip the captured tower")
	t.that(stray._try_hit_enemy_turret(), "enemy projectiles damage a captured tower")
	t.eq(neutral.health, neutral_health - GameConfig.BULLET_DAMAGE, "damage applies to the existing captured tower")
	claimant.free()
	stray.free()

	var release_x := lerpf(chamber._current_x2_width(), chamber.chamber_size.x, 0.25)
	for tower in [auxiliary, neutral, primary, auxiliary]:
		chamber.pending_count = 19
		_land(chamber, release_x)
		t.eq(tower.burst_remaining, 19, "the three-tower rotation routes exactly one full volley")
		t.eq(main.runtime.bullet_pool.get_tracked_queue_total(), 19, "three towers do not duplicate faction firepower")
		tower.cancel_burst()
	primary.take_damage(primary.health)
	auxiliary.take_damage(auxiliary.health)
	t.that(not chamber.is_damaged, "the captured tower keeps the faction alive")
	t.eq(main.runtime.turrets[BLUE], neutral, "captured tower becomes the faction representative")
	chamber.pending_count = 5
	_land(chamber, release_x)
	t.eq(neutral.burst_remaining, 5, "captured tower receives the next volley")
	for faction in [GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var opponent: Turret = main.runtime.turrets[faction]
		opponent.take_damage(opponent.health)
	t.that(main.is_game_over and not chamber.is_damaged, "the faction can win with only the captured tower")
	t.eq(neutral.burst_remaining, 0, "end of match stops the captured tower")

func _land(chamber: ControlChamber, x: float) -> void:
	var ball: ControlBall = chamber.balls[0]
	ball.position = Vector2(x, chamber.chamber_size.y - ball.radius - 1.0)
	ball.velocity = Vector2(0, 120)
	chamber._physics_process(1.0 / 60.0)
