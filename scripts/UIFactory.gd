extends RefCounted
class_name UIFactory

static func make_outline_label(pos: Vector2, label_size: Vector2, text_value: String, font_size: int, font_color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline_size: int = 2) -> Label:
    var label := Label.new()
    label.position = pos
    label.size = label_size
    label.text = text_value
    label.horizontal_alignment = align as HorizontalAlignment
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", font_color)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", outline_size)
    return label

static func make_action_button(pos: Vector2, button_size: Vector2, text_value: String, tint: Color) -> Button:
    var button := Button.new()
    button.position = pos
    button.size = button_size
    button.text = text_value
    button.self_modulate = tint
    button.add_theme_color_override("font_color", Color.WHITE)
    button.process_mode = Node.PROCESS_MODE_ALWAYS
    return button

static func make_fill_rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
    var rect := ColorRect.new()
    rect.position = pos
    rect.size = rect_size
    rect.color = color
    return rect

static func make_panel_shell(pos: Vector2, panel_size: Vector2, tint: Color) -> Panel:
    var panel := Panel.new()
    panel.position = pos
    panel.size = panel_size
    panel.self_modulate = tint
    return panel
