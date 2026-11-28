extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const BLUE := GameConfig.Faction.BLUE
const RED := GameConfig.Faction.RED

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestAssert.new()
	var main := MainScript.new()
	main.match_seed = 31337
	root.add_child(main)
	main.audio_manager.set_enabled(false)

	main._start_game(40, true, false)
	t.eq(main.runtime.reserve_economy, null, "classic starts without a reserve ledger")
	var chamber: ControlChamber = main.runtime.chambers[BLUE]
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 2, "classic add-ball remains free")
	t.that(not chamber._build_draw_snapshot().reserve_rect.has_area(), "classic has no third gate")
	_land(chamber, 400, _reserve_lane_center(chamber))
	t.eq(main.runtime.turrets[BLUE].burst_remaining, 400, "classic right edge still releases all 400 shots")
	t.eq(chamber.get_pending_count(), 1, "classic burst-lock retains its original pending state")

	var slot_path := main._get_save_path(main.selected_save_slot)
	var slot_hash := FileAccess.get_sha256(slot_path) if FileAccess.file_exists(slot_path) else ""
	main._start_game(40, true, true, true)
	var economy: ReserveEconomy = main.runtime.reserve_economy
	chamber = main.runtime.chambers[BLUE]
	var turret: Turret = main.runtime.turrets[BLUE]
	var red_chamber: ControlChamber = main.runtime.chambers[RED]
	var red_turret: Turret = main.runtime.turrets[RED]
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 1, "add-ball requires reserve in experimental matches")
	_land(chamber, 1, _reserve_lane_center(chamber))
	t.eq(chamber.get_pending_count(), 1, "one ready shot stays available for firing")
	t.eq(economy.balance(BLUE), 0, "one shot is too small to convert")
	_land(chamber, 407, _reserve_lane_center(chamber))
	t.eq(turret.burst_remaining, 0, "reserve gate does not fire")
	t.that(not chamber.is_locked, "reserve gate relaunches without locking")
	t.that(chamber.balls[0].position.y < chamber.chamber_size.y / 2.0, "ball returns to top")
	t.eq(chamber.get_pending_count(), 306, "ready firepower after rounding down 25% reserve")
	t.eq(chamber.chamber_state.pending_count, 306, "reserve gate debits the authoritative chamber state")
	t.eq(economy.balance(BLUE), 101, "conversion conserves all 407 shots")
	t.eq(economy.balance(RED), 0, "reserve is scoped to a faction")
	var release_x := _release_lane_center(chamber)
	_land(chamber, chamber.get_pending_count(), release_x)
	t.eq(turret.burst_remaining, 306, "normal gate releases all remaining ready shots")
	t.eq(chamber.get_pending_count(), 306, "experimental burst-lock retains the authoritative pending value")
	t.eq(economy.balance(BLUE), 101, "ordinary fire does not add to reserve")
	_drop(chamber, _reserve_lane_center(chamber))
	t.eq(economy.balance(BLUE), 101, "locked chamber does not run the reserve gate")
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "locked chamber purchase spends nothing")
	turret.cancel_burst()
	chamber.apply_jammed(3.0)
	_land(chamber, 407, _reserve_lane_center(chamber))
	t.eq(economy.balance(BLUE), 101, "jammed floor cannot credit reserve")
	t.eq(chamber.get_pending_count(), 407, "jammed floor leaves ready firepower unchanged")
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "jammed chamber purchase spends nothing")
	t.eq(chamber.get_ball_count(), 1, "jammed chamber gains no ball")
	chamber.set_jammed_time_left(0.0)
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 2, "successful purchase adds exactly one ball")
	t.eq(economy.balance(BLUE), 1, "successful purchase costs 100")
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 2, "second purchase requires a second payment")
	_land(red_chamber, 1604, _reserve_lane_center(red_chamber))
	t.eq(red_chamber.get_pending_count(), 1204, "conversion overflow stays ready")
	t.eq(economy.balance(RED), 400, "reserve is capped at 400 per faction")
	t.eq(economy.balance(BLUE), 1, "red release leaves blue balance unchanged")
	_land(red_chamber, 400, _reserve_lane_center(red_chamber))
	t.eq(red_chamber.get_pending_count(), 400, "a full reserve leaves all firepower ready")
	_land(red_chamber, 400, red_chamber._current_x2_width() / 2.0)
	t.eq(red_chamber.get_pending_count(), 800, "multiplier gate still doubles the ready firepower")
	t.eq(economy.balance(RED), 400, "multiplier gate does not credit reserve")
	main._add_ball_to_chamber(RED)
	red_chamber.set_game_elapsed_time(ControlChamber.GATE_RAMP_SECONDS)
	var draw_snapshot := red_chamber._build_draw_snapshot()
	var reserve_rect: Rect2 = draw_snapshot.reserve_rect
	t.that(reserve_rect.has_area() and reserve_rect.has_point(Vector2(_reserve_lane_center(red_chamber), reserve_rect.get_center().y)),
		"late-game reserve marker follows its physical lane")
	_drop(red_chamber, _reserve_lane_center(red_chamber))
	t.eq(red_chamber.get_pending_count(), 700, "narrow late-game reserve lane stays reachable")
	_drop(red_chamber, _release_lane_center(red_chamber))
	t.eq(red_turret.burst_remaining, 700, "narrow late-game release lane stays reachable")
	red_turret.cancel_burst()
	while red_chamber.get_ball_count() < GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
		if not red_chamber.add_control_ball():
			break
	t.eq(red_chamber.get_ball_count(), GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER, "fixture fills the red chamber")
	main._add_ball_to_chamber(RED)
	t.eq(economy.balance(RED), 400, "full chamber purchase spends nothing")
	_land(chamber, 400, _reserve_lane_center(chamber))
	turret.take_damage(turret.health)
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "damaged chamber with capacity spends nothing")
	t.eq(chamber.get_ball_count(), 0, "damaged chamber remains empty")
	t.eq(turret.burst_remaining, 0, "destroyed turret cannot start a volley")
	t.that(not main._save_game_progress().ok, "experiment refuses the normal save path")
	t.eq(FileAccess.get_sha256(slot_path) if FileAccess.file_exists(slot_path) else "", slot_hash,
		"experiment does not create, erase, or overwrite the selected normal slot")

	main._start_game(40, true, false, true)
	t.eq(main.runtime.reserve_economy.balance(RED), 0, "new experiment resets the reserve ledger")
	main._start_game(40, true, false)
	t.eq(main.runtime.reserve_economy, null, "new classic match discards the experiment ledger")
	main._start_game(40, true, true, false, ReserveEconomy.PricePreset.STANDARD, 2)
	chamber = main.runtime.chambers[BLUE]
	t.eq(chamber._build_draw_snapshot().left_gate_text, "+2", "additive gate has its own label")
	t.that(not chamber._build_draw_snapshot().reserve_rect.has_area(), "additive lab opens only two gates")
	_drop(chamber, chamber._current_x2_width() / 2.0)
	t.eq(chamber.pending_count, 3, "additive landing grows 1 to 3")
	_drop(chamber, chamber._current_x2_width() / 2.0)
	t.eq(chamber.chamber_state.pending_count, 5, "second landing adds two to the authoritative count")
	_land(chamber, GameConfig.get_max_pending_count() - 1, chamber._current_x2_width() / 2.0)
	t.eq(chamber.pending_count, GameConfig.get_max_pending_count(), "additive landing respects the pending cap")
	_land(chamber, 5, _release_lane_center(chamber))
	turret = main.runtime.turrets[BLUE]
	t.eq(turret.burst_remaining, 5, "release gate fires the accumulated additive volley")
	turret.cancel_burst()
	t.eq(chamber.pending_count, 1, "burst completion resets the additive round")
	t.that(not main._save_game_progress().ok, "additive lab declines ordinary save")
	t.eq(FileAccess.get_sha256(slot_path) if FileAccess.file_exists(slot_path) else "", slot_hash,
		"additive lab does not create, erase, or overwrite the selected normal slot")
	main.queue_free()
	await process_frame
	t.report("ReserveEconomyTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _reserve_lane_center(chamber: ControlChamber) -> float:
	var right_end := chamber.chamber_size.x
	var split := lerpf(chamber._current_x2_width(), right_end, 0.5)
	return (split + right_end) / 2.0

func _release_lane_center(chamber: ControlChamber) -> float:
	var left := chamber._current_x2_width()
	return lerpf(left, chamber.chamber_size.x, 0.25)

func _land(chamber: ControlChamber, firepower: int, x: float) -> void:
	chamber.pending_count = firepower
	_drop(chamber, x)

func _drop(chamber: ControlChamber, x: float) -> void:
	var ball: ControlBall = chamber.balls[0]
	ball.position = Vector2(x, chamber.chamber_size.y - ball.radius - 1.0)
	ball.velocity = Vector2(0.0, 120.0)
	chamber._physics_process(1.0 / 60.0)
