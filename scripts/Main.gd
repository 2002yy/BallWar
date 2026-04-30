extends Node2D

var battlefield
var bullet_container
var turrets = {}
var chambers = {}
var add_ball_buttons = {}

var score_label
var winner_label
var game_title_label

var menu_layer
var game_layer
var selected_grid_size = 40

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
		var t = 1.0 + 0.015 * sin(ui_time * 2.0)
		game_title_label.scale = Vector2(t, t)

func _create_background() -> void:
	var background = ColorRect.new()
	background.color = Color(0.06, 0.08, 0.11)
	background.size = Vector2(1200, 820)
	add_child(background)
	background.z_index = -100

func _create_start_menu() -> void:
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.70)
	shade.size = Vector2(1200, 820)
	menu_layer.add_child(shade)

	var panel = Panel.new()
	panel.position = Vector2(255, 80)
	panel.size = Vector2(690, 630)
	panel.self_modulate = Color(0.98, 0.99, 1.0, 0.96)
	menu_layer.add_child(panel)

	var panel_bg = ColorRect.new()
	panel_bg.position = Vector2(8, 8)
	panel_bg.size = panel.size - Vector2(16, 16)
	panel_bg.color = Color(0.08, 0.12, 0.18, 0.96)
	panel.add_child(panel_bg)

	var title = Label.new()
	title.position = Vector2(100, 26)
	title.size = Vector2(490, 54)
	title.text = "领土战争"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06))
	title.add_theme_constant_override("outline_size", 6)
	panel.add_child(title)
	menu_title_label = title

	var subtitle = Label.new()
	subtitle.position = Vector2(120, 82)
	subtitle.size = Vector2(450, 24)
	subtitle.text = "四控制仓 · 四角炮台 · 领土争夺"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	panel.add_child(subtitle)

	var decor = preload("res://scripts/MenuDecor.gd").new()
	decor.position = Vector2(345, 286)
	panel.add_child(decor)

	var select_bar = Panel.new()
	select_bar.position = Vector2(86, 496)
	select_bar.size = Vector2(518, 92)
	panel.add_child(select_bar)

	var select_bg = ColorRect.new()
	select_bg.position = Vector2(4, 4)
	select_bg.size = select_bar.size - Vector2(8, 8)
	select_bg.color = Color(0.12, 0.16, 0.23)
	select_bar.add_child(select_bg)

	var size_label = Label.new()
	size_label.position = Vector2(26, 18)
	size_label.size = Vector2(180, 28)
	size_label.text = "选择正方形大小"
	size_label.add_theme_font_size_override("font_size", 20)
	size_label.add_theme_color_override("font_color", Color.WHITE)
	select_bar.add_child(size_label)

	var size_option = OptionButton.new()
	size_option.position = Vector2(238, 14)
	size_option.size = Vector2(160, 34)
	size_option.add_item("20 × 20", 20)
	size_option.add_item("30 × 30", 30)
	size_option.add_item("40 × 40", 40)
	size_option.add_item("50 × 50", 50)
	size_option.select(2)
	size_option.item_selected.connect(func(index: int) -> void:
		selected_grid_size = size_option.get_item_id(index)
	)
	select_bar.add_child(size_option)

	var tip = Label.new()
	tip.position = Vector2(26, 52)
	tip.size = Vector2(360, 24)
	tip.text = "提示：控制台发射时会锁定，炮台血量归零则阵营出局。"
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0))
	select_bar.add_child(tip)

	var start_button = Button.new()
	start_button.position = Vector2(424, 16)
	start_button.size = Vector2(70, 58)
	start_button.text = "开始"
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_button.self_modulate = Color(0.22, 0.60, 1.0)
	start_button.pressed.connect(func() -> void:
		_start_game(selected_grid_size)
	)
	select_bar.add_child(start_button)
	menu_start_button = start_button

func _start_game(grid_size: int) -> void:
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
	var origin = Vector2((1200.0 - map_pixel_size) * 0.5, (820.0 - map_pixel_size) * 0.5 + 20.0)

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
		game_layer.add_child(turret)
		turrets[faction_id] = turret

	for turret in turrets.values():
		turret.set_all_turrets(turrets)

func _create_control_chambers() -> void:
	var map_left = battlefield.position.x
	var map_top = battlefield.position.y
	var map_size = battlefield.grid_size * battlefield.cell_size
	var chamber_w = 160.0
	var chamber_h = 206.0
	var gap = 34.0

	var left_x = max(18.0, map_left - chamber_w - gap)
	var right_x = min(1022.0, map_left + map_size + gap)
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
	top_panel.position = Vector2(290, 10)
	top_panel.size = Vector2(620, 78)
	top_panel.self_modulate = Color(0.96, 0.98, 1.0, 0.96)
	canvas.add_child(top_panel)

	var top_bg = ColorRect.new()
	top_bg.position = Vector2(5, 5)
	top_bg.size = top_panel.size - Vector2(10, 10)
	top_bg.color = Color(0.09, 0.12, 0.18, 0.94)
	top_panel.add_child(top_bg)

	score_label = Label.new()
	score_label.position = Vector2(10, 10)
	score_label.size = Vector2(600, 24)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 3)
	top_panel.add_child(score_label)

	game_title_label = Label.new()
	game_title_label.position = Vector2(100, 36)
	game_title_label.size = Vector2(420, 28)
	game_title_label.text = "球球游戏战争"
	game_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title_label.add_theme_font_size_override("font_size", 24)
	game_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	game_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	game_title_label.add_theme_constant_override("outline_size", 4)
	top_panel.add_child(game_title_label)

	winner_label = Label.new()
	winner_label.position = Vector2(350, 94)
	winner_label.size = Vector2(500, 40)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 30)
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
		button.position = pos + Vector2(44, 214)
		button.size = Vector2(72, 32)
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
		button.self_modulate = Color(0.24, 0.36, 0.58)
	else:
		button.text = "+球"
		button.self_modulate = GameConfig.faction_color(faction_id)

func _on_chamber_release_requested(faction_id, bullet_count, chamber) -> void:
	if turrets.has(faction_id):
		chamber.set_locked(true)
		_refresh_add_ball_button(faction_id)
		turrets[faction_id].fire_burst(bullet_count)

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
	if score_label == null:
		return
	var parts = []
	for faction_id in [GameConfig.Faction.BLUE, GameConfig.Faction.RED, GameConfig.Faction.GREEN, GameConfig.Faction.YELLOW]:
		parts.append("%s:%d" % [GameConfig.faction_name(faction_id), counts.get(faction_id, 0)])
	score_label.text = " | ".join(parts)
