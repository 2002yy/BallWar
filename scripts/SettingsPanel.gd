extends Control
class_name SettingsPanelController

const PlayerSettingsStoreClass = preload("res://scripts/PlayerSettingsStore.gd")

signal settings_changed(settings: Dictionary)

@onready var performance_check: CheckButton = get_node("PanelMargin/MainVBox/PerformanceCheck")
@onready var low_effect_check: CheckButton = get_node("PanelMargin/MainVBox/LowEffectCheck")
@onready var event_log_check: CheckButton = get_node("PanelMargin/MainVBox/EventLogCheck")
@onready var master_slider: HSlider = get_node("PanelMargin/MainVBox/MasterVolumeRow/MasterVolumeSlider")
@onready var sfx_slider: HSlider = get_node("PanelMargin/MainVBox/SfxVolumeRow/SfxVolumeSlider")
@onready var music_slider: HSlider = get_node("PanelMargin/MainVBox/MusicVolumeRow/MusicVolumeSlider")

var current_settings: Dictionary = {}
# Dragging a slider fires value_changed per pixel; writing the JSON file that
# often is pointless I/O. The value is applied immediately and only the write is
# deferred until the drag ends (or the panel closes).
var _volume_save_timer: float = 0.0
const VOLUME_SAVE_DELAY := 0.35


func _ready() -> void:
	current_settings = PlayerSettingsStoreClass.load_settings()
	_apply_settings_to_controls()

	performance_check.toggled.connect(_on_setting_toggled)
	low_effect_check.toggled.connect(_on_setting_toggled)
	event_log_check.toggled.connect(_on_setting_toggled)
	master_slider.value_changed.connect(_on_volume_changed)
	sfx_slider.value_changed.connect(_on_volume_changed)
	music_slider.value_changed.connect(_on_volume_changed)
	master_slider.drag_ended.connect(_on_volume_drag_ended)
	sfx_slider.drag_ended.connect(_on_volume_drag_ended)
	music_slider.drag_ended.connect(_on_volume_drag_ended)
	get_node("PanelMargin/MainVBox/CloseButton").pressed.connect(hide_panel)


func _process(delta: float) -> void:
	if _volume_save_timer <= 0.0:
		return
	_volume_save_timer -= delta
	if _volume_save_timer <= 0.0:
		_flush_volume_save()


func _apply_settings_to_controls() -> void:
	performance_check.set_pressed_no_signal(bool(current_settings.get("show_performance_info", true)))
	low_effect_check.set_pressed_no_signal(bool(current_settings.get("low_effect_mode", false)))
	event_log_check.set_pressed_no_signal(bool(current_settings.get("show_event_log", true)))
	master_slider.set_value_no_signal(_unit(current_settings, "master_volume", 0.7))
	sfx_slider.set_value_no_signal(_unit(current_settings, "sfx_volume", 0.55))
	music_slider.set_value_no_signal(_unit(current_settings, "music_volume", 0.6))


func _unit(settings: Dictionary, key: String, fallback: float) -> float:
	var raw = settings.get(key, fallback)
	var value: float = float(raw) if (raw is float or raw is int) else fallback
	if not is_finite(value):
		return fallback
	return clampf(value, 0.0, 1.0)


func _on_setting_toggled(_pressed: bool) -> void:
	current_settings["show_performance_info"] = performance_check.button_pressed
	current_settings["low_effect_mode"] = low_effect_check.button_pressed
	current_settings["show_event_log"] = event_log_check.button_pressed
	PlayerSettingsStoreClass.save_settings(current_settings)
	settings_changed.emit(current_settings.duplicate())


func _on_volume_changed(_value: float) -> void:
	current_settings["master_volume"] = master_slider.value
	current_settings["sfx_volume"] = sfx_slider.value
	current_settings["music_volume"] = music_slider.value
	# Applied at once so the player hears the slider while dragging it.
	settings_changed.emit(current_settings.duplicate())
	_volume_save_timer = VOLUME_SAVE_DELAY


func _on_volume_drag_ended(_value_changed: bool) -> void:
	_flush_volume_save()


func _flush_volume_save() -> void:
	_volume_save_timer = 0.0
	PlayerSettingsStoreClass.save_settings(current_settings)


func show_panel() -> void:
	current_settings = PlayerSettingsStoreClass.load_settings()
	_apply_settings_to_controls()
	visible = true


func hide_panel() -> void:
	if _volume_save_timer > 0.0:
		_flush_volume_save()
	visible = false
