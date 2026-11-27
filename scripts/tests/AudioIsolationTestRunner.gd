extends SceneTree

# A4 audio isolation test - the CI-safe half.
#
# Three claims, each with a positive control, because a check that cannot fail is
# not evidence:
#
#   A. No presentation code draws from the global RNG stream.
#      Bullet seeds its hit-check jitter from the global RNG (Bullet.gd:45), the
#      chamber and the event roulette do the same. One extra global draw anywhere
#      in the presentation path shifts every later draw, which changes the match.
#      This is a STATIC guard on purpose; see the note above claim A.
#
#   B. Presentation events never write simulation state.
#      Every event is fired many times against a live match and the simulation
#      signature is compared before and after.
#
#   C. The bus exposes nothing a simulation node could read back.
#
# Why this file starts no audio playback, even though that would be a nicer test:
# a headless run that starts an Ogg playback leaves playback objects in the
# AudioServer and the engine reports "resources still in use at exit" -
# unreliably, depending on mixer timing, and it has been observed both ways on
# this machine. A suite that greps for ^ERROR: counts that as this test failing.
# Real playback is exercised by tools/tests/audio_lifecycle_probe.gd, which is
# deliberately not part of CI.
#
# The runtime proof that audio cannot change a match is
# tools/tests/run_audio_determinism.sh: three audio arms, one seed, one fixed
# tick rate, 3600 ticks compared one by one, plus a different-seed control that
# must diverge. This file is the regression guard that keeps that property from
# being broken by a future edit.
#
# Exit: 0 pass, 1 failure.

const TestAssert = preload("res://scripts/tests/TestAssert.gd")
const MainScript = preload("res://scripts/Main.gd")
const AudioManagerScript = preload("res://scripts/AudioManager.gd")

const GRID_SIZE := 40
const EVENT_ROUNDS := 24

# The bare forms are what would silently share the simulation's random stream.
const BARE_RNG_CALLS := [
	"randf(", "randi(", "randf_range(", "randi_range(", "randomize(", "seed(",
]

var _main = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var t: TestAssert = TestAssert.new()
	print("[AudioIsolationTest] v2")
	await process_frame

	_test_no_global_rng_in_presentation(t)
	_test_private_jitter_stream_is_live(t)

	await _build_match()
	if _main == null:
		t.that(false, "match did not build, claims B and C were not tested")
	else:
		_test_events_do_not_write_simulation(t)
		_test_event_bus_is_one_way(t)

	t.report("[AudioIsolationTest]")
	if t.failures.is_empty():
		print("[AudioIsolationTest] RESULT PASS")
		quit(0)
	else:
		print("[AudioIsolationTest] RESULT FAIL")
		quit(1)


# --- A. global RNG stream ---------------------------------------------------

# Static instead of behavioural. The behavioural version - seed the global RNG,
# play sounds, compare the following sequence - needs a real playback, and a real
# playback in a headless run is what leaves the engine's exit-time resource noise
# described in the header. The static form catches the same regression (someone
# writing `randf_range()` instead of `_rng.randf_range()`) and cannot be flaky.
# It is weaker than a runtime proof and is labelled as such rather than presented
# as more than it is; the runtime proof is the determinism comparison named in
# the header.
func _test_no_global_rng_in_presentation(t: TestAssert) -> void:
	print("  [A] no bare global-RNG calls in the presentation layer")
	var targets: Array[String] = ["res://scripts/AudioManager.gd"]
	var presentation_dir: String = "res://scripts/presentation"
	for file_name in DirAccess.get_files_at(presentation_dir):
		if file_name.ends_with(".gd"):
			targets.append("%s/%s" % [presentation_dir, file_name])
	t.gte(targets.size(), 2, "A: presentation layer has fewer files than expected, guard is scanning nothing")

	var files_with_bare: int = 0
	var saw_private_generator: int = 0
	for path in targets:
		var text: String = FileAccess.get_file_as_string(path)
		t.that(text != "", "A: cannot read %s" % path)
		if text.contains("_rng."):
			saw_private_generator += 1
		var found: Array = _scan_snippet(_strip_comments_and_strings(text))
		if not found.is_empty():
			print("    %s -> %s" % [path, str(found)])
			files_with_bare += 1
	t.eq(files_with_bare, 0, "A: presentation layer calls the global RNG somewhere")
	t.gte(saw_private_generator, 1, "A: no private generator found, so the guard proved nothing")

	# Positive control: the scanner must find a bare call when there is one, and
	# must not report a call chained onto a private generator. Without this the
	# zero above could be a scanner that matches nothing at all.
	t.eq(_scan_snippet("var x = randf_range(0.0, 1.0)").size(), 1, "A control: scanner missed a bare randf_range")
	t.eq(_scan_snippet("var x = _rng.randf_range(0.0, 1.0)").size(), 0, "A control: scanner flagged a private-generator call")
	t.eq(_scan_snippet("var x = my_rng.randi()").size(), 0, "A control: scanner flagged a chained call")
	t.eq(_scan_snippet("var y = randi() % 3").size(), 1, "A control: scanner missed a bare randi")


func _scan_snippet(code: String) -> Array:
	var found: Array = []
	for pattern in BARE_RNG_CALLS:
		var from: int = 0
		while true:
			var at: int = code.find(pattern, from)
			if at < 0:
				break
			var previous: String = code.substr(maxi(0, at - 1), 1) if at > 0 else ""
			if not (previous == "." or previous.is_valid_identifier()):
				found.append(pattern)
			from = at + pattern.length()
	return found


# Comments and string literals are removed first: a doc comment that mentions
# `randf()` is not a call, and reporting it would teach everyone to ignore this
# test. Audit lines are the reason this stripper exists at all.
func _strip_comments_and_strings(text: String) -> String:
	var out: String = ""
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var c: String = text[i]
		if c == "#":
			while i < n and text[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			var quote: String = c
			i += 1
			while i < n and text[i] != quote:
				if text[i] == "\\":
					i += 1
				i += 1
			i += 1
			out += " "
			continue
		out += c
		i += 1
	return out


# The jitter must come from the private stream, otherwise "no global draws" would
# be true only because no jitter happens at all.
func _test_private_jitter_stream_is_live(t: TestAssert) -> void:
	print("  [A] the private jitter stream is in use and varies")
	var audio = AudioManagerScript.new()
	# Not added to the tree: _ready() would build the player pool, and this check
	# only needs the generator.
	var first: float = 0.0
	var distinct: bool = false
	audio._rng.seed = 9001
	for i in 64:
		var v: float = audio._rng.randf_range(-1.0, 1.0)
		if i == 0:
			first = v
		elif v != first:
			distinct = true
	t.that(distinct, "A: audio jitter stream is constant, so no jitter is applied")
	audio.free()


# --- B. simulation state ----------------------------------------------------

func _build_match() -> void:
	GameConfig.reset_runtime_defaults()
	GameConfig.set_quality_by_name(GameConfig.QUALITY_MEDIUM)
	GameConfig.set_game_mode_by_name(GameConfig.GAME_MODE_BASIC)
	_main = MainScript.new()
	_main.name = "IsolationMain"
	_main.match_seed = 4242
	_main.selected_grid_size = GRID_SIZE
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 5
	_main.selected_save_slot = 5
	get_root().add_child(_main)
	await process_frame
	# Muted before the match exists so no playback is ever started. Playback is
	# what leaves the engine's exit-time resource noise; muting does not touch the
	# event path, which is the path this claim is about.
	if _main.audio_manager != null:
		_main.audio_manager.set_enabled(false)
	_main._start_game(GRID_SIZE, true, false)
	await process_frame
	await process_frame
	if _main.runtime == null or _main.runtime.battlefield == null:
		push_error("[AudioIsolationTest] match did not build")
		_main = null


# Simulation-visible state only: fps, node counts, animation phase and audio
# state are deliberately absent, because they are allowed to change.
func _sim_signature() -> String:
	var turret_ids: Array = _main.runtime.turrets.keys()
	turret_ids.sort()
	var turret_sig: Array = []
	for fid in turret_ids:
		var turret = _main.runtime.turrets[fid]
		if turret == null or not is_instance_valid(turret):
			turret_sig.append("%d:gone" % int(fid))
			continue
		turret_sig.append("%d:%d:%d:%d:%.5f:%d" % [
			int(fid), int(turret.health), 1 if turret.is_destroyed else 0,
			int(turret.burst_remaining), float(turret.burst_timer), int(turret.burst_index)])
	var chamber_ids: Array = _main.runtime.chambers.keys()
	chamber_ids.sort()
	var chamber_sig: Array = []
	for fid in chamber_ids:
		var chamber = _main.runtime.chambers[fid]
		if chamber == null or not is_instance_valid(chamber):
			chamber_sig.append("%d:gone" % int(fid))
			continue
		chamber_sig.append("%d:%d:%d:%d:%d:%d:%.4f" % [
			int(fid), int(chamber.pending_count), int(chamber.locked_remaining),
			1 if chamber.is_locked else 0, 1 if chamber.is_damaged else 0,
			chamber.balls.size(), float(chamber.jammed_time_left)])
	var bullets: Array = []
	var pool = _main.runtime.bullet_pool
	if pool != null and is_instance_valid(pool):
		for bullet in pool.get_active_bullets():
			if bullet == null or not is_instance_valid(bullet):
				continue
			bullets.append("%d:%.3f:%.3f" % [
				int(bullet.faction_id), bullet.global_position.x, bullet.global_position.y])
	bullets.sort()
	var controller = _main.runtime.event_controller
	var event_sig: String = "none"
	if controller != null and is_instance_valid(controller):
		event_sig = "%d:%.4f:%d:%s:%d" % [
			1 if controller.event_roulette_enabled else 0,
			float(controller.next_event_time_left), int(controller.last_event_faction),
			str(controller.last_event_effect), int(controller.reroll_count)]
	return var_to_str([
		hash(_main.runtime.battlefield.owners),
		turret_sig, chamber_sig, bullets, event_sig,
	]).sha256_text()


func _test_events_do_not_write_simulation(t: TestAssert) -> void:
	print("  [B] firing every presentation event leaves simulation state identical")
	t.gte(_main.runtime.turrets.size(), 4, "B: match has no turrets to observe")
	var events = _main.presentation_events
	if events == null:
		t.that(false, "B: Main has no presentation bus")
		return

	var before: String = _sim_signature()
	var emitted_before: Dictionary = events.snapshot()
	for i in EVENT_ROUNDS:
		events.emit_released(1, 3)
		events.emit_damaged(2, 10)
		events.emit_destroyed(3)
		events.emit_ball_landed(4, 2)
		events.emit_multiplier_applied(1, 2, 5)
	var after: String = _sim_signature()
	t.eq(after, before, "B: simulation signature changed after presentation events")

	# Evidence the events really reached the bus, so "nothing changed" is not
	# "nothing happened".
	var delta: int = 0
	var now: Dictionary = events.snapshot()
	for key in now.keys():
		delta += int(now[key]) - int(emitted_before.get(key, 0))
	t.eq(delta, EVENT_ROUNDS * 5, "B: the bus did not record every event that was fired")

	# Positive control: real damage must move the signature.
	var ids: Array = _main.runtime.turrets.keys()
	ids.sort()
	var target = _main.runtime.turrets[ids[0]]
	var health_before: int = int(target.health)
	target.take_damage(1)
	t.neq(_sim_signature(), before, "B control: take_damage(1) did not change the signature")
	t.eq(int(target.health), health_before - 1, "B control: health did not drop by 1")


# --- C. one-way-ness --------------------------------------------------------

# The bus must not expose anything a simulation node could read back. This is a
# structural check on the contract, and it is what keeps a future FX or HUD
# subscriber from turning presentation into a second source of truth.
func _test_event_bus_is_one_way(t: TestAssert) -> void:
	print("  [C] presentation bus exposes no writable simulation surface")
	var events = _main.presentation_events
	for method in ["emit_released", "emit_damaged", "emit_destroyed", "emit_ball_landed", "emit_multiplier_applied"]:
		t.that(events.has_method(method), "C: bus is missing %s" % method)
	var snapshot: Dictionary = events.snapshot()
	t.that(snapshot is Dictionary, "C: snapshot() does not return a dictionary")
	# The counters must be a copy: a caller editing the returned dictionary must
	# not be able to rewrite what the bus recorded.
	snapshot["released"] = 999999
	t.neq(int(events.snapshot().get("released", 0)), 999999, "C: snapshot() leaks the internal counter dictionary")
