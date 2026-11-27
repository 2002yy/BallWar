extends CanvasLayer
class_name ReserveLab

const LAUNCH_FLAG := "--reserve-lab"
const FIXTURE_FIREPOWER := 800

var controller
var _panel: PanelContainer
var _faction: OptionButton
var _balances: Label
var _notice: Label
var _buy_ball: Button
var _buy_blast: Button
var _drop_fixture: Button

static func is_requested(debug_build: bool, args: PackedStringArray) -> bool:
	return debug_build and args.has(LAUNCH_FLAG)

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 260)
	_panel.custom_minimum_size.x = 174
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.33, 0.48, 0.60)
	panel_style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "储备实验 · F8"
	rows.add_child(title)
	_balances = Label.new()
	rows.add_child(_balances)
	_faction = OptionButton.new()
	_faction.name = "Faction"
	for faction_id in controller.runtime.chambers:
		_faction.add_item(GameConfig.faction_name(faction_id), faction_id)
	_faction.select(0)
	_faction.item_selected.connect(func(_index: int): _refresh())
	rows.add_child(_faction)

	var purchases := HBoxContainer.new()
	rows.add_child(purchases)
	_buy_ball = _button(purchases, "BuyBall", "加球 %d" % ReserveEconomy.ADD_BALL_COST, _purchase_ball)
	_buy_blast = _button(purchases, "BuyBlast", "试爆 %d" % ReserveEconomy.LUCKY_BLAST_COST, _purchase_blast)
	_buy_blast.tooltip_text = "购买幸运爆炸"
	var tools := HBoxContainer.new()
	rows.add_child(tools)
	_drop_fixture = _button(tools, "DropFixture", "构造落门", _prepare_fixture)
	_drop_fixture.tooltip_text = "构造 800 待发火力，让一颗球落入储备门"
	_button(tools, "Restart", "重开", func(): controller.call_deferred("_start_reserve_lab_match"))
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.text = "储备上限 %d" % ReserveEconomy.CAPACITY
	rows.add_child(_notice)
	_refresh()

func _button(parent: Control, node_name: String, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F8 and event.pressed and not event.echo:
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _panel.visible:
		_refresh()

func _selected_chamber() -> ControlChamber:
	return controller.runtime.chambers.get(_faction.get_selected_id())

func _refresh() -> void:
	var economy: ReserveEconomy = controller.runtime.reserve_economy
	if economy == null:
		return
	var balance_labels := PackedStringArray()
	for faction_id in controller.runtime.chambers:
		balance_labels.append("%s %d" % [GameConfig.faction_name(faction_id), economy.balance(faction_id)])
	_balances.text = "  ".join(balance_labels.slice(0, 2)) + "\n" + "  ".join(balance_labels.slice(2))
	var chamber := _selected_chamber()
	var unavailable: bool = controller.is_game_over or get_tree().paused or chamber == null or chamber.is_damaged
	var blocked: bool = unavailable or chamber.is_locked or chamber.is_jammed()
	var balance := economy.balance(_faction.get_selected_id())
	_buy_ball.disabled = blocked or balance < ReserveEconomy.ADD_BALL_COST or chamber.get_ball_count() >= GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER
	_buy_blast.disabled = unavailable or balance < ReserveEconomy.LUCKY_BLAST_COST
	_drop_fixture.disabled = blocked or chamber.balls.is_empty() or balance >= ReserveEconomy.CAPACITY

func _purchase_ball() -> void:
	var chamber := _selected_chamber()
	var before := chamber.get_ball_count()
	controller._add_ball_to_chamber(chamber.faction_id)
	_notice.text = "控制球 +1" if chamber.get_ball_count() > before else "加球未完成"
	_refresh()

func _purchase_blast() -> void:
	var changed: int = controller._buy_lucky_blast(_faction.get_selected_id())
	_notice.text = "幸运爆炸夺取 %d 格" % changed if changed > 0 else "爆炸未完成，储备未扣除"
	_refresh()

func _prepare_fixture() -> void:
	var chamber := _selected_chamber()
	var gate_x := chamber._reserve_gate_x(chamber._current_x2_width())
	if gate_x < 0.0 or chamber.balls.is_empty():
		return
	chamber.pending_count = FIXTURE_FIREPOWER
	var ball: ControlBall = chamber.balls[0]
	ball.position = Vector2(lerpf(gate_x, chamber.chamber_size.x, 0.5), chamber.chamber_size.y - ball.radius - 1.0)
	ball.velocity = Vector2(0.0, 120.0)
	chamber.set_ball_stay_time(ball, 0.0)
	_notice.text = "已构造落球，等待结算"
