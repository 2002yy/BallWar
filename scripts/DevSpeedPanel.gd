extends CanvasLayer

const SAMPLE_USEC: int = 400_000

var clock: MatchClock
var _main: Node
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
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	reset_match()


func begin_match() -> void:
	_started_usec = Time.get_ticks_usec()
	_sample_usec = _started_usec
	_sample_tick = clock.ticks
	_toggle.show()


func reset_match() -> void:
	clock.reset()
	_started_usec = 0
	_actual_speed = 0.0
	_panel.hide()
	_toggle.hide()


func _exit_tree() -> void:
	if clock != null:
		clock.reset()


func _process(_delta: float) -> void:
	if _started_usec == 0:
		return
	var now: int = Time.get_ticks_usec()
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
			_main._toggle_pause()
		KEY_F10:
			clock.request_step()
		_:
			if not _panel.visible or event.keycode < KEY_1 or event.keycode > KEY_5:
				return
			clock.set_speed(MatchClock.SPEEDS[event.keycode - KEY_1])
	get_viewport().set_input_as_handled()


func _toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_update_panel(Time.get_ticks_usec())


func _update_panel(now: int) -> void:
	var paused: bool = get_tree().paused
	_stats.text = "模拟 %.3f s    现实 %.1f s\n实际 %.2f×    目标 %d×    %.0f FPS" % [
		_main.game_elapsed_time, float(now - _started_usec) / 1000000.0,
		0.0 if paused else _actual_speed, clock.speed, Engine.get_frames_per_second()
	]
	_pause.text = "继续 F9" if paused else "暂停 F9"
	_step.disabled = not paused
	for speed in MatchClock.SPEEDS:
		_speed_buttons[speed].set_pressed_no_signal(speed == clock.speed)


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
