extends CanvasLayer
class_name GameHUD

@onready var fps_label: Label = get_node("FPSLabel")
@onready var event_label: Label = get_node("EventLabel")
@onready var settings_button: Button = get_node("SettingsButton")
@onready var pause_button: Button = get_node("PauseButton")
@onready var exit_button: Button = get_node("ExitButton")
@onready var pause_overlay: Control = get_node("PauseOverlay")
@onready var winner_label: Label = get_node("WinnerLabel")

var settings_panel: Panel

func _ready() -> void:
	var sp_path: String = "res://scenes/ui/SettingsPanel.tscn"
	if ResourceLoader.exists(sp_path):
		settings_panel = load(sp_path).instantiate()
		settings_panel.name = "SettingsPanel"
		settings_panel.position = Vector2(816, 236)
		add_child(settings_panel)
		print("[GameHUD] Loaded SettingsPanel.tscn")
	else:
		settings_panel = Panel.new()
		settings_panel.name = "SettingsPanel"
		settings_panel.visible = false
		settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		settings_panel.self_modulate = Color(0.94, 0.97, 1.0, 0.96)
		settings_panel.position = Vector2(816, 236)
		settings_panel.size = Vector2(286, 96)
		add_child(settings_panel)
		print("[GameHUD] SettingsPanel.tscn not found, fallback to code-generated")

func setup_static(owner, _view_size: Vector2) -> void:
	fps_label.visible = true
	settings_button.pressed.connect(Callable(owner, "_toggle_settings_panel"))
	pause_button.pressed.connect(Callable(owner, "_toggle_pause"))
	exit_button.pressed.connect(Callable(owner, "_save_and_exit_to_menu"))

func setup_side_buttons(owner) -> void:
	settings_button.pressed.connect(Callable(owner, "_toggle_settings_panel"))
	pause_button.pressed.connect(Callable(owner, "_toggle_pause"))
	exit_button.pressed.connect(Callable(owner, "_save_and_exit_to_menu"))

func get_static_parts() -> Dictionary:
	return {
		"fps_label": fps_label,
		"event_label": event_label,
		"settings_button": settings_button,
		"pause_button": pause_button,
		"exit_button": exit_button,
		"settings_panel": settings_panel,
		"pause_overlay": pause_overlay,
		"winner_label": winner_label,
	}
