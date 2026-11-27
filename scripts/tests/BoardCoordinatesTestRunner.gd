extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const STEP: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = MainScript.new()
	main.match_seed = 12345
	root.add_child(main)
	main._start_game(40, true, false)
	paused = true

	_set_logical_view(main, Vector2(1120, 720))
	var base := _measure_projectiles(main)
	_set_logical_view(main, Vector2(1900, 1350))
	_check(is_equal_approx(main._board_transform().get_scale().x, 1.45), "1.45x display path is active")
	var scaled := _measure_projectiles(main)
	print("[BoardCoordinates] 1x=%s 1.45x=%s" % [base, scaled])
	_check(is_equal_approx(float(base.travel), 108.0) and is_equal_approx(float(scaled.travel), 108.0), "108 px per fixed simulation second")
	_check(base.cell == scaled.cell and base.cell == Vector2i(12, 10), "same final battlefield cell")
	_check(is_equal_approx(float(base.muzzle), 35.0) and is_equal_approx(float(scaled.muzzle), 35.0), "same muzzle offset")
	_check(base.hit and scaled.hit, "same hit at 22 battlefield px")
	_check(not base.miss and not scaled.miss, "same miss at 26 battlefield px")

	var field: Battlefield = main.runtime.battlefield
	var pool: BulletPool = main.runtime.bullet_pool
	var original_field_position: Vector2 = field.position
	var bounce_reference := _bounce(main)
	field.position += Vector2(31, 42)
	var bounce_translated := _bounce(main)
	_check(bounce_reference.is_equal_approx(bounce_translated) and bounce_reference.x < 0.0,
		"near-axis rebound independent of simulation-origin translation")
	field.position = original_field_position
	pool.clear_active()

	await _set_window(main, Vector2i(1920, 1080))
	var source_view: Vector2 = main._view_size
	var source_pos := Vector2(112, 130)
	var source_tail := Vector2(103, 130)
	var bullet: Bullet = pool.spawn_bullet(0, field.to_global(source_pos), Vector2.RIGHT, field, {})
	bullet.replace_trail_points([field.to_global(source_pos), field.to_global(source_tail)])
	var before: Vector2 = bullet.global_position
	var before_trail: Array = bullet.trail_points.duplicate()
	var canvas_before: Transform2D = field.get_global_transform_with_canvas()

	# Real save writer and reader, with a unique name distinct from game slots.
	var template: String = "user://a2_coord_check_%d_" + str(Time.get_ticks_usec()) + ".save"
	var saved: Dictionary = SaveFlowController.write_game_progress_result(
		1, template, 1, main.runtime.chambers, main.runtime.turrets, field, pool,
		main.runtime.event_controller, 0.0, false, main._hud_ref("winner_label"))
	_check(bool(saved.get("ok", false)), "save through production writer")
	var prepared := SaveFlowController.prepare_continue_payload(1, 1, 1, template, "", false, "")
	_check(bool(prepared.get("ok", false)), "read and validate new save")
	var states: Array = prepared.get("data", {}).get("bullets", [])
	_check(states.size() == 1 and states[0].get("position_space") == SaveGameCodec.BULLET_BATTLEFIELD_SPACE
		and SaveGameCodec.arr_to_vec2(states[0].position).is_equal_approx(source_pos),
		"disk payload uses tagged battlefield coordinates")

	await _set_window(main, Vector2i(1120, 720))
	var target_view: Vector2 = main._view_size
	print("[BoardCoordinates] windows 1920×1080 / 1120×720 -> layouts %s / %s" % [source_view, target_view])
	var canvas_after := field.get_global_transform_with_canvas()
	_check(not canvas_before.is_equal_approx(canvas_after), "resize changes visible board origin")
	_check(before.is_equal_approx(bullet.global_position) and before_trail == bullet.trail_points,
		"resize preserves active projectile and stored trail positions")
	var trail_layer: BulletTrailLayer = pool.trail_layer
	var screen_tail: Vector2 = trail_layer.get_global_transform_with_canvas() * trail_layer.to_local(bullet.trail_points[1])
	_check(screen_tail.is_equal_approx(canvas_after * source_tail), "old trail point follows new display transform")
	var buttons: Dictionary = main._ui_runtime_ref("add_ball_buttons", {})
	_check(buttons[0].get_parent().layer > main.board_root.layer, "input CanvasLayer is above the board")
	if DisplayServer.get_name() != "headless":
		_check_resize_input(main, buttons[0])

	if bool(prepared.get("ok", false)):
		main._continue_from_prepared_payload(prepared)
		paused = true
		main._process_pending_bullet_restore()
		_validate_continue(main, source_pos, source_tail)

	var old_state: Dictionary = {
		"faction_id": 0,
		"position": SaveGameCodec.vec2_to_arr(before),
		"direction": [1.0, 0.0],
		"trail_points": [SaveGameCodec.vec2_to_arr(before_trail[1])],
	}
	var legacy_field: Battlefield = main.runtime.battlefield
	var legacy: Bullet = main.runtime.bullet_pool.spawn_bullet_from_state(old_state, legacy_field, {})
	_check(legacy.global_position.is_equal_approx(before) and legacy.trail_points[0] == before_trail[1],
		"untagged legacy saves retain canonical world coordinates")
	var full_path := SaveFlowController.get_save_path(1, template, 1)
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(full_path))
	print("[BoardCoordinates] %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL", _checks])
	quit(0 if _failures == 0 else 1)


func _set_logical_view(main, size: Vector2) -> void:
	main._view_size = size
	main._apply_board_transform()


func _set_window(main, pixels: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		var height: float = 720.0
		_set_logical_view(main, Vector2(maxf(1120.0, float(pixels.x) / pixels.y * height), height))
	else:
		root.size = pixels
		for i in range(6):
			await process_frame
		_check(root.size == pixels, "actual Windows resolution %s" % pixels)


func _measure_projectiles(main) -> Dictionary:
	var field: Battlefield = main.runtime.battlefield
	var pool: BulletPool = main.runtime.bullet_pool
	var turrets: Dictionary = main.runtime.turrets
	pool.clear_active()
	var projectile: Bullet = pool.spawn_bullet(0, field.to_global(Vector2(60, 130)), Vector2.RIGHT, field, {})
	for i in range(60):
		projectile._physics_process(STEP)
	var travel: float = field.to_local(projectile.global_position).x - 60.0
	var cell: Vector2i = field.world_to_cell(projectile.global_position)
	var turret: Turret = turrets[0]
	turret.cancel_burst()
	turret.rotation = 0.0
	turret.fire_burst(1)
	turret._spawn_bullet()
	var muzzle: Bullet = pool.get_active_bullets().back()
	var offset: float = field.to_local(muzzle.global_position).distance_to(field.to_local(turret.global_position))
	var enemy: Turret = turrets[1]
	var enemy_pos: Vector2 = field.to_local(enemy.global_position)
	var hit_probe: Bullet = pool.spawn_bullet(0, field.to_global(enemy_pos + Vector2(-22, 0)), Vector2.RIGHT, field, turrets)
	var miss_probe: Bullet = pool.spawn_bullet(0, field.to_global(enemy_pos + Vector2(-26, 0)), Vector2.RIGHT, field, turrets)
	var hit: bool = hit_probe._try_hit_enemy_turret()
	var miss: bool = miss_probe._try_hit_enemy_turret()
	return {"travel": travel, "cell": cell, "muzzle": offset, "hit": hit, "miss": miss}


func _bounce(main) -> Vector2:
	var field: Battlefield = main.runtime.battlefield
	var edge: float = field.grid_size * field.cell_size - 1
	var bullet: Bullet = main.runtime.bullet_pool.spawn_bullet(
		1, field.to_global(Vector2(edge, 245)), Vector2(1, 0.001), field, {})
	bullet._physics_process(STEP)
	return bullet.direction


func _check_resize_input(main, button: Control) -> void:
	var chamber: ControlChamber = main.runtime.chambers[0]
	var initial: int = chamber.balls.size()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	paused = false
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)
	paused = true
	_check(chamber.balls.size() == initial + 1, "Windows mouse reaches the resized add-ball button")

func _validate_continue(main, source_pos: Vector2, source_tail: Vector2) -> void:
	var restored: Array = main.runtime.bullet_pool.get_active_bullets()
	_check(restored.size() == 1, "continue restores one projectile")
	if restored.size() != 1:
		return
	var bullet: Bullet = restored[0]
	var field: Battlefield = main.runtime.battlefield
	_check(field.to_local(bullet.global_position).is_equal_approx(source_pos), "save/continue preserves battlefield position")
	_check(bullet.trail_points.size() == 2 and field.to_local(bullet.trail_points[1]).is_equal_approx(source_tail),
		"save/continue preserves battlefield trail coordinates")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[BoardCoordinates] %s %s" % ["OK" if ok else "FAIL", label])
