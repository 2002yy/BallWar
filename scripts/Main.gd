extends Node2D

const VIEW_W: float = 1360.0
const VIEW_H: float = 920.0

var battlefield
var bullet_container
var turrets: Dictionary = {}
var chambers: Dictionary = {}
var add_ball_buttons: Dictionary = {}
var add_ball_button_base_positions: Dictionary = {}

var top_bar_segments: Dictionary = {}
var top_bar_labels: Dictionary = {}
var top_bar_name_labels: Dictionary = {}

var winner_label
var game_title_label
var ui_canvas
var opening_banner

var menu_layer
var game_layer
var selected_grid_size: int = 40
var selected_palette_name: String = "默认随机"

var menu_title_label
var menu_start_button
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
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)

    var shade = ColorRect.new()
    shade.color = Color(0.02, 0.03, 0.05, 0.70)
    shade.size = Vector2(VIEW_W, VIEW_H)
    menu_layer.add_child(shade)

    var panel = Panel.new()
    panel.position = Vector2(180, 34)
    panel.size = Vector2(920, 780)
    panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
    menu_layer.add_child(panel)

    var panel_bg = ColorRect.new()
    panel_bg.position = Vector2(8, 8)
    panel_bg.size = panel.size - Vector2(16, 16)
    panel_bg.color = Color(0.08, 0.12, 0.18, 0.97)
    panel.add_child(panel_bg)

    var title = Label.new()
    title.position = Vector2(160, 24)
    title.size = Vector2(600, 60)
    title.text = "领土战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.add_theme_font_size_override("font_size", 46)
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
    title.add_theme_constant_override("outline_size", 7)
    panel.add_child(title)
    menu_title_label = title

    var subtitle = Label.new()
    subtitle.position = Vector2(180, 84)
    subtitle.size = Vector2(560, 28)
    subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    subtitle.add_theme_font_size_override("font_size", 18)
    subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    panel.add_child(subtitle)

    var decor = preload("res://scripts/MenuDecor.gd").new()
    decor.position = Vector2(460, 342)
    panel.add_child(decor)

    var config_panel = Panel.new()
    config_panel.position = Vector2(138, 640)
    config_panel.size = Vector2(644, 108)
    panel.add_child(config_panel)

    var cfg_bg = ColorRect.new()
    cfg_bg.position = Vector2(4, 4)
    cfg_bg.size = config_panel.size - Vector2(8, 8)
    cfg_bg.color = Color(0.12, 0.16, 0.23)
    config_panel.add_child(cfg_bg)

    var size_label = Label.new()
    size_label.position = Vector2(20, 14)
    size_label.size = Vector2(120, 24)
    size_label.text = "正方形大小"
    size_label.add_theme_font_size_override("font_size", 19)
    size_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(size_label)

    var size_option = OptionButton.new()
    size_option.position = Vector2(134, 10)
    size_option.size = Vector2(148, 32)
    size_option.add_item("20 × 20", 20)
    size_option.add_item("30 × 30", 30)
    size_option.add_item("40 × 40", 40)
    size_option.add_item("50 × 50", 50)
    size_option.select(2)
    size_option.item_selected.connect(func(index: int) -> void:
        selected_grid_size = size_option.get_item_id(index)
    )
    config_panel.add_child(size_option)

    var palette_label = Label.new()
    palette_label.position = Vector2(324, 14)
    palette_label.size = Vector2(98, 24)
    palette_label.text = "配色方案"
    palette_label.add_theme_font_size_override("font_size", 19)
    palette_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(palette_label)

    var palette_option = OptionButton.new()
    palette_option.position = Vector2(422, 10)
    palette_option.size = Vector2(156, 32)
    palette_option.add_item("默认随机")
    for palette_name in GameConfig.get_palette_names():
        palette_option.add_item(palette_name)
    palette_option.select(0)
    palette_option.item_selected.connect(func(index: int) -> void:
        selected_palette_name = palette_option.get_item_text(index)
    )
    config_panel.add_child(palette_option)

    var tip = Label.new()
    tip.position = Vector2(18, 50)
    tip.size = Vector2(470, 42)
    tip.text = "提示：发射期间控制仓会锁定并显示剩余子弹数；血量归零则该阵营出局。"
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
    tip.add_theme_font_size_override("font_size", 15)
    tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    config_panel.add_child(tip)

    var start_button = Button.new()
    start_button.position = Vector2(522, 44)
    start_button.size = Vector2(100, 44)
    start_button.text = "开始"
    start_button.add_theme_font_size_override("font_size", 24)
    start_button.add_theme_color_override("font_color", Color.WHITE)
    start_button.add_theme_color_override("font_hover_color", Color.WHITE)
    start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
    start_button.self_modulate = Color(0.22, 0.60, 1.0)
    start_button.pressed.connect(func() -> void:
        _start_game(selected_grid_size)
    )
    config_panel.add_child(start_button)
    menu_start_button = start_button

func _start_game(grid_size: int) -> void:
    if selected_palette_name == "默认随机":
        GameConfig.set_random_palette()
    else:
        GameConfig.set_palette_by_name(selected_palette_name)

    if menu_layer != null:
        menu_layer.queue_free()
        menu_layer = null
        menu_title_label = null
        menu_start_button = null

    if game_layer != null:
        game_layer.queue_free()

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
    _show_center_banner("领土战争", "开战！", Color(1.0, 0.94, 0.48), true)

func _create_battlefield(grid_size: int) -> void:
    battlefield = Battlefield.new()
    battlefield.configure(grid_size)
    var map_pixel_size: float = battlefield.grid_size * battlefield.cell_size
    var origin: Vector2 = Vector2((VIEW_W - map_pixel_size) * 0.5, (VIEW_H - map_pixel_size) * 0.5 + 58.0)
    battlefield.position = origin
    battlefield.scores_changed.connect(_on_scores_changed)
    game_layer.add_child(battlefield)

    bullet_container = Node2D.new()
    bullet_container.name = "BulletContainer"
    game_layer.add_child(bullet_container)

    chamber_scale = clampf(map_pixel_size / 520.0, 0.90, 1.03)

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
    var map_top: float = battlefield.position.y
    var map_size: float = battlefield.grid_size * battlefield.cell_size
    var base_w: float = 124.0
    var base_h: float = 214.0
    var scaled_w: float = base_w * chamber_scale
    var scaled_h: float = base_h * chamber_scale
    var gap: float = clampf(26.0 + (520.0 - map_size) * 0.02, 24.0, 38.0)

    var left_x: float = map_left - scaled_w - gap
    var right_x: float = map_left + map_size + gap
    var top_y: float = map_top + 8.0
    var bottom_y: float = map_top + map_size - scaled_h - 8.0

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

    var top_panel = Panel.new()
    top_panel.position = Vector2((VIEW_W - 940.0) * 0.5, 10)
    top_panel.size = Vector2(940, 100)
    top_panel.self_modulate = Color(0.96, 0.98, 1.0, 0.96)
    ui_canvas.add_child(top_panel)

    var top_bg = ColorRect.new()
    top_bg.position = Vector2(5, 5)
    top_bg.size = top_panel.size - Vector2(10, 10)
    top_bg.color = Color(0.09, 0.12, 0.18, 0.94)
    top_panel.add_child(top_bg)

    var bar_bg = Panel.new()
    bar_bg.position = Vector2(18, 10)
    bar_bg.size = Vector2(904, 40)
    bar_bg.self_modulate = Color(0.93, 0.96, 1.0, 0.93)
    top_panel.add_child(bar_bg)

    var bar_inner = ColorRect.new()
    bar_inner.position = Vector2(3, 3)
    bar_inner.size = Vector2(bar_bg.size.x - 6, bar_bg.size.y - 6)
    bar_inner.color = Color(0.03, 0.05, 0.09, 0.62)
    bar_bg.add_child(bar_inner)

    var x_offset: float = 3.0
    var total_width: float = bar_inner.size.x
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var segment = Panel.new()
        segment.position = Vector2(x_offset, 3)
        segment.size = Vector2(total_width * 0.25, 34)
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
        value_label.size = Vector2(segment.size.x, 32)
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
        value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
        value_label.add_theme_font_size_override("font_size", 23)
        value_label.add_theme_color_override("font_color", Color.WHITE)
        value_label.add_theme_color_override("font_outline_color", Color.BLACK)
        value_label.add_theme_constant_override("outline_size", 3)
        segment.add_child(value_label)
        top_bar_labels[faction_id] = value_label

        x_offset += total_width * 0.25

    game_title_label = Label.new()
    game_title_label.position = Vector2(352, 52)
    game_title_label.size = Vector2(220, 36)
    game_title_label.text = "领土战争"
    game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    game_title_label.add_theme_font_size_override("font_size", 30)
    game_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    game_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
    game_title_label.add_theme_constant_override("outline_size", 4)
    top_panel.add_child(game_title_label)

    var palette_label = Label.new()
    palette_label.position = Vector2(626, 57)
    palette_label.size = Vector2(180, 24)
    palette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    palette_label.text = "配色：%s" % GameConfig.get_palette_name()
    palette_label.add_theme_font_size_override("font_size", 16)
    palette_label.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
    top_panel.add_child(palette_label)

    winner_label = Label.new()
    winner_label.position = Vector2((VIEW_W - 600.0) * 0.5, 120)
    winner_label.size = Vector2(600, 46)
    winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    winner_label.add_theme_font_size_override("font_size", 34)
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
        button.size = Vector2(62, 40)
        button.pivot_offset = button.size * 0.5

        if faction_id == GameConfig.Faction.BLUE or faction_id == GameConfig.Faction.GREEN:
            button.position = pos + Vector2(-72, 86.0 * chamber.scale.y)
        else:
            button.position = pos + Vector2(scaled_w + 10, 86.0 * chamber.scale.y)

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

    var total_bar_width: float = 898.0
    var running_x: float = 3.0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var ratio: float = float(counts.get(faction_id, 0)) / float(total)
        var p: int = int(round(ratio * 100.0))
        var segment = top_bar_segments[faction_id]
        var seg_w: float = total_bar_width * ratio
        if faction_id == GameConfig.Faction.YELLOW:
            seg_w = maxf(50.0, 901.0 - running_x)
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

        if segment.size.x < 118.0:
            # 窄条状态：阵营名移到上方，百分比放下方，避免横向重叠。
            name_label.position = Vector2(0, 0)
            name_label.size = Vector2(segment.size.x, 14)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 11)

            value_label.position = Vector2(0, 10)
            value_label.size = Vector2(segment.size.x, 24)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 18)
        else:
            # 宽条状态：左侧阵营名 + 中部百分比。
            name_label.position = Vector2(8, 2)
            name_label.size = Vector2(60, 16)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT as HorizontalAlignment
            name_label.add_theme_font_size_override("font_size", 13)

            value_label.position = Vector2(0, -1)
            value_label.size = Vector2(segment.size.x, 32)
            value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
            value_label.add_theme_font_size_override("font_size", 23)

        running_x += segment.size.x

func _show_center_banner(title_text: String, sub_text: String, accent: Color, auto_hide: bool) -> void:
    if ui_canvas == null:
        return
    if opening_banner != null:
        opening_banner.queue_free()
    var holder = Control.new()
    holder.position = Vector2.ZERO
    holder.size = Vector2(VIEW_W, VIEW_H)
    ui_canvas.add_child(holder)
    opening_banner = holder

    var title = Label.new()
    title.position = Vector2((VIEW_W - 500.0) * 0.5, 368)
    title.size = Vector2(500, 64)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.text = title_text
    title.add_theme_font_size_override("font_size", 54)
    title.add_theme_color_override("font_color", accent)
    title.add_theme_color_override("font_outline_color", Color.BLACK)
    title.add_theme_constant_override("outline_size", 8)
    holder.add_child(title)

    var sub = Label.new()
    sub.position = Vector2((VIEW_W - 340.0) * 0.5, 432)
    sub.size = Vector2(340, 26)
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
