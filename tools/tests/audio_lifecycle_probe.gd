extends SceneTree

# A4 audio verification: does each presentation event fire from real gameplay,
# and does the audio layer behave across mute, pause, and a rematch?
#
# This drives the shipped Main.tscn through the same start path as the menu, so
# the events come from the real rules - not from synthesised signals. The only
# fixture is topping up the chambers through the public add_control_ball() the
# +ball button uses, because a fresh 40x40 match keeps 1-4 bullets alive and the
# release pipeline would otherwise take minutes to fire often enough to observe.
#
# Two kinds of checks, deliberately kept apart:
#   PASS - the event fires in a real match
#   PATH - the event and its sound work when the entry point is called, but no
#          hit happened in THIS sample, which is not the same as "the rules make
#          it unreachable". These are
#          reported with the measurement that shows why, instead of being forced
#          green or left as a permanent red that teaches everyone to ignore it.
#
# Run headless with an isolated user directory:
#   APPDATA=$(mktemp -d) <godot> --headless --audio-driver Dummy --path . \
#     --script res://tools/tests/audio_lifecycle_probe.gd

const MAIN_SCENE = preload("res://scenes/Main.tscn")

var _main = null
var _failures: int = 0
var _checks: int = 0
var _gaps: Array = []
var _min_enemy_turret_distance: float = 99999.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	_main.name = "ProbeMain"
	get_root().add_child(_main)
	for i in 8:
		await process_frame

	_main.selected_grid_size = 40
	_main.selected_palette_name = "经典"
	_main.selected_quality_name = GameConfig.QUALITY_HIGH
	_main.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_main.selected_time_limit_minutes = 3
	_main.selected_save_slot = 5
	_main.match_seed = 12345
	_main._start_game(40, true, true)
	for i in 4:
		await process_frame

	_check(_main.presentation_events != null, "presentation events object exists")
	_check(_main.audio_manager != null, "audio manager exists")

	_fill_chambers()
	# Wait until the events the current rules can actually produce have fired, or
	# give up after three minutes of match time. Recording *when* each first fired
	# matters: audio wired to something that only happens after five minutes is
	# not shipped audio.
	var first_seen: Dictionary = await _watch_events(180.0, [
		"released", "ball_landed", "multiplier_applied",
	])

	var events: Dictionary = _main.presentation_events.snapshot()
	var played: Dictionary = _main.audio_manager.play_counts()
	print("[A4] events = ", JSON.stringify(events))
	print("[A4] played = ", JSON.stringify(played))
	print("[A4] first_seen = ", JSON.stringify(first_seen))
	print("[A4] closest a bullet ever got to an enemy turret: %.2f px (hit radius %.1f px)" % [
		_min_enemy_turret_distance, GameConfig.TURRET_HIT_RADIUS])

	_check(int(events.get("released", 0)) > 0, "release fired from a real gate pass")
	_check(int(events.get("ball_landed", 0)) > 0, "ball_landed fired from a real +ball")
	_check(int(events.get("multiplier_applied", 0)) > 0, "multiplier applied at a real gate")

	for kind in ["release", "multiplier", "ball_land"]:
		_check(int(played.get(kind, 0)) > 0, "sound played at least once: %s" % kind)

	# Reachability verdict for the two combat events. The entry point is exercised
	# directly below, but a real match has to be able to reach it too.
	var reachable: bool = _min_enemy_turret_distance <= GameConfig.TURRET_HIT_RADIUS
	if not reachable:
		_note_gap(
			"damaged / destroyed",
			"no bullet came within %.1f px of an enemy turret in three match minutes (hit radius %.1f px); this run cannot show whether the hit path is reachable in normal play, and the likeliest cause is territory depth in front of the turret" % [
				_min_enemy_turret_distance, GameConfig.TURRET_HIT_RADIUS])

	_check_damage_path(reachable)
	_check_destroy_path(reachable)
	_check_player_pool_bounded()
	await _check_mute()
	await _check_pause()
	await _check_rematch_connections()
	await _check_result_screen()

	if not _gaps.is_empty():
		print("[A4] ---- gaps (not failures, but not working combat audio either) ----")
		for gap in _gaps:
			print("[A4] PATH  %s: %s" % [gap[0], gap[1]])

	print("[A4] %d checks, %d failures, %d gaps" % [_checks, _failures, _gaps.size()])
	print("[A4] RESULT %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check_damage_path(naturally_reachable: bool) -> void:
	var before_events: int = int(_main.presentation_events.snapshot().get("damaged", 0))
	var before_plays: int = int(_main.audio_manager.play_counts().get("hit", 0))
	for turret in _main.runtime.turrets.values():
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			# Exactly the call Bullet._try_hit_enemy_turret makes on a hit.
			turret.take_damage(1)
			break
	var after_events: int = int(_main.presentation_events.snapshot().get("damaged", 0))
	var after_plays: int = int(_main.audio_manager.play_counts().get("hit", 0))
	_check(after_events > before_events, "damaged fires when a turret takes damage")
	_check(after_plays > before_plays, "hit sound plays when a turret takes damage")
	if not naturally_reachable:
		_note_gap("damaged", "entry point verified directly; no hit occurred in this sample (see distance above)")


func _check_destroy_path(naturally_reachable: bool) -> void:
	var before_events: int = int(_main.presentation_events.snapshot().get("destroyed", 0))
	var before_plays: int = int(_main.audio_manager.play_counts().get("destroy", 0))
	for turret in _main.runtime.turrets.values():
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			turret.take_damage(9999)
			break
	var after_events: int = int(_main.presentation_events.snapshot().get("destroyed", 0))
	var after_plays: int = int(_main.audio_manager.play_counts().get("destroy", 0))
	_check(after_events > before_events, "destroyed fires when a turret dies")
	_check(after_plays > before_plays, "destroy sound plays when a turret dies")
	if not naturally_reachable:
		_note_gap("destroyed", "same hit path as damaged; no hit happened in this sample")


func _fill_chambers() -> void:
	var added: int = 0
	for chamber in _main.runtime.chambers.values():
		if chamber == null or not is_instance_valid(chamber):
			continue
		for i in 64:
			if not chamber.add_control_ball():
				break
			added += 1
	print("[A4] fixture: added %d control balls" % added)


func _watch_events(deadline_seconds: float, required: Array) -> Dictionary:
	var first_seen: Dictionary = {}
	var frame: int = 0
	while true:
		if _main == null or not is_instance_valid(_main):
			return first_seen
		if bool(_main.is_game_over):
			return first_seen
		if float(_main.game_elapsed_time) >= deadline_seconds:
			return first_seen
		frame += 1
		# Sampling every frame copies the counter dictionary a thousand times a
		# second; every 8th frame is still far finer than the sounds measured.
		if frame % 8 == 0:
			_sample_turret_distance()
			var counts: Dictionary = _main.presentation_events.snapshot()
			var missing: bool = false
			for key in required:
				if int(counts.get(key, 0)) > 0:
					if not first_seen.has(key):
						first_seen[key] = snappedf(float(_main.game_elapsed_time), 0.01)
				else:
					missing = true
			if not missing:
				return first_seen
		await process_frame
	return first_seen


# How close do bullets actually get to an enemy turret? This is the number that
# decides whether turret damage is reachable at all, so it is measured rather
# than assumed.
func _sample_turret_distance() -> void:
	var pool = _main.runtime.bullet_pool
	if pool == null or not pool.has_method("get_active_bullets"):
		return
	for bullet in pool.get_active_bullets():
		for faction_id in _main.runtime.turrets.keys():
			var turret = _main.runtime.turrets[faction_id]
			if turret == null or not is_instance_valid(turret) or turret.is_destroyed:
				continue
			if int(faction_id) == int(bullet.faction_id):
				continue
			var distance: float = bullet.global_position.distance_to(turret.global_position)
			if distance < _min_enemy_turret_distance:
				_min_enemy_turret_distance = distance


func _check_player_pool_bounded() -> void:
	var playing: int = 0
	for player in _main.audio_manager._pool:
		if player != null and player.playing:
			playing += 1
	_check(_main.audio_manager._pool.size() == 8, "voice pool stays at 8 players")
	_check(playing <= 8, "simultaneous voices never exceed the pool (%d)" % playing)


func _check_mute() -> void:
	_main.audio_manager.set_enabled(false)
	var playing_after_mute: int = 0
	for player in _main.audio_manager._pool:
		if player != null and player.playing:
			playing_after_mute += 1
	_check(playing_after_mute == 0, "muting stops sounds already in flight")

	var plays_before: int = int(_main.audio_manager.play_counts().get("release", 0))
	var events_before: int = int(_main.presentation_events.snapshot().get("released", 0))
	await _trigger_release()
	var plays_after: int = int(_main.audio_manager.play_counts().get("release", 0))
	var events_after: int = int(_main.presentation_events.snapshot().get("released", 0))
	# Both halves matter: if no release happened at all, "no sound" proves nothing.
	_check(events_after > events_before, "releases keep firing while muted")
	_check(plays_after == plays_before, "muted: no sound is scheduled")

	_main.audio_manager.set_enabled(true)
	_check(_main.audio_manager.play("release"), "unmuting resumes playback")
	for i in 3:
		await process_frame

	# Master at zero must skip the work, not just mute the bus. Checked on the
	# return value because that is what tells a caller whether a player was
	# started: bus muting alone would still have paid for play().
	var saved_master: float = _main.audio_manager.master_volume
	_main.audio_manager.apply_volumes(0.0, _main.audio_manager.sfx_volume, _main.audio_manager.music_volume)
	var played_at_zero: bool = _main.audio_manager.play("release")
	_main.audio_manager.apply_volumes(saved_master, _main.audio_manager.sfx_volume, _main.audio_manager.music_volume)
	_check(not played_at_zero, "master at zero skips playback instead of muting the bus")
	# Real time, not frames: the per-kind throttle is wall-clock based, and the
	# check above just consumed this kind's slot if it got as far as a player.
	OS.delay_msec(150)
	_check(_main.audio_manager.play("release"), "master back up resumes playback")


func _trigger_release() -> void:
	# The real path: a ball added to a chamber eventually passes a gate. Adding
	# several raises the chance that one release lands inside a few frames.
	for chamber in _main.runtime.chambers.values():
		if chamber != null and is_instance_valid(chamber):
			for i in 4:
				chamber.add_control_ball()
	for i in 90:
		await process_frame


func _check_pause() -> void:
	_main.audio_manager.play("destroy")
	await process_frame
	_main._toggle_pause()
	await process_frame
	_check(paused, "pause actually pauses the tree")
	var playing: int = 0
	for player in _main.audio_manager._pool:
		if player != null and player.playing:
			playing += 1
	_check(playing == 0, "pause stops battle sounds instead of leaving a tail")
	_main._toggle_pause()
	await process_frame
	_check(not paused, "unpause resumes the tree")
	await process_frame
	await process_frame


func _check_rematch_connections() -> void:
	_main._start_game(40, true, true)
	for i in 4:
		await process_frame
	var duplicates: int = 0
	for turret in _main.runtime.turrets.values():
		if turret == null or not is_instance_valid(turret):
			continue
		for pair in [["damaged", "_on_turret_damaged_sfx"], ["destroyed", "_on_turret_destroyed_sfx"]]:
			var signal_name: String = String(pair[0])
			if not turret.has_signal(signal_name):
				continue
			var count: int = _count_callback(turret.get(signal_name), String(pair[1]))
			if count != 1:
				print("[A4] turret %s -> %s via %s: %d" % [turret.name, signal_name, pair[1], count])
				duplicates += 1
	for chamber in _main.runtime.chambers.values():
		if chamber == null or not is_instance_valid(chamber):
			continue
		for pair in [
			["release_requested", "_on_release_sfx"],
			["ball_landed", "_on_ball_landed_sfx"],
			["gate_multiplier_applied", "_on_gate_multiplier_sfx"],
		]:
			var signal_name: String = String(pair[0])
			if not chamber.has_signal(signal_name):
				continue
			var count: int = _count_callback(chamber.get(signal_name), String(pair[1]))
			if count != 1:
				print("[A4] chamber %s -> %s via %s: %d" % [chamber.name, signal_name, pair[1], count])
				duplicates += 1
	_check(duplicates == 0, "no duplicated signal connections after a rematch")
	_check(_main.presentation_events.snapshot().is_empty(), "rematch resets the event counters")


# 结算 (result screen) was the one lifecycle state the rest of this probe never
# reached: every check above runs inside a live match. The questions here are
# narrow - does the result arrive at all, does the match actually go quiet, and
# is audio still usable on the "再来一局" that follows - because "audio plays
# during a match" says nothing about what happens when the match stops.
func _check_result_screen() -> void:
	# One sound in flight when the match ends, so "the result screen is quiet"
	# is a real observation instead of an empty pool. Deliberately not "destroy":
	# that kind has a 140 ms throttle, and pre-playing it here would swallow the
	# real destroy sounds asserted below. That was this probe's own bug the first
	# time round, not an audio bug.
	_main.audio_manager.play("hit")
	OS.delay_msec(250)
	var before_destroyed: int = int(_main.presentation_events.snapshot().get("destroyed", 0))
	var before_destroy_plays: int = int(_main.audio_manager.play_counts().get("destroy", 0))

	var ids: Array = _main.runtime.turrets.keys()
	ids.sort()
	var destroyed_now: int = 0
	for i in range(ids.size() - 1):
		var turret = _main.runtime.turrets[ids[i]]
		if turret != null and is_instance_valid(turret) and not turret.is_destroyed:
			turret.take_damage(9999)
			destroyed_now += 1
	for i in 30:
		await process_frame

	_check(_main.is_game_over, "match ends when only one turret is left")
	var winner_label = _main._hud_ref("winner_label")
	var winner_visible: bool = winner_label != null and is_instance_valid(winner_label) and winner_label.visible
	var winner_text: String = str(winner_label.text) if winner_label != null and is_instance_valid(winner_label) else ""
	print("[A4] result: winner_label visible=%s text='%s'" % [str(winner_visible), winner_text])
	_check(winner_visible and winner_text != "", "result panel shows a winner instead of an empty string")

	var destroyed_delta: int = int(_main.presentation_events.snapshot().get("destroyed", 0)) - before_destroyed
	var destroy_play_delta: int = int(_main.audio_manager.play_counts().get("destroy", 0)) - before_destroy_plays
	print("[A4] result: destroyed events +%d, destroy sounds +%d (turrets killed=%d)" % [
		destroyed_delta, destroy_play_delta, destroyed_now])
	_check(destroyed_delta >= destroyed_now, "each turret that dies raises 'destroyed'")
	_check(destroy_play_delta >= 1, "destroy sound plays on the final kill")

	var bullets_left: int = _main.runtime.bullet_pool.get_active_count()
	_check(bullets_left == 0, "game over clears bullets (was %d)" % bullets_left)

	# The result screen must fall silent on its own. Battle sounds are one-shots
	# of a second or two, so the honest question is not "is it silent 50 ms
	# later" but "does it stop by itself, and does the result screen start
	# anything new". Waiting for a bound also catches a stream that loops.
	var plays_at_game_over: int = _played_total()
	var silence_ms: int = 0
	while silence_ms < 6000 and _any_player_playing():
		OS.delay_msec(100)
		silence_ms += 100
	print("[A4] result: pool went quiet after %d ms of real time" % silence_ms)
	_check(not _any_player_playing(), "result screen goes quiet instead of leaving sounds looping")
	_check(_played_total() == plays_at_game_over, "result screen starts no new battle sounds")

	# The result screen is not a dead end for the audio layer.
	_check(_main.audio_manager.play("release"), "audio still responds after the match ended")

	_main._start_game(40, true, true)
	for i in 6:
		await process_frame
	_check(not _main.is_game_over, "再来一局 restarts into a live match")
	_check(_main.presentation_events.snapshot().is_empty(), "再来一局 clears the result event counters")
	# A fresh HUD comes from GameHUD.tscn, where WinnerLabel has no `visible`
	# override, so it is visible-with-empty-text from the first match onward. The
	# thing that matters is that the previous winner's text did not survive.
	var label_after = _main._hud_ref("winner_label")
	var text_after: String = str(label_after.text) if label_after != null and is_instance_valid(label_after) else ""
	print("[A4] result: after restart winner_label text='%s'" % text_after)
	_check(text_after == "", "再来一局 clears the winner text instead of leaving the old result on screen")
	_check(_main.audio_manager.play("release"), "audio still responds in the restarted match")


func _any_player_playing() -> bool:
	for player in _main.audio_manager._pool:
		if player != null and player.playing:
			return true
	return false


func _played_total() -> int:
	var total: int = 0
	var counts: Dictionary = _main.audio_manager.play_counts()
	for key in counts.keys():
		total += int(counts[key])
	return total


# Counts one *specific* callback, not every callback owned by Main: some signals
# legitimately have a second Main listener for gameplay (release_requested feeds
# the round tracker as well as the bus), and counting those as duplicates would
# report a bug that is not there.
func _count_callback(sig: Signal, method: String) -> int:
	var n: int = 0
	for entry in sig.get_connections():
		var cb = entry["callable"]
		if cb.get_object() == _main and String(cb.get_method()) == method:
			n += 1
	return n


func _note_gap(what: String, why: String) -> void:
	_gaps.append([what, why])


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[A4] %s  %s" % ["PASS" if ok else "FAIL", label])
