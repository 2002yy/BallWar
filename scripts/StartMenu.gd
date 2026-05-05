extends CanvasLayer
class_name StartMenu

@onready var title_label: Label = get_node("RootPanel/TitleLabel")
@onready var start_button: Button = get_node("RootPanel/ConfigPanel/StartButton")
@onready var continue_button: Button = get_node("RootPanel/ContinueButton")
@onready var size_option: OptionButton = get_node("RootPanel/ConfigPanel/GridSizeOption")
@onready var mode_option: OptionButton = get_node("RootPanel/ConfigPanel/ModeOption")
@onready var time_spin: SpinBox = get_node("RootPanel/ConfigPanel/TimeSpin")
@onready var palette_option: OptionButton = get_node("RootPanel/ConfigPanel/PaletteOption")
@onready var menu_status_label: Label = get_node("RootPanel/MenuStatusLabel")
@onready var slot_container: Control = get_node("RootPanel/SavePanel/SaveSlotContainer")

var _owner

func get_parts() -> Dictionary:
	var slot_buttons: Dictionary = {}
	if slot_container != null:
		for i in range(5):
			var slot: int = i + 1
			var node_name: String = "SlotButton_%d" % slot
			if slot_container.has_node(node_name):
				slot_buttons[slot] = slot_container.get_node(node_name)
	return {
		"menu_layer": self,
		"menu_title_label": title_label,
		"menu_start_button": start_button,
		"menu_continue_button": continue_button,
		"menu_save_slot_buttons": slot_buttons,
		"menu_status_label": menu_status_label,
	}

func setup(p_owner, _view_size: Vector2, save_summaries: Array) -> void:
	_owner = p_owner
	_owner.selected_grid_size = 40
	_owner.selected_palette_name = "默认随机"
	_owner.selected_quality_name = GameConfig.QUALITY_MEDIUM
	_owner.selected_game_mode_name = GameConfig.GAME_MODE_BASIC
	_owner.selected_time_limit_minutes = GameConfig.DEFAULT_TIMED_MODE_MINUTES
	_owner.selected_save_slot = clampi(int(_owner.selected_save_slot), 1, _owner.SAVE_SLOT_COUNT)

	_init_options()
	_init_decor()
	_refresh_slots(save_summaries)
	_connect_signals()

func _init_options() -> void:
	for gs in [10, 20, 30, 40, 50, 60]:
		size_option.add_item("%d × %d" % [gs, gs], gs)
	size_option.select(3)

	for mode_name in GameConfig.get_game_mode_names():
		mode_option.add_item(mode_name)
	mode_option.select(0)

	var quality_option: OptionButton = get_node("RootPanel/ConfigPanel/QualityOption")
	for quality_name in GameConfig.get_quality_names():
		quality_option.add_item(quality_name)
	quality_option.select(1)

	palette_option.add_item("默认随机")
	for palette_name in GameConfig.get_palette_names():
		palette_option.add_item(palette_name)
	palette_option.select(0)

func _init_decor() -> void:
	var decor_node: Node2D = get_node("RootPanel/ChamberPreview")
	var decor = preload("res://scripts/MenuDecor.gd").new()
	decor.position = Vector2(420.0, 260.0)
	decor.scale = Vector2(0.78, 0.78)
	decor_node.add_child(decor)

func _refresh_slots(save_summaries: Array) -> void:
	var buttons := _get_slot_buttons()
	for summary in save_summaries:
		if not (summary is Dictionary):
			continue
		var slot: int = int(summary.get("slot", 1))
		if slot < 1 or slot > 5:
			continue
		var button: Button = buttons[slot - 1]
		var title_text: String = str(summary.get("title", "空存档"))
		var marker: String = "● " if slot == _owner.selected_save_slot else ""
		button.text = "%s槽%d  %s" % [marker, slot, title_text]
		button.tooltip_text = "%s\n%s" % [title_text, str(summary.get("detail", ""))]
		button.self_modulate = Color(0.28, 0.54, 0.88) if slot == _owner.selected_save_slot else Color(0.16, 0.22, 0.32)

	continue_button.text = "读取槽%d" % _owner.selected_save_slot
	continue_button.disabled = not _owner._has_save_file(_owner.selected_save_slot)
	menu_status_label.text = "当前存档槽：%d" % _owner.selected_save_slot

func _get_slot_buttons() -> Array:
	var result: Array = []
	for i in range(5):
		result.append(slot_container.get_node("SlotButton_%d" % (i + 1)))
	return result

func _connect_signals() -> void:
	size_option.item_selected.connect(func(index: int) -> void:
		_owner.selected_grid_size = size_option.get_item_id(index)
	)
	mode_option.item_selected.connect(func(index: int) -> void:
		_owner.selected_game_mode_name = mode_option.get_item_text(index)
	)
	var quality_option: OptionButton = get_node("RootPanel/ConfigPanel/QualityOption")
	quality_option.item_selected.connect(func(index: int) -> void:
		_owner.selected_quality_name = quality_option.get_item_text(index)
	)
	time_spin.value_changed.connect(func(value: float) -> void:
		_owner.selected_time_limit_minutes = clampi(int(round(value)), GameConfig.TIMED_MODE_MIN_MINUTES, GameConfig.TIMED_MODE_MAX_MINUTES)
	)
	palette_option.item_selected.connect(func(index: int) -> void:
		_owner.selected_palette_name = palette_option.get_item_text(index)
	)
	start_button.pressed.connect(func() -> void:
		_owner._start_game(_owner.selected_grid_size)
	)
	continue_button.pressed.connect(Callable(_owner, "_continue_saved_game"))

	for i in range(5):
		var slot: int = i + 1
		var btn: Button = _get_slot_buttons()[i]
		btn.pressed.connect(func() -> void:
			_owner._select_save_slot(slot)
		)
