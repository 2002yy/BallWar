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


func serialize_states() -> Array:
	# JSON 没有 64 位整数；状态用十进制字符串保存，避免低位被浮点截断。
	var entries: Array = []
	var keys := _streams.keys()
	keys.sort()
	for key in keys:
		if key.x != Stream.PALETTE:
			entries.append([key.x, key.y, str(_streams[key].state)])
	return entries


func restore_states(entries) -> bool:
	if not (entries is Array):
		return false
	# 先完整校验，再替换：坏存档不能把当前对局的随机流清空。
	var parsed: Array = []
	for entry in entries:
		if not (entry is Array) or entry.size() < 3:
			return false
		var channel: int = int(entry[0])
		var faction: int = int(entry[1])
		if channel < Stream.CHAMBER or channel >= Stream.PALETTE:
			return false
		parsed.append([channel, faction, int(str(entry[2]))])
	_streams.clear()
	for item in parsed:
		var stream := get_stream(item[0], item[1])
		stream.state = item[2]
	return true
