extends SceneTree

var _failures: Array[String] = []
var _passes: int = 0

class DummyMain extends RefCounted:
	var current_score_counts: Dictionary = {}
	var game_elapsed_time: float = 0.0
	var selected_grid_size: int = 40
	var is_game_over: bool = false

	func _init() -> void:
		current_score_counts = {
			GameConfig.Faction.BLUE: 25,
			GameConfig.Faction.RED: 15,
			GameConfig.Faction.GREEN: 10,
			GameConfig.Faction.YELLOW: 50,
		}

	func _show_center_banner(_title: String, _body: String, _color: Color, _important: bool) -> void:
		pass

	func _refresh_add_ball_button(_faction_id: int) -> void:
		pass

class DummyCancelableTurret extends Node:
	var remaining: int = 0

	func cancel_burst() -> int:
		return remaining

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("[SmokeTest] Starting BallWar smoke tests")
	await process_frame

	_test_save_game_codec_defaults()
	_test_event_roulette_intervals_and_weights()
	await _test_control_chamber_event_rules()
	await _test_restore_from_state_interfaces()
	_test_turret_cancel_burst()
	_test_bullet_restore_from_state()
	_test_bullet_pool_incremental_metrics()
	await _flush_test_cleanup()

	if _failures.is_empty():
		print("[SmokeTest] PASS (%d checks)" % _passes)
		quit(0)
		return

	push_error("[SmokeTest] FAIL (%d failures)" % _failures.size())
	for failure in _failures:
		push_error(failure)
	quit(1)

func _cleanup_node(node: Node) -> void:
	if node == null:
		return
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.queue_free()
	else:
		node.free()

func _cleanup_object(object) -> void:
	if object == null:
		return
	if not is_instance_valid(object):
		return
	if object is Node:
		_cleanup_node(object as Node)
		return
	if object.has_method("free"):
		object.free()

func _flush_test_cleanup() -> void:
	await process_frame
	await process_frame

func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		return
	_failures.append(message)

func _assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		_passes += 1
		return
	_failures.append("%s | expected=%s actual=%s" % [message, str(expected), str(actual)])

func _test_save_game_codec_defaults() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	var raw: Dictionary = {
		"save_version": "1.9.35",
		"grid_size": 40,
		"quality_name": "bad_quality",
		"game_mode_name": "bad_mode",
		"time_limit_minutes": 999,
		"bullets": "bad_bullets",
		"event_state": {
			"next_event_time_left": -5.0,
			"reroll_count": 99,
		},
		"factions": [
			{
				"faction_id": 9,
				"chamber_pending_count": 99999,
				"queued_round_modifiers": "bad_modifiers",
			}
		],
	}
	var clean: Dictionary = SaveGameCodec.validate_save_data(raw)

	_assert_eq(clean.get("game_mode_name", ""), GameConfig.GAME_MODE_BASIC, "save codec should normalize invalid game mode")
	_assert_true(str(clean.get("quality_name", "")) in GameConfig.get_quality_names(), "save codec should normalize invalid quality name")
	_assert_eq(int(clean.get("time_limit_minutes", 0)), GameConfig.TIMED_MODE_MAX_MINUTES, "save codec should clamp timed mode minutes")
	_assert_true(clean.get("bullets", []) is Array, "save codec should normalize bullet list")
	_assert_true(clean.get("event_state", {}) is Dictionary, "save codec should preserve event_state dictionary")
	_assert_eq(float(clean["event_state"].get("next_event_time_left", 999.0)), 0.0, "save codec should clamp negative event countdown")
	_assert_eq(int(clean["event_state"].get("reroll_count", -1)), 2, "save codec should clamp reroll count")
	_assert_eq(int(clean["factions"][0].get("faction_id", -1)), 3, "save codec should clamp faction id")
	_assert_true(clean["factions"][0].get("queued_round_modifiers", null) is Array, "save codec should normalize queued_round_modifiers")
	_assert_eq(float(clean["factions"][0].get("chamber_jammed_time_left", -1.0)), 0.0, "save codec should default chamber jammed time")

func _test_event_roulette_intervals_and_weights() -> void:
	var controller: EventRouletteController = EventRouletteController.new()
	var dummy_main: DummyMain = DummyMain.new()
	var dummy_battlefield: Node = Node.new()
	controller.main_ref = dummy_main
	controller.battlefield = dummy_battlefield

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	_assert_eq(controller._compute_initial_delay(), 60.0, "basic mode initial delay should be 60s")
	_assert_eq(controller._compute_current_interval(), 60.0, "basic mode interval should be 60s")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_OCCUPATION)
	dummy_main.current_score_counts = {
		GameConfig.Faction.BLUE: 26,
		GameConfig.Faction.RED: 24,
		GameConfig.Faction.GREEN: 25,
		GameConfig.Faction.YELLOW: 25,
	}
	_assert_eq(controller._compute_current_interval(), 40.0, "occupation mode default interval should be 40s")
	dummy_main.current_score_counts = {
		GameConfig.Faction.BLUE: 70,
		GameConfig.Faction.RED: 10,
		GameConfig.Faction.GREEN: 10,
		GameConfig.Faction.YELLOW: 10,
	}
	_assert_eq(controller._compute_current_interval(), 30.0, "occupation mode should speed up near 65 percent lead")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_TIMED)
	GameConfig.set_time_limit_minutes(5)
	dummy_main.game_elapsed_time = 100.0
	_assert_eq(controller._compute_current_interval(), 45.0, "timed mode early interval should be 45s")
	dummy_main.game_elapsed_time = 190.0
	_assert_eq(controller._compute_current_interval(), 30.0, "timed mode mid interval should be 30s")
	dummy_main.game_elapsed_time = 250.0
	_assert_eq(controller._compute_current_interval(), 20.0, "timed mode late interval should be 20s")

	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_WILD)
	var wild_interval: float = controller._compute_current_interval()
	_assert_true(wild_interval >= 20.0 and wild_interval <= 30.0, "wild mode interval should stay in 20-30s range")

	_assert_true(
		controller._weight_for_effect_rank(EventRouletteController.EFFECT_BONUS_10, 4) > controller._weight_for_effect_rank(EventRouletteController.EFFECT_BONUS_10, 1),
		"positive events should favor trailing factions"
	)
	_assert_true(
		controller._weight_for_effect_rank(EventRouletteController.EFFECT_JAM, 1) > controller._weight_for_effect_rank(EventRouletteController.EFFECT_JAM, 4),
		"jam should favor leading factions"
	)

	var save_state: Dictionary = {
		"event_roulette_enabled": true,
		"next_event_time_left": 12.5,
		"current_event_interval": 45.0,
		"last_event_faction": 2,
		"last_event_effect": EventRouletteController.EFFECT_X3,
		"reroll_count": 1,
	}
	controller.import_save_state(save_state)
	var exported: Dictionary = controller.export_save_state()
	_assert_eq(float(exported.get("next_event_time_left", 0.0)), 12.5, "event controller should preserve imported countdown")
	_assert_eq(str(exported.get("last_event_effect", "")), EventRouletteController.EFFECT_X3, "event controller should preserve imported effect")
	controller.battlefield = null
	controller.main_ref = null
	_cleanup_node(dummy_battlefield)
	_cleanup_node(controller)

func _test_control_chamber_event_rules() -> void:
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)

	var chamber: ControlChamber = ControlChamber.new()
	get_root().add_child(chamber)
	await process_frame

	chamber.pending_count = 10
	chamber.apply_pending_bonus(10)
	_assert_eq(chamber.pending_count, 20, "pending bonus should apply immediately when chamber is not locked")
	chamber.apply_pending_multiplier(3)
	_assert_eq(chamber.pending_count, 60, "pending multiplier should apply immediately when chamber is not locked")

	while chamber.balls.size() < GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER:
		chamber.add_control_ball()
	var before_full_bonus: int = chamber.pending_count
	chamber.add_control_ball_from_event()
	_assert_eq(chamber.pending_count, before_full_bonus + 10, "full chamber should convert add-ball event into +10 pending")

	chamber.set_damaged()
	chamber.apply_jammed(5.0)
	_assert_eq(chamber.get_jammed_time_left(), 0.0, "jam should not reactivate a damaged chamber")

	var burst_chamber: ControlChamber = ControlChamber.new()
	get_root().add_child(burst_chamber)
	await process_frame

	var dummy_turret: DummyCancelableTurret = DummyCancelableTurret.new()
	dummy_turret.remaining = 40
	get_root().add_child(dummy_turret)
	burst_chamber.set_linked_turret(dummy_turret)
	burst_chamber.is_locked = true
	burst_chamber.pending_count = 99
	burst_chamber.cancel_current_burst_with_refund(0.25)
	_assert_true(not burst_chamber.is_locked, "jam refund path should unlock the chamber")
	_assert_eq(burst_chamber.pending_count, 10, "jam refund should preserve 25 percent of remaining burst")

	burst_chamber.queue_next_round_modifier({"type": "bonus_10", "amount": 10})
	_assert_eq(burst_chamber.get_queued_round_modifiers().size(), 1, "queued modifiers should be stored while chamber is locked")

	burst_chamber.set_linked_turret(null)
	_cleanup_node(chamber)
	_cleanup_node(burst_chamber)
	_cleanup_node(dummy_turret)
	await _flush_test_cleanup()

func _test_restore_from_state_interfaces() -> void:
	var chamber: ControlChamber = ControlChamber.new()
	chamber.setup(GameConfig.Faction.GREEN, Vector2(48.0, 64.0))
	get_root().add_child(chamber)
	await process_frame

	chamber.restore_from_state({
		"chamber_pending_count": 7,
		"chamber_locked_remaining": 5,
		"chamber_jammed_time_left": 2.5,
		"chamber_is_locked": true,
		"chamber_release_ball_index": 1,
		"queued_round_modifiers": [{"type": "bonus_10", "amount": 10}],
		"control_balls": [
			{
				"position": [20.0, 30.0],
				"velocity": [12.0, -24.0],
				"stay_time": 0.5,
			},
			{
				"position": [40.0, 56.0],
				"velocity": [-18.0, 8.0],
				"stay_time": 1.25,
			}
		]
	})
	_assert_eq(chamber.pending_count, 7, "restore_from_state should restore chamber pending count")
	_assert_eq(chamber.locked_remaining, 5, "restore_from_state should restore chamber locked remaining")
	_assert_true(chamber.is_locked, "restore_from_state should restore chamber locked flag")
	_assert_eq(chamber.balls.size(), 2, "restore_from_state should rebuild chamber control balls")
	_assert_true(chamber.release_ball == chamber.balls[1], "restore_from_state should restore chamber release ball")
	_assert_eq(chamber.get_queued_round_modifiers().size(), 1, "restore_from_state should restore queued chamber modifiers")
	_assert_eq(snappedf(chamber.get_jammed_time_left(), 0.01), 2.5, "restore_from_state should restore chamber jam timer")

	var turret: Turret = Turret.new()
	turret.restore_from_state({
		"turret_health": 17,
		"turret_burst_remaining": 12,
		"turret_burst_total": 16,
		"turret_burst_index": 4,
		"turret_burst_timer": 0.3,
		"turret_burst_locked": true,
	})
	_assert_eq(turret.health, 17, "restore_from_state should restore turret health")
	_assert_eq(turret.burst_remaining, 12, "restore_from_state should restore turret burst remaining")
	_assert_eq(turret.burst_total, 16, "restore_from_state should restore turret burst total")
	_assert_true(turret.burst_locked, "restore_from_state should restore turret burst lock")

	_cleanup_node(chamber)
	_cleanup_node(turret)
	await _flush_test_cleanup()

func _test_turret_cancel_burst() -> void:
	var turret: Turret = Turret.new()
	turret.burst_remaining = 32
	turret.burst_total = 32
	turret.burst_index = 6
	turret.burst_timer = 0.5
	turret.burst_progress_emit_timer = 0.2
	turret.burst_locked = true

	var remaining: int = turret.cancel_burst()
	_assert_eq(remaining, 32, "cancel_burst should return the remaining shot count")
	_assert_eq(turret.burst_remaining, 0, "cancel_burst should clear remaining shots")
	_assert_eq(turret.burst_total, 0, "cancel_burst should clear total shots")
	_assert_true(not turret.burst_locked, "cancel_burst should unlock the turret")
	_cleanup_node(turret)

func _test_bullet_restore_from_state() -> void:
	var bullet: Bullet = Bullet.new()
	bullet.simple_draw = false
	bullet.trail_max_points = 8
	bullet.restore_from_state({
		"faction_id": GameConfig.Faction.YELLOW,
		"position": [60.0, 80.0],
		"direction": [0.0, 1.0],
		"age": 1.75,
		"last_cell": [3, 4],
		"trail_points": [
			[60.0, 80.0],
			[60.0, 72.0],
			[60.0, 64.0],
			[60.0, 56.0],
		],
	}, null, {})
	_assert_eq(bullet.faction_id, GameConfig.Faction.YELLOW, "bullet restore should restore faction")
	_assert_eq(snappedf(bullet.global_position.x, 0.01), 60.0, "bullet restore should restore position x")
	_assert_eq(snappedf(bullet.global_position.y, 0.01), 80.0, "bullet restore should restore position y")
	_assert_eq(snappedf(bullet.direction.x, 0.01), 0.0, "bullet restore should restore direction x")
	_assert_eq(snappedf(bullet.direction.y, 0.01), 1.0, "bullet restore should restore direction y")
	_assert_eq(snappedf(bullet.age, 0.01), 1.75, "bullet restore should restore age")
	_assert_eq(bullet.last_cell, Vector2i(3, 4), "bullet restore should restore last touched cell")
	_assert_eq(bullet.trail_points.size(), 3, "bullet restore should clamp trail restore length")
	_assert_eq(bullet.trail_points[0], Vector2(60.0, 80.0), "bullet restore should preserve leading trail point")
	_cleanup_node(bullet)

func _test_bullet_pool_incremental_metrics() -> void:
	var turret: Turret = Turret.new()
	var pool: BulletPool = BulletPool.new()
	pool.set_tracked_turrets({GameConfig.Faction.BLUE: turret})
	_assert_eq(pool.get_tracked_queue_total(), 0, "tracked queue total should start from current turret state")

	turret.restore_from_state({
		"turret_burst_remaining": 18,
		"turret_burst_total": 18,
		"turret_burst_locked": true,
	})
	_assert_eq(pool.get_tracked_queue_total(), 18, "tracked queue total should update from turret burst progress")

	turret.cancel_burst()
	_assert_eq(pool.get_tracked_queue_total(), 0, "tracked queue total should shrink when burst is cancelled")

	var bullet: Bullet = Bullet.new()
	bullet.pool = pool
	bullet.global_position = Vector2(32.0, 48.0)
	bullet.replace_trail_points([Vector2(32.0, 48.0), Vector2(40.0, 48.0), Vector2(48.0, 48.0)])
	_assert_eq(pool.estimate_trail_segments(), 2, "trail segment estimate should track bullet trail changes incrementally")
	bullet.replace_trail_points([Vector2(48.0, 48.0)])
	_assert_eq(pool.estimate_trail_segments(), 0, "trail segment estimate should drop when bullet trail collapses")

	var restored = pool.spawn_bullet_from_state({
		"faction_id": GameConfig.Faction.BLUE,
		"position": [20.0, 24.0],
		"direction": [1.0, 0.0],
		"trail_points": [
			[20.0, 24.0],
			[14.0, 24.0],
			[8.0, 24.0],
		],
	}, null, {})
	_assert_eq(restored.faction_id, GameConfig.Faction.BLUE, "spawn_bullet_from_state should restore faction through pool")
	_assert_eq(pool.estimate_trail_segments(), 2, "spawn_bullet_from_state should register restored trail segments")

	_cleanup_node(turret)
	_cleanup_node(bullet)
	_cleanup_node(pool)
