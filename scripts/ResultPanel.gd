extends CanvasLayer
class_name ResultPanel

signal replay_requested
signal return_menu_requested

@onready var title_label: Label = get_node("Panel/MainVBox/TitleLabel")
@onready var reason_label: Label = get_node("Panel/MainVBox/ReasonLabel")
@onready var duration_label: Label = get_node("Panel/MainVBox/DurationLabel")
@onready var occupation_label: Label = get_node("Panel/MainVBox/OccupationLabel")
@onready var stats_label: Label = get_node("Panel/MainVBox/StatsLabel")
@onready var replay_button: Button = get_node("Panel/MainVBox/ButtonRow/ReplayButton")
@onready var return_menu_button: Button = get_node("Panel/MainVBox/ButtonRow/ReturnMenuButton")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	replay_button.pressed.connect(func(): replay_requested.emit())
	return_menu_button.pressed.connect(func(): return_menu_requested.emit())
	hide()


func show_result(result: Dictionary) -> void:
	var winner_name: String = str(result.get("winner_name", "未知阵营"))
	title_label.text = "%s胜利！" % winner_name
	title_label.add_theme_color_override("font_color", result.get("winner_color", Color(1.0, 0.95, 0.72)))

	var reason_text: String = str(result.get("reason_text", "达成胜利条件"))
	reason_label.text = reason_text

	var duration: float = float(result.get("duration_seconds", 0.0))
	duration_label.text = "游戏时长：%s" % _format_time(duration)

	occupation_label.text = _build_occupation_text(result.get("occupation_rates", {}))

	var peak_bullets: int = int(result.get("peak_active_bullets", 0))
	var event_count: int = int(result.get("event_count", 0))
	stats_label.text = "最高活跃子弹：%d | 触发事件：%d 次" % [peak_bullets, event_count]

	show()


func hide_panel() -> void:
	hide()


func _format_time(seconds: float) -> String:
	var total: int = int(maxf(0.0, seconds))
	var m: int = total / 60
	var s: int = total % 60
	return "%02d:%02d" % [m, s]


func _build_occupation_text(rates: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("最终占领率：")

	var sorted: Array = []
	for faction_id in rates.keys():
		sorted.append({"id": int(faction_id), "rate": float(rates[faction_id])})
	sorted.sort_custom(func(a, b): return a["rate"] > b["rate"])

	var parts: PackedStringArray = []
	for entry in sorted:
		var fid: int = entry["id"]
		var percent: int = int(round(entry["rate"] * 100.0))
		parts.append("%s %d%%" % [GameConfig.faction_name(fid), percent])

	lines.append(" | ".join(parts))
	return "\n".join(lines)
