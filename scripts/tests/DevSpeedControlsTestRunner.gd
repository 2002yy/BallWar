extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = MainScript.new()
	main.match_seed = 12345
	root.add_child(main)
	if not _check(main.dev_speed != null, "isolated session enables developer controls"):
		return
	main._start_game(40, true, false)
	var panel = main.dev_speed
	var clock: MatchClock = panel.clock
	panel._toggle.pressed.emit()
	if not _check(panel._panel.visible, "toggle opens panel"):
		return
	panel._speed_buttons[20].pressed.emit()
	if not _check(clock.speed == 20 and Engine.physics_ticks_per_second == 1200, "20x engine schedule"):
		return
	panel._pause.pressed.emit()
	var start_tick: int = clock.ticks
	var start_time: float = main.game_elapsed_time
	await _frames(4)
	if not _check(paused and clock.ticks == start_tick, "pause freezes the match"):
		return
	panel._step.pressed.emit()
	panel._step.pressed.emit()
	await _frames(4)
	if not _check(paused and clock.ticks == start_tick + 1, "one requested tick"):
		return
	if not _check(is_equal_approx(main.game_elapsed_time - start_time, MatchClock.STEP_SECONDS), "single step uses 1/60s"):
		return
	panel._pause.pressed.emit()
	await _frames(4)
	if not _check(not paused and clock.ticks > start_tick + 1, "resume advances the match"):
		return
	main._start_game(40, true, false)
	if not _check(clock.speed == 1 and Engine.time_scale == 1.0 and clock.ticks == 0, "new game restores 1x"):
		return
	clock.set_speed(5)
	main._save_and_exit_to_menu()
	if not _check(clock.speed == 1 and Engine.physics_ticks_per_second == 60 and main.menu_layer != null, "menu restores 1x"):
		return
	print("[DevSpeedControls] PASS")
	quit(0)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _check(value: bool, label: String) -> bool:
	print("[DevSpeedControls] %s %s" % ["OK" if value else "FAIL", label])
	if not value:
		quit(1)
	return value
