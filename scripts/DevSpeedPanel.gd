extends CanvasLayer

const SAMPLE_USEC: int = 400_000

var clock: MatchClock
var _main: Node
var _tools: DevBattleTools
var _advance_box: VBoxContainer
var _construct_box: VBoxContainer
var _goal_factions: OptionButton
var _action_factions: OptionButton
var _status: Label
var _finished_usec: int = 0
var _constructed: bool = false
var _reset_tool_inputs: Callable
var _panel: PanelContainer
var _toggle: Button
var _stats: Label
var _pause: Button
var _step: Button
var _speed_buttons: Dictionary = {}
var _started_usec: int = 0
var _sample_usec: int = 0
var _sample_tick: int = 0
var _actual_speed: float = 0.0


func setup(main: Node) -> void:
	_main = main
	clock = MatchClock.new(get_tree())
	_tools = DevBattleTools.new(main)
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	reset_match()


func begin_match() -> void:
	_started_usec = Time.get_ticks_usec()
	_sample_usec = _started_usec
	_sample_tick = clock.ticks
	_toggle.show()
	_reset_tool_inputs.call()
	for i in 4:
		_goal_factions.set_item_text(i + 1, GameConfig.faction_name(i))
		_action_factions.set_item_text(i, GameConfig.faction_name(i))


func reset_match() -> void:
	clock.reset()
	_started_usec = 0
	_finished_usec = 0
	_constructed = false
	_tools.reset()
	_status.text = ""
	_advance_box.hide()
	_construct_box.hide()
	_panel.offset_top = -228
	_actual_speed = 0.0
	_panel.hide()
	_toggle.hide()


func _exit_tree() -> void:
	if clock != null:
		clock.reset()


func _process(_delta: float) -> void:
	if _started_usec == 0:
		return
	var now: int = _finished_usec if _finished_usec > 0 else Time.get_ticks_usec()
	if now - _sample_usec >= SAMPLE_USEC:
		_actual_speed = float(clock.ticks - _sample_tick) * MatchClock.STEP_SECONDS * 1000000.0 / (now - _sample_usec)
		_sample_usec = now
		_sample_tick = clock.ticks
	if _panel.visible:
		_update_panel(now)


func _input(event: InputEvent) -> void:
	if _started_usec == 0 or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F8:
			_toggle_panel()
		KEY_F9:
			if _finished_usec == 0:
				_main._toggle_pause()
		KEY_F10:
			if _finished_usec == 0:
				clock.request_step()
		KEY_ESCAPE:
			if _main._construction_faction >= 0:
				return
			if not _tools.is_advancing() and clock.speed == 1:
				return
			_stop_advance("已取消，恢复 1×", false)
		_:
			if not _panel.visible or _finished_usec > 0 or get_viewport().gui_get_focus_owner() is LineEdit:
				return
			if event.keycode < KEY_1 or event.keycode > KEY_5:
				return
			clock.set_speed(MatchClock.SPEEDS[event.keycode - KEY_1])
	get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_update_panel(_finished_usec if _finished_usec > 0 else Time.get_ticks_usec())


func _update_panel(now: int) -> void:
	var paused: bool = get_tree().paused
	var finished: bool = _finished_usec > 0
	_stats.text = "模拟 %.3f s    现实 %.1f s\n实际 %.2f×    目标 %d×    %.0f FPS" % [
		_main.game_elapsed_time, float(now - _started_usec) / 1000000.0,
		0.0 if paused or finished else _actual_speed, clock.speed, Engine.get_frames_per_second()
	]
	var pool: BulletPool = _main.runtime.bullet_pool
	if is_instance_valid(pool) and pool.collision_resolver != null:
		_stats.text += "\n炮弹互撞已抵消 %d 发" % pool.collision_resolver.removed_projectiles
	if _constructed:
		_stats.text += "\n调试构造战况"
	_pause.text = "继续 F9" if paused else "暂停 F9"
	_pause.disabled = finished
	_step.disabled = not paused or finished
	for speed in MatchClock.SPEEDS:
		_speed_buttons[speed].set_pressed_no_signal(speed == clock.speed)
		_speed_buttons[speed].disabled = finished


func _build_panel() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toggle = Button.new()
	_toggle.text = "调试 F8"
	root.add_child(_toggle)
	_toggle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toggle.offset_left = 12
	_toggle.offset_top = -36
	_toggle.offset_bottom = -8
	_toggle.pressed.connect(_toggle_panel)

	_panel = PanelContainer.new()
	root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 12
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -232
	_panel.offset_bottom = -48
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.075, 0.11, 0.97)
	background.set_border_width_all(1)
	background.border_color = Color(0.34, 0.45, 0.60)
	_panel.add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	margin.add_child(content)
	var title := Label.new()
	title.text = "DEV-SPEED · 隔离试玩"
	content.add_child(title)
	_stats = Label.new()
	_stats.custom_minimum_size.x = 292
	content.add_child(_stats)

	var rates := HBoxContainer.new()
	content.add_child(rates)
	for speed in MatchClock.SPEEDS:
		var rate := Button.new()
		rate.text = "%d×" % speed
		rate.toggle_mode = true
		rate.pressed.connect(clock.set_speed.bind(speed))
		_speed_buttons[speed] = rate
		rates.add_child(rate)

	var actions := HBoxContainer.new()
	content.add_child(actions)
	_pause = Button.new()
	_pause.pressed.connect(_main._toggle_pause)
	actions.add_child(_pause)
	_step = Button.new()
	_step.text = "单步 F10"
	_step.pressed.connect(clock.request_step)
	actions.add_child(_step)
	_build_tools(content)

func before_simulation_step() -> void:
	if _tools.is_advancing() and _tools.goal_reached():
		_stop_advance("到达目标，已暂停", true)


func record_event() -> void:
	_tools.record_event()


func finish_match() -> void:
	if _started_usec == 0 or _finished_usec > 0:
		return
	_finished_usec = Time.get_ticks_usec()
	clock.cancel_step()
	clock.set_speed(1)
	_tools.cancel_goal()
	_status.text = "对局结束，已恢复 1×"


func start_advance(goal: DevBattleTools.Goal, threshold: float, faction: int) -> void:
	if _finished_usec > 0 or _started_usec == 0:
		return
	_tools.arm_goal(goal, threshold, faction)
	before_simulation_step()
	if not _tools.is_advancing():
		return
	if get_tree().paused:
		_main._toggle_pause()
	if clock.speed == 1:
		clock.set_speed(20)
	_status.text = "正在推进，Esc 取消"


func construct(action: DevBattleTools.Action, faction: int, amount: int) -> bool:
	if _finished_usec > 0 or _started_usec == 0:
		return false
	var result: String = _tools.construct(action, faction, amount)
	if result.is_empty():
		_status.text = "当前无法执行，请检查目标、数量或进行中的发射/事件"
		return false
	if _tools.is_advancing():
		_tools.cancel_goal()
		clock.set_speed(1)
	_constructed = true
	_status.text = result
	_main._flush_battle_view()
	return true


func _stop_advance(message: String, pause_match: bool) -> void:
	_tools.cancel_goal()
	clock.set_speed(1)
	if pause_match:
		clock.cancel_step()
		if not get_tree().paused:
			_main._toggle_pause()
		_main._flush_battle_view()
	_status.text = message


func _toggle_tools(pane: Control) -> void:
	var show_pane: bool = not pane.visible
	_advance_box.hide()
	_construct_box.hide()
	pane.visible = show_pane
	_panel.offset_top = -358 if show_pane else -228


func _build_tools(content: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	var advance := Button.new()
	advance.text = "推进条件"
	tabs.add_child(advance)
	var construct_tab := Button.new()
	construct_tab.text = "构造战况"
	tabs.add_child(construct_tab)

	_advance_box = VBoxContainer.new()
	content.add_child(_advance_box)
	var goal := OptionButton.new()
	for name in ["指定模拟时间（秒）", "首次发射", "指定在场弹量", "下一次随机事件生效",
		"炮塔生命低于比例（%）", "首次炮塔摧毁", "指定占地比例（%）", "对局结束"]:
		goal.add_item(name)
	_advance_box.add_child(goal)
	var target_row := HBoxContainer.new()
	_advance_box.add_child(target_row)
	var goal_fraction: OptionButton = _make_faction_picker(true)
	_goal_factions = goal_fraction
	target_row.add_child(goal_fraction)
	var threshold := SpinBox.new()
	threshold.min_value = 0
	threshold.max_value = 36000
	threshold.value = 60
	target_row.add_child(threshold)
	var go := Button.new()
	go.text = "开始推进"
	_advance_box.add_child(go)
	var cancel := Button.new()
	cancel.text = "取消 Esc"
	_advance_box.add_child(cancel)
	go.pressed.connect(func(): start_advance(goal.selected as DevBattleTools.Goal, threshold.value, goal_fraction.get_selected_id()))
	cancel.pressed.connect(func(): _stop_advance("已取消，恢复 1×", false))
	goal.item_selected.connect(func(index: int): _configure_goal_inputs(index, threshold, goal_fraction))
	_configure_goal_inputs(0, threshold, goal_fraction)
	advance.pressed.connect(_toggle_tools.bind(_advance_box))
	_advance_box.hide()

	_construct_box = VBoxContainer.new()
	content.add_child(_construct_box)
	var action := OptionButton.new()
	for name in ["增加控制球", "立即排入炮弹", "触发随机事件", "设置炮塔生命",
		"摧毁指定炮塔", "布置高密度弹幕"]:
		action.add_item(name)
	_construct_box.add_child(action)
	var action_row := HBoxContainer.new()
	_construct_box.add_child(action_row)
	var faction: OptionButton = _make_faction_picker(false)
	_action_factions = faction
	action_row.add_child(faction)
	var amount := SpinBox.new()
	action_row.add_child(amount)
	var apply := Button.new()
	apply.text = "执行构造"
	_construct_box.add_child(apply)
	apply.pressed.connect(func(): construct(action.selected as DevBattleTools.Action, faction.get_selected_id(), int(amount.value)))
	action.item_selected.connect(func(index: int): _configure_action_inputs(index, amount, faction))
	_configure_action_inputs(0, amount, faction)
	construct_tab.pressed.connect(_toggle_tools.bind(_construct_box))
	_construct_box.hide()
	_reset_tool_inputs = func():
		goal.select(0)
		action.select(0)
		goal_fraction.select(0)
		faction.select(0)
		_configure_goal_inputs(0, threshold, goal_fraction)
		_configure_action_inputs(0, amount, faction)

	_status = Label.new()
	_status.custom_minimum_size.x = 292
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)


func _make_faction_picker(allow_any: bool) -> OptionButton:
	var picker := OptionButton.new()
	if allow_any:
		picker.add_item("任意阵营", 4)
	for i in range(4):
		picker.add_item("阵营 %d" % (i + 1), i)
	return picker


func _configure_goal_inputs(kind: int, threshold: SpinBox, faction: OptionButton) -> void:
	var uses_faction: bool = kind in [DevBattleTools.Goal.LOW_HEALTH, DevBattleTools.Goal.TERRITORY]
	faction.visible = uses_faction
	threshold.visible = uses_faction or kind in [DevBattleTools.Goal.TIME, DevBattleTools.Goal.ACTIVE_BULLETS]
	threshold.step = 0.1 if kind == DevBattleTools.Goal.TIME else 1.0
	threshold.min_value = threshold.step
	if uses_faction:
		threshold.max_value = 100
		threshold.value = 50
	elif kind == DevBattleTools.Goal.ACTIVE_BULLETS:
		threshold.max_value = GameConfig.get_max_active_bullets()
		threshold.value = 200
	else:
		threshold.max_value = 36000
		threshold.value = 60


func _configure_action_inputs(kind: int, amount: SpinBox, faction: OptionButton) -> void:
	faction.visible = kind != DevBattleTools.Action.TRIGGER_EVENT
	amount.visible = kind not in [DevBattleTools.Action.TRIGGER_EVENT, DevBattleTools.Action.DESTROY_TURRET]
	amount.min_value = 1
	match kind:
		DevBattleTools.Action.ADD_BALLS:
			amount.max_value = GameConfig.MAX_CONTROL_BALLS_PER_CHAMBER
			amount.value = 1
		DevBattleTools.Action.FIRE_BURST:
			amount.max_value = GameConfig.get_max_pending_count()
			amount.value = 128
		DevBattleTools.Action.SET_HEALTH:
			amount.min_value = 0
			amount.max_value = GameConfig.get_turret_max_health(_main.selected_grid_size)
			amount.value = 30
		DevBattleTools.Action.DENSE_BULLETS:
			amount.max_value = GameConfig.get_max_active_bullets()
			amount.value = amount.max_value
