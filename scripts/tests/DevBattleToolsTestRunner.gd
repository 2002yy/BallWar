extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const Goal = DevBattleTools.Goal
const Action = DevBattleTools.Action

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScript.new()
	main.match_seed = 12345
	root.add_child(main)
	if not _check(main.dev_speed != null, "isolated tool session"):
		return
	main._start_game(40, true, false)
	var panel = main.dev_speed
	var clock: MatchClock = panel.clock

	panel.start_advance(Goal.TIME, 0.25, -1)
	await _until_stopped(panel, 120)
	if not _check(paused and clock.ticks == 15 and clock.speed == 1, "time goal stops at tick 15"):
		return
	panel.start_advance(Goal.FIRST_SHOT, 0, -1)
	await _until_stopped(panel, 900)
	if not _check(paused and main.runtime.bullet_pool.peak_active_count > 0, "first shot stops the simulation"):
		return
	panel.start_advance(Goal.NEXT_EVENT, 0, -1)
	await _until_stopped(panel, 5000)
	if not _check(paused and main.runtime.event_controller.last_event_effect != "", "natural event is applied before stopping"):
		return
	panel.start_advance(Goal.TIME, 300, -1)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	if not _check(not panel._tools.is_advancing() and not paused and clock.speed == 1, "Esc cancels advance while running"):
		return

	main._start_game(40, true, false)
	main._toggle_pause()
	var chamber: ControlChamber = main.runtime.chambers[0]
	var turret: Turret = main.runtime.turrets[0]
	if not _check(panel.construct(Action.ADD_BALLS, 0, 2) and chamber.balls.size() == 3, "add two control balls"):
		return
	if not _check(panel.construct(Action.FIRE_BURST, 0, 128) and turret.burst_remaining == 128 and chamber.is_locked, "128 shots use the regular burst"):
		return
	if not _check(not panel.construct(Action.ADD_BALLS, 0, 1) and chamber.balls.size() == 3, "locked chamber does not report phantom balls"):
		return
	if not _check(panel.construct(Action.TRIGGER_EVENT, 0, 0) and main.runtime.event_controller.is_presenting_event, "trigger random event immediately"):
		return
	if not _check(panel.construct(Action.SET_HEALTH, 0, 24) and turret.health == 24, "adjust turret health"):
		return
	panel.start_advance(Goal.LOW_HEALTH, 50, 0)
	if not _check(paused and not panel._tools.is_advancing(), "health goal reads faction turret"):
		return
	if not _check(panel.construct(Action.DENSE_BULLETS, 0, 2800) and main.runtime.bullet_pool.active_bullets.size() == 2800, "dense scenario uses all 2800 valid slots"):
		return
	clock.request_step()
	for i in range(4):
		await physics_frame
	if not _check(main.runtime.bullet_pool.active_bullets.size() >= 2700, "dense fixture persists through a physics step"):
		return
	panel.start_advance(Goal.ACTIVE_BULLETS, 2700, -1)
	if not _check(paused and not panel._tools.is_advancing(), "bullet threshold stops at current boundary"):
		return
	panel.start_advance(Goal.TERRITORY, 25, 0)
	if not _check(paused and not panel._tools.is_advancing(), "territory goal uses actual ownership"):
		return
	if not _check(panel.construct(Action.DESTROY_TURRET, 1, 0) and main.runtime.turrets[1].is_destroyed, "destroy via normal damage signal"):
		return
	panel.start_advance(Goal.FIRST_DESTROY, 0, -1)
	if not _check(paused and not panel._tools.is_advancing(), "destroyed turret satisfies first-destroy goal"):
		return
	panel.construct(Action.DESTROY_TURRET, 2, 0)
	panel.start_advance(Goal.GAME_OVER, 0, -1)
	var last_opponent: Turret = main.runtime.turrets[3]
	last_opponent.take_damage(last_opponent.health)
	if not _check(main.is_game_over and clock.speed == 1 and not panel._tools.is_advancing() and panel._constructed, "game over stops acceleration and keeps the constructed marker"):
		return
	main._save_and_exit_to_menu()
	if not _check(not paused and not panel._constructed and main.menu_layer != null, "menu clears debug state"):
		return
	print("[DevBattleTools] PASS")
	quit(0)

func _until_stopped(panel, limit: int) -> void:
	for i in range(limit):
		if not panel._tools.is_advancing():
			return
		await physics_frame

func _check(value: bool, label: String) -> bool:
	print("[DevBattleTools] %s %s" % ["OK" if value else "FAIL", label])
	if not value:
		quit(1)
	return value
