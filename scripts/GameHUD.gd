extends CanvasLayer
class_name GameHUD

@onready var top_panel: Panel = get_node("TopPanel")
@onready var top_panel_bg: ColorRect = get_node("TopPanel/Bg")
@onready var top_panel_accent: ColorRect = get_node("TopPanel/AccentLine")
@onready var top_panel_header: ColorRect = get_node("TopPanel/HeaderStrip")
@onready var leader_label: Label = get_node("TopPanel/LeaderLabel")
@onready var timer_label: Label = get_node("TopPanel/TimerLabel")
@onready var stage_label: Label = get_node("TopPanel/StageLabel")
@onready var top_bar_shell: Panel = get_node("TopPanel/BarBG")
@onready var top_bar_inner: ColorRect = get_node("TopPanel/BarBG/BarInner")
@onready var badge: Control = get_node("TopPanel/Badge")
@onready var game_title_label: Label = get_node("TopPanel/GameTitleLabel")
@onready var palette_label: Label = get_node("TopPanel/PaletteLabel")

@onready var fps_bg: ColorRect = get_node("FPSBg")
@onready var fps_label: Label = get_node("FPSLabel")
@onready var event_label: Label = get_node("EventLabel")
@onready var settings_button: Button = get_node("SettingsButton")
@onready var pause_button: Button = get_node("PauseButton")
@onready var exit_button: Button = get_node("ExitButton")
@onready var pause_overlay: Control = get_node("PauseOverlay")
@onready var pause_panel: Panel = get_node("PauseOverlay/PausePanel")
@onready var resume_button: Button = get_node("PauseOverlay/PausePanel/ResumeButton")
@onready var save_exit_button: Button = get_node("PauseOverlay/PausePanel/SaveExitButton")
@onready var winner_label: Label = get_node("WinnerLabel")

var settings_panel: Panel
var top_bar_segments: Dictionary = {}
var top_bar_labels: Dictionary = {}
var top_bar_name_labels: Dictionary = {}
var top_bar_total_width: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_collect_top_bar_nodes()
	_load_settings_panel()

func setup_static(controller_ref, view_size: Vector2, current_layout: Dictionary = {}, mobile_mode: bool = false) -> void:
	var layout: Dictionary = current_layout if not current_layout.is_empty() else LayoutProfiles.get_profile(40)
	_collect_top_bar_nodes()

	var top_panel_w: float = float(layout.get("top_panel_w", 710.0))
	var top_panel_h: float = float(layout.get("top_panel_h", 90.0))
	if mobile_mode:
		top_panel_w = minf(top_panel_w, 660.0)
		top_panel_h = 98.0

	top_panel.position = Vector2((view_size.x - top_panel_w) * 0.5, 8.0)
	top_panel.size = Vector2(top_panel_w, top_panel_h)
	top_panel_bg.position = Vector2(4.0, 4.0)
	top_panel_bg.size = top_panel.size - Vector2(8.0, 8.0)
	top_panel_accent.position = Vector2(12.0, 4.0)
	top_panel_accent.size = Vector2(top_panel.size.x - 24.0, 2.0)
	top_panel_header.position = Vector2(10.0, 6.0)
	top_panel_header.size = Vector2(top_panel.size.x - 20.0, 22.0)

	leader_label.position = Vector2(16.0, 4.0)
	leader_label.size = Vector2(176.0, 24.0)
	timer_label.position = Vector2((top_panel.size.x - 110.0) * 0.5, 1.0)
	timer_label.size = Vector2(110.0, 26.0)
	stage_label.position = Vector2(top_panel.size.x - 182.0, 4.0)
	stage_label.size = Vector2(168.0, 24.0)

	var bar_h: float = float(layout.get("bar_h", 36.0))
	top_bar_shell.position = Vector2(18.0, 31.0)
	top_bar_shell.size = Vector2(top_panel.size.x - 36.0, bar_h)
	top_bar_inner.position = Vector2(3.0, 3.0)
	top_bar_inner.size = Vector2(top_bar_shell.size.x - 6.0, top_bar_shell.size.y - 6.0)
	top_bar_total_width = top_bar_inner.size.x
	_layout_top_bar_segments()

	badge.position = Vector2(top_panel.size.x * 0.5 - 118.0, 60.0)
	badge.size = Vector2(28.0, 28.0)
	game_title_label.position = Vector2(0.0, top_panel.size.y - 26.0)
	game_title_label.size = Vector2(top_panel.size.x, 28.0)
	game_title_label.add_theme_font_size_override("font_size", 24 if mobile_mode else int(layout.get("title_font", 31)))

	if mobile_mode:
		palette_label.visible = false
	else:
		palette_label.visible = true
		palette_label.position = Vector2(top_panel.size.x - 166.0, 66.0)
		palette_label.size = Vector2(152.0, 22.0)
		palette_label.text = "配色：%s" % GameConfig.get_palette_name()
		palette_label.add_theme_font_size_override("font_size", int(layout.get("palette_font", 16)))

	_layout_side_buttons(view_size, mobile_mode)
	_layout_bottom_hud(view_size, mobile_mode)
	_layout_pause_overlay(view_size)
	winner_label.position = Vector2(0.0, float(layout.get("winner_y", 666.0)))
	winner_label.size = Vector2(view_size.x, 34.0)

	_refresh_settings_panel_content(mobile_mode)
	_connect_if_available(settings_button, controller_ref, "_toggle_settings_panel")
	_connect_if_available(pause_button, controller_ref, "_toggle_pause")
	_connect_if_available(exit_button, controller_ref, "_save_and_exit_to_menu")
	_connect_if_available(resume_button, controller_ref, "_toggle_pause")
	_connect_if_available(save_exit_button, controller_ref, "_save_and_exit_to_menu")

func get_static_parts() -> Dictionary:
	return {
		"ui_canvas": self,
		"top_bar_segments": top_bar_segments,
		"top_bar_labels": top_bar_labels,
		"top_bar_name_labels": top_bar_name_labels,
		"top_bar_total_width": top_bar_total_width,
		"winner_label": winner_label,
		"game_title_label": game_title_label,
		"pause_overlay": pause_overlay,
		"pause_button": pause_button,
		"exit_button": exit_button,
		"fps_label": fps_label,
		"settings_button": settings_button,
		"settings_panel": settings_panel,
		"leader_label": leader_label,
		"timer_label": timer_label,
		"stage_label": stage_label,
		"event_label": event_label,
	}

func setup_side_buttons(controller_ref) -> void:
	_connect_if_available(settings_button, controller_ref, "_toggle_settings_panel")
	_connect_if_available(pause_button, controller_ref, "_toggle_pause")
	_connect_if_available(exit_button, controller_ref, "_save_and_exit_to_menu")

func _collect_top_bar_nodes() -> void:
	top_bar_segments = {
		GameConfig.Faction.BLUE: get_node("TopPanel/BarBG/BarInner/BlueSegment"),
		GameConfig.Faction.RED: get_node("TopPanel/BarBG/BarInner/RedSegment"),
		GameConfig.Faction.GREEN: get_node("TopPanel/BarBG/BarInner/GreenSegment"),
		GameConfig.Faction.YELLOW: get_node("TopPanel/BarBG/BarInner/YellowSegment"),
	}
	top_bar_labels = {
		GameConfig.Faction.BLUE: get_node("TopPanel/BarBG/BarInner/BlueSegment/ValueLabel"),
		GameConfig.Faction.RED: get_node("TopPanel/BarBG/BarInner/RedSegment/ValueLabel"),
		GameConfig.Faction.GREEN: get_node("TopPanel/BarBG/BarInner/GreenSegment/ValueLabel"),
		GameConfig.Faction.YELLOW: get_node("TopPanel/BarBG/BarInner/YellowSegment/ValueLabel"),
	}
	top_bar_name_labels = {
		GameConfig.Faction.BLUE: get_node("TopPanel/BarBG/BarInner/BlueSegment/NameLabel"),
		GameConfig.Faction.RED: get_node("TopPanel/BarBG/BarInner/RedSegment/NameLabel"),
		GameConfig.Faction.GREEN: get_node("TopPanel/BarBG/BarInner/GreenSegment/NameLabel"),
		GameConfig.Faction.YELLOW: get_node("TopPanel/BarBG/BarInner/YellowSegment/NameLabel"),
	}

func _layout_top_bar_segments() -> void:
	var x_offset: float = 3.0
	var segment_height: float = top_bar_inner.size.y
	var segment_width: float = top_bar_total_width * 0.25
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		var segment: Panel = top_bar_segments.get(faction_id, null)
		if segment == null:
			continue
		segment.position = Vector2(x_offset, 3.0)
		segment.size = Vector2(segment_width, segment_height)

		var fill: ColorRect = segment.get_node("Fill") as ColorRect
		fill.position = Vector2(2.0, 2.0)
		fill.size = Vector2(segment.size.x - 4.0, segment.size.y - 4.0)
		fill.color = GameConfig.faction_color(faction_id)

		var gloss: ColorRect = segment.get_node("Gloss") as ColorRect
		gloss.position = Vector2(2.0, 2.0)
		gloss.size = Vector2(segment.size.x - 4.0, maxf(5.0, (segment.size.y - 4.0) * 0.42))

		var bottom_shadow: ColorRect = segment.get_node("BottomShadow") as ColorRect
		bottom_shadow.position = Vector2(2.0, maxf(4.0, segment.size.y - 8.0))
		bottom_shadow.size = Vector2(segment.size.x - 4.0, 4.0)

		var name_label: Label = top_bar_name_labels.get(faction_id, null)
		name_label.position = Vector2(6.0, 2.0)
		name_label.size = Vector2(74.0, 14.0)
		name_label.text = GameConfig.faction_name(faction_id)
		name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.56))

		var value_label: Label = top_bar_labels.get(faction_id, null)
		value_label.position = Vector2(0.0, -1.0)
		value_label.size = segment.size

		if segment.has_node("Separator"):
			var separator: ColorRect = segment.get_node("Separator") as ColorRect
			separator.position = Vector2(segment.size.x - 2.0, 0.0)
			separator.size = Vector2(2.0, segment.size.y)

		x_offset += segment.size.x

func _layout_side_buttons(view_size: Vector2, mobile_mode: bool) -> void:
	var side_button_size: Vector2 = Vector2(114.0, 46.0) if mobile_mode else Vector2(96.0, 42.0)
	var side_margin: float = 12.0 if mobile_mode else 18.0
	var side_gap: float = 8.0
	var side_x: float = view_size.x - side_button_size.x - side_margin

	_apply_button_layout(settings_button, Vector2(side_x, 84.0), side_button_size)
	_apply_button_layout(pause_button, Vector2(side_x, 84.0 + side_button_size.y + side_gap), side_button_size)
	_apply_button_layout(exit_button, Vector2(side_x, 84.0 + (side_button_size.y + side_gap) * 2.0), side_button_size)

	if settings_panel != null and is_instance_valid(settings_panel):
		var settings_panel_size: Vector2 = Vector2(278.0, 92.0) if mobile_mode else Vector2(286.0, 96.0)
		var settings_panel_x: float = clampf(side_x - settings_panel_size.x + side_button_size.x, 10.0, view_size.x - settings_panel_size.x - 10.0)
		settings_panel.position = Vector2(settings_panel_x, exit_button.position.y + side_button_size.y + 10.0)
		settings_panel.size = settings_panel_size

func _layout_bottom_hud(view_size: Vector2, mobile_mode: bool) -> void:
	fps_bg.position = Vector2(396.0, 652.0)
	fps_bg.size = Vector2(714.0, 30.0)
	fps_bg.visible = not mobile_mode
	fps_label.position = Vector2(402.0, 649.0)
	fps_label.size = Vector2(702.0, 24.0)
	fps_label.visible = not mobile_mode

	var event_label_size: Vector2 = Vector2(260.0, 22.0) if mobile_mode else Vector2(332.0, 24.0)
	var event_label_pos: Vector2 = Vector2(
		fps_label.position.x + fps_label.size.x - event_label_size.x,
		fps_label.position.y - event_label_size.y - 4.0
	)
	if mobile_mode:
		event_label_pos = Vector2(view_size.x - event_label_size.x - 12.0, view_size.y - 84.0)
	event_label.position = event_label_pos
	event_label.size = event_label_size

func _layout_pause_overlay(view_size: Vector2) -> void:
	pause_overlay.position = Vector2.ZERO
	pause_overlay.size = view_size
	var dimmer: ColorRect = pause_overlay.get_node("Dimmer") as ColorRect
	dimmer.size = view_size
	pause_panel.position = Vector2((view_size.x - pause_panel.size.x) * 0.5, (view_size.y - pause_panel.size.y) * 0.5)

func _apply_button_layout(button: Button, position_value: Vector2, size_value: Vector2) -> void:
	button.position = position_value
	button.size = size_value

func _load_settings_panel() -> void:
	var sp_path: String = "res://scenes/ui/SettingsPanel.tscn"
	if ResourceLoader.exists(sp_path):
		settings_panel = load(sp_path).instantiate()
		settings_panel.name = "SettingsPanel"
		add_child(settings_panel)
		print("[GameHUD] Loaded SettingsPanel.tscn")
	else:
		settings_panel = Panel.new()
		settings_panel.name = "SettingsPanel"
		settings_panel.visible = false
		settings_panel.process_mode = Node.PROCESS_MODE_ALWAYS
		settings_panel.self_modulate = Color(0.94, 0.97, 1.0, 0.96)
		settings_panel.size = Vector2(286.0, 96.0)
		add_child(settings_panel)
		print("[GameHUD] SettingsPanel.tscn not found, fallback to code-generated")

func _refresh_settings_panel_content(mobile_mode: bool) -> void:
	if settings_panel == null or not is_instance_valid(settings_panel):
		return

	var layout_name: String = "手机横屏" if mobile_mode else "电脑"
	if settings_panel.has_method("show_content"):
		settings_panel.show_content(GameConfig.get_quality_name(), layout_name)
		if settings_panel.has_method("hide_panel"):
			settings_panel.hide_panel()
		else:
			settings_panel.visible = false
		return

	if settings_panel.has_node("ContentLabel"):
		var content_label: Label = settings_panel.get_node("ContentLabel") as Label
		content_label.text = "画质：%s\n布局：%s\n说明：手机使用大按钮布局，电脑保留更多 HUD 信息。" % [GameConfig.get_quality_name(), layout_name]
		settings_panel.visible = false

func _connect_if_available(button: Button, controller_ref, method_name: String) -> void:
	if button == null or controller_ref == null or not controller_ref.has_method(method_name):
		return
	var target := Callable(controller_ref, method_name)
	if not button.pressed.is_connected(target):
		button.pressed.connect(target)
