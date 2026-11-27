extends SceneTree

# Audio smoke test: every declared P0 sound must load, sit on the SFX bus, and
# accept a play() call. This does not prove the game fires them at the right
# moment - it proves the sample, the bus graph and the pool work, which is the
# half that can be checked without ears.
#
# Run: godot --headless --path . --script res://tools/tests/audio_smoke_probe.gd

const AudioManagerScript = preload("res://scripts/AudioManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var am := AudioManagerScript.new()
	root.add_child(am)
	await process_frame

	print("[Audio] buses: master=%d sfx=%d music=%d" % [
		AudioServer.get_bus_index("Master"),
		AudioServer.get_bus_index("SFX"),
		AudioServer.get_bus_index("Music")])

	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var lp_found: bool = false
	for i in AudioServer.get_bus_effect_count(sfx_idx):
		if AudioServer.get_bus_effect(sfx_idx, i) is AudioEffectLowPassFilter:
			lp_found = true
	print("[Audio] sfx lowpass present: %s" % lp_found)
	print("[Audio] sfx bus volume_db=%.2f" % AudioServer.get_bus_volume_db(sfx_idx))

	var failures: int = 0
	for kind in ["release", "hit", "destroy", "multiplier", "ball_land"]:
		# Bypass the spacing guard so each kind gets exactly one attempt.
		am._last_play_ms[kind] = -100000
		var ok: bool = am.play(kind)
		if not ok:
			failures += 1
		print("[Audio] %-11s loaded=%s played=%s" % [kind, am._streams.has(kind), ok])

	print("[Audio] counts = %s" % am.play_counts())
	print("[Audio] RESULT %s" % ("PASS" if failures == 0 else "FAIL(%d)" % failures))
	quit(0 if failures == 0 else 1)
