extends Control
class_name SettingsPanelController

const PlayerSettingsStore = preload("res://scripts/PlayerSettingsStore.gd")

signal settings_changed(settings: Dictionary)

@onready var performance_check: CheckButton = get_node("PanelMargin/MainVBox/PerformanceCheck")
@onready var low_effect_check: CheckButton = get_node("PanelMargin/MainVBox/LowEffectCheck")
@onready var event_log_check: CheckButton = get_node("PanelMargin/MainVBox/EventLogCheck")

var current_settings: Dictionary = {}


func _ready() -> void:
	current_settings = PlayerSettingsStore.load_settings()
	_apply_settings_to_controls()

	performance_check.toggled.connect(_on_setting_toggled)
	low_effect_check.toggled.connect(_on_setting_toggled)
	event_log_check.toggled.connect(_on_setting_toggled)
	get_node("PanelMargin/MainVBox/CloseButton").pressed.connect(hide_panel)


func _apply_settings_to_controls() -> void:
	performance_check.button_pressed = bool(current_settings.get("show_performance_info", true))
	low_effect_check.button_pressed = bool(current_settings.get("low_effect_mode", false))
	event_log_check.button_pressed = bool(current_settings.get("show_event_log", true))


func _on_setting_toggled(_pressed: bool) -> void:
	current_settings["show_performance_info"] = performance_check.button_pressed
	current_settings["low_effect_mode"] = low_effect_check.button_pressed
	current_settings["show_event_log"] = event_log_check.button_pressed
	PlayerSettingsStore.save_settings(current_settings)
	settings_changed.emit(current_settings.duplicate())


func show_panel() -> void:
	current_settings = PlayerSettingsStore.load_settings()
	_apply_settings_to_controls()
	visible = true


func hide_panel() -> void:
	visible = false
