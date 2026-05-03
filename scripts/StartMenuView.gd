extends RefCounted
class_name StartMenuView

static func create(owner, view_size: Vector2, save_summaries: Array) -> Dictionary:
    owner.selected_grid_size = 40
    owner.selected_palette_name = "默认随机"
    owner.selected_quality_name = GameConfig.QUALITY_MEDIUM
    owner.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
    owner.selected_time_limit_minutes = GameConfig.DEFAULT_TIMED_MODE_MINUTES
    owner.selected_save_slot = clampi(int(owner.selected_save_slot), 1, owner.SAVE_SLOT_COUNT)

    var menu_layer := CanvasLayer.new()
    menu_layer.name = "MenuLayer"
    owner.add_child(menu_layer)

    var shade := ColorRect.new()
    shade.color = Color(0.02, 0.03, 0.05, 0.72)
    shade.size = view_size
    menu_layer.add_child(shade)

    var panel := Panel.new()
    panel.size = Vector2(840.0, 670.0)
    panel.position = Vector2((view_size.x - panel.size.x) * 0.5, 22.0)
    panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
    menu_layer.add_child(panel)

    var panel_bg := ColorRect.new()
    panel_bg.position = Vector2(8.0, 8.0)
    panel_bg.size = panel.size - Vector2(16.0, 16.0)
    panel_bg.color = Color(0.08, 0.12, 0.18, 0.97)
    panel.add_child(panel_bg)

    var title := Label.new()
    title.position = Vector2(150.0, 16.0)
    title.size = Vector2(540.0, 56.0)
    title.text = "领土战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.add_theme_font_size_override("font_size", 44)
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
    title.add_theme_constant_override("outline_size", 7)
    panel.add_child(title)

    var subtitle := Label.new()
    subtitle.position = Vector2(180.0, 72.0)
    subtitle.size = Vector2(480.0, 24.0)
    subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    panel.add_child(subtitle)

    var mobile_hint := Label.new()
    mobile_hint.position = Vector2(180.0, 98.0)
    mobile_hint.size = Vector2(480.0, 22.0)
    mobile_hint.text = "电脑 / 安卓均可游玩 · 手机建议横屏"
    mobile_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    mobile_hint.add_theme_font_size_override("font_size", 15)
    mobile_hint.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0))
    panel.add_child(mobile_hint)

    var decor = preload("res://scripts/MenuDecor.gd").new()
    decor.position = Vector2(420.0, 260.0)
    decor.scale = Vector2(0.78, 0.78)
    panel.add_child(decor)

    var config_panel := Panel.new()
    config_panel.position = Vector2(48.0, 372.0)
    config_panel.size = Vector2(744.0, 168.0)
    panel.add_child(config_panel)

    var cfg_bg := ColorRect.new()
    cfg_bg.position = Vector2(4.0, 4.0)
    cfg_bg.size = config_panel.size - Vector2(8.0, 8.0)
    cfg_bg.color = Color(0.12, 0.16, 0.23)
    config_panel.add_child(cfg_bg)

    config_panel.add_child(_make_config_label("地图大小", Vector2(18.0, 14.0), Vector2(88.0, 24.0)))
    var size_option := OptionButton.new()
    size_option.position = Vector2(104.0, 10.0)
    size_option.size = Vector2(126.0, 36.0)
    for grid_size in [10, 20, 30, 40, 50, 60]:
        size_option.add_item("%d × %d" % [grid_size, grid_size], grid_size)
    size_option.select(3)
    size_option.item_selected.connect(func(index: int) -> void:
        owner.selected_grid_size = size_option.get_item_id(index)
    )
    config_panel.add_child(size_option)

    config_panel.add_child(_make_config_label("游戏模式", Vector2(258.0, 14.0), Vector2(76.0, 24.0)))
    var mode_option := OptionButton.new()
    mode_option.position = Vector2(340.0, 10.0)
    mode_option.size = Vector2(136.0, 36.0)
    for mode_name in GameConfig.get_game_mode_names():
        mode_option.add_item(mode_name)
    mode_option.select(0)
    mode_option.item_selected.connect(func(index: int) -> void:
        owner.selected_game_mode_name = mode_option.get_item_text(index)
    )
    config_panel.add_child(mode_option)

    config_panel.add_child(_make_config_label("画质", Vector2(506.0, 14.0), Vector2(42.0, 24.0)))
    var quality_option := OptionButton.new()
    quality_option.position = Vector2(548.0, 10.0)
    quality_option.size = Vector2(60.0, 36.0)
    for quality_name in GameConfig.get_quality_names():
        quality_option.add_item(quality_name)
    quality_option.select(1)
    quality_option.item_selected.connect(func(index: int) -> void:
        owner.selected_quality_name = quality_option.get_item_text(index)
    )
    config_panel.add_child(quality_option)

    config_panel.add_child(_make_config_label("限时", Vector2(626.0, 14.0), Vector2(44.0, 24.0)))
    var time_spin := SpinBox.new()
    time_spin.position = Vector2(668.0, 10.0)
    time_spin.size = Vector2(58.0, 36.0)
    time_spin.min_value = GameConfig.TIMED_MODE_MIN_MINUTES
    time_spin.max_value = GameConfig.TIMED_MODE_MAX_MINUTES
    time_spin.step = 1.0
    time_spin.value = GameConfig.DEFAULT_TIMED_MODE_MINUTES
    time_spin.tooltip_text = "限时模式分钟数，范围 5~15 分钟。"
    time_spin.value_changed.connect(func(value: float) -> void:
        owner.selected_time_limit_minutes = clampi(int(round(value)), GameConfig.TIMED_MODE_MIN_MINUTES, GameConfig.TIMED_MODE_MAX_MINUTES)
    )
    config_panel.add_child(time_spin)

    config_panel.add_child(_make_config_label("配色方案", Vector2(18.0, 58.0), Vector2(88.0, 24.0)))
    var palette_option := OptionButton.new()
    palette_option.position = Vector2(104.0, 54.0)
    palette_option.size = Vector2(162.0, 36.0)
    palette_option.add_item("默认随机")
    for palette_name in GameConfig.get_palette_names():
        palette_option.add_item(palette_name)
    palette_option.select(0)
    palette_option.item_selected.connect(func(index: int) -> void:
        owner.selected_palette_name = palette_option.get_item_text(index)
    )
    config_panel.add_child(palette_option)

    var mode_tip := Label.new()
    mode_tip.position = Vector2(288.0, 52.0)
    mode_tip.size = Vector2(270.0, 76.0)
    mode_tip.text = "占领：达到 75% 胜利\n限时：5~15 分钟结算\n狂野：全局 x3，单次上限 2187，事件更频繁"
    mode_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
    mode_tip.add_theme_font_size_override("font_size", 13)
    mode_tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    config_panel.add_child(mode_tip)

    var start_button := Button.new()
    start_button.position = Vector2(590.0, 72.0)
    start_button.size = Vector2(134.0, 52.0)
    start_button.text = "开始 / 覆盖存档"
    start_button.add_theme_font_size_override("font_size", 18)
    start_button.add_theme_color_override("font_color", Color.WHITE)
    start_button.add_theme_color_override("font_hover_color", Color.WHITE)
    start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
    start_button.self_modulate = Color(0.22, 0.60, 1.0)
    start_button.pressed.connect(func() -> void:
        owner._start_game(owner.selected_grid_size)
    )
    config_panel.add_child(start_button)

    var save_panel := Panel.new()
    save_panel.position = Vector2(48.0, 548.0)
    save_panel.size = Vector2(744.0, 82.0)
    panel.add_child(save_panel)

    var save_bg := ColorRect.new()
    save_bg.position = Vector2(4.0, 4.0)
    save_bg.size = save_panel.size - Vector2(8.0, 8.0)
    save_bg.color = Color(0.10, 0.14, 0.20)
    save_panel.add_child(save_bg)

    var save_title := Label.new()
    save_title.position = Vector2(14.0, 6.0)
    save_title.size = Vector2(300.0, 22.0)
    save_title.text = "选择存档槽（暂停 / 退出会保存到当前槽）"
    save_title.add_theme_font_size_override("font_size", 13)
    save_title.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    save_panel.add_child(save_title)

    var save_slot_buttons: Dictionary = {}
    for summary in save_summaries:
        if not (summary is Dictionary):
            continue
        var slot: int = int(summary.get("slot", 1))
        var button := Button.new()
        button.position = Vector2(14.0 + float(slot - 1) * 144.0, 32.0)
        button.size = Vector2(136.0, 36.0)
        var title_text: String = str(summary.get("title", "空存档"))
        var marker: String = "● " if slot == owner.selected_save_slot else ""
        button.text = "%s槽%d  %s" % [marker, slot, title_text]
        button.clip_text = true
        button.tooltip_text = "%s\n%s" % [title_text, str(summary.get("detail", ""))]
        button.add_theme_font_size_override("font_size", 12)
        button.add_theme_color_override("font_color", Color.WHITE)
        button.self_modulate = Color(0.28, 0.54, 0.88) if slot == owner.selected_save_slot else Color(0.16, 0.22, 0.32)
        var captured_slot: int = slot
        button.pressed.connect(func() -> void:
            owner._select_save_slot(captured_slot)
        )
        save_panel.add_child(button)
        save_slot_buttons[slot] = button

    var continue_button := Button.new()
    continue_button.position = Vector2(648.0, 500.0)
    continue_button.size = Vector2(120.0, 44.0)
    continue_button.text = "读取槽%d" % owner.selected_save_slot
    continue_button.add_theme_font_size_override("font_size", 18)
    continue_button.add_theme_color_override("font_color", Color.WHITE)
    continue_button.self_modulate = Color(0.20, 0.66, 0.42)
    continue_button.disabled = not owner._has_save_file(owner.selected_save_slot)
    continue_button.pressed.connect(Callable(owner, "_continue_saved_game"))
    panel.add_child(continue_button)

    var menu_status_label := Label.new()
    menu_status_label.position = Vector2(120.0, 636.0)
    menu_status_label.size = Vector2(600.0, 22.0)
    menu_status_label.text = "当前存档槽：%d" % owner.selected_save_slot
    menu_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    menu_status_label.add_theme_font_size_override("font_size", 15)
    menu_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.44))
    menu_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
    menu_status_label.add_theme_constant_override("outline_size", 2)
    panel.add_child(menu_status_label)

    return {
        "menu_layer": menu_layer,
        "menu_title_label": title,
        "menu_start_button": start_button,
        "menu_continue_button": continue_button,
        "menu_save_slot_buttons": save_slot_buttons,
        "menu_status_label": menu_status_label,
    }

static func _make_config_label(text_value: String, pos: Vector2, size: Vector2) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = size
    label.text = text_value
    label.add_theme_font_size_override("font_size", 17)
    label.add_theme_color_override("font_color", Color.WHITE)
    return label
