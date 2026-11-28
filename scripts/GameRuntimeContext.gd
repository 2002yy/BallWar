extends RefCounted
class_name GameRuntimeContext

var battlefield = null
var bullet_pool = null
var turrets: Dictionary = {}
var chambers: Dictionary = {}
var hud: Dictionary = {}
var ui_runtime: Dictionary = {}
var event_controller = null
var event_view = null
var current_config: Dictionary = {}
var current_layout: Dictionary = {}
var match_config = null
var reserve_economy: ReserveEconomy

func reset() -> void:
    battlefield = null
    bullet_pool = null
    turrets.clear()
    chambers.clear()
    hud.clear()
    ui_runtime.clear()
    event_controller = null
    event_view = null
    current_config.clear()
    current_layout.clear()
    match_config = null
    reserve_economy = null

func set_config(config: Dictionary) -> void:
    current_config = config.duplicate(true)

func set_match_config(config) -> void:
    match_config = config
    reserve_economy = ReserveEconomy.new(config.seed_value, config.reserve_price_preset) if config.reserve_economy_enabled else null

func set_layout(layout: Dictionary) -> void:
    current_layout = layout.duplicate(true)

func set_hud_parts(parts: Dictionary) -> void:
    hud = parts.duplicate(false)

func hud_ref(key: String, default_value = null):
    return hud.get(key, default_value)

func set_hud_ref(key: String, value) -> void:
    hud[key] = value

func ui_runtime_ref(key: String, default_value = null):
    return ui_runtime.get(key, default_value)

func set_ui_runtime_ref(key: String, value) -> void:
    ui_runtime[key] = value

func set_ui_runtime_parts(parts: Dictionary) -> void:
    for key in parts.keys():
        ui_runtime[key] = parts[key]
