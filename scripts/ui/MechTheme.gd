extends RefCounted

# 主菜单视觉主题：只用 StyleBoxFlat + 颜色/字号覆盖。
# 不含 Shader，不引用任何贴图。切角、螺栓、能源灯由 MechShell.gd / MechStage.gd
# 用 draw_* 画出来，因为 StyleBoxFlat 只有圆角，做不出机械外壳的直角切削。
#
# 为什么集中在代码里而不是一个 .tres：
# 这套描边宽度、圆角、熔边色必须和 MechShell 画的切角轮廓逐像素对齐，
# 分成两份资源以后必然漂移。集中一处，改轮廓时顺手就能改配套描边。
#
# 纯展示层。这里任何数值都不得反馈到伤害、位移、碰撞、倍率、胜负或经济。

# ---------------------------------------------------------------- 调色板
# 深蓝钢 = 外壳底色；钢边 = 描边；金 = 主操作；青 = 能源灯/监控色。
const BG_DEEP := Color("#0a1118")
const PLATE := Color("#101a24")
const PLATE_HI := Color("#16232f")
const PLATE_LO := Color("#0b131b")
const EDGE := Color("#2a3e51")
const EDGE_HI := Color("#3e5b76")
const EDGE_LO := Color("#1b2b3a")

const GOLD := Color("#e8b63c")
const GOLD_HI := Color("#f6ce72")
const GOLD_LO := Color("#a87f22")
const GOLD_TEXT := Color("#1a1206")

const BLUE := Color("#274c6e")
const BLUE_HI := Color("#356389")
const BLUE_LO := Color("#1a3348")

const CYAN := Color("#4fd6e8")
const TEXT := Color("#e6eff8")
const TEXT_DIM := Color("#94aabe")
const TEXT_FAINT := Color("#6b7f92")
const AMBER := Color("#f4c98a")

# 四阵营色：和 PreviewScene / 战场渲染保持一致，菜单里只做指引不参与判定。
const FACTION_RED := Color(0.85, 0.18, 0.18)
const FACTION_YELLOW := Color(0.95, 0.85, 0.16)
const FACTION_GREEN := Color(0.20, 0.88, 0.26)
const FACTION_BLUE := Color(0.22, 0.54, 0.96)

const RADIUS := 6

# 字号不动，全部走 theme 覆盖，避免每个节点写一遍 theme_override_font_sizes。


static func _flat(bg: Color, border: Color, border_width: int, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


static func _padded(bg: Color, border: Color, border_width: int, pad_h: float, pad_v: float, radius: int = RADIUS) -> StyleBoxFlat:
	var sb := _flat(bg, border, border_width, radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func _focus_ring(color: Color) -> StyleBoxFlat:
	# 透明底 + 1px 描边 = 焦点环。不用自发光/Shader。
	var sb := _flat(Color(0, 0, 0, 0), color, 1, RADIUS)
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 0.0
	return sb


static func _register_button_variant(theme: Theme, type_name: String,
		normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat,
		disabled: StyleBoxFlat, focus: Color,
		font_color: Color, font_hover: Color, font_pressed: Color, font_disabled: Color,
		font_size: int) -> void:
	theme.set_type_variation(type_name, "Button")
	theme.set_stylebox("normal", type_name, normal)
	theme.set_stylebox("hover", type_name, hover)
	theme.set_stylebox("pressed", type_name, pressed)
	theme.set_stylebox("disabled", type_name, disabled)
	theme.set_stylebox("focus", type_name, _focus_ring(focus))
	theme.set_color("font_color", type_name, font_color)
	theme.set_color("font_hover_color", type_name, font_hover)
	theme.set_color("font_pressed_color", type_name, font_pressed)
	theme.set_color("font_focus_color", type_name, font_hover)
	theme.set_color("font_disabled_color", type_name, font_disabled)
	theme.set_font_size("font_size", type_name, font_size)


static func _register_label_variant(theme: Theme, type_name: String, color: Color, font_size: int,
		outline_size: int = 0, outline_color: Color = Color(0, 0, 0, 0)) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_color("font_color", type_name, color)
	theme.set_font_size("font_size", type_name, font_size)
	theme.set_constant("outline_size", type_name, outline_size)
	if outline_size > 0:
		theme.set_color("font_outline_color", type_name, outline_color)


static func build() -> Theme:
	var theme := Theme.new()

	# ------------------------------------------------------------ 基础控件
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font_size("font_size", "Label", 15)
	theme.set_stylebox("panel", "Panel", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", _padded(PLATE, EDGE, 1, 12.0, 10.0))

	# 主操作：金色。文字压深色，才有"金属铭牌"的重量感，而不是黄底白字。
	_register_button_variant(theme, "PrimaryButton",
		_padded(GOLD_LO, GOLD_HI, 1, 18.0, 12.0),
		_padded(GOLD, GOLD_HI, 2, 18.0, 12.0),
		_padded(GOLD_HI, Color("#fff2cd"), 2, 18.0, 12.0),
		_padded(Color("#2a2418"), Color("#3d3626"), 1, 18.0, 12.0),
		GOLD_HI,
		GOLD_TEXT, GOLD_TEXT, Color("#0d0a04"), Color("#7a6f57"),
		18)

	# 次级操作：深蓝钢。
	_register_button_variant(theme, "SecondaryButton",
		_padded(PLATE_HI, EDGE, 1, 16.0, 10.0),
		_padded(BLUE, EDGE_HI, 1, 16.0, 10.0),
		_padded(BLUE_LO, GOLD, 1, 16.0, 10.0),
		_padded(PLATE_LO, EDGE_LO, 1, 16.0, 10.0),
		CYAN,
		TEXT, TEXT, GOLD, TEXT_FAINT,
		16)

	# 返回/翻页用的小号次级按钮。
	_register_button_variant(theme, "GhostButton",
		_padded(Color(0, 0, 0, 0), EDGE, 1, 12.0, 8.0),
		_padded(PLATE_HI, EDGE_HI, 1, 12.0, 8.0),
		_padded(BLUE_LO, GOLD, 1, 12.0, 8.0),
		_padded(Color(0, 0, 0, 0), EDGE_LO, 1, 12.0, 8.0),
		CYAN,
		TEXT_DIM, TEXT, GOLD, TEXT_FAINT,
		14)

	# 存档槽：常态暗、选中金框。选中态靠 toggle + ButtonGroup，不靠 modulate。
	_register_button_variant(theme, "SlotButton",
		_padded(PLATE_HI, EDGE, 1, 10.0, 9.0),
		_padded(BLUE, EDGE_HI, 1, 10.0, 9.0),
		_padded(BLUE_LO, GOLD, 2, 10.0, 9.0),
		_padded(PLATE_LO, EDGE_LO, 1, 10.0, 9.0),
		CYAN,
		TEXT, TEXT, GOLD, TEXT_FAINT,
		14)

	# 模式卡片：比槽位大一号，选中态用金色左边条 + 亮底。
	_register_button_variant(theme, "ModeCard",
		_padded(PLATE_HI, EDGE, 1, 14.0, 11.0),
		_padded(BLUE, EDGE_HI, 1, 14.0, 11.0),
		_padded(BLUE, GOLD, 2, 14.0, 11.0),
		_padded(PLATE_LO, EDGE_LO, 1, 14.0, 11.0),
		GOLD_HI,
		TEXT, TEXT, GOLD, TEXT_FAINT,
		17)

	# ------------------------------------------------------------ OptionButton
	# OptionButton 是 Button 的子类，但主题里必须单独注册，不会继承变体。
	theme.set_stylebox("normal", "OptionButton", _padded(PLATE_HI, EDGE, 1, 12.0, 6.0))
	theme.set_stylebox("hover", "OptionButton", _padded(BLUE, EDGE_HI, 1, 12.0, 6.0))
	theme.set_stylebox("pressed", "OptionButton", _padded(BLUE_LO, GOLD, 1, 12.0, 6.0))
	theme.set_stylebox("disabled", "OptionButton", _padded(PLATE_LO, EDGE_LO, 1, 12.0, 6.0))
	theme.set_stylebox("focus", "OptionButton", _focus_ring(CYAN))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	theme.set_color("font_pressed_color", "OptionButton", GOLD)
	theme.set_color("font_disabled_color", "OptionButton", TEXT_FAINT)
	theme.set_font_size("font_size", "OptionButton", 15)

	# ------------------------------------------------------------ SpinBox / LineEdit
	theme.set_stylebox("normal", "LineEdit", _padded(PLATE_LO, EDGE, 1, 8.0, 5.0))
	theme.set_stylebox("focus", "LineEdit", _padded(PLATE_LO, CYAN, 1, 8.0, 5.0))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", CYAN)
	theme.set_color("selection_color", "LineEdit", BLUE)
	theme.set_font_size("font_size", "LineEdit", 15)

	# ------------------------------------------------------------ Label 变体
	_register_label_variant(theme, "TitleLabel", Color("#fdf0c4"), 44, 8, Color("#05080c"))
	_register_label_variant(theme, "SubtitleLabel", TEXT_DIM, 17)
	_register_label_variant(theme, "HintLabel", TEXT_FAINT, 13)
	_register_label_variant(theme, "StatusLabel", Color("#f4c98a"), 14, 3, Color("#0a0f14"))
	_register_label_variant(theme, "PageTitleLabel", TEXT, 24, 4, Color("#05080c"))
	_register_label_variant(theme, "SectionLabel", TEXT_FAINT, 12)
	_register_label_variant(theme, "ValueLabel", TEXT, 15)
	_register_label_variant(theme, "StageCaptionLabel", TEXT_DIM, 13)
	_register_label_variant(theme, "ModeTipLabel", TEXT_DIM, 13)

	return theme
