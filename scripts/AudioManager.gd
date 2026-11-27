extends Node
class_name AudioManager

# Presentation-only audio. Nothing here may influence simulation: it subscribes
# to PresentationEvents, which Main fills from simulation signals, and it never
# writes back into gameplay state. There is no polling of gameplay or visual
# state anywhere in this file.
#
# Buses are created here instead of in project.godot so the audio graph is
# reviewable in one place and the project file stays untouched.
#
# Voice budget: a fixed pool of players, round-robin with stealing. The bullet
# pool can hold 6000 bullets; giving each one a player would be the obvious way
# to kill the frame budget, so sound is only emitted for discrete events and the
# pool size is what bounds simultaneous voices.

const MASTER_BUS := "Master"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

const POOL_SIZE := 8

# Event name (PresentationEvents) -> sound kind. This table is the extension
# point: a new mechanic adds its event and one line here, and nothing else in
# the audio path changes.
const KIND_BY_EVENT := {
	"released": "release",
	"damaged": "hit",
	"destroyed": "destroy",
	"ball_landed": "ball_land",
	"multiplier_applied": "multiplier",
}

# Per-kind minimum spacing in milliseconds. Dense bursts collapse into one sound
# instead of turning into noise, and the CPU cost stays flat.
const MIN_INTERVAL_MS := {
	"release": 95,
	"hit": 130,
	"destroy": 140,
	"multiplier": 120,
	"ball_land": 70,
}

# Per-kind trim in dB, applied on top of the SFX bus volume. The first pass was
# reported as "too shrill": dense repeats of a bright sample read as a hiss
# rather than as impacts. Repeat-fire events get pushed down hardest because
# they are the ones that overlap.
const KIND_TRIM_DB := {
	"release": -9.0,
	"hit": -7.0,
	"destroy": -3.0,
	"multiplier": -6.0,
	"ball_land": -6.0,
}

# Small pitch scatter. Identical repeats at identical pitch are what make a
# burst sound synthetic and piercing; +-5% is enough to break the monotony
# without sounding detuned.
const PITCH_JITTER := 0.05

# One low-pass on the SFX bus: the cheap, global answer to "too sharp". Keeps
# the body of the sounds and removes the top end that carries the sting.
# Set CUTOFF_HZ to 0.0 to disable.
const SFX_LOWPASS_HZ := 5200.0

const SFX_PATHS := {
	"release": "res://assets/sfx/bullets/bullet_fire_retro_01.ogg",
	"hit": "res://assets/sfx/chamber/chamber_gate_bong_01.ogg",
	"destroy": "res://assets/sfx/turret_destroy/turret_destroy_explosion_01.ogg",
	"multiplier": "res://assets/sfx/chamber/chamber_gate_pluck_01.ogg",
	"ball_land": "res://assets/sfx/chamber/chamber_gate_drop_01.ogg",
}

var master_volume: float = 0.7
var sfx_volume: float = 0.55
var music_volume: float = 0.6  # must match PlayerSettingsStore defaults

var _streams: Dictionary = {}
var _pool: Array = []
var _next_player: int = 0
var _last_play_ms: Dictionary = {}
var _played_counts: Dictionary = {}
var _enabled: bool = true
# Own RNG stream. Drawing from the global one would shift the sequence that
# Bullet's hit-check jitter depends on, i.e. audio would change the match.
var _rng := RandomNumberGenerator.new()
var _events = null


func _ready() -> void:
	_ensure_buses()
	_rng.seed = 0x5EA0D10
	for kind in SFX_PATHS.keys():
		var path: String = String(SFX_PATHS[kind])
		if ResourceLoader.exists(path):
			_streams[kind] = load(path)
		else:
			push_warning("[Audio] missing sound for '%s': %s" % [kind, path])
		_last_play_ms[kind] = -100000
		_played_counts[kind] = 0
	_apply_sfx_lowpass()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
	apply_volumes(master_volume, sfx_volume, music_volume)


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(MASTER_BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, MASTER_BUS)
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var idx: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, MASTER_BUS)


func _apply_sfx_lowpass() -> void:
	if SFX_LOWPASS_HZ <= 0.0:
		return
	var idx: int = AudioServer.get_bus_index(SFX_BUS)
	if idx < 0:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			return
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = SFX_LOWPASS_HZ
	AudioServer.add_bus_effect(idx, lp)


func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		# Muting has to be immediate: sounds already in flight would otherwise
		# keep playing for up to a second after the switch.
		stop_all()


# Pausing the match must not leave a tail of battle sounds ringing, and it must
# not queue anything up either - events are played immediately, so there is
# nothing to drain on resume.
func on_pause_changed(paused: bool) -> void:
	if paused:
		stop_all()


func stop_all() -> void:
	for player in _pool:
		if player != null and player.playing:
			player.stop()


# Bind once, from the composition root. Consumers receive normalised events and
# never reach into simulation nodes.
#
# One handler per signal rather than a bound name argument: Callable.bind()
# appends the bound values *after* the signal's own arguments, so a single
# generic handler would read the event name from the wrong position whenever the
# signal's arity differs from 3.
func bind_presentation(events) -> void:
	if events == null or _events == events:
		return
	_events = events
	_connect_once(events.released, Callable(self, "_on_released"))
	_connect_once(events.damaged, Callable(self, "_on_damaged"))
	_connect_once(events.destroyed, Callable(self, "_on_destroyed"))
	_connect_once(events.ball_landed, Callable(self, "_on_ball_landed"))
	_connect_once(events.multiplier_applied, Callable(self, "_on_multiplier_applied"))


func _connect_once(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)


func _on_released(_faction_id = null, _count = null) -> void:
	_play_event("released")


func _on_damaged(_faction_id = null, _amount = null) -> void:
	_play_event("damaged")


func _on_destroyed(_faction_id = null) -> void:
	_play_event("destroyed")


func _on_ball_landed(_faction_id = null, _ball_count = null) -> void:
	_play_event("ball_landed")


func _on_multiplier_applied(_faction_id = null, _multiplier = null, _pending = null) -> void:
	_play_event("multiplier_applied")


func _play_event(event_name: String) -> void:
	play(String(KIND_BY_EVENT.get(event_name, event_name)))


func event_counts() -> Dictionary:
	if _events != null and _events.has_method("snapshot"):
		return _events.snapshot()
	return {}


# Volumes are linear 0..1. Master scales everything through the bus graph; the
# music bus exists even though this batch only ships SFX.
func apply_volumes(master: float, sfx: float, music: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	_set_bus_linear(MASTER_BUS, master_volume)
	_set_bus_linear(SFX_BUS, sfx_volume)
	_set_bus_linear(MUSIC_BUS, music_volume)


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func play(kind: String) -> bool:
	# Master at zero already silences the whole graph through the bus, so starting
	# a player would buy nothing and still pay for it. Returning here is what makes
	# "master down" mean "no SFX work at all" instead of "muted but still paying".
	# The same reasoning covers SFX at zero, which was already handled.
	if not _enabled or master_volume <= 0.001 or sfx_volume <= 0.001:
		return false
	if not _streams.has(kind):
		return false
	var now: int = Time.get_ticks_msec()
	var last: int = int(_last_play_ms.get(kind, -100000))
	var gap: int = int(MIN_INTERVAL_MS.get(kind, 50))
	if now - last < gap:
		return false
	_last_play_ms[kind] = now
	var player: AudioStreamPlayer = _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = _streams[kind]
	player.volume_db = float(KIND_TRIM_DB.get(kind, 0.0))
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()
	_played_counts[kind] = int(_played_counts.get(kind, 0)) + 1
	return true


func play_counts() -> Dictionary:
	return _played_counts.duplicate()
