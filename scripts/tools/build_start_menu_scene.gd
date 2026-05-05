# TOOL-ONLY SCRIPT — DO NOT RUN AFTER MANUAL EDITS.
# Running this script will overwrite scenes/ui/StartMenu.tscn.
# Only run intentionally when you need to regenerate from scratch.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := CanvasLayer.new()
	root.name = "StartMenu"
	root.script = preload("res://scripts/StartMenu.gd")
	_own_recursive(root, root)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.02, 0.03, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var main_panel := Panel.new()
	main_panel.name = "RootPanel"
	main_panel.position = Vector2(140, 22)
	main_panel.size = Vector2(840, 670)
	main_panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
	root.add_child(main_panel)

	var panel_bg := ColorRect.new()
	panel_bg.name = "PanelBg"
	panel_bg.position = Vector2(8, 8)
	panel_bg.size = main_panel.size - Vector2(16, 16)
	panel_bg.color = Color(0.08, 0.12, 0.18, 0.97)
	main_panel.add_child(panel_bg)

	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.position = Vector2(150, 16)
	title_label.size = Vector2(540, 56)
	title_label.text = "领土战争"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 44)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
	title_label.add_theme_constant_override("outline_size", 7)
	main_panel.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.position = Vector2(180, 72)
	subtitle_label.size = Vector2(480, 24)
	subtitle_label.text = "四控制仓 · 四角炮台 · 领土争夺"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	main_panel.add_child(subtitle_label)

	var mobile_hint := Label.new()
	mobile_hint.name = "MobileHint"
	mobile_hint.position = Vector2(180, 98)
	mobile_hint.size = Vector2(480, 22)
	mobile_hint.text = "电脑 / 安卓均可游玩 · 手机建议横屏"
	mobile_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mobile_hint.add_theme_font_size_override("font_size", 15)
	mobile_hint.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0))
	main_panel.add_child(mobile_hint)

	var decor := Node2D.new()
	decor.name = "ChamberPreview"
	decor.position = Vector2(420, 260)
	decor.scale = Vector2(0.78, 0.78)
	main_panel.add_child(decor)

	var config_panel := Panel.new()
	config_panel.name = "ConfigPanel"
	config_panel.position = Vector2(48, 372)
	config_panel.size = Vector2(744, 168)
	main_panel.add_child(config_panel)

	var cfg_bg := ColorRect.new()
	cfg_bg.name = "ConfigBg"
	cfg_bg.position = Vector2(4, 4)
	cfg_bg.size = config_panel.size - Vector2(8, 8)
	cfg_bg.color = Color(0.12, 0.16, 0.23)
	config_panel.add_child(cfg_bg)

	config_panel.add_child(_make_config_label("SizeLabel", "地图大小", Vector2(18, 14), Vector2(88, 24)))

	var size_option := OptionButton.new()
	size_option.name = "GridSizeOption"
	size_option.position = Vector2(104, 10)
	size_option.size = Vector2(126, 36)
	config_panel.add_child(size_option)

	config_panel.add_child(_make_config_label("ModeLabel", "游戏模式", Vector2(258, 14), Vector2(76, 24)))

	var mode_option := OptionButton.new()
	mode_option.name = "ModeOption"
	mode_option.position = Vector2(340, 10)
	mode_option.size = Vector2(136, 36)
	config_panel.add_child(mode_option)

	config_panel.add_child(_make_config_label("QualityLabel", "画质", Vector2(506, 14), Vector2(42, 24)))

	var quality_option := OptionButton.new()
	quality_option.name = "QualityOption"
	quality_option.position = Vector2(548, 10)
	quality_option.size = Vector2(60, 36)
	config_panel.add_child(quality_option)

	config_panel.add_child(_make_config_label("TimeLabel", "限时", Vector2(626, 14), Vector2(44, 24)))

	var time_spin := SpinBox.new()
	time_spin.name = "TimeSpin"
	time_spin.position = Vector2(668, 10)
	time_spin.size = Vector2(58, 36)
	time_spin.min_value = GameConfig.TIMED_MODE_MIN_MINUTES
	time_spin.max_value = GameConfig.TIMED_MODE_MAX_MINUTES
	time_spin.step = 1.0
	time_spin.value = GameConfig.DEFAULT_TIMED_MODE_MINUTES
	config_panel.add_child(time_spin)

	config_panel.add_child(_make_config_label("PaletteLabel", "配色方案", Vector2(18, 58), Vector2(88, 24)))

	var palette_option := OptionButton.new()
	palette_option.name = "PaletteOption"
	palette_option.position = Vector2(104, 54)
	palette_option.size = Vector2(162, 36)
	config_panel.add_child(palette_option)

	var mode_tip := Label.new()
	mode_tip.name = "ModeTip"
	mode_tip.position = Vector2(288, 52)
	mode_tip.size = Vector2(270, 76)
	mode_tip.text = "占领：达到 75% 胜利\n限时：5~15 分钟结算\n狂野：全局 x3，单次上限 2187，事件更频繁"
	mode_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_tip.add_theme_font_size_override("font_size", 13)
	mode_tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	config_panel.add_child(mode_tip)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.position = Vector2(590, 72)
	start_button.size = Vector2(134, 52)
	start_button.text = "开始 / 覆盖存档"
	start_button.add_theme_font_size_override("font_size", 18)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.self_modulate = Color(0.22, 0.60, 1.0)
	config_panel.add_child(start_button)

	var save_panel := Panel.new()
	save_panel.name = "SavePanel"
	save_panel.position = Vector2(48, 548)
	save_panel.size = Vector2(744, 82)
	main_panel.add_child(save_panel)

	var save_bg := ColorRect.new()
	save_bg.name = "SaveBg"
	save_bg.position = Vector2(4, 4)
	save_bg.size = save_panel.size - Vector2(8, 8)
	save_bg.color = Color(0.10, 0.14, 0.20)
	save_panel.add_child(save_bg)

	var save_title := Label.new()
	save_title.name = "SaveTitle"
	save_title.position = Vector2(14, 6)
	save_title.size = Vector2(300, 22)
	save_title.text = "选择存档槽（暂停 / 退出会保存到当前槽）"
	save_title.add_theme_font_size_override("font_size", 13)
	save_title.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	save_panel.add_child(save_title)

	var slot_container := Control.new()
	slot_container.name = "SaveSlotContainer"
	slot_container.position = Vector2(0, 32)
	slot_container.size = Vector2(744, 40)
	for slot in range(1, 6):
		var btn := Button.new()
		btn.name = "SlotButton_%d" % slot
		btn.position = Vector2(14 + float(slot - 1) * 144.0, 0)
		btn.size = Vector2(136, 36)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.self_modulate = Color(0.16, 0.22, 0.32)
		slot_container.add_child(btn)
	save_panel.add_child(slot_container)

	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.position = Vector2(648, 500)
	continue_button.size = Vector2(120, 44)
	continue_button.text = "读取槽1"
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.add_theme_color_override("font_color", Color.WHITE)
	continue_button.self_modulate = Color(0.20, 0.66, 0.42)
	main_panel.add_child(continue_button)

	var menu_status_label := Label.new()
	menu_status_label.name = "MenuStatusLabel"
	menu_status_label.position = Vector2(120, 636)
	menu_status_label.size = Vector2(600, 22)
	menu_status_label.text = "当前存档槽：1"
	menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_status_label.add_theme_font_size_override("font_size", 15)
	menu_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.44))
	menu_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	menu_status_label.add_theme_constant_override("outline_size", 2)
	main_panel.add_child(menu_status_label)

	_own_recursive(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/ui/StartMenu.tscn")
	print("SUCCESS: scenes/ui/StartMenu.tscn")
	quit(0)

func _own_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		_own_recursive(child, scene_root)

func _make_config_label(node_name: String, text_value: String, pos: Vector2, sz: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = pos
	label.size = sz
	label.text = text_value
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label
