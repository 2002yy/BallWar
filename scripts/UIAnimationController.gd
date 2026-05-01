extends RefCounted
class_name UIAnimationController

static func animate_menu_and_title(ui_time: float, menu_title_label, menu_start_button, menu_continue_button, game_title_label, winner_label) -> void:
    if menu_title_label != null and is_instance_valid(menu_title_label):
        menu_title_label.rotation = sin(ui_time * 1.2) * 0.01

    if menu_start_button != null and is_instance_valid(menu_start_button):
        var pulse: float = 1.0 + 0.03 * sin(ui_time * 2.8)
        menu_start_button.scale = Vector2(pulse, pulse)

    if menu_continue_button != null and is_instance_valid(menu_continue_button):
        var cpulse: float = 1.0 + 0.02 * sin(ui_time * 2.2 + 0.8)
        menu_continue_button.scale = Vector2(cpulse, cpulse)

    if game_title_label != null and is_instance_valid(game_title_label):
        var t: float = 1.0 + 0.018 * sin(ui_time * 2.0)
        game_title_label.scale = Vector2(t, t)

    if winner_label != null and is_instance_valid(winner_label) and winner_label.text != "":
        var w: float = 1.0 + 0.04 * sin(ui_time * 3.0)
        winner_label.scale = Vector2(w, w)

static func animate_add_ball_buttons(paused: bool, add_ball_buttons: Dictionary, add_ball_button_base_positions: Dictionary, ui_time: float) -> void:
    # 暂停时停止游戏内 +球 按钮呼吸，避免暂停后游戏内 UI 仍像在运行。
    if paused:
        return

    for faction_id in add_ball_buttons.keys():
        var button: Button = add_ball_buttons[faction_id] as Button
        if button == null or not is_instance_valid(button):
            continue
        if not add_ball_button_base_positions.has(faction_id):
            continue

        var base_pos: Vector2 = add_ball_button_base_positions[faction_id]
        var phase: float = ui_time * 3.0 + float(faction_id) * 0.85
        var breath: float = sin(phase)
        var hover_bonus: float = 0.0

        if button.has_method("is_hovered") and button.is_hovered() and not button.disabled:
            hover_bonus = 0.055

        if button.disabled:
            button.position = base_pos
            button.scale = Vector2.ONE
        else:
            button.position = base_pos + Vector2(0.0, -2.0 + breath * 2.2)
            var s: float = 1.0 + breath * 0.028 + hover_bonus
            button.scale = Vector2(s, s)
