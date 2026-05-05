# TOOL-ONLY SCRIPT — DO NOT RUN AFTER MANUAL EDITS.
# Running this script will overwrite scenes/ui/GameHUD.tscn.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := CanvasLayer.new()
	root.name = "GameHUD"
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.script = preload("res://scripts/GameHUD.gd")

	var fps_label := Label.new()
	fps_label.name = "FPSLabel"
	fps_label.position = Vector2(402, 649)
	fps_label.size = Vector2(702, 24)
	fps_label.text = "FPS -- | 子弹 -- | 队列 -- | 画质 -- | 地图 -- | 战场 -- | 压力 --"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", Color(0.72, 1.0, 0.72))
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 3)
	fps_label.process_mode = Node.PROCESS_MODE_ALWAYS
	fps_label.visible = false
	root.add_child(fps_label)

	var event_label := Label.new()
	event_label.name = "EventLabel"
	event_label.size = Vector2(332, 24)
	event_label.position = Vector2(fps_label.position.x + fps_label.size.x - event_label.size.x, fps_label.position.y - event_label.size.y - 4)
	event_label.text = "事件：无 | 下次 00:00"
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	event_label.add_theme_font_size_override("font_size", 14)
	event_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.68))
	event_label.add_theme_color_override("font_outline_color", Color.BLACK)
	event_label.add_theme_constant_override("outline_size", 3)
	event_label.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(event_label)

	var side_button_size := Vector2(96, 42)
	var side_margin := 18.0
	var view_w := 1120.0
	var side_x := view_w - side_button_size.x - side_margin
	var side_gap := 8.0

	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.position = Vector2(side_x, 84)
	settings_button.size = side_button_size
	settings_button.text = "设置"
	settings_button.add_theme_font_size_override("font_size", 14)
	settings_button.add_theme_color_override("font_color", Color.WHITE)
	settings_button.self_modulate = Color(0.34, 0.34, 0.54)
	root.add_child(settings_button)

	var pause_button := Button.new()
	pause_button.name = "PauseButton"
	pause_button.position = Vector2(side_x, 84 + side_button_size.y + side_gap)
	pause_button.size = side_button_size
	pause_button.text = "暂停"
	pause_button.add_theme_font_size_override("font_size", 14)
	pause_button.add_theme_color_override("font_color", Color.WHITE)
	pause_button.self_modulate = Color(0.24, 0.52, 0.92)
	root.add_child(pause_button)

	var exit_button := Button.new()
	exit_button.name = "ExitButton"
	exit_button.position = Vector2(side_x, 84 + (side_button_size.y + side_gap) * 2)
	exit_button.size = side_button_size
	exit_button.text = "退出"
	exit_button.add_theme_font_size_override("font_size", 14)
	exit_button.add_theme_color_override("font_color", Color.WHITE)
	exit_button.self_modulate = Color(0.62, 0.24, 0.22)
	root.add_child(exit_button)

	var pause_overlay := Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.position = Vector2.ZERO
	pause_overlay.size = Vector2(view_w, 720)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pause_overlay)

	var winner_label := Label.new()
	winner_label.name = "WinnerLabel"
	winner_label.position = Vector2(0, 648)
	winner_label.size = Vector2(view_w, 34)
	winner_label.text = ""
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 28)
	winner_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.22))
	winner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	winner_label.add_theme_constant_override("outline_size", 5)
	root.add_child(winner_label)

	_own_recursive(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/ui/GameHUD.tscn")
	print("SUCCESS: scenes/ui/GameHUD.tscn")
	quit(0)

func _own_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		if child != node:
			_own_recursive(child, scene_root)
