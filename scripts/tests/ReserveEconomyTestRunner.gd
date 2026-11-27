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
	_release(chamber, 400)
	t.eq(main.runtime.turrets[BLUE].burst_remaining, 400, "classic releases all 400 shots")

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
	_release(chamber, 1)
	t.eq(turret.burst_remaining, 1, "one ready shot is still fired")
	t.eq(economy.balance(BLUE), 0, "one shot is too small to convert")
	turret.cancel_burst()
	_release(chamber, 407)
	t.eq(turret.burst_remaining, 306, "firepower after rounding down 25% reserve")
	t.eq(economy.balance(BLUE), 101, "conversion conserves all 407 shots")
	t.eq(economy.balance(RED), 0, "reserve is scoped to a faction")
	main._on_chamber_release_requested(BLUE, 407, chamber)
	t.eq(economy.balance(BLUE), 101, "duplicate release cannot credit a live burst")
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "locked chamber purchase spends nothing")
	turret.cancel_burst()
	chamber.apply_jammed(3.0)
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "jammed chamber purchase spends nothing")
	t.eq(chamber.get_ball_count(), 1, "jammed chamber gains no ball")
	chamber.set_jammed_time_left(0.0)
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 2, "successful purchase adds exactly one ball")
	t.eq(economy.balance(BLUE), 1, "successful purchase costs 100")
	main._add_ball_to_chamber(BLUE)
	t.eq(chamber.get_ball_count(), 2, "second purchase requires a second payment")
	_release(red_chamber, 1604)
	t.eq(red_turret.burst_remaining, 1204, "conversion overflow stays in the ready volley")
	t.eq(economy.balance(RED), 400, "reserve is capped at 400 per faction")
	t.eq(economy.balance(BLUE), 1, "red release leaves blue balance unchanged")
	red_turret.cancel_burst()
	_release(red_chamber, 400)
	t.eq(red_turret.burst_remaining, 400, "a full reserve leaves all firepower ready")
	red_turret.cancel_burst()
	while red_chamber.get_ball_count() < GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
		if not red_chamber.add_control_ball():
			break
	t.eq(red_chamber.get_ball_count(), GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER, "fixture fills the red chamber")
	main._add_ball_to_chamber(RED)
	t.eq(economy.balance(RED), 400, "full chamber purchase spends nothing")
	_release(chamber, 400)
	turret.cancel_burst()
	turret.take_damage(turret.health)
	main._add_ball_to_chamber(BLUE)
	t.eq(economy.balance(BLUE), 101, "damaged chamber with capacity spends nothing")
	t.eq(chamber.get_ball_count(), 0, "damaged chamber remains empty")
	main._on_chamber_release_requested(BLUE, 407, chamber)
	t.eq(economy.balance(BLUE), 101, "destroyed turret cannot credit reserve")
	t.eq(turret.burst_remaining, 0, "destroyed turret cannot start a volley")
	t.that(not main._save_game_progress().ok, "experiment refuses the normal save path")
	t.eq(FileAccess.get_sha256(slot_path) if FileAccess.file_exists(slot_path) else "", slot_hash,
		"experiment does not create, erase, or overwrite the selected normal slot")

	main._start_game(40, true, false, true)
	t.eq(main.runtime.reserve_economy.balance(RED), 0, "new experiment resets the reserve ledger")
	main._start_game(40, true, false)
	t.eq(main.runtime.reserve_economy, null, "new classic match discards the experiment ledger")
	main.queue_free()
	await process_frame
	t.report("ReserveEconomyTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _release(chamber: ControlChamber, firepower: int) -> void:
	chamber.pending_count = firepower
	chamber._on_right_gate(chamber.balls[0])
