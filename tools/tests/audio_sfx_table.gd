extends SceneTree

# Prints the shipped SFX table: source length, per-kind trim, and the resulting
# gain at the default master/SFX settings. The numbers are read from the loaded
# resources and from AudioManager's own constants, so a document quoting this
# table cannot drift away from the code.
#
# AudioStreamOggVorbis has no mix_rate property (that one is on AudioStreamWAV),
# so no sample rate is printed rather than a guessed one.
#
# Run: APPDATA=$(mktemp -d) <godot> --headless --audio-driver Dummy --path . \
#        --script res://tools/tests/audio_sfx_table.gd

const AudioManagerScript = preload("res://scripts/AudioManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var order: Array = ["release", "hit", "destroy", "multiplier", "ball_land"]
	var manager = AudioManagerScript.new()
	get_root().add_child(manager)
	await process_frame

	# Default player settings: master 0.7 and SFX 0.55 both scale the signal, so
	# the two multiply. Every per-kind trim is applied on top, at play time.
	var bus_gain: float = manager.master_volume * manager.sfx_volume
	print("[SfxTable] default master=%.2f sfx=%.2f -> bus gain %+.2f dB" % [
		manager.master_volume, manager.sfx_volume, linear_to_db(bus_gain)])

	for kind in order:
		var path: String = String(AudioManagerScript.SFX_PATHS.get(kind, ""))
		var trim: float = float(AudioManagerScript.KIND_TRIM_DB.get(kind, 0.0))
		var gap: int = int(AudioManagerScript.MIN_INTERVAL_MS.get(kind, 0))
		var stream = manager._streams.get(kind, null)
		var length: float = stream.get_length() if stream != null else -1.0
		var effective: float = linear_to_db(bus_gain * pow(10.0, trim / 20.0))
		print("[SfxTable] %-11s len=%.3fs trim=%+.1fdB effective=%+.2fdB throttle=%dms  %s" % [
			kind, length, trim, effective, gap, path.get_file()])

	manager.stop_all()
	OS.delay_msec(150)
	get_root().remove_child(manager)
	manager.free()
	print("[SfxTable] every adjustment above is applied at play time; the five source files are unchanged")
	quit(0)
