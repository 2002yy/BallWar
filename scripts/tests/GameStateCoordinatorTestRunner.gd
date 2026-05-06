extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const GameStateCoordinator = preload("res://scripts/GameStateCoordinator.gd")

class MockTree extends RefCounted:
	var paused: bool = false

class MockOverlay extends RefCounted:
	var visible: bool = false

class MockMenuLayer extends RefCounted:
	var visible: bool = true

class MockButton extends RefCounted:
	var text: String = ""

class MockLabel extends RefCounted:
	var text: String = ""
	var visible: bool = true

class MockOwner extends RefCounted:
	var is_game_over: bool = false
	var banner_calls: Array = []
	var stop_calls: int = 0

	func _show_center_banner(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
		banner_calls.append({
			"title": title_text,
			"sub_text": sub_text,
			"accent": accent,
			"auto_hide": auto_hide,
		})

	func _stop_all_actions_for_game_over() -> void:
		stop_calls += 1

class MockTurret extends RefCounted:
	var cancel_calls: int = 0
	var burst_remaining: int = 8
	var burst_total: int = 8
	var burst_timer: float = 0.5
	var burst_locked: bool = true

	func cancel_burst() -> int:
		cancel_calls += 1
		burst_remaining = 0
		burst_total = 0
		burst_timer = 0.0
		burst_locked = false
		return 8

class MockChamber extends RefCounted:
	var locked_history: Array = []

	func set_locked(locked: bool) -> void:
		locked_history.append(locked)

class MockEventController extends RefCounted:
	var is_presenting_event: bool = true
	var event_roulette_enabled: bool = true

class MockEventView extends RefCounted:
	var visible: bool = true

class RefreshRecorder extends RefCounted:
	var refreshed: Array = []

	func call_refresh(faction_id: int) -> void:
		refreshed.append(faction_id)

class ClearRecorder extends RefCounted:
	var call_count: int = 0

	func call_clear() -> void:
		call_count += 1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[GameStateCoordinatorTest] v2.1.2 state-flow helper verification")

	_test_pause_helpers(t)
	_test_state_predicates(t)
	_test_finish_with_winner(t)
	_test_finish_as_draw(t)
	_test_stop_actions_for_game_over(t)
	_test_reset_visual_state(t)

	t.report("[GameStateCoordinatorTest]")
	quit(0 if t.failures.is_empty() else 1)

func _test_pause_helpers(t: TestAssert) -> void:
	t.that(GameStateCoordinator.should_ignore_pause(true, RefCounted.new()), "pause ignored when game over")
	t.that(GameStateCoordinator.should_ignore_pause(false, null), "pause ignored without game layer")
	t.that(not GameStateCoordinator.should_ignore_pause(false, RefCounted.new()), "pause allowed during active game")

	var tree_ref := MockTree.new()
	var overlay := MockOverlay.new()
	var button := MockButton.new()
	var save_recorder := ClearRecorder.new()

	var paused_now: bool = GameStateCoordinator.apply_pause_toggle(
		tree_ref,
		overlay,
		button,
		Callable(save_recorder, "call_clear")
	)
	t.that(paused_now, "pause helper should enter paused state")
	t.that(tree_ref.paused, "tree paused set true")
	t.eq(save_recorder.call_count, 1, "pause helper should save once when entering pause")
	t.that(overlay.visible, "pause overlay visible when paused")
	t.eq(button.text, "\u7ee7\u7eed", "pause button switches to continue text")

	var resumed_now: bool = GameStateCoordinator.apply_pause_toggle(
		tree_ref,
		overlay,
		button,
		Callable(save_recorder, "call_clear")
	)
	t.that(not resumed_now, "pause helper should exit paused state")
	t.that(not tree_ref.paused, "tree paused reset false")
	t.eq(save_recorder.call_count, 1, "resume should not save again")
	t.that(not overlay.visible, "pause overlay hidden after resume")
	t.eq(button.text, "\u6682\u505c", "pause button switches back to pause text")

func _test_state_predicates(t: TestAssert) -> void:
	var tree_ref := MockTree.new()
	var menu_layer := MockMenuLayer.new()
	t.that(GameStateCoordinator.is_menu_visible(menu_layer), "menu visible when layer visible")
	menu_layer.visible = false
	t.that(not GameStateCoordinator.is_menu_visible(menu_layer), "menu hidden when layer hidden")
	t.that(not GameStateCoordinator.should_process_restore_queue(tree_ref, false, 0), "restore skipped when queue empty")
	t.that(GameStateCoordinator.should_process_restore_queue(tree_ref, false, 3), "restore runs when active")
	tree_ref.paused = true
	t.that(not GameStateCoordinator.should_process_restore_queue(tree_ref, false, 3), "restore skipped while paused")
	tree_ref.paused = false
	t.that(GameStateCoordinator.should_advance_gameplay(tree_ref, RefCounted.new(), false), "gameplay advances while active")
	t.that(not GameStateCoordinator.should_advance_gameplay(tree_ref, null, false), "gameplay blocked without layer")
	t.that(not GameStateCoordinator.should_advance_gameplay(tree_ref, RefCounted.new(), true), "gameplay blocked on game over")

func _test_finish_with_winner(t: TestAssert) -> void:
	var owner := MockOwner.new()
	var winner_label := MockLabel.new()

	GameStateCoordinator.finish_with_winner(owner, winner_label, GameConfig.Faction.BLUE, "\u5360\u9886\u8fbe\u6210")

	t.that(owner.is_game_over, "winner flow marks owner as game over")
	t.eq(owner.stop_calls, 1, "winner flow stops actions once")
	t.eq(winner_label.text, "%s \u80dc\u5229\uff01" % GameConfig.faction_name(GameConfig.Faction.BLUE), "winner flow writes winner label")
	t.eq(owner.banner_calls.size(), 1, "winner flow shows one banner")
	t.eq(owner.banner_calls[0]["title"], winner_label.text, "winner flow banner title matches label")
	t.eq(owner.banner_calls[0]["sub_text"], "\u5360\u9886\u8fbe\u6210", "winner flow keeps sub text")
	t.that(not owner.banner_calls[0]["auto_hide"], "winner flow banner should stay visible")

func _test_finish_as_draw(t: TestAssert) -> void:
	var owner := MockOwner.new()
	var winner_label := MockLabel.new()

	GameStateCoordinator.finish_as_draw(owner, winner_label, "\u65f6\u95f4\u5230")

	t.that(owner.is_game_over, "draw flow marks owner as game over")
	t.eq(owner.stop_calls, 1, "draw flow stops actions once")
	t.eq(winner_label.text, "\u5e73\u5c40", "draw flow writes draw label")
	t.eq(owner.banner_calls.size(), 1, "draw flow shows one banner")
	t.eq(owner.banner_calls[0]["title"], "\u5e73\u5c40", "draw flow banner title is draw")
	t.eq(owner.banner_calls[0]["sub_text"], "\u65f6\u95f4\u5230", "draw flow keeps sub text")
	t.that(not owner.banner_calls[0]["auto_hide"], "draw flow banner should stay visible")

func _test_stop_actions_for_game_over(t: TestAssert) -> void:
	var turret_a := MockTurret.new()
	var turret_b := MockTurret.new()
	var chamber_a := MockChamber.new()
	var chamber_b := MockChamber.new()
	var refresh_recorder := RefreshRecorder.new()
	var clear_recorder := ClearRecorder.new()
	var event_controller := MockEventController.new()
	var event_view := MockEventView.new()

	GameStateCoordinator.stop_actions_for_game_over(
		{0: turret_a, 1: turret_b},
		{0: chamber_a, 1: chamber_b},
		Callable(refresh_recorder, "call_refresh"),
		Callable(clear_recorder, "call_clear"),
		event_controller,
		event_view
	)

	t.eq(turret_a.cancel_calls, 1, "first turret burst canceled")
	t.eq(turret_b.cancel_calls, 1, "second turret burst canceled")
	t.eq(clear_recorder.call_count, 1, "bullets cleared once")
	t.eq(chamber_a.locked_history.size(), 1, "first chamber unlocked once")
	t.eq(chamber_b.locked_history.size(), 1, "second chamber unlocked once")
	t.eq(chamber_a.locked_history[0], false, "first chamber unlocked to false")
	t.eq(chamber_b.locked_history[0], false, "second chamber unlocked to false")
	t.eq(refresh_recorder.refreshed.size(), 2, "refresh called for each chamber")
	t.that(not event_controller.is_presenting_event, "event presentation cleared at game over")
	t.that(not event_controller.event_roulette_enabled, "event controller disabled at game over")
	t.that(not event_view.visible, "event view hidden at game over")

func _test_reset_visual_state(t: TestAssert) -> void:
	var overlay := MockOverlay.new()
	var button := MockButton.new()
	var winner_label := MockLabel.new()

	overlay.visible = true
	button.text = "\u7ee7\u7eed"
	winner_label.text = "winner"
	winner_label.visible = true

	GameStateCoordinator.reset_pause_and_winner_state(overlay, button, winner_label)

	t.that(not overlay.visible, "reset hides pause overlay")
	t.eq(button.text, "\u6682\u505c", "reset restores pause button text")
	t.eq(winner_label.text, "", "reset clears winner label")
	t.that(not winner_label.visible, "reset hides winner label")
