extends RefCounted
class_name StartMenuView

static func create(owner, view_size: Vector2, has_save_file: bool) -> Dictionary:
    owner.selected_grid_size = 40
    owner.selected_palette_name = "默认随机"
    owner.selected_quality_name = "中"
    owner.selected_game_mode_name = GameConfig.GAME_MODE_BASIC

    var menu_layer = CanvasLayer.new()
    menu_layer.name = "MenuLayer"
    owner.add_child(menu_layer)

    var shade = ColorRect.new()
    shade.color = Color(0.02, 0.03, 0.05, 0.72)
    shade.size = view_size
    menu_layer.add_child(shade)

    var panel = Panel.new()
    panel.size = Vector2(790, 620)
    panel.position = Vector2((view_size.x - panel.size.x) * 0.5, 30)
    panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
    menu_layer.add_child(panel)

    var panel_bg = ColorRect.new()
    panel_bg.position = Vector2(8, 8)
    panel_bg.size = panel.size - Vector2(16, 16)
    panel_bg.color = Color(0.08, 0.12, 0.18, 0.97)
    panel.add_child(panel_bg)

    var title = Label.new()
    title.position = Vector2(125, 18)
    title.size = Vector2(540, 58)
    title.text = "领土战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.add_theme_font_size_override("font_size", 44)
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
    title.add_theme_constant_override("outline_size", 7)
    panel.add_child(title)

    var subtitle = Label.new()
    subtitle.position = Vector2(155, 74)
    subtitle.size = Vector2(480, 26)
    subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    panel.add_child(subtitle)

    var mobile_hint = Label.new()
    mobile_hint.position = Vector2(155, 102)
    mobile_hint.size = Vector2(480, 22)
    mobile_hint.text = "电脑/安卓均可游玩 · 手机建议横屏"
    mobile_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    mobile_hint.add_theme_font_size_override("font_size", 15)
    mobile_hint.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0))
    panel.add_child(mobile_hint)

    var decor = preload("res://scripts/MenuDecor.gd").new()
    decor.position = Vector2(395, 285)
    decor.scale = Vector2(0.82, 0.82)
    panel.add_child(decor)

    var config_panel = Panel.new()
    config_panel.position = Vector2(86, 454)
    config_panel.size = Vector2(590, 126)
    panel.add_child(config_panel)

    var cfg_bg = ColorRect.new()
    cfg_bg.position = Vector2(4, 4)
    cfg_bg.size = config_panel.size - Vector2(8, 8)
    cfg_bg.color = Color(0.12, 0.16, 0.23)
    config_panel.add_child(cfg_bg)

    var size_label = Label.new()
    size_label.position = Vector2(18, 12)
    size_label.size = Vector2(88, 24)
    size_label.text = "地图大小"
    size_label.add_theme_font_size_override("font_size", 17)
    size_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(size_label)

    var size_option = OptionButton.new()
    size_option.position = Vector2(104, 8)
    size_option.size = Vector2(126, 36)
    size_option.add_item("10 × 10", 10)
    size_option.add_item("20 × 20", 20)
    size_option.add_item("30 × 30", 30)
    size_option.add_item("40 × 40", 40)
    size_option.add_item("50 × 50", 50)
    size_option.add_item("60 × 60", 60)
    size_option.select(3)
    size_option.item_selected.connect(func(index: int) -> void:
        owner.selected_grid_size = size_option.get_item_id(index)
    )
    config_panel.add_child(size_option)

    var mode_label = Label.new()
    mode_label.position = Vector2(258, 12)
    mode_label.size = Vector2(76, 24)
    mode_label.text = "游戏模式"
    mode_label.add_theme_font_size_override("font_size", 17)
    mode_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(mode_label)

    var mode_option = OptionButton.new()
    mode_option.position = Vector2(340, 8)
    mode_option.size = Vector2(134, 36)
    for mode_name in GameConfig.get_game_mode_names():
        mode_option.add_item(mode_name)
    mode_option.select(0)
    mode_option.item_selected.connect(func(index: int) -> void:
        owner.selected_game_mode_name = mode_option.get_item_text(index)
    )
    config_panel.add_child(mode_option)

    var quality_label = Label.new()
    quality_label.position = Vector2(492, 12)
    quality_label.size = Vector2(42, 24)
    quality_label.text = "画质"
    quality_label.add_theme_font_size_override("font_size", 17)
    quality_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(quality_label)

    var quality_option = OptionButton.new()
    quality_option.position = Vector2(526, 8)
    quality_option.size = Vector2(52, 36)
    for quality_name in GameConfig.get_quality_names():
        quality_option.add_item(quality_name)
    quality_option.select(1)
    quality_option.item_selected.connect(func(index: int) -> void:
        owner.selected_quality_name = quality_option.get_item_text(index)
    )
    config_panel.add_child(quality_option)

    var palette_label = Label.new()
    palette_label.position = Vector2(18, 52)
    palette_label.size = Vector2(88, 24)
    palette_label.text = "配色方案"
    palette_label.add_theme_font_size_override("font_size", 17)
    palette_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(palette_label)

    var palette_option = OptionButton.new()
    palette_option.position = Vector2(104, 48)
    palette_option.size = Vector2(162, 36)
    palette_option.add_item("默认随机")
    for palette_name in GameConfig.get_palette_names():
        palette_option.add_item(palette_name)
    palette_option.select(0)
    palette_option.item_selected.connect(func(index: int) -> void:
        owner.selected_palette_name = palette_option.get_item_text(index)
    )
    config_panel.add_child(palette_option)

    var mode_tip = Label.new()
    mode_tip.position = Vector2(282, 48)
    mode_tip.size = Vector2(168, 50)
    mode_tip.text = "占领：60%胜利\n限时：3分钟结算\n狂野：事件预留"
    mode_tip.add_theme_font_size_override("font_size", 13)
    mode_tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    config_panel.add_child(mode_tip)

    var start_button = Button.new()
    start_button.position = Vector2(462, 58)
    start_button.size = Vector2(112, 46)
    start_button.text = "开始"
    start_button.add_theme_font_size_override("font_size", 22)
    start_button.add_theme_color_override("font_color", Color.WHITE)
    start_button.add_theme_color_override("font_hover_color", Color.WHITE)
    start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
    start_button.self_modulate = Color(0.22, 0.60, 1.0)
    start_button.pressed.connect(func() -> void:
        owner._start_game(owner.selected_grid_size)
    )
    config_panel.add_child(start_button)

    var menu_status_label = Label.new()
    menu_status_label.position = Vector2(120, 590)
    menu_status_label.size = Vector2(550, 22)
    menu_status_label.text = ""
    menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    menu_status_label.add_theme_font_size_override("font_size", 15)
    menu_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.44))
    menu_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
    menu_status_label.add_theme_constant_override("outline_size", 2)
    panel.add_child(menu_status_label)

    var continue_button = null
    if has_save_file:
        continue_button = Button.new()
        continue_button.position = Vector2(680, 500)
        continue_button.size = Vector2(88, 50)
        continue_button.text = "继续"
        continue_button.add_theme_font_size_override("font_size", 21)
        continue_button.add_theme_color_override("font_color", Color.WHITE)
        continue_button.self_modulate = Color(0.20, 0.66, 0.42)
        continue_button.pressed.connect(Callable(owner, "_continue_saved_game"))
        panel.add_child(continue_button)

        var save_tip = Label.new()
        save_tip.position = Vector2(650, 556)
        save_tip.size = Vector2(132, 20)
        save_tip.text = "检测到存档"
        save_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
        save_tip.add_theme_font_size_override("font_size", 13)
        save_tip.add_theme_color_override("font_color", Color(0.75, 0.95, 0.80))
        panel.add_child(save_tip)

    return {
        "menu_layer": menu_layer,
        "menu_title_label": title,
        "menu_start_button": start_button,
        "menu_continue_button": continue_button,
        "menu_status_label": menu_status_label,
    }
