extends RefCounted
class_name BannerController

static func show(owner, ui_canvas, old_banner, view_size: Vector2, current_layout: Dictionary, title_text: String, sub_text: String, accent: Color, auto_hide: bool):
    if ui_canvas == null:
        return old_banner
    if old_banner != null and is_instance_valid(old_banner):
        old_banner.queue_free()

    var holder = Control.new()
    holder.position = Vector2.ZERO
    holder.size = view_size
    holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_canvas.add_child(holder)

    var title = Label.new()
    title.position = Vector2((view_size.x - 460.0) * 0.5, current_layout.get("banner_title_y", 284.0))
    title.size = Vector2(460, 58)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    title.text = title_text
    title.add_theme_font_size_override("font_size", 50)
    title.add_theme_color_override("font_color", accent)
    title.add_theme_color_override("font_outline_color", Color.BLACK)
    title.add_theme_constant_override("outline_size", 8)
    holder.add_child(title)

    var sub = Label.new()
    sub.position = Vector2((view_size.x - 340.0) * 0.5, current_layout.get("banner_sub_y", 338.0))
    sub.size = Vector2(340, 24)
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER as HorizontalAlignment
    sub.text = sub_text
    sub.add_theme_font_size_override("font_size", 20)
    sub.add_theme_color_override("font_color", Color.WHITE)
    sub.add_theme_color_override("font_outline_color", Color.BLACK)
    sub.add_theme_constant_override("outline_size", 4)
    holder.add_child(sub)

    holder.scale = Vector2(0.7, 0.7)
    holder.modulate = Color(1, 1, 1, 0)
    var tween = owner.create_tween()
    tween.tween_property(holder, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.parallel().tween_property(holder, "modulate", Color(1, 1, 1, 1), 0.24)
    if auto_hide:
        tween.tween_interval(1.2)
        tween.tween_property(holder, "modulate", Color(1, 1, 1, 0), 0.42)
        tween.tween_callback(holder.queue_free)
    else:
        title.add_theme_color_override("font_color", accent)

    return holder
