extends RefCounted
class_name MatchRandom

enum Stream { CHAMBER, TURRET, PROJECTILE, EVENT, PALETTE }

var root_seed: int
var _streams: Dictionary[Vector2i, RandomNumberGenerator] = {}
# 公平性实验：把阵营身份与随机流身份拆开。空数组 = 原行为（流跟着阵营）。
var _faction_stream_map: Array = []


func _init(requested_seed: int, faction_stream_map: Array = []) -> void:
	root_seed = requested_seed
	if requested_seed < 0:
		var entropy := RandomNumberGenerator.new()
		entropy.randomize()
		root_seed = entropy.seed
	set_faction_stream_map(faction_stream_map)


func set_faction_stream_map(values: Array) -> void:
	_faction_stream_map = values.duplicate()


func get_stream(channel: Stream, faction: int = -1) -> RandomNumberGenerator:
	var stream_faction: int = _stream_faction(channel, faction)
	var key := Vector2i(channel, stream_faction)
	if not _streams.has(key):
		# Fixed derivation keeps one stream independent of creation or draw order.
		var bytes := ("%d:%d:%d" % [root_seed, channel, stream_faction]).sha256_buffer()
		var stream := RandomNumberGenerator.new()
		stream.seed = bytes.decode_s64(0)
		_streams[key] = stream
	return _streams[key]


func _stream_faction(channel: int, faction: int) -> int:
	# 事件流（阵营 -1）与配色流不参与阵营映射。
	if faction < 0 or channel >= Stream.EVENT or _faction_stream_map.is_empty():
		return faction
	if faction < _faction_stream_map.size():
		return int(_faction_stream_map[faction])
	return faction


static func parse_faction_stream_map(raw: String, rotation: int = 0) -> Array:
	# identity | slot | reverse | rotate1..3 | 显式排列 "1,2,3,0"
	var value: String = raw.strip_edges().to_lower()
	if value == "" or value == "identity":
		return []
	if value == "slot":
		var slot_map: Array = []
		for faction in range(4):
			slot_map.append(posmod(faction + rotation, 4))
		return slot_map
	if value == "reverse":
		return [3, 2, 1, 0]
	if value == "rotate1":
		return [1, 2, 3, 0]
	if value == "rotate2":
		return [2, 3, 0, 1]
	if value == "rotate3":
		return [3, 0, 1, 2]
	var parts: PackedStringArray = value.split(",")
	if parts.size() != 4:
		return []
	var seen: Dictionary = {}
	var mapped: Array = []
	for part in parts:
		var token: String = part.strip_edges()
		if not token.is_valid_int():
			return []
		var mapped_faction: int = int(token)
		if mapped_faction < 0 or mapped_faction > 3 or seen.has(mapped_faction):
			return []
		seen[mapped_faction] = true
		mapped.append(mapped_faction)
	return mapped


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
