extends Button
class_name EnergyButton

enum VisualState {
    NORMAL,
    HOVER,
    PRESSED,
    LOCKED,
    DAMAGED,
    FULL,
}

var faction_id: int = 0
var pulse_t: float = 0.0
var visual_state: int = VisualState.NORMAL
var display_text: String = "+球"

func _ready() -> void:
    flat = true
    clip_contents = false
    mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_button_status(state_name: String, new_text: String = "") -> void:
    if new_text != "":
        display_text = new_text
        text = new_text

    match state_name:
        "locked":
            visual_state = VisualState.LOCKED
            disabled = true
        "damaged":
            visual_state = VisualState.DAMAGED
            disabled = true
        "full":
            visual_state = VisualState.FULL
            disabled = true
        _:
            visual_state = VisualState.NORMAL
            disabled = false

    queue_redraw()

func _process(delta: float) -> void:
    pulse_t += delta

    if visual_state != VisualState.LOCKED and visual_state != VisualState.DAMAGED and visual_state != VisualState.FULL:
        if button_pressed:
            visual_state = VisualState.PRESSED
        elif is_hovered():
            visual_state = VisualState.HOVER
        else:
            visual_state = VisualState.NORMAL

    queue_redraw()

func _draw() -> void:
    var base: Color = GameConfig.faction_color(faction_id)
    var rect: Rect2 = Rect2(Vector2.ZERO, size)
    var outer: Rect2 = rect.grow(-1.0)
    var shell: Rect2 = rect.grow(-3.0)
    var core: Rect2 = rect.grow(-6.0)
    var icon_center: Vector2 = Vector2(18.0, size.y * 0.5)

    var border_color: Color = Color(base.r, base.g, base.b, 0.44)
    var fill_color: Color = base.lightened(0.08)
    var glow_alpha: float = 0.20 + 0.08 * sin(pulse_t * 3.4)
    var label_color: Color = Color.WHITE
    var add_stripe: bool = false
    var draw_cross: bool = false

    match visual_state:
        VisualState.NORMAL:
            fill_color = base.lightened(0.08)
            glow_alpha = 0.18 + 0.06 * sin(pulse_t * 3.2)
        VisualState.HOVER:
            fill_color = base.lightened(0.22)
            glow_alpha = 0.32 + 0.10 * sin(pulse_t * 4.2)
            outer = outer.grow(1.0)
        VisualState.PRESSED:
            fill_color = base.darkened(0.10)
            glow_alpha = 0.14
            outer.position += Vector2(0, 2)
            shell.position += Vector2(0, 2)
            core.position += Vector2(0, 2)
            icon_center += Vector2(0, 2)
        VisualState.LOCKED:
            fill_color = Color(0.35, 0.36, 0.40)
            border_color = Color(0.54, 0.56, 0.60, 0.38)
            glow_alpha = 0.05
            add_stripe = true
            label_color = Color(0.88, 0.88, 0.90)
        VisualState.DAMAGED:
            fill_color = Color(0.40, 0.18, 0.18)
            border_color = Color(0.94, 0.26, 0.24, 0.55)
            glow_alpha = 0.10 + 0.08 * sin(pulse_t * 6.0)
            draw_cross = true
            label_color = Color(1.0, 0.88, 0.88)
        VisualState.FULL:
            fill_color = Color(0.40, 0.40, 0.44)
            border_color = Color(0.78, 0.78, 0.82, 0.24)
            glow_alpha = 0.06
            label_color = Color(0.92, 0.92, 0.94)

    draw_rect(outer, Color(0.0, 0.0, 0.0, 0.26), true)
    draw_rect(outer.grow(2.0), Color(base.r, base.g, base.b, glow_alpha), false, 3.0)

    draw_rect(shell, Color(0.10, 0.11, 0.14, 0.96), true)
    draw_rect(shell, border_color, false, 2.0)

    draw_rect(core, fill_color, true)
    draw_rect(Rect2(core.position + Vector2(2.0, 2.0), Vector2(core.size.x - 4.0, maxf(4.0, core.size.y * 0.38))), Color(1.0, 1.0, 1.0, 0.12), true)
    draw_rect(Rect2(core.position + Vector2(0.0, core.size.y - 6.0), Vector2(core.size.x, 4.0)), Color(0.0, 0.0, 0.0, 0.12), true)

    if add_stripe:
        for i in range(6):
            var x: float = 6.0 + float(i) * 14.0
            draw_line(Vector2(x, 4.0), Vector2(x + 12.0, size.y - 4.0), Color(1.0, 1.0, 1.0, 0.08), 2.0)

    draw_circle(icon_center, 8.4, Color(0.07, 0.09, 0.12, 0.94))
    draw_circle(icon_center, 6.4, Color(base.r, base.g, base.b, 0.92 if visual_state not in [VisualState.LOCKED, VisualState.FULL] else 0.34))
    draw_circle(icon_center + Vector2(-1.2, -1.2), 2.5, Color(1.0, 1.0, 1.0, 0.42 if visual_state != VisualState.DAMAGED else 0.18))

    if draw_cross:
        draw_line(icon_center + Vector2(-4.0, -4.0), icon_center + Vector2(4.0, 4.0), Color(0.12, 0.02, 0.02, 0.95), 2.0)
        draw_line(icon_center + Vector2(-4.0, 4.0), icon_center + Vector2(4.0, -4.0), Color(0.12, 0.02, 0.02, 0.95), 2.0)

    var final_text: String = display_text if display_text != "" else "+球"
    var font = ThemeDB.fallback_font
    draw_string_outline(font, Vector2(34.0, size.y * 0.5 + 6.0), final_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 18, 2, Color(0.0, 0.0, 0.0, 0.90))
    draw_string(font, Vector2(34.0, size.y * 0.5 + 6.0), final_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 18, label_color)
