extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const BLUE := GameConfig.Faction.BLUE
const RED := GameConfig.Faction.RED

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t := TestAssert.new()
	var main := MainScript.new()
	main.match_seed = 7341
	root.add_child(main)
	main.audio_manager.set_enabled(false)

	main._start_game(10, true, false)
	t.eq(main._buy_lucky_blast(BLUE), 0, "classic mode cannot buy an experimental item")

	main._start_game(10, true, false, true)
	var field: Battlefield = main.runtime.battlefield
	var economy: ReserveEconomy = main.runtime.reserve_economy
	var starting_owners := field.owners.duplicate(true)
	economy.convert_pending(796, BLUE)
	t.eq(economy.balance(BLUE), 199, "buyer begins one reserve short")
	t.eq(main._buy_lucky_blast(BLUE), 0, "insufficient reserve rejects the purchase")
	t.eq(economy.balance(BLUE), 199, "rejected purchase does not debit the buyer")
	t.eq(field.owners, starting_owners, "rejected purchase does not change the board")

	economy.convert_pending(4, BLUE)
	economy.convert_pending(800, RED)
	var before_counts := field.count_cells_by_team()
	var event_state: Dictionary = main.runtime.event_controller.export_save_state()
	var health := _turret_health(main)
	seed(911)
	var expected_next_draw := randi()
	seed(911)
	var captured: int = main._buy_lucky_blast(BLUE)
	t.eq(randi(), expected_next_draw, "purchase does not advance global RNG")
	t.between(captured, 1, 29, "successful blast captures within a radius-three disk")
	t.eq(economy.balance(BLUE), 0, "success debits exactly 200 reserve")
	t.eq(economy.balance(RED), 200, "success leaves the other faction reserve intact")
	var counts := field.count_cells_by_team()
	t.eq(counts[BLUE] - before_counts[BLUE], captured, "reported captures match the battlefield counts")
	t.eq(counts.values().reduce(func(total, value): return total + value, 0), 100, "every cell retains exactly one owning faction")
	t.that(field.score_emit_pending and field.redraw_pending, "capture schedules the usual score and visual updates")
	t.eq(_turret_health(main), health, "lucky blast does not damage turrets")
	t.eq(main.runtime.bullet_pool.get_active_bullets().size(), 0, "lucky blast does not create projectiles")
	t.eq(main.runtime.event_controller.export_save_state(), event_state, "purchase leaves event roulette unchanged")
	var expected_owners := field.owners.duplicate(true)
	t.that(_matches_radius_three_disk(starting_owners, expected_owners), "captured cells match one disk centered on an enemy cell")
	t.eq(main._buy_lucky_blast(BLUE), 0, "repeated purchase requires another payment")
	t.eq(field.owners, expected_owners, "failed repeated purchase has no second effect")

	main._start_game(10, true, false, true)
	field = main.runtime.battlefield
	economy = main.runtime.reserve_economy
	economy.convert_pending(800, BLUE)
	for x in range(field.grid_size):
		for y in range(field.grid_size):
			field.claim_cell(Vector2i(x, y), BLUE)
	t.eq(main._buy_lucky_blast(BLUE), 0, "no enemy cell rejects the purchase")
	t.eq(economy.balance(BLUE), 200, "no enemy cell rolls back the charge")
	field.reset_quadrants()
	for draw_index in range(13):
		randi()
	t.eq(main._buy_lucky_blast(BLUE), captured, "same seed reproduces captured count after failed purchase")
	t.eq(field.owners, expected_owners, "same seed reproduces the exact cells despite global RNG draws")

	for x in range(field.grid_size):
		for y in range(field.grid_size):
			field.claim_cell(Vector2i(x, y), RED if y == 0 else BLUE)
	economy.convert_pending(800, BLUE)
	var edge_captures: int = main._buy_lucky_blast(BLUE)
	t.between(edge_captures, 4, 7, "forced top-edge blast clips its area to the board")
	var captured_columns: Array[int] = []
	for x in range(field.grid_size):
		if field.owners[x][0] == BLUE:
			captured_columns.append(x)
	t.eq(captured_columns.size(), edge_captures, "only enemy cells in the top row are captured")
	if not captured_columns.is_empty():
		t.eq(captured_columns.back() - captured_columns.front() + 1, edge_captures, "affected columns form one radius-three interval")

	t.eq(main._buy_lucky_blast(-1), 0, "invalid faction is rejected")
	main.runtime.turrets[RED].take_damage(main.runtime.turrets[RED].health)
	economy.convert_pending(800, RED)
	t.eq(main._buy_lucky_blast(RED), 0, "eliminated faction cannot use the item")
	t.eq(economy.balance(RED), 200, "eliminated faction keeps its balance")
	main.is_game_over = true
	economy.convert_pending(800, BLUE)
	t.eq(main._buy_lucky_blast(BLUE), 0, "game over disables item purchases")
	t.eq(economy.balance(BLUE), 200, "game-over rejection leaves the balance untouched")

	main.queue_free()
	await process_frame
	t.report("LuckyBlastTestRunner")
	quit(0 if t.failures.is_empty() else 1)

func _turret_health(main) -> Dictionary:
	var health := {}
	for faction in main.runtime.turrets:
		health[faction] = main.runtime.turrets[faction].health
	return health

func _matches_radius_three_disk(before: Array, after: Array) -> bool:
	var enemy_cells: Array[Vector2i] = []
	var changed: Array[Vector2i] = []
	for x in range(before.size()):
		for y in range(before[x].size()):
			if before[x][y] != BLUE:
				enemy_cells.append(Vector2i(x, y))
			if before[x][y] != after[x][y]:
				if after[x][y] != BLUE:
					return false
				changed.append(Vector2i(x, y))
	for center in enemy_cells:
		var disk := enemy_cells.filter(func(cell: Vector2i): return (cell - center).length_squared() <= 9)
		if disk == changed:
			return true
	return false
