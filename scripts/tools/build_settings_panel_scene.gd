# TOOL-ONLY — DO NOT RUN AFTER MANUAL EDITS.
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Panel.new()
	root.name = "SettingsPanel"
	root.size = Vector2(286, 96)
	root.visible = false
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.self_modulate = Color(0.94, 0.97, 1.0, 0.96)
	root.script = preload("res://scripts/SettingsPanel.gd")

	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.position = Vector2(4, 4)
	bg.size = root.size - Vector2(8, 8)
	bg.color = Color(0.06, 0.09, 0.15, 0.96)
	root.add_child(bg)

	var label := Label.new()
	label.name = "ContentLabel"
	label.position = Vector2(12, 10)
	label.size = root.size - Vector2(24, 20)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = ""
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	root.add_child(label)

	_own_recursive(root, root)

	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, "res://scenes/ui/SettingsPanel.tscn")
	print("SUCCESS: scenes/ui/SettingsPanel.tscn")
	quit(0)

func _own_recursive(node: Node, scene_root: Node) -> void:
	node.owner = scene_root
	for child in node.get_children():
		if child != node:
			_own_recursive(child, scene_root)
