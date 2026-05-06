extends RefCounted
class_name GameStateCoordinator

static func is_menu_visible(menu_layer) -> bool:
	return menu_layer != null and is_instance_valid(menu_layer) and bool(menu_layer.visible)

static func should_ignore_pause(is_game_over: bool, game_layer) -> bool:
	return is_game_over or game_layer == null

static func should_process_restore_queue(tree_ref, is_game_over: bool, pending_restore_count: int) -> bool:
	if tree_ref == null:
		return false
	return pending_restore_count > 0 and not bool(tree_ref.paused) and not is_game_over

static func should_advance_gameplay(tree_ref, game_layer, is_game_over: bool) -> bool:
	if tree_ref == null:
		return false
	return game_layer != null and not bool(tree_ref.paused) and not is_game_over

static func apply_pause_toggle(tree_ref, pause_overlay, pause_button, save_game_progress: Callable) -> bool:
	if tree_ref == null:
		return false

	if bool(tree_ref.paused):
		tree_ref.paused = false
		_apply_pause_visuals(pause_overlay, pause_button, false)
		return false

	tree_ref.paused = true
	if save_game_progress.is_valid():
		save_game_progress.call()
	_apply_pause_visuals(pause_overlay, pause_button, true)
	return true

static func finish_with_winner(owner, winner_label, faction_id: int, sub_text: String) -> void:
	var title_text: String = "%s \u80dc\u5229\uff01" % GameConfig.faction_name(faction_id)
	var accent: Color = GameConfig.faction_color(faction_id).lightened(0.35)
	_apply_game_over(owner, winner_label, title_text, sub_text, accent)

static func finish_as_draw(owner, winner_label, sub_text: String) -> void:
	_apply_game_over(owner, winner_label, "\u5e73\u5c40", sub_text, Color(1.0, 1.0, 1.0))

static func stop_actions_for_game_over(turrets: Dictionary, chambers: Dictionary, refresh_add_ball_button: Callable, clear_bullets: Callable, event_controller = null, event_view = null) -> void:
	for turret in turrets.values():
		if turret == null or not is_instance_valid(turret):
			continue
		if turret.has_method("cancel_burst"):
			turret.cancel_burst()
		else:
			turret.burst_remaining = 0
			turret.burst_total = 0
			turret.burst_timer = 0.0
			if turret.has_method("_set_burst_locked"):
				turret._set_burst_locked(false)

	if event_controller != null and is_instance_valid(event_controller):
		event_controller.set("is_presenting_event", false)
		if "event_roulette_enabled" in event_controller:
			event_controller.set("event_roulette_enabled", false)

	if event_view != null and is_instance_valid(event_view):
		event_view.visible = false

	if clear_bullets.is_valid():
		clear_bullets.call()

	for faction_id in chambers.keys():
		var chamber = chambers[faction_id]
		if chamber != null and is_instance_valid(chamber) and chamber.has_method("set_locked"):
			chamber.set_locked(false)
		if refresh_add_ball_button.is_valid():
			refresh_add_ball_button.call(int(faction_id))

static func _apply_pause_visuals(pause_overlay, pause_button, is_paused: bool) -> void:
	if pause_overlay != null and is_instance_valid(pause_overlay):
		pause_overlay.visible = is_paused
	if pause_button != null and is_instance_valid(pause_button):
		pause_button.text = "\u7ee7\u7eed" if is_paused else "\u6682\u505c"

static func reset_pause_and_winner_state(pause_overlay, pause_button, winner_label) -> void:
	_apply_pause_visuals(pause_overlay, pause_button, false)
	apply_winner_label_state(winner_label, "", false)

static func apply_winner_label_state(winner_label, text: String, is_visible: bool = true) -> void:
	if winner_label == null or not is_instance_valid(winner_label):
		return
	winner_label.text = text
	if "visible" in winner_label:
		winner_label.visible = is_visible

static func _apply_game_over(owner, winner_label, title_text: String, sub_text: String, accent: Color) -> void:
	if owner != null:
		owner.is_game_over = true
		if owner.has_method("_stop_all_actions_for_game_over"):
			owner._stop_all_actions_for_game_over()

	apply_winner_label_state(winner_label, title_text, true)

	if owner != null and owner.has_method("_show_center_banner"):
		owner._show_center_banner(title_text, sub_text, accent, false)
