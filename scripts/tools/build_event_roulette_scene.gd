# TOOL-ONLY — DO NOT RUN AFTER MANUAL EDITS.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Control.new()
	root.name = "EventRouletteView"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.script = preload("res://scripts/EventRouletteView.gd")

	var stage_panel := Panel.new()
	stage_panel.name = "StagePanel"
	stage_panel.visible = false
	stage_panel.self_modulate = Color(0.94, 0.97, 1.0, 0.96)
	stage_panel.size = Vector2(448, 168)
	root.add_child(stage_panel)

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.position = Vector2(4, 4)
	bg.size = stage_panel.size - Vector2(8, 8)
	bg.color = Color(0.05, 0.08, 0.14, 0.98)
	stage_panel.add_child(bg)

	var header_label := Label.new()
	header_label.name = "HeaderLabel"
	header_label.position = Vector2(0, 8)
	header_label.size = Vector2(stage_panel.size.x, 28)
	header_label.text = "事件转盘"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", 24)
	header_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
	header_label.add_theme_color_override("font_outline_color", Color.BLACK)
	header_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(header_label)

	var left_title_label := Label.new()
	left_title_label.name = "LeftTitleLabel"
	left_title_label.position = Vector2(34, 44)
	left_title_label.size = Vector2(150, 20)
	left_title_label.text = "阵营"
	left_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_title_label.add_theme_font_size_override("font_size", 16)
	left_title_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	left_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	left_title_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(left_title_label)

	var right_title_label := Label.new()
	right_title_label.name = "RightTitleLabel"
	right_title_label.position = Vector2(stage_panel.size.x - 184, 44)
	right_title_label.size = Vector2(150, 20)
	right_title_label.text = "效果"
	right_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_title_label.add_theme_font_size_override("font_size", 16)
	right_title_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0))
	right_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	right_title_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(right_title_label)

	var wheel_w: float = (stage_panel.size.x - 72) * 0.5
	var wheel_h: float = 58

	var left_value_label := Label.new()
	left_value_label.name = "LeftValueLabel"
	left_value_label.position = Vector2(24, 66)
	left_value_label.size = Vector2(wheel_w, wheel_h)
	left_value_label.text = ""
	left_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left_value_label.add_theme_font_size_override("font_size", 28)
	left_value_label.add_theme_color_override("font_color", Color.WHITE)
	left_value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	left_value_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(left_value_label)

	var right_value_label := Label.new()
	right_value_label.name = "RightValueLabel"
	right_value_label.position = Vector2(stage_panel.size.x - 24 - wheel_w, 66)
	right_value_label.size = Vector2(wheel_w, wheel_h)
	right_value_label.text = ""
	right_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_value_label.add_theme_font_size_override("font_size", 26)
	right_value_label.add_theme_color_override("font_color", Color.WHITE)
	right_value_label.add_theme_color_override("font_outline_color", Color.BLACK)
	right_value_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(right_value_label)

	var left_pointer := ColorRect.new()
	left_pointer.name = "LeftPointer"
	left_pointer.color = Color(1.0, 0.84, 0.18, 0.58)
	left_pointer.position = Vector2(left_value_label.position.x + 12, left_value_label.position.y + wheel_h + 4)
	left_pointer.size = Vector2(wheel_w - 24, 4)
	stage_panel.add_child(left_pointer)

	var right_pointer := ColorRect.new()
	right_pointer.name = "RightPointer"
	right_pointer.color = Color(1.0, 0.84, 0.18, 0.58)
	right_pointer.position = Vector2(right_value_label.position.x + 12, right_value_label.position.y + wheel_h + 4)
	right_pointer.size = Vector2(wheel_w - 24, 4)
	stage_panel.add_child(right_pointer)

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.position = Vector2(18, stage_panel.size.y - 48)
	result_label.size = Vector2(stage_panel.size.x - 36, 30)
	result_label.text = ""
	result_label.visible = false
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.42))
	result_label.add_theme_color_override("font_outline_color", Color.BLACK)
	result_label.add_theme_constant_override("outline_size", 3)
	stage_panel.add_child(result_label)

	_own_recursive(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/ui/EventRouletteView.tscn")
	print("SUCCESS: scenes/ui/EventRouletteView.tscn")
	quit(0)

func _own_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		if child != node:
			_own_recursive(child, scene_root)
