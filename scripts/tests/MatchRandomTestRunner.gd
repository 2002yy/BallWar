extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const Stream = MatchRandom.Stream

var _checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var a := MatchRandom.new(12345)
	var b := MatchRandom.new(12345)
	var other := MatchRandom.new(12346)


	var expected_event: int = b.get_stream(Stream.EVENT).randi()
	var expected_chamber: int = b.get_stream(Stream.CHAMBER, 0).randi()
	var expected_projectile: int = b.get_stream(Stream.PROJECTILE, 0).randi()
	# Vary both draw and creation order across unrelated streams.
	for i in range(24):
		a.get_stream(Stream.CHAMBER, 1).randi()
		a.get_stream(Stream.PROJECTILE, 1).randi()
		a.get_stream(Stream.PALETTE).randi()
		a.get_stream(Stream.TURRET, 0).randi()


	var serialized := a.serialize_states()
	var restored := MatchRandom.new(999)
	if not _check(restored.restore_states(serialized), "serialized simulation state restores"):
		return
	if not _check(restored.serialize_states() == serialized, "restored state round-trips exactly"):
		return
	if not _check(restored.get_stream(Stream.CHAMBER, 1).randi() == a.get_stream(Stream.CHAMBER, 1).randi(),
		"restored stream continues the same sequence"):
		return
	if not _check(not restored.restore_states([[Stream.PALETTE, 0, "1"]]), "palette stream is not restorable as simulation"):
		return

	var isolated := MatchRandom.new(12345)
	isolated.get_stream(Stream.EVENT).randi()
	var before_palette: Array = isolated.simulation_states()
	isolated.get_stream(Stream.PALETTE).randi()
	if not _check(isolated.simulation_states() == before_palette, "palette is excluded from the simulated RNG state"):
		return
	if not _check(a.get_stream(Stream.EVENT).randi() == expected_event, "other systems do not move event RNG"):
		return
	if not _check(a.get_stream(Stream.CHAMBER, 0).randi() == expected_chamber, "another faction does not move chamber RNG"):
		return
	if not _check(a.get_stream(Stream.PROJECTILE, 0).randi() == expected_projectile, "another faction does not move hit-check RNG"):
		return
	if not _check(other.get_stream(Stream.EVENT).randi() != expected_event, "the root seed changes the actual stream"):
		return

	var main = MainScript.new()
	main.match_seed = 12345
	root.add_child(main)
	main.selected_palette_name = "经典"
	main._start_game(40, true, false)
	var initial: Array = _starting_state(main)
	if not _check(main.runtime.match_random.get_stream(Stream.CHAMBER, 0) == main.runtime.chambers[0].random_source
		and main.runtime.match_random.get_stream(Stream.TURRET, 0) == main.runtime.turrets[0].sweep_random
		and main.runtime.match_random.get_stream(Stream.EVENT) == main.runtime.event_controller.random_source
		and main.runtime.bullet_pool.match_random == main.runtime.match_random,
		"runtime gives each subsystem the match-owned generator"):
		return
	main.runtime.match_random.get_stream(Stream.EVENT).randi()
	main.runtime.match_random.get_stream(Stream.PALETTE).randi()
	main.runtime.match_random.get_stream(Stream.CHAMBER, 0).randi()
	main._start_game(40, true, false)
	if not _check(_starting_state(main) == initial, "starting a round again re-seeds simulation at match creation"):
		return
	main.selected_palette_name = "默认随机"
	main._start_game(40, true, false)
	if not _check(_starting_state(main) == initial, "the production palette roll does not change opening simulation"):
		return
	print("[MatchRandomTest] PASS (%d checks)" % _checks)
	quit(0)


func _starting_state(main) -> Array:
	var state: Array = [main.runtime.match_random.simulation_states()]
	for faction in range(4):
		var ball = main.runtime.chambers[faction].balls[0]
		state.append([ball.position, ball.velocity, main.runtime.turrets[faction].sweep_phase])
	return state


func _check(value: bool, label: String) -> bool:
	_checks += 1
	if not value:
		printerr("[MatchRandomTest] FAIL: %s" % label)
		quit(1)
	return value
