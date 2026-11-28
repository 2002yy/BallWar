extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

var _checks: int = 0
var _main
var _released: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = MainScript.new()
	_main.match_seed = 12345
	_main.selected_grid_size = 20
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	main_setup()
	root.add_child(_main)
	await process_frame
	_main._start_game(20, true, false)
	await process_frame
	var chamber = _main.runtime.chambers[0]
	chamber.release_requested.connect(func(_fid, count, _c): _released.append(int(count)))

	_test_locked_baseline(chamber)
	_test_accumulate(chamber)
	_test_extra_batch(chamber)
	_test_lock_preserves_queue(chamber)
	_test_release_ball_is_frozen(chamber)
	_test_mode_roundtrip(chamber)

	print("[ProductionDecoupling] PASS (%d checks)" % _checks)
	quit(0)


func main_setup() -> void:
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 1


func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		printerr("[ProductionDecoupling] FAIL: %s" % label)
		quit(1)
	return value


func _reset(chamber, mode: String, pending: int = 1) -> void:
	chamber.production_mode = mode
	chamber.queued_volley = 0
	chamber.queued_ball = null
	chamber.is_locked = true
	chamber.chamber_state.is_locked = true
	chamber.pending_count = pending
	chamber.chamber_state.pending_count = pending
	_released.clear()


func _test_locked_baseline(chamber) -> void:
	_reset(chamber, "locked", 5)
	chamber._on_right_gate(chamber.balls[0])
	if not _check(_released.is_empty(), "locked: right gate does not release"):
		return
	chamber.set_locked(false)
	if not _check(chamber.pending_count == 1, "locked: unlock resets pending to 1"):
		return


func _test_accumulate(chamber) -> void:
	_reset(chamber, "accumulate", 5)
	chamber._on_right_gate(chamber.balls[0])
	if not _check(_released.is_empty(), "accumulate: firing period does not release"):
		return
	chamber._on_left_gate(chamber.balls[0])
	var accumulated: int = chamber.pending_count
	if not _check(accumulated >= 1, "accumulate: left gate keeps producing"):
		return
	chamber.set_locked(false)
	if not _check(chamber.pending_count == accumulated, "accumulate: unlock preserves next-round fire"):
		return
	if not _check(_released.is_empty(), "accumulate: unlock does not force a release"):
		return


func _test_extra_batch(chamber) -> void:
	_reset(chamber, "extra_batch", 4)
	chamber._on_right_gate(chamber.balls[0])
	if not _check(chamber.queued_volley == 4, "extra: one batch is cached"):
		return
	if not _check(chamber.pending_count == 1, "extra: pending restarts at 1"):
		return
	chamber._on_right_gate(chamber.balls[0])
	if not _check(chamber.queue_overflow_events == 1, "extra: second batch overflows"):
		return
	chamber.set_locked(false)
	if not _check(_released.size() == 1 and _released[0] == 4, "extra: cached batch fires on unlock"):
		return
	if not _check(chamber.is_locked and chamber.locked_remaining == 4, "extra: cached batch locks the chamber"):
		return
	chamber.queued_volley = 0
	chamber.queued_ball = null
	chamber.set_locked(false)


func _test_lock_preserves_queue(chamber) -> void:
	_reset(chamber, "extra_batch", 4)
	chamber._on_right_gate(chamber.balls[0])
	if not _check(chamber.queued_volley == 4, "lock: queue exists before set_locked(true)"):
		return
	chamber.set_locked(true)
	if not _check(chamber.queued_volley == 4, "lock: set_locked(true) keeps the queue"):
		return
	chamber.clear_queued_volley()
	chamber.set_locked(false)


func _test_release_ball_is_frozen(chamber) -> void:
	_reset(chamber, "accumulate", 3)
	var ball = chamber.balls[0]
	chamber.release_ball = ball
	ball.position = Vector2(10, 10)
	ball.velocity = Vector2(30, 40)
	chamber._physics_process(1.0 / 60.0)
	if not _check(ball.position == Vector2(10, 10), "accumulate: released ball is frozen during firing"):
		return
	chamber.release_ball = null
	chamber.set_locked(false)


func _test_mode_roundtrip(chamber) -> void:
	chamber.production_mode = "extra_batch"
	var state: Dictionary = ChamberSaveAdapter.collect_state(chamber)
	chamber.production_mode = "locked"
	var restored: Dictionary = ChamberSaveAdapter.restore_state(state, {
		"chamber_size": chamber.chamber_size,
		"default_ball_radius": ControlChamber.CONTROL_BALL_RADIUS,
		"max_restore_control_balls": 8,
		"max_control_balls": GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER,
		"max_pending_count": GameConfig.get_max_pending_count(),
	})
	chamber.production_mode = str(restored.get("chamber_production_mode", "locked"))
	if not _check(chamber.production_mode == "extra_batch", "save: production mode survives restore"):
		return
	chamber.production_mode = "locked"
