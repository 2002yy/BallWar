extends RefCounted
class_name StartMenuView

# Compatibility surface for a broken/mispackaged build only.
# The real start menu is res://scenes/ui/StartMenu.tscn + StartMenu.gd and is
# covered by StartMenuSceneTestRunner. Do not duplicate product UI here again.
static func create(owner, view_size: Vector2, _save_summaries: Array, _current_layout: Dictionary = {}) -> Dictionary:
	push_error("StartMenu.tscn is missing; this build cannot enter the game menu.")

	var menu_layer := CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	owner.add_child(menu_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.96)
	shade.size = view_size
	menu_layer.add_child(shade)

	var status := Label.new()
	status.text = "启动菜单资源缺失\n请重新导出或安装完整版本"
	status.position = Vector2.ZERO
	status.size = view_size
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER as VerticalAlignment
	status.add_theme_font_size_override("font_size", 24)
	status.add_theme_color_override("font_color", Color(1.0, 0.72, 0.44))
	menu_layer.add_child(status)

	return {
		"menu_layer": menu_layer,
		"menu_title_label": null,
		"menu_start_button": null,
		"menu_continue_button": null,
		"menu_save_slot_buttons": {},
		"menu_status_label": status,
	}
