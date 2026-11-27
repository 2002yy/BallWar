extends Node
class_name AudioManager

# Presentation-only audio. Nothing here may influence simulation: it is fed by
# signals and by one read-only poll of a public visual timer, and it never writes
# back into gameplay state.
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
	if not _enabled or sfx_volume <= 0.001:
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
