extends SceneTree

const CardfrontRulesScript = preload("res://scripts/cardfront/CardfrontRules.gd")

var _assert: TestAssert


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert = TestAssert.new()
	print("[CardfrontHandPanelGuidanceTest] Starting hand panel guidance tests")
	await process_frame

	_test_all_cards_have_hints()
	_test_selection_shows_hint()
	_test_clear_selection_hides_hint()
	_test_action_hint_bg_visibility()

	GameConfig.reset_runtime_defaults()
	await _flush()

	_assert.report("[CardfrontHandPanelGuidanceTest]")
	if _assert.failures.is_empty():
		quit(0)
	else:
		quit(1)


func _flush() -> void:
	await process_frame
	await process_frame


func _make_main():
	GameConfig.reset_runtime_defaults()
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_CARDFRONT)
	var main = load("res://scripts/Main.gd").new()
	get_root().add_child(main)
	main.selected_game_mode_name = GameConfig.GAME_MODE_CARDFRONT
	main.selected_grid_size = 20
	main._start_game(20, true, false)
	return main


func _select_card(main, card_data: Dictionary) -> void:
	main.runtime.selection_controller.on_card_clicked(int(card_data.id), card_data)


func _test_all_cards_have_hints() -> void:
	var main = _make_main()
	var hand_panel = main.runtime.hand_panel
	var card_ids := [1001, 1002, 1003, 1004]

	for card_id in card_ids:
		var hint: String = hand_panel.get_action_hint_for_card(card_id)
		_assert.that(hint != "", "guidance: card %d should have non-empty hint" % card_id)

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_selection_shows_hint() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	_assert.that(not hand_data.is_empty(), "guidance: should have hand cards")

	var card_data: Dictionary = hand_data[0]
	_select_card(main, card_data)

	_assert.that(main.runtime.hand_panel.is_action_hint_visible(), "guidance: selecting card should show action hint")
	var hint_text: String = main.runtime.hand_panel.get_action_hint_text()
	_assert.that(hint_text != "", "guidance: hint text should be non-empty when visible")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_clear_selection_hides_hint() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var card_data: Dictionary = hand_data[0]
	_select_card(main, card_data)
	_assert.that(main.runtime.hand_panel.is_action_hint_visible(), "guidance: hint should be visible after selection")

	main.runtime.selection_controller.clear_selection()
	_assert.that(not main.runtime.hand_panel.is_action_hint_visible(), "guidance: hint should be hidden after clear_selection")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_action_hint_bg_visibility() -> void:
	var main = _make_main()
	var hand_panel = main.runtime.hand_panel
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var card_data: Dictionary = hand_data[0]

	# Before selection - bg should be hidden
	_assert.that(not hand_panel.is_action_hint_visible(), "guidance: bg should be hidden before selection")

	# After selection - bg should be visible
	_select_card(main, card_data)
	_assert.that(hand_panel.is_action_hint_visible(), "guidance: bg should be visible after selection")

	# After clear - bg should be hidden
	main.runtime.selection_controller.clear_selection()
	_assert.that(not hand_panel.is_action_hint_visible(), "guidance: bg should be hidden after clear")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)
