extends Area2D
class_name Gate

signal gate_entered(gate_type)

var gate_type = "RELEASE_R"
var label_text = "发射"
var gate_size = Vector2(44, 26)

func setup(t: String, label: String, s: Vector2 = Vector2(44, 26)) -> void:
    gate_type = t
    label_text = label
    gate_size = s

func _ready() -> void:
    var shape = RectangleShape2D.new()
    shape.size = gate_size
    var cs = CollisionShape2D.new()
    cs.shape = shape
    add_child(cs)
    area_entered.connect(_on_area_entered)
    z_index = 10
    queue_redraw()

func _on_area_entered(area) -> void:
    if area is ControlBall:
        gate_entered.emit(gate_type)

func _draw() -> void:
    var fill = Color(0.93, 0.93, 0.93)
    if gate_type == "MULTIPLY_X2":
        fill = Color(0.76, 1.0, 0.18)
    elif gate_type == "RELEASE_R":
        fill = Color(1.00, 0.57, 0.02)

    var half_gate = gate_size * 0.5
    draw_rect(Rect2(-half_gate, gate_size), fill, true)
    draw_rect(Rect2(-half_gate + Vector2(0, 2), gate_size - Vector2(0, 2)), fill.lightened(0.18), true)
    draw_rect(Rect2(-half_gate, gate_size), Color.BLACK, false, 2)

    var font = ThemeDB.fallback_font
    var font_size = 17
    var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    draw_string(font, -text_size * 0.5 + Vector2(0, 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
