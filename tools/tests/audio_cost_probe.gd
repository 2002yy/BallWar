extends SceneTree

# What does starting one sound cost, and what does that mean at real rates?
#
# The whole-match frame comparison (tools/tests/run_audio_perf_ab.sh) can only
# resolve a cost larger than the spread between two runs of the SAME build. At
# the current event rate - about one presentation event per second in a 40x40
# classic match - that comparison comes back as "no difference", which is true
# but says nothing about a dense-ammo future. So this measures the cost per
# sound start and converts it into a budget.
#
# What the measurement actually found, and why the probe is shaped this way:
# assigning the stream (1.1 us) and setting pitch (0.2 us) are free. The cost is
# AudioStreamPlayer.play(), about 0.4 ms, and it is the same with the Dummy and
# the WASAPI driver - so it is the cost of instantiating an Ogg playback, not an
# artefact of the headless driver.
#
# Run: APPDATA=$(mktemp -d) <godot> --headless --audio-driver Dummy --path . \
#        --script res://tools/tests/audio_cost_probe.gd
# Exit: 0 always. This is a measurement, not a gate.

const AudioManagerScript = preload("res://scripts/AudioManager.gd")
const PresentationEventsScript = preload("res://scripts/presentation/PresentationEvents.gd")

const WARMUP := 60
const ITERATIONS := 500

var _audio = null
var _events = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_events = PresentationEventsScript.new()
	_audio = AudioManagerScript.new()
	_audio.name = "CostAudio"
	get_root().add_child(_audio)
	_audio.bind_presentation(_events)
	await process_frame

	# Prime once: the very first play() also assigns the stream, and folding that
	# into the average is what made an earlier version of this probe report the
	# stream assignment as 400 us.
	_prime()

	var start_us: float = _measure_start(WARMUP)
	start_us = _measure_start(ITERATIONS)
	var throttled_us: float = _measure_throttled(ITERATIONS)
	var muted_us: float = _measure_muted(ITERATIONS)

	# Hard ceiling on sustained sound rate: the per-kind minimum spacing is the
	# only thing that bounds how many starts per second the mixer can be asked
	# for, so the worst case is every kind firing as fast as it is allowed.
	var ceiling_per_s: float = 0.0
	for kind in _audio.MIN_INTERVAL_MS.keys():
		ceiling_per_s += 1000.0 / float(_audio.MIN_INTERVAL_MS[kind])

	var per_second_ms: float = start_us * ceiling_per_s / 1000.0
	var report: Dictionary = {
		"iterations": ITERATIONS,
		"driver": AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "unknown",
		"start_us_per_sound": snappedf(start_us, 0.1),
		"throttled_us_per_call": snappedf(throttled_us, 0.001),
		"muted_us_per_call": snappedf(muted_us, 0.001),
		"throttle_ceiling_sounds_per_s": snappedf(ceiling_per_s, 0.1),
		"worst_case_ms_per_second": snappedf(per_second_ms, 0.001),
		"worst_case_share_of_60hz_budget": snappedf(per_second_ms / 16.667, 0.0001),
		"frame_budget_ms_60hz": 16.667,
		"note": "share is ms of audio work per second divided by one frame; 1.0 would mean a whole frame lost every second",
	}
	print("[AudioCost] %s" % JSON.stringify(report))
	_audio.stop_all()
	OS.delay_msec(200)
	quit(0)


func _prime() -> void:
	for kind in _audio._streams.keys():
		_audio._last_play_ms[kind] = -1000000
		_audio.play(String(kind))
	OS.delay_msec(50)


# The throttle would reject almost every call in a tight loop, which would
# measure the early return instead of a sound start. Backdating _last_play_ms
# deliberately defeats it: the expensive branch is the one under measurement.
func _measure_start(iterations: int) -> float:
	var start: int = Time.get_ticks_usec()
	for i in iterations:
		for kind in _audio._last_play_ms.keys():
			_audio._last_play_ms[kind] = -1000000
		_audio.play("release")
	var elapsed: int = Time.get_ticks_usec() - start
	return float(elapsed) / float(maxi(1, iterations))


# What a call costs when the throttle rejects it - the common case, since events
# arrive in clumps. This is the number that decides whether listening to many
# events is cheap or expensive.
func _measure_throttled(iterations: int) -> float:
	for kind in _audio._last_play_ms.keys():
		_audio._last_play_ms[kind] = Time.get_ticks_msec()
	var start: int = Time.get_ticks_usec()
	for i in iterations:
		_audio.play("release")
	var elapsed: int = Time.get_ticks_usec() - start
	return float(elapsed) / float(maxi(1, iterations))


func _measure_muted(iterations: int) -> float:
	_audio.set_enabled(false)
	var start: int = Time.get_ticks_usec()
	for i in iterations:
		_audio.play("release")
	var elapsed: int = Time.get_ticks_usec() - start
	_audio.set_enabled(true)
	return float(elapsed) / float(maxi(1, iterations))
