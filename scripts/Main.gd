extends Node2D

const VIEW_W: float = 1100.0
const VIEW_H: float = 700.0
const SAVE_PATH: String = "user://ballwar_save.json"

var battlefield
var bullet_container
var turrets: Dictionary = {}
var chambers: Dictionary = {}
var add_ball_buttons: Dictionary = {}
var add_ball_button_base_positions: Dictionary = {}

var top_bar_segments: Dictionary = {}
var top_bar_labels: Dictionary = {}
var top_bar_name_labels: Dictionary = {}
var top_bar_total_width: float = 0.0

var winner_label
var game_title_label
var ui_canvas
var opening_banner
var pause_overlay
var pause_button
var exit_button

var menu_layer
var game_layer
var selected_grid_size: int = 40
var selected_palette_name: String = "默认随机"
var current_layout: Dictionary = {}

var menu_title_label
var menu_start_button
var menu_continue_button
var ui_time: float = 0.0
var chamber_scale: float = 1.0

func _ready() -> void:
    randomize()
    _create_background()
    _create_start_menu()

func _process(delta: float) -> void:
    ui_time += delta
    if menu_title_label != null:
        menu_title_label.rotation = sin(ui_time * 1.2) * 0.01
    if menu_start_button != null:
        var pulse: float = 1.0 + 0.03 * sin(ui_time * 2.8)
        menu_start_button.scale = Vector2(pulse, pulse)
    if menu_continue_button != null:
        var cpulse: float = 1.0 + 0.02 * sin(ui_time * 2.2 + 0.8)
        menu_continue_button.scale = Vector2(cpulse, cpulse)
    if game_title_label != null:
        var t: float = 1.0 + 0.018 * sin(ui_time * 2.0)
        game_title_label.scale = Vector2(t, t)
    if winner_label != null and winner_label.text != "":
        var w: float = 1.0 + 0.04 * sin(ui_time * 3.0)
        winner_label.scale = Vector2(w, w)

    _animate_add_ball_buttons()

func _animate_add_ball_buttons() -> void:
    for faction_id in add_ball_buttons.keys():
        var button = add_ball_buttons[faction_id]
        if button == null or not is_instance_valid(button):
            continue
        if not add_ball_button_base_positions.has(faction_id):
            continue

        var base_pos: Vector2 = add_ball_button_base_positions[faction_id]
        var phase: float = ui_time * 3.0 + float(faction_id) * 0.85
        var breath: float = sin(phase)
        var hover_bonus: float = 0.0

        if button.has_method("is_hovered") and button.is_hovered() and not button.disabled:
            hover_bonus = 0.055

        if button.disabled:
            button.position = base_pos
            button.scale = Vector2.ONE
        else:
            button.position = base_pos + Vector2(0.0, -2.0 + breath * 2.2)
            var s: float = 1.0 + breath * 0.028 + hover_bonus
            button.scale = Vector2(s, s)

func _create_background() -> void:
    var background = ColorRect.new()
    background.color = Color(0.03, 0.07, 0.14)
    background.size = Vector2(VIEW_W, VIEW_H)
    add_child(background)
    background.z_index = -100

func _create_start_menu() -> void:
    if menu_layer != null:
        menu_layer.queue_free()
    menu_layer = CanvasLayer.new()
    menu_layer.name = "MenuLayer"
    add_child(menu_layer)

    var shade = ColorRect.new()
    shade.color = Color(0.02, 0.03, 0.05, 0.72)
    shade.size = Vector2(VIEW_W, VIEW_H)
    menu_layer.add_child(shade)

    var panel = Panel.new()
    panel.position = Vector2(170, 46)
    panel.size = Vector2(760, 590)
    panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
    menu_layer.add_child(panel)

    var panel_bg = ColorRect.new()
    panel_bg.position = Vector2(8, 8)
    panel_bg.size = panel.size - Vector2(16, 16)
    panel_bg.color = Color(0.08, 0.12, 0.18, 0.97)
    panel.add_child(panel_bg)

    var title = Label.new()
    title.position = Vector2(110, 20)
    title.size = Vector2(540, 58)
    title.text = "领土战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.add_theme_font_size_override("font_size", 44)
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
    title.add_theme_constant_override("outline_size", 7)
    panel.add_child(title)
    menu_title_label = title

    var subtitle = Label.new()
    subtitle.position = Vector2(140, 76)
    subtitle.size = Vector2(480, 26)
    subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    panel.add_child(subtitle)

    var decor = preload("res://scripts/MenuDecor.gd").new()
    decor.position = Vector2(380, 286)
    decor.scale = Vector2(0.86, 0.86)
    panel.add_child(decor)

    var config_panel = Panel.new()
    config_panel.position = Vector2(120, 468)
    config_panel.size = Vector2(520, 96)
    panel.add_child(config_panel)

    var cfg_bg = ColorRect.new()
    cfg_bg.position = Vector2(4, 4)
    cfg_bg.size = config_panel.size - Vector2(8, 8)
    cfg_bg.color = Color(0.12, 0.16, 0.23)
    config_panel.add_child(cfg_bg)

    var size_label = Label.new()
    size_label.position = Vector2(18, 12)
    size_label.size = Vector2(110, 24)
    size_label.text = "地图大小"
    size_label.add_theme_font_size_override("font_size", 18)
    size_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(size_label)

    var size_option = OptionButton.new()
    size_option.position = Vector2(110, 8)
    size_option.size = Vector2(126, 30)
    size_option.add_item("10 × 10", 10)
    size_option.add_item("20 × 20", 20)
    size_option.add_item("30 × 30", 30)
    size_option.add_item("40 × 40", 40)
    size_option.add_item("50 × 50", 50)
    size_option.add_item("60 × 60", 60)
    size_option.select(3)
    size_option.item_selected.connect(func(index: int) -> void:
        selected_grid_size = size_option.get_item_id(index)
    )
    config_panel.add_child(size_option)

    var palette_label = Label.new()
    palette_label.position = Vector2(256, 12)
    palette_label.size = Vector2(96, 24)
    palette_label.text = "配色方案"
    palette_label.add_theme_font_size_override("font_size", 18)
    palette_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(palette_label)

    var palette_option = OptionButton.new()
    palette_option.position = Vector2(348, 8)
    palette_option.size = Vector2(148, 30)
    palette_option.add_item("默认随机")
    for palette_name in GameConfig.get_palette_names():
        palette_option.add_item(palette_name)
    palette_option.select(0)
    palette_option.item_selected.connect(func(index: int) -> void:
        selected_palette_name = palette_option.get_item_text(index)
    )
    config_panel.add_child(palette_option)

    var tip = Label.new()
    tip.position = Vector2(18, 46)
    tip.size = Vector2(360, 40)
    tip.text = "提示：现已支持暂停、保存退出与继续游戏。"
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
    tip.add_theme_font_size_override("font_size", 15)
    tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    config_panel.add_child(tip)

    var start_button = Button.new()
    start_button.position = Vector2(396, 48)
    start_button.size = Vector2(104, 36)
    start_button.text = "开始"
    start_button.add_theme_font_size_override("font_size", 22)
    start_button.add_theme_color_override("font_color", Color.WHITE)
    start_button.add_theme_color_override("font_hover_color", Color.WHITE)
    start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
    start_button.self_modulate = Color(0.22, 0.60, 1.0)
    start_button.pressed.connect(func() -> void:
        _start_game(selected_grid_size)
    )
    config_panel.add_child(start_button)
    menu_start_button = start_button

    if _has_save_file():
        var continue_button = Button.new()
        continue_button.position = Vector2(636, 504)
        continue_button.size = Vector2(92, 48)
        continue_button.text = "继续"
        continue_button.add_theme_font_size_override("font_size", 22)
        continue_button.add_theme_color_override("font_color", Color.WHITE)
        continue_button.self_modulate = Color(0.20, 0.66, 0.42)
        continue_button.pressed.connect(_continue_saved_game)
        panel.add_child(continue_button)
        menu_continue_button = continue_button

        var save_tip = Label.new()
        save_tip.position = Vector2(598, 560)
        save_tip.size = Vector2(140, 20)
        save_tip.text = "检测到存档"
        save_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
        save_tip.add_theme_font_size_override("font_size", 13)
        save_tip.add_theme_color_override("font_color", Color(0.75, 0.95, 0.80))
        panel.add_child(save_tip)
    else:
        menu_continue_button = null

func _get_layout_profile(grid_size: int) -> Dictionary:
    match grid_size:
        10:
            return {
                "map_y": 178.0,
                "chamber_scale": 0.74,
                "left_chamber_y_top": 136.0,
                "left_chamber_y_bottom": 396.0,
                "chamber_gap": 18.0,
                "button_gap": 10.0,
                "button_size": Vector2(58.0, 34.0),
                "top_panel_w": 690.0,
                "top_panel_h": 84.0,
                "bar_h": 34.0,
                "title_font": 26,
                "title_y": 42.0,
                "palette_font": 15,
                "winner_y": 654.0,
                "banner_title_y": 294.0,
                "banner_sub_y": 346.0,
            }
        20:
            return {
                "map_y": 128.0,
                "chamber_scale": 0.76,
                "left_chamber_y_top": 136.0,
                "left_chamber_y_bottom": 382.0,
                "chamber_gap": 20.0,
                "button_gap": 10.0,
                "button_size": Vector2(60.0, 36.0),
                "top_panel_w": 730.0,
                "top_panel_h": 86.0,
                "bar_h": 35.0,
                "title_font": 28,
                "title_y": 44.0,
                "palette_font": 15,
                "winner_y": 652.0,
                "banner_title_y": 292.0,
                "banner_sub_y": 346.0,
            }
        30:
            return {
                "map_y": 108.0,
                "chamber_scale": 0.78,
                "left_chamber_y_top": 120.0,
                "left_chamber_y_bottom": 374.0,
                "chamber_gap": 20.0,
                "button_gap": 10.0,
                "button_size": Vector2(62.0, 38.0),
                "top_panel_w": 770.0,
                "top_panel_h": 88.0,
                "bar_h": 36.0,
                "title_font": 30,
                "title_y": 45.0,
                "palette_font": 16,
                "winner_y": 650.0,
                "banner_title_y": 286.0,
                "banner_sub_y": 338.0,
            }
        40:
            return {
                "map_y": 96.0,
                "chamber_scale": 0.80,
                "left_chamber_y_top": 104.0,
                "left_chamber_y_bottom": 362.0,
                "chamber_gap": 22.0,
                "button_gap": 11.0,
                "button_size": Vector2(64.0, 38.0),
                "top_panel_w": 810.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 31,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 648.0,
                "banner_title_y": 282.0,
                "banner_sub_y": 334.0,
            }
        50:
            return {
                "map_y": 86.0,
                "chamber_scale": 0.78,
                "left_chamber_y_top": 96.0,
                "left_chamber_y_bottom": 354.0,
                "chamber_gap": 22.0,
                "button_gap": 11.0,
                "button_size": Vector2(64.0, 38.0),
                "top_panel_w": 840.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 31,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 648.0,
                "banner_title_y": 282.0,
                "banner_sub_y": 334.0,
            }
        60:
            return {
                "map_y": 92.0,
                "chamber_scale": 0.76,
                "left_chamber_y_top": 100.0,
                "left_chamber_y_bottom": 352.0,
                "chamber_gap": 20.0,
                "button_gap": 10.0,
                "button_size": Vector2(62.0, 36.0),
                "top_panel_w": 840.0,
                "top_panel_h": 90.0,
                "bar_h": 36.0,
                "title_font": 30,
                "title_y": 46.0,
                "palette_font": 16,
                "winner_y": 648.0,
                "banner_title_y": 284.0,
                "banner_sub_y": 336.0,
            }
        _:
            return _get_layout_profile(40)

func _start_game(grid_size: int, suppress_banner: bool = false) -> void:
    selected_grid_size = grid_size
    current_layout = _get_layout_profile(grid_size)

    if selected_palette_name == "默认随机":
        GameConfig.set_random_palette()
    else:
        GameConfig.set_palette_by_name(selected_palette_name)

    _cleanup_menu()
    _cleanup_game_layer()
    get_tree().paused = false

    turrets.clear()
    chambers.clear()
    add_ball_buttons.clear()
    add_ball_button_base_positions.clear()
    top_bar_segments.clear()
    top_bar_labels.clear()
    top_bar_name_labels.clear()

    game_layer = Node2D.new()
    game_layer.name = "GameLayer"
    add_child(game_layer)

    _create_battlefield(grid_size)
    _create_turrets()
    _create_control_chambers()
    _create_ui()
    _create_control_buttons()
    if not suppress_banner:
        _show_center_banner("领土战争", "开战！", Color(1.0, 0.94, 0.48), true)

func _create_battlefield(grid_size: int) -> void:
    battlefield = Battlefield.new()
    battlefield.configure(grid_size)
    var map_pixel_size: float = battlefield.grid_size * battlefield.cell_size
    var origin: Vector2 = Vector2((VIEW_W - map_pixel_size) * 0.5, current_layout.get("map_y", 96.0))
    battlefield.position = origin
    battlefield.scores_changed.connect(_on_scores_changed)
    game_layer.add_child(battlefield)

    bullet_container = Node2D.new()
    bullet_container.name = "BulletContainer"
    game_layer.add_child(bullet_container)

    chamber_scale = current_layout.get("chamber_scale", 0.80)

func _create_turrets() -> void:
    var size: float = battlefield.grid_size * battlefield.cell_size
    var margin: float = 16.0
    var origin: Vector2 = battlefield.position
    var positions: Dictionary = {
        GameConfig.Faction.BLUE: origin + Vector2(margin, margin),
        GameConfig.Faction.RED: origin + Vector2(size - margin, margin),
        GameConfig.Faction.GREEN: origin + Vector2(margin, size - margin),
        GameConfig.Faction.YELLOW: origin + Vector2(size - margin, size - margin),
    }

    for faction_id in positions.keys():
        var turret = Turret.new()
        turret.setup(faction_id, positions[faction_id], battlefield, bullet_container)
        turret.name = "Turret_%s" % GameConfig.faction_name(faction_id)
        turret.destroyed.connect(_on_turret_destroyed)
        turret.burst_lock_changed.connect(_on_turret_burst_lock_changed)
        turret.burst_progress.connect(_on_turret_burst_progress)
        game_layer.add_child(turret)
        turrets[faction_id] = turret

    for turret in turrets.values():
        turret.set_all_turrets(turrets)

func _create_control_chambers() -> void:
    var map_left: float = battlefield.position.x
    var map_size: float = battlefield.grid_size * battlefield.cell_size
    var base_w: float = 106.0
    var scaled_w: float = base_w * chamber_scale
    var gap: float = current_layout.get("chamber_gap", 20.0)

    var left_x: float = map_left - scaled_w - gap
    var right_x: float = map_left + map_size + gap
    var top_y: float = current_layout.get("left_chamber_y_top", 110.0)
    var bottom_y: float = current_layout.get("left_chamber_y_bottom", 360.0)

    var chamber_positions: Dictionary = {
        GameConfig.Faction.BLUE: Vector2(left_x, top_y),
        GameConfig.Faction.RED: Vector2(right_x, top_y),
        GameConfig.Faction.GREEN: Vector2(left_x, bottom_y),
        GameConfig.Faction.YELLOW: Vector2(right_x, bottom_y),
    }

    for faction_id in chamber_positions.keys():
        var chamber = ControlChamber.new()
        chamber.setup(faction_id, chamber_positions[faction_id])
        chamber.scale = Vector2.ONE * chamber_scale
        chamber.name = "Chamber_%s" % GameConfig.faction_name(faction_id)
        chamber.release_requested.connect(_on_chamber_release_requested)
        chamber.ball_count_changed.connect(_on_ball_count_changed)
        game_layer.add_child(chamber)
        chambers[faction_id] = chamber

func _create_ui() -> void:
    ui_canvas = CanvasLayer.new()
    ui_canvas.name = "UICanvas"
    game_layer.add_child(ui_canvas)

    var top_panel_w: float = current_layout.get("top_panel_w", 810.0)
    var top_panel_h: float = current_layout.get("top_panel_h", 90.0)
    var top_panel = Panel.new()
    top_panel.position = Vector2((VIEW_W - top_panel_w) * 0.5, 8)
    top_panel.size = Vector2(top_panel_w, top_panel_h)
    top_panel.self_modulate = Color(0.96, 0.98, 1.0, 0.96)
    ui_canvas.add_child(top_panel)

    var top_bg = ColorRect.new()
    top_bg.position = Vector2(5, 5)
    top_bg.size = top_panel.size - Vector2(10, 10)
    top_bg.color = Color(0.09, 0.12, 0.18, 0.94)
    top_panel.add_child(top_bg)

    var bar_h: float = current_layout.get("bar_h", 36.0)
    var bar_bg = Panel.new()
    bar_bg.position = Vector2(18, 9)
    bar_bg.size = Vector2(top_panel.size.x - 36.0, bar_h)
    bar_bg.self_modulate = Color(0.93, 0.96, 1.0, 0.93)
    top_panel.add_child(bar_bg)

    var bar_inner = ColorRect.new()
    bar_inner.position = Vector2(3, 3)
    bar_inner.size = Vector2(bar_bg.size.x - 6, bar_bg.size.y - 6)
    bar_inner.color = Color(0.03, 0.05, 0.09, 0.62)
    bar_bg.add_child(bar_inner)
    top_bar_total_width = bar_inner.size.x

    var x_offset: float = 3.0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var segment = Panel.new()
        segment.position = Vector2(x_offset, 3)
        segment.size = Vector2(top_bar_total_width * 0.25, bar_inner.size.y)
        segment.self_modulate = Color(0.94, 0.96, 1.0, 0.92)
        bar_bg.add_child(segment)
        top_bar_segments[faction_id] = segment

        var fill = ColorRect.new()
        fill.name = "Fill"
        fill.position = Vector2(2, 2)
        fill.size = Vector2(segment.size.x - 4, segment.size.y - 4)
        fill.color = Color(GameConfig.faction_color(faction_id).r, GameConfig.faction_color(faction_id).g, GameConfig.faction_color(faction_id).b, 0.18)
        segment.add_child(fill)

        var name_label = Label.new()
        name_label.position = Vector2(8, 2)
        name_label.size = Vector2(60, 16)
        name_label.add_theme_font_size_override("font_size", 13)
        name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.52))
        name_label.add_theme_color_override("font_outline_color", Color.BLACK)
        name_label.add_theme_constant_override("outline_size", 2)
        segment.add_child(name_label)
        top_bar_name_labels[faction_id] = name_label

        var value_label = Label.new()
        value_label.position = Vector2(0, -1)
        value_label.size = Vector2(segment.size.x, segment.size.y)
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
        value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
        value_label.add_theme_font_size_override("font_size", 22)
        value_label.add_theme_color_override("font_color", Color.WHITE)
        value_label.add_theme_color_override("font_outline_color", Color.BLACK)
        value_label.add_theme_constant_override("outline_size", 3)
        segment.add_child(value_label)
        top_bar_labels[faction_id] = value_label

        x_offset += segment.size.x

    var title = Label.new()
    title.position = Vector2(0, current_layout.get("title_y", 46.0))
    title.size = Vector2(top_panel.size.x, 32)
    title.text = "领土战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.add_theme_font_size_override("font_size", current_layout.get("title_font", 31))
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color.BLACK)
    title.add_theme_constant_override("outline_size", 5)
    top_panel.add_child(title)
    game_title_label = title

    var palette_label = Label.new()
    palette_label.position = Vector2(top_panel.size.x - 180.0, current_layout.get("title_y", 46.0) + 1.0)
    palette_label.size = Vector2(164, 24)
    palette_label.text = "配色：%s" % GameConfig.get_palette_name()
    palette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT as HorizontalAlignment
    palette_label.add_theme_font_size_override("font_size", current_layout.get("palette_font", 16))
    palette_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
    top_panel.add_child(palette_label)

    pause_button = Button.new()
    pause_button.position = Vector2(VIEW_W - 148, 18)
    pause_button.size = Vector2(64, 32)
    pause_button.text = "暂停"
    pause_button.self_modulate = Color(0.24, 0.52, 0.92)
    pause_button.add_theme_color_override("font_color", Color.WHITE)
    pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
    pause_button.pressed.connect(_toggle_pause)
    ui_canvas.add_child(pause_button)

    exit_button = Button.new()
    exit_button.position = Vector2(VIEW_W - 78, 18)
    exit_button.size = Vector2(64, 32)
    exit_button.text = "退出"
    exit_button.self_modulate = Color(0.62, 0.24, 0.22)
    exit_button.add_theme_color_override("font_color", Color.WHITE)
    exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
    exit_button.pressed.connect(_save_and_exit_to_menu)
    ui_canvas.add_child(exit_button)

    pause_overlay = Control.new()
    pause_overlay.position = Vector2.ZERO
    pause_overlay.size = Vector2(VIEW_W, VIEW_H)
    pause_overlay.visible = false
    pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    ui_canvas.add_child(pause_overlay)

    var overlay_bg = ColorRect.new()
    overlay_bg.size = pause_overlay.size
    overlay_bg.color = Color(0.0, 0.0, 0.0, 0.35)
    pause_overlay.add_child(overlay_bg)

    var pause_panel = Panel.new()
    pause_panel.position = Vector2((VIEW_W - 260.0) * 0.5, (VIEW_H - 140.0) * 0.5)
    pause_panel.size = Vector2(260, 140)
    pause_overlay.add_child(pause_panel)

    var pause_label = Label.new()
    pause_label.position = Vector2(0, 22)
    pause_label.size = Vector2(260, 34)
    pause_label.text = "已暂停"
    pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    pause_label.add_theme_font_size_override("font_size", 28)
    pause_panel.add_child(pause_label)

    var pause_sub = Label.new()
    pause_sub.position = Vector2(18, 66)
    pause_sub.size = Vector2(224, 20)
    pause_sub.text = "当前进度已保存，可继续或退出"
    pause_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    pause_sub.add_theme_font_size_override("font_size", 15)
    pause_panel.add_child(pause_sub)

    var resume_button = Button.new()
    resume_button.position = Vector2(26, 98)
    resume_button.size = Vector2(92, 28)
    resume_button.text = "继续"
    resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
    resume_button.pressed.connect(_toggle_pause)
    pause_panel.add_child(resume_button)

    var save_exit_button = Button.new()
    save_exit_button.position = Vector2(142, 98)
    save_exit_button.size = Vector2(92, 28)
    save_exit_button.text = "保存退出"
    save_exit_button.process_mode = Node.PROCESS_MODE_ALWAYS
    save_exit_button.pressed.connect(_save_and_exit_to_menu)
    pause_panel.add_child(save_exit_button)

    winner_label = Label.new()
    winner_label.position = Vector2(0, current_layout.get("winner_y", 648.0))
    winner_label.size = Vector2(VIEW_W, 34)
    winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    winner_label.add_theme_font_size_override("font_size", 28)
    winner_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.22))
    winner_label.add_theme_color_override("font_outline_color", Color.BLACK)
    winner_label.add_theme_constant_override("outline_size", 5)
    winner_label.text = ""
    ui_canvas.add_child(winner_label)

    _on_scores_changed(battlefield.count_cells_by_team())

func _create_control_buttons() -> void:
    var canvas = CanvasLayer.new()
    canvas.name = "ControlButtons"
    game_layer.add_child(canvas)

    for faction_id in chambers.keys():
        var chamber = chambers[faction_id]
        var button = Button.new()
        var pos: Vector2 = chamber.global_position
        var scaled_w: float = chamber.chamber_size.x * chamber.scale.x
        var scaled_h: float = chamber.chamber_size.y * chamber.scale.y
        var button_size: Vector2 = current_layout.get("button_size", Vector2(64.0, 38.0))
        var button_gap: float = current_layout.get("button_gap", 10.0)
        button.size = button_size
        button.pivot_offset = button.size * 0.5

        var y_pos: float = pos.y + scaled_h * 0.5 - button.size.y * 0.5
        if faction_id == GameConfig.Faction.BLUE or faction_id == GameConfig.Faction.GREEN:
            button.position = Vector2(pos.x - button.size.x - button_gap, y_pos)
        else:
            button.position = Vector2(pos.x + scaled_w + button_gap, y_pos)

        add_ball_button_base_positions[faction_id] = button.position
        button.text = "+球"
        button.add_theme_font_size_override("font_size", 18)
        button.add_theme_color_override("font_color", Color.WHITE)
        button.add_theme_color_override("font_pressed_color", Color.WHITE)
        button.add_theme_color_override("font_hover_color", Color.WHITE)
        button.self_modulate = GameConfig.faction_color(faction_id)
        button.pressed.connect(_add_ball_to_chamber.bind(faction_id))
        canvas.add_child(button)
        add_ball_buttons[faction_id] = button
        _refresh_add_ball_button(faction_id)

func _add_ball_to_chamber(faction_id: int) -> void:
    if not chambers.has(faction_id):
        return
    chambers[faction_id].add_control_ball()
    _refresh_add_ball_button(faction_id)

func _on_ball_count_changed(faction_id: int, _count: int) -> void:
    _refresh_add_ball_button(faction_id)

func _refresh_add_ball_button(faction_id: int) -> void:
    if not add_ball_buttons.has(faction_id):
        return
    var button = add_ball_buttons[faction_id]
    var count: int = 0
    var damaged: bool = false
    var locked: bool = false
    if chambers.has(faction_id):
        count = chambers[faction_id].get_ball_count()
        damaged = chambers[faction_id].is_damaged
        locked = chambers[faction_id].is_locked

    button.disabled = damaged or locked or count >= GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER
    if damaged:
        button.text = "损坏"
        button.self_modulate = Color(0.45, 0.18, 0.18)
    elif locked:
        button.text = "锁定"
        button.self_modulate = Color(0.30, 0.30, 0.35)
    else:
        button.text = "+球"
        button.self_modulate = GameConfig.faction_color(faction_id)

func _on_chamber_release_requested(faction_id, bullet_count, chamber) -> void:
    if turrets.has(faction_id):
        chamber.start_locked(bullet_count)
        _refresh_add_ball_button(faction_id)
        turrets[faction_id].fire_burst(bullet_count)

func _on_turret_burst_progress(faction_id, remaining) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].update_locked_remaining(remaining)
    _refresh_add_ball_button(faction_id)

func _on_turret_burst_lock_changed(faction_id, locked) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].set_locked(locked)
    _refresh_add_ball_button(faction_id)

func _on_turret_destroyed(faction_id: int) -> void:
    if chambers.has(faction_id):
        chambers[faction_id].set_damaged()
    _refresh_add_ball_button(faction_id)
    _check_winner()

func _check_winner() -> void:
    var alive: Array = []
    for faction_id in turrets.keys():
        var turret = turrets[faction_id]
        if not turret.is_destroyed:
            alive.append(faction_id)
    if alive.size() == 1:
        winner_label.text = "%s 胜利！" % GameConfig.faction_name(alive[0])
        _show_center_banner(winner_label.text, "终局", GameConfig.faction_color(alive[0]).lightened(0.35), false)
    elif alive.size() == 0:
        winner_label.text = "平局"
        _show_center_banner("平局", "终局", Color(1.0, 1.0, 1.0), false)

func _on_scores_changed(counts: Dictionary) -> void:
    if top_bar_segments.size() == 0:
        return
    var total: int = 0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        total += counts.get(faction_id, 0)
    if total <= 0:
        total = 1

    var running_x: float = 3.0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var ratio: float = float(counts.get(faction_id, 0)) / float(total)
        var p: int = int(round(ratio * 100.0))
        var segment = top_bar_segments[faction_id]
        var seg_w: float = top_bar_total_width * ratio
        if faction_id == GameConfig.Faction.YELLOW:
            seg_w = maxf(50.0, top_bar_total_width + 3.0 - running_x)
        segment.position.x = running_x
        segment.size.x = maxf(50.0, seg_w)
        var fill = segment.get_node("Fill")
        fill.size = Vector2(maxf(4.0, segment.size.x - 4.0), segment.size.y - 4.0)
        fill.color = Color(GameConfig.faction_color(faction_id).r, GameConfig.faction_color(faction_id).g, GameConfig.faction_color(faction_id).b, 0.22)
        var value_label = top_bar_labels[faction_id]
        var name_label = top_bar_name_labels[faction_id]
        value_label.text = "%d%%" % p
        name_label.text = GameConfig.faction_name(faction_id)
        name_label.add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.45))
        name_label.visible = true

        if segment.size.x < 110.0:
            name_label.position = Vector2(0, 0)
            name_label.size = Vector2(segment.size.x, 14)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 11)

            value_label.position = Vector2(0, 10)
            value_label.size = Vector2(segment.size.x, 22)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 18)
        else:
            name_label.position = Vector2(8, 2)
            name_label.size = Vector2(60, 16)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 13)

            value_label.position = Vector2(0, -1)
            value_label.size = Vector2(segment.size.x, segment.size.y)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 22)

        running_x += segment.size.x

func _show_center_banner(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
    if ui_canvas == null:
        return
    if opening_banner != null:
        opening_banner.queue_free()
    var holder = Control.new()
    holder.position = Vector2.ZERO
    holder.size = Vector2(VIEW_W, VIEW_H)
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_canvas.add_child(holder)
    opening_banner = holder

    var title = Label.new()
    title.position = Vector2((VIEW_W - 460.0) * 0.5, current_layout.get("banner_title_y", 284.0))
    title.size = Vector2(460, 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.text = title_text
    title.add_theme_font_size_override("font_size", 50)
    title.add_theme_color_override("font_color", accent)
    title.add_theme_color_override("font_outline_color", Color.BLACK)
    title.add_theme_constant_override("outline_size", 8)
    holder.add_child(title)

    var sub = Label.new()
    sub.position = Vector2((VIEW_W - 340.0) * 0.5, current_layout.get("banner_sub_y", 338.0))
    sub.size = Vector2(340, 24)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    sub.text = sub_text
    sub.add_theme_font_size_override("font_size", 20)
    sub.add_theme_color_override("font_color", Color.WHITE)
    sub.add_theme_color_override("font_outline_color", Color.BLACK)
    sub.add_theme_constant_override("outline_size", 4)
    holder.add_child(sub)

    holder.scale = Vector2(0.7, 0.7)
    holder.modulate = Color(1, 1, 1, 0)
    var tween = create_tween()
    tween.tween_property(holder, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(holder, "modulate", Color(1, 1, 1, 1), 0.24)
    if auto_hide:
        tween.tween_interval(1.2)
        tween.tween_property(holder, "modulate", Color(1, 1, 1, 0), 0.42)
        tween.tween_callback(holder.queue_free)
    else:
        title.add_theme_color_override("font_color", accent)

func _toggle_pause() -> void:
    if game_layer == null:
        return
    if get_tree().paused:
        get_tree().paused = false
        if pause_overlay != null:
            pause_overlay.visible = false
        if pause_button != null:
            pause_button.text = "暂停"
    else:
        _save_game_progress()
        get_tree().paused = true
        if pause_overlay != null:
            pause_overlay.visible = true
        if pause_button != null:
            pause_button.text = "继续"

func _save_and_exit_to_menu() -> void:
    if battlefield != null:
        _save_game_progress()
    get_tree().paused = false
    _cleanup_game_layer()
    _create_start_menu()

func _cleanup_menu() -> void:
    if menu_layer != null:
        menu_layer.queue_free()
        menu_layer = null
    menu_title_label = null
    menu_start_button = null
    menu_continue_button = null

func _cleanup_game_layer() -> void:
    if game_layer != null:
        game_layer.queue_free()
        game_layer = null
    battlefield = null
    bullet_container = null
    ui_canvas = null
    opening_banner = null
    pause_overlay = null
    pause_button = null
    exit_button = null
    winner_label = null
    game_title_label = null
    turrets.clear()
    chambers.clear()
    add_ball_buttons.clear()
    add_ball_button_base_positions.clear()
    top_bar_segments.clear()
    top_bar_labels.clear()
    top_bar_name_labels.clear()

func _has_save_file() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func _save_game_progress() -> void:
    if battlefield == null:
        return

    var factions: Array = []
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var chamber = chambers.get(faction_id)
        var turret = turrets.get(faction_id)
        factions.append({
            "faction_id": faction_id,
            "chamber_pending_count": chamber.pending_count if chamber != null else 1,
            "chamber_locked_remaining": chamber.locked_remaining if chamber != null else 0,
            "chamber_is_locked": chamber.is_locked if chamber != null else false,
            "chamber_is_damaged": chamber.is_damaged if chamber != null else false,
            "chamber_ball_count": chamber.get_ball_count() if chamber != null else 0,
            "turret_health": turret.health if turret != null else GameConfig.TURRET_MAX_HEALTH,
            "turret_destroyed": turret.is_destroyed if turret != null else false,
            "turret_burst_remaining": turret.burst_remaining if turret != null else 0,
        })

    var data: Dictionary = {
        "grid_size": battlefield.grid_size,
        "palette_name": GameConfig.get_palette_name(),
        "owners": battlefield.owners,
        "factions": factions,
        "winner_text": winner_label.text if winner_label != null else "",
    }

    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))

func _load_saved_data() -> Dictionary:
    if not _has_save_file():
        return {}
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    var content: String = file.get_as_text()
    var parsed = JSON.parse_string(content)
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return {}

func _continue_saved_game() -> void:
    var data: Dictionary = _load_saved_data()
    if data.is_empty():
        return

    var palette_name: String = str(data.get("palette_name", "经典"))
    selected_palette_name = palette_name
    GameConfig.set_palette_by_name(palette_name)
    _start_game(int(data.get("grid_size", 40)), true)
    _apply_saved_state(data)
    _show_center_banner("领土战争", "继续作战", Color(0.84, 0.96, 1.0), true)

func _apply_saved_state(data: Dictionary) -> void:
    if battlefield == null:
        return

    var owners = data.get("owners", [])
    if owners is Array and owners.size() == battlefield.grid_size:
        battlefield.owners = owners
        battlefield.queue_redraw()
        _on_scores_changed(battlefield.count_cells_by_team())

    var factions = data.get("factions", [])
    if factions is Array:
        for faction_state in factions:
            if not (faction_state is Dictionary):
                continue
            var faction_id: int = int(faction_state.get("faction_id", 0))
            if chambers.has(faction_id):
                _apply_chamber_state(chambers[faction_id], faction_state)
            if turrets.has(faction_id):
                _apply_turret_state(turrets[faction_id], faction_state)
            _refresh_add_ball_button(faction_id)

    if winner_label != null:
        winner_label.text = str(data.get("winner_text", ""))

func _apply_chamber_state(chamber, state: Dictionary) -> void:
    for ball in chamber.balls:
        if ball != null and is_instance_valid(ball):
            ball.queue_free()
    chamber.balls.clear()
    chamber.release_ball = null
    chamber.is_damaged = false
    chamber.is_locked = false
    chamber.pending_count = max(1, int(state.get("chamber_pending_count", 1)))
    chamber.locked_remaining = max(0, int(state.get("chamber_locked_remaining", 0)))

    var ball_count: int = clampi(int(state.get("chamber_ball_count", 0)), 0, GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER)
    for i in range(ball_count):
        chamber.add_control_ball()

    chamber.pending_count = max(1, int(state.get("chamber_pending_count", 1)))

    if bool(state.get("chamber_is_damaged", false)):
        chamber.set_damaged()
    elif bool(state.get("chamber_is_locked", false)):
        chamber.is_locked = true
        chamber.locked_remaining = max(0, int(state.get("chamber_locked_remaining", 0)))
        chamber._update_label()
    else:
        chamber._update_label()

func _apply_turret_state(turret, state: Dictionary) -> void:
    turret.health = clampi(int(state.get("turret_health", GameConfig.TURRET_MAX_HEALTH)), 0, turret.max_health)
    turret.is_destroyed = bool(state.get("turret_destroyed", false))
    turret.damage_flash = 0.0
    turret.destroy_anim_time = 0.0 if turret.is_destroyed else -1.0
    turret.burst_remaining = 0
    turret.burst_total = 0
    turret.burst_index = 0
    turret.burst_timer = 0.0
    turret._set_burst_locked(false)

    var remaining: int = max(0, int(state.get("turret_burst_remaining", 0)))
    if remaining > 0 and not turret.is_destroyed:
        turret.burst_remaining = remaining
        turret.burst_total = remaining
        turret.burst_timer = 0.03
        turret.burst_index = 0
        turret._set_burst_locked(true)

    turret.queue_redraw()
