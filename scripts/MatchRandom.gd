extends RefCounted
class_name MatchRandom

enum Stream { CHAMBER, TURRET, PROJECTILE, EVENT, PALETTE }

var root_seed: int
var _streams: Dictionary[Vector2i, RandomNumberGenerator] = {}


func _init(requested_seed: int) -> void:
	root_seed = requested_seed
	if requested_seed < 0:
		var entropy := RandomNumberGenerator.new()
		entropy.randomize()
		root_seed = entropy.seed


func get_stream(channel: Stream, faction: int = -1) -> RandomNumberGenerator:
	var key := Vector2i(channel, faction)
	if not _streams.has(key):
		# Fixed derivation keeps one stream independent of creation or draw order.
		var bytes := ("%d:%d:%d" % [root_seed, channel, faction]).sha256_buffer()
		var stream := RandomNumberGenerator.new()
		stream.seed = bytes.decode_s64(0)
		_streams[key] = stream
	return _streams[key]


func simulation_states() -> Array:
	var entries: Array = []
	var keys := _streams.keys()
	keys.sort()
	for key in keys:
		if key.x != Stream.PALETTE:
			entries.append([key, _streams[key].state])
	return entries
