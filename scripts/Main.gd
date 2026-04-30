extends Node2D

var battlefield
var bullet_container
var turrets = {}
var chambers = {}
var add_ball_buttons = {}
var percent_name_labels = {}
var percent_value_labels = {}

var winner_label
var game_title_label

var menu_layer
var game_layer
var selected_grid_size = 40
var selected_palette_name = "默认随机"

var menu_title_label
var menu_start_button
var ui_time = 0.0

func _ready() -> void:
    randomize()
    _create_background()
    _create_start_menu()

func _process(delta: float) -> void:
    ui_time += delta
    if menu_title_label != null:
        menu_title_label.rotation = sin(ui_time * 1.2) * 0.01
    if menu_start_button != null:
        var pulse = 1.0 + 0.03 * sin(ui_time * 2.8)
        menu_start_button.scale = Vector2(pulse, pulse)
    if game_title_label != null:
        var t = 1.0 + 0.018 * sin(ui_time * 2.0)
        game_title_label.scale = Vector2(t, t)

func _create_background() -> void:
    var background = ColorRect.new()
    background.color = Color(0.06, 0.08, 0.11)
    background.size = Vector2(1280, 860)
    add_child(background)
    background.z_index = -100

func _create_start_menu() -> void:
    menu_layer = CanvasLayer.new()
    add_child(menu_layer)

    var shade = ColorRect.new()
    shade.color = Color(0.02, 0.03, 0.05, 0.70)
    shade.size = Vector2(1280, 860)
    menu_layer.add_child(shade)

    var panel = Panel.new()
    panel.position = Vector2(260, 84)
    panel.size = Vector2(760, 660)
    panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
    menu_layer.add_child(panel)

    var panel_bg = ColorRect.new()
    panel_bg.position = Vector2(8, 8)
    panel_bg.size = panel.size - Vector2(16, 16)
    panel_bg.color = Color(0.08, 0.12, 0.18, 0.96)
    panel.add_child(panel_bg)

    var title = Label.new()
    title.position = Vector2(130, 28)
    title.size = Vector2(500, 54)
    title.text = "球球游戏战争"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
    title.add_theme_constant_override("outline_size", 6)
    panel.add_child(title)
    menu_title_label = title

    var subtitle = Label.new()
    subtitle.position = Vector2(140, 82)
    subtitle.size = Vector2(480, 24)
    subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_font_size_override("font_size", 16)
    subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
    panel.add_child(subtitle)

    var decor = preload("res://scripts/MenuDecor.gd").new()
    decor.position = Vector2(380, 275)
    panel.add_child(decor)

    var config_panel = Panel.new()
    config_panel.position = Vector2(78, 498)
    config_panel.size = Vector2(602, 116)
    panel.add_child(config_panel)

    var cfg_bg = ColorRect.new()
    cfg_bg.position = Vector2(4, 4)
    cfg_bg.size = config_panel.size - Vector2(8, 8)
    cfg_bg.color = Color(0.12, 0.16, 0.23)
    config_panel.add_child(cfg_bg)

    var size_label = Label.new()
    size_label.position = Vector2(22, 16)
    size_label.size = Vector2(180, 24)
    size_label.text = "正方形大小"
    size_label.add_theme_font_size_override("font_size", 19)
    size_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(size_label)

    var size_option = OptionButton.new()
    size_option.position = Vector2(156, 12)
    size_option.size = Vector2(150, 30)
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
    palette_label.position = Vector2(326, 16)
    palette_label.size = Vector2(120, 24)
    palette_label.text = "配色方案"
    palette_label.add_theme_font_size_override("font_size", 19)
    palette_label.add_theme_color_override("font_color", Color.WHITE)
    config_panel.add_child(palette_label)

    var palette_option = OptionButton.new()
    palette_option.position = Vector2(434, 12)
    palette_option.size = Vector2(138, 30)
    palette_option.add_item("默认随机")
    for palette_name in GameConfig.get_palette_names():
        palette_option.add_item(palette_name)
    palette_option.select(0)
    palette_option.item_selected.connect(func(index: int) -> void:
        selected_palette_name = palette_option.get_item_text(index)
    )
    config_panel.add_child(palette_option)

    var tip = Label.new()
    tip.position = Vector2(22, 56)
    tip.size = Vector2(440, 40)
    tip.text = "提示：发射期间控制仓会锁定并显示剩余子弹数；血量归零则该阵营出局。"
    tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tip.add_theme_font_size_override("font_size", 14)
    tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
    config_panel.add_child(tip)

    var start_button = Button.new()
    start_button.position = Vector2(612, 536)
    start_button.size = Vector2(92, 52)
    start_button.text = "开始"
    start_button.add_theme_font_size_override("font_size", 24)
    start_button.add_theme_color_override("font_color", Color.WHITE)
    start_button.add_theme_color_override("font_hover_color", Color.WHITE)
    start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
    start_button.self_modulate = Color(0.22, 0.60, 1.0)
    start_button.pressed.connect(func() -> void:
        _start_game(selected_grid_size)
    )
    panel.add_child(start_button)
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
    percent_name_labels.clear()
    percent_value_labels.clear()

    game_layer = Node2D.new()
    game_layer.name = "GameLayer"
    add_child(game_layer)

    _create_battlefield(grid_size)
    _create_turrets()
    _create_control_chambers()
    _create_ui()
    _create_control_buttons()

func _create_battlefield(grid_size: int) -> void:
    var map_pixel_size = grid_size * GameConfig.CELL_SIZE
    var origin = Vector2((1280.0 - map_pixel_size) * 0.5, (860.0 - map_pixel_size) * 0.5 + 42.0)

    battlefield = Battlefield.new()
    battlefield.configure(grid_size)
    battlefield.position = origin
    battlefield.scores_changed.connect(_on_scores_changed)
    game_layer.add_child(battlefield)

    bullet_container = Node2D.new()
    bullet_container.name = "BulletContainer"
    game_layer.add_child(bullet_container)

func _create_turrets() -> void:
    var size = battlefield.grid_size * battlefield.cell_size
    var margin = 16.0
    var origin = battlefield.position
    var positions = {
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
    var map_left = battlefield.position.x
    var map_top = battlefield.position.y
    var map_size = battlefield.grid_size * battlefield.cell_size
    var chamber_w = 168.0
    var chamber_h = 214.0
    var gap = 28.0

    var left_x = max(10.0, map_left - chamber_w - gap)
    var right_x = min(1100.0, map_left + map_size + gap)
    var top_y = map_top
    var bottom_y = map_top + map_size - chamber_h

    var chamber_positions = {
        GameConfig.Faction.BLUE: Vector2(left_x, top_y),
        GameConfig.Faction.RED: Vector2(right_x, top_y),
        GameConfig.Faction.GREEN: Vector2(left_x, bottom_y),
        GameConfig.Faction.YELLOW: Vector2(right_x, bottom_y),
    }

    for faction_id in chamber_positions.keys():
        var chamber = ControlChamber.new()
        chamber.setup(faction_id, chamber_positions[faction_id])
        chamber.name = "Chamber_%s" % GameConfig.faction_name(faction_id)
        chamber.release_requested.connect(_on_chamber_release_requested)
        chamber.ball_count_changed.connect(_on_ball_count_changed)
        game_layer.add_child(chamber)
        chambers[faction_id] = chamber

func _create_ui() -> void:
    var canvas = CanvasLayer.new()
    game_layer.add_child(canvas)

    var top_panel = Panel.new()
    top_panel.position = Vector2(210, 8)
    top_panel.size = Vector2(860, 102)
    top_panel.self_modulate = Color(0.96, 0.98, 1.0, 0.96)
    canvas.add_child(top_panel)

    var top_bg = ColorRect.new()
    top_bg.position = Vector2(5, 5)
    top_bg.size = top_panel.size - Vector2(10, 10)
    top_bg.color = Color(0.09, 0.12, 0.18, 0.94)
    top_panel.add_child(top_bg)

    var card_positions = [16, 224, 432, 640]
    for i in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        var card = Panel.new()
        card.position = Vector2(card_positions[i], 8)
        card.size = Vector2(204, 46)
        card.self_modulate = Color(0.95, 0.98, 1.0, 0.92)
        top_panel.add_child(card)

        var accent = ColorRect.new()
        accent.position = Vector2(4, 4)
        accent.size = Vector2(card.size.x - 8, card.size.y - 8)
        accent.color = Color(GameConfig.faction_color(i).r, GameConfig.faction_color(i).g, GameConfig.faction_color(i).b, 0.14)
        card.add_child(accent)

        var name_label = Label.new()
        name_label.position = Vector2(10, 4)
        name_label.size = Vector2(80, 16)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        name_label.add_theme_font_size_override("font_size", 15)
        name_label.add_theme_color_override("font_color", GameConfig.faction_color(i).lightened(0.45))
        name_label.add_theme_color_override("font_outline_color", Color.BLACK)
        name_label.add_theme_constant_override("outline_size", 2)
        name_label.text = GameConfig.faction_name(i)
        card.add_child(name_label)
        percent_name_labels[i] = name_label

        var value_label = Label.new()
        value_label.position = Vector2(72, -2)
        value_label.size = Vector2(122, 42)
        value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        value_label.add_theme_font_size_override("font_size", 28)
        value_label.add_theme_color_override("font_color", GameConfig.faction_color(i).lightened(0.55))
        value_label.add_theme_color_override("font_outline_color", Color.BLACK)
        value_label.add_theme_constant_override("outline_size", 4)
        card.add_child(value_label)
        percent_value_labels[i] = value_label

    game_title_label = Label.new()
    game_title_label.position = Vector2(300, 58)
    game_title_label.size = Vector2(260, 32)
    game_title_label.text = "领土战争"
    game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    game_title_label.add_theme_font_size_override("font_size", 30)
    game_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
    game_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
    game_title_label.add_theme_constant_override("outline_size", 4)
    top_panel.add_child(game_title_label)

    var palette_label = Label.new()
    palette_label.position = Vector2(566, 62)
    palette_label.size = Vector2(210, 22)
    palette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    palette_label.text = "配色：%s" % GameConfig.get_palette_name()
    palette_label.add_theme_font_size_override("font_size", 16)
    palette_label.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0))
    top_panel.add_child(palette_label)

    winner_label = Label.new()
    winner_label.position = Vector2(360, 110)
    winner_label.size = Vector2(560, 40)
    winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    winner_label.add_theme_font_size_override("font_size", 32)
    winner_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.22))
    winner_label.add_theme_color_override("font_outline_color", Color.BLACK)
    winner_label.add_theme_constant_override("outline_size", 5)
    winner_label.text = ""
    canvas.add_child(winner_label)

    _on_scores_changed(battlefield.count_cells_by_team())

func _create_control_buttons() -> void:
    var canvas = CanvasLayer.new()
    canvas.name = "ControlButtons"
    game_layer.add_child(canvas)

    for faction_id in chambers.keys():
        var chamber = chambers[faction_id]
        var button = Button.new()
        var pos = chamber.global_position
        button.size = Vector2(62, 40)

        if faction_id == GameConfig.Faction.BLUE or faction_id == GameConfig.Faction.GREEN:
            button.position = pos + Vector2(-70, 86)
        else:
            button.position = pos + Vector2(chamber.chamber_size.x + 8, 86)

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

func _on_ball_count_changed(faction_id: int, count: int) -> void:
    _refresh_add_ball_button(faction_id)

func _refresh_add_ball_button(faction_id: int) -> void:
    if not add_ball_buttons.has(faction_id):
        return
    var button = add_ball_buttons[faction_id]
    var count = 0
    var damaged = false
    var locked = false
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
    var alive = []
    for faction_id in turrets.keys():
        var turret = turrets[faction_id]
        if not turret.is_destroyed:
            alive.append(faction_id)
    if alive.size() == 1:
        winner_label.text = "%s 胜利！" % GameConfig.faction_name(alive[0])
    elif alive.size() == 0:
        winner_label.text = "平局"

func _on_scores_changed(counts: Dictionary) -> void:
    var total = 0
    for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
        total += counts.get(faction_id, 0)
    if total <= 0:
        total = 1

    for faction_id in percent_value_labels.keys():
        var p = int(round(float(counts.get(faction_id, 0)) * 100.0 / float(total)))
        percent_value_labels[faction_id].text = "%d%%" % p
        percent_value_labels[faction_id].add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.55))
        percent_name_labels[faction_id].text = GameConfig.faction_name(faction_id)
        percent_name_labels[faction_id].add_theme_color_override("font_color", GameConfig.faction_color(faction_id).lightened(0.45))
