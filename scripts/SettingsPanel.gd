extends Panel
class_name SettingsPanelController

@onready var content_label: Label = get_node("ContentLabel")

func show_content(quality_name: String, layout_name: String) -> void:
	content_label.text = "画质：%s\n布局：%s\n说明：手机使用大按钮布局，电脑保留更多 HUD 信息。" % [quality_name, layout_name]
	visible = true

func hide_panel() -> void:
	visible = false
