extends RefCounted
class_name MatchConfig

# 一场对局的配置快照：地图、武器规则、模式、网格、种子、画质。
# P0 只建立容器与默认值（= 现有行为），不改任何战斗规则，也不写存档。
# 后续地图/弹种接入时，新字段只在这里扩展，不再散落到 GameConfig 静态变量。

const CLASSIC_MAP_ID: String = "classic_plains"
const KNOWN_MAP_IDS: Array[String] = [CLASSIC_MAP_ID]

var map_id: String = CLASSIC_MAP_ID
var weapon_ruleset_id: String = WeaponRuleset.CLASSIC_ID
var weapon_ruleset: WeaponRuleset
var grid_size: int = GameConfig.GRID_SIZE
var mode_name: String = GameConfig.GAME_MODE_BASIC
var quality_name: String = GameConfig.QUALITY_MEDIUM
var seed_value: int = -1
# P2 实验参数：默认值 = 只有普通弹、行为与经典一致。
var piercing_captures: int = 1
var piercing_mix_percent: int = 0
var explosion_radius: int = 0
var explosion_mix_percent: int = 0

func _init() -> void:
	weapon_ruleset = WeaponRuleset.for_id(weapon_ruleset_id)

static func capture_current(grid_size: int, seed_value: int = -1) -> MatchConfig:
	# 从现有全局状态取一份快照。P0 不迁移模式/画质的所有权，
	# 只保证地图与武器规则从第一场对局起就有唯一落点。
	var config := MatchConfig.new()
	config.grid_size = grid_size
	config.seed_value = seed_value
	config.mode_name = GameConfig.get_game_mode_name()
	config.quality_name = GameConfig.get_quality_name()
	config.piercing_captures = _env_int("BALLWAR_PIERCE", 1)
	config.piercing_mix_percent = clampi(_env_int("BALLWAR_MIX_PIERCING", 0), 0, 100)
	config.explosion_radius = clampi(_env_int("BALLWAR_EXPLOSION_RADIUS", 0), 0, 3)
	config.explosion_mix_percent = clampi(_env_int("BALLWAR_MIX_EXPLOSIVE", 0), 0, 100)
	config.sanitize()
	return config

func sanitize() -> void:
	if not KNOWN_MAP_IDS.has(map_id):
		map_id = CLASSIC_MAP_ID
	if not GameConfig.get_game_mode_names().has(mode_name):
		mode_name = GameConfig.GAME_MODE_BASIC
	if not GameConfig.get_quality_names().has(quality_name):
		quality_name = GameConfig.QUALITY_MEDIUM
	grid_size = LayoutProfiles.sanitize_grid_size(grid_size)
	if not WeaponRuleset.KNOWN_IDS.has(weapon_ruleset_id):
		weapon_ruleset_id = WeaponRuleset.CLASSIC_ID
	weapon_ruleset = WeaponRuleset.for_id(weapon_ruleset_id)
	if piercing_captures != -1:
		piercing_captures = clampi(piercing_captures, 1, 10)
	piercing_mix_percent = clampi(piercing_mix_percent, 0, 100)
	explosion_radius = clampi(explosion_radius, 0, 3)
	explosion_mix_percent = clampi(explosion_mix_percent, 0, 100)
	var experiment_types: Array = []
	if piercing_mix_percent > 0:
		experiment_types.append(WeaponRuleset.BulletType.PIERCING)
	if explosion_mix_percent > 0:
		experiment_types.append(WeaponRuleset.BulletType.EXPLOSIVE)
	if not experiment_types.is_empty():
		weapon_ruleset = WeaponRuleset.with_unlocked(experiment_types)

func volley_shares() -> Dictionary:
	var shares: Dictionary = {}
	if piercing_mix_percent > 0:
		shares[WeaponRuleset.BulletType.PIERCING] = piercing_mix_percent
	if explosion_mix_percent > 0:
		shares[WeaponRuleset.BulletType.EXPLOSIVE] = explosion_mix_percent
	return shares

func allocate_volley(fire: int, shares: Dictionary = {}) -> Dictionary:
	if weapon_ruleset == null:
		weapon_ruleset = WeaponRuleset.classic()
	if shares.is_empty():
		shares = volley_shares()
	return weapon_ruleset.allocate(fire, shares)

static func _env_int(key: String, fallback: int) -> int:
	var raw: String = OS.get_environment(key).strip_edges()
	if raw == "" or not raw.is_valid_int():
		return fallback
	return int(raw)
