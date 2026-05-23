extends SceneTree

const CardfrontRulesScript = preload("res://scripts/cardfront/CardfrontRules.gd")

var _assert: TestAssert


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert = TestAssert.new()
	print("[CardfrontTargetPreviewGuidanceTest] Starting target preview guidance tests")
	await process_frame

	_test_show_for_card_activates_preview()
	_test_preview_pulse_breathes()
	_test_flash_invalid_cell_appends()
	_test_flash_invalid_cell_expires()
	_test_hover_target_info_valid()
	_test_hover_target_info_invalid()
	_test_hover_target_info_no_card()

	GameConfig.reset_runtime_defaults()
	await _flush()

	_assert.report("[CardfrontTargetPreviewGuidanceTest]")
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


func _test_show_for_card_activates_preview() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var preview = main.runtime.target_preview_layer

	_assert.that(not preview._active, "guidance preview: should not be active initially")
	_assert.eq(preview._valid_cells.size(), 0, "guidance preview: should have no valid cells initially")

	var card_data: Dictionary = hand_data[0]
	_select_card(main, card_data)

	_assert.that(preview._active, "guidance preview: should be active after card selection")
	_assert.that(preview._valid_cells.size() > 0, "guidance preview: should have valid cells after selection")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_preview_pulse_breathes() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var preview = main.runtime.target_preview_layer
	_select_card(main, hand_data[0])

	var alpha_before: float = preview.get_preview_pulse_alpha_for_test()
	preview._process(0.20)
	var alpha_after: float = preview.get_preview_pulse_alpha_for_test()
	_assert.that(not is_equal_approx(alpha_before, alpha_after), "guidance preview: pulse alpha should breathe after process tick")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_flash_invalid_cell_appends() -> void:
	var main = _make_main()
	var preview = main.runtime.target_preview_layer
	var test_cell := Vector2i(5, 5)

	_assert.eq(preview._invalid_flash_cells.size(), 0, "guidance preview: flash list should be empty initially")

	preview.flash_invalid_cell(test_cell)

	_assert.that(preview._invalid_flash_cells.size() > 0, "guidance preview: flash list should have entries after flash_invalid_cell")
	var first: Dictionary = preview._invalid_flash_cells[0]
	_assert.eq(first.get("cell", Vector2i.ZERO), test_cell, "guidance preview: flash cell should match the called cell")
	_assert.that(float(first.get("remaining", 0.0)) > 0.0, "guidance preview: flash remaining time should be positive")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_flash_invalid_cell_expires() -> void:
	var main = _make_main()
	var preview = main.runtime.target_preview_layer
	preview.flash_invalid_cell(Vector2i(3, 7))

	_assert.that(preview._invalid_flash_cells.size() > 0, "guidance preview: flash should exist before tick")

	# Tick past the 0.25s duration
	preview._tick_invalid_flash(0.30)

	_assert.eq(preview._invalid_flash_cells.size(), 0, "guidance preview: flash list should be empty after duration elapses")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_hover_target_info_valid() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var preview = main.runtime.target_preview_layer

	_select_card(main, hand_data[0])
	_assert.that(preview._valid_cells.size() > 0, "guidance hover: should have valid cells")

	var first_valid: Vector2i = preview._valid_cells[0]
	var info: Dictionary = preview.get_hover_target_info(first_valid)

	_assert.that(bool(info.get("active", false)), "guidance hover: info should show active")
	_assert.that(bool(info.get("valid", false)), "guidance hover: valid cell should report valid")
	_assert.eq(str(info.get("reason", "")), "valid_target", "guidance hover: valid cell reason should be valid_target")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_hover_target_info_invalid() -> void:
	var main = _make_main()
	var hand_data: Array = main.runtime.card_system.get_hand_card_data()
	var preview = main.runtime.target_preview_layer

	_select_card(main, hand_data[0])
	var invalid_cell := Vector2i(-5, -5)
	var info: Dictionary = preview.get_hover_target_info(invalid_cell)

	_assert.that(bool(info.get("active", false)), "guidance hover: invalid cell info should show active")
	_assert.that(not bool(info.get("valid", false)), "guidance hover: invalid cell should report not valid")
	var reason: String = str(info.get("reason", ""))
	_assert.that(reason != "", "guidance hover: invalid cell should have a reason")
	_assert.that(reason != "valid_target", "guidance hover: invalid cell reason should not be valid_target")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)


func _test_hover_target_info_no_card() -> void:
	var main = _make_main()
	var preview = main.runtime.target_preview_layer

	# No card selected - info should show not active
	var info: Dictionary = preview.get_hover_target_info(Vector2i(0, 0))
	_assert.that(not bool(info.get("active", false)), "guidance hover: no card should report not active")
	_assert.that(not bool(info.get("valid", false)), "guidance hover: no card should report not valid")
	_assert.eq(str(info.get("reason", "")), "no_active_card", "guidance hover: no card reason should be no_active_card")

	main._cleanup_game_layer()
	TestFixtures.cleanup_node(main)
