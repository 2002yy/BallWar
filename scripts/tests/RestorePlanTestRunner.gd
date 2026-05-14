extends SceneTree

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const RestorePlan = preload("res://scripts/RestorePlan.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[RestorePlanTest] v2.1.3 restore-plan audit seam verification")

	_test_build_from_clean_data(t)
	_test_to_restore_dictionary(t)

	t.report("[RestorePlanTest]")
	quit(0 if t.failures.is_empty() else 1)

func _test_build_from_clean_data(t: TestAssert) -> void:
	var raw: Dictionary = {
		"owners": [[0, 1], [2, 3]],
		"factions": [{"faction_id": 1}, {"faction_id": 2}],
		"event_state": {"event_roulette_enabled": false},
		"bullets": [{"faction_id": 3}],
		"is_game_over": true,
		"winner_text": "BLUE wins",
		"grid_size": 40,
	}
	var plan: RestorePlan = RestorePlan.build_from_clean_data(raw)

	t.eq(plan.owners_data.size(), 2, "restore plan keeps owners data")
	t.eq(plan.faction_states.size(), 2, "restore plan keeps faction states")
	t.eq(bool(plan.event_state.get("event_roulette_enabled", true)), false, "restore plan keeps event state")
	t.eq(plan.bullet_states.size(), 1, "restore plan keeps bullet states")
	t.that(bool(plan.game_over_state.get("is_game_over", false)), "restore plan keeps game over flag")
	t.eq(str(plan.game_over_state.get("winner_text", "")), "BLUE wins", "restore plan keeps winner text")

func _test_to_restore_dictionary(t: TestAssert) -> void:
	var raw: Dictionary = {
		"owners": [[0]],
		"factions": [{"faction_id": 0, "turret_health": 5}],
		"event_state": {"reroll_count": 2},
		"bullets": [{"faction_id": 1, "age": 0.5}],
		"is_game_over": false,
		"winner_text": "",
		"grid_size": 40,
	}
	var plan: RestorePlan = RestorePlan.build_from_clean_data(raw)
	var restored: Dictionary = plan.to_restore_dictionary()

	t.eq((restored.get("owners", []) as Array).size(), 1, "restore plan roundtrip owners")
	t.eq((restored.get("factions", []) as Array).size(), 1, "restore plan roundtrip factions")
	t.eq(int(restored.get("event_state", {}).get("reroll_count", -1)), 2, "restore plan roundtrip event state")
	t.eq((restored.get("bullets", []) as Array).size(), 1, "restore plan roundtrip bullets")
	t.eq(bool(restored.get("is_game_over", true)), false, "restore plan roundtrip game over flag")
