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


static func _top_rule(bg: Color, line: Color, width: int, pad_h: float, pad_v: float) -> StyleBoxFlat:
	# 只有上缘一条线的面板：通栏状态条用。四边都描边会读成"又一张卡片"。
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.border_width_top = width
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
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


static func _register_icon_colors(theme: Theme, type_name: String,
		normal: Color, hover: Color, pressed: Color, disabled: Color, max_width: int) -> void:
	# 图标颜色要跟着文字状态一起走，否则悬停时"字亮图不亮"。
	theme.set_color("icon_normal_color", type_name, normal)
	theme.set_color("icon_hover_color", type_name, hover)
	theme.set_color("icon_pressed_color", type_name, pressed)
	theme.set_color("icon_focus_color", type_name, hover)
	theme.set_color("icon_disabled_color", type_name, disabled)
	theme.set_constant("icon_max_width", type_name, max_width)
	theme.set_constant("h_separation", type_name, 12)


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
	# 金底上的图标压深色，否则白图标在金色上糊成一片。
	_register_icon_colors(theme, "PrimaryButton", GOLD_TEXT, GOLD_TEXT, Color("#0d0a04"), Color("#7a6f57"), 20)

	# 主导航条：全宽深蓝钢条。常态暗、悬停亮、选中（toggle）整圈金边 ——
	# 靠 ButtonGroup 保证同时只有一项被选中。
	# 圆角收到 4：比次级按钮的 6 更方，读作"机台按键"而不是网页按钮。
	_register_button_variant(theme, "NavButton",
		_padded(PLATE_HI, EDGE, 1, 16.0, 12.0, 4),
		_padded(BLUE, EDGE_HI, 1, 16.0, 12.0, 4),
		_padded(BLUE_LO, GOLD, 2, 16.0, 12.0, 4),
		_padded(PLATE_LO, EDGE_LO, 1, 16.0, 12.0, 4),
		CYAN,
		TEXT, Color("#ffffff"), GOLD_HI, TEXT_FAINT,
		17)
	_register_icon_colors(theme, "NavButton", TEXT_DIM, Color("#ffffff"), GOLD_HI, TEXT_FAINT, 20)

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

	# 模式卡片：比槽位大一号，选中态用金边 + 亮底。主菜单右侧改成 2×2 大卡，
	# 所以内边距给足，文字左对齐（居中会跟下方规则说明错开）。
	_register_button_variant(theme, "ModeCard",
		_padded(PLATE_HI, EDGE, 1, 16.0, 14.0, 4),
		_padded(BLUE, EDGE_HI, 1, 16.0, 14.0, 4),
		_padded(BLUE, GOLD, 2, 16.0, 14.0, 4),
		_padded(PLATE_LO, EDGE_LO, 1, 16.0, 14.0, 4),
		GOLD_HI,
		TEXT, TEXT, GOLD_HI, TEXT_FAINT,
		19)

	# 页面外板：右栏承载"选择玩法 / 对局设置 / 玩法说明 / 继续游戏"。
	# 内边距比普通 PanelContainer 大，页面才有"一整屏"的呼吸感。
	theme.set_type_variation("PagePanel", "PanelContainer")
	theme.set_stylebox("panel", "PagePanel", _padded(Color("#0d151d"), EDGE, 1, 22.0, 18.0, 8))

	# 摘要小卡：主菜单左下角三格（玩法 / 地图 / 画质）。
	theme.set_type_variation("CardPanel", "PanelContainer")
	theme.set_stylebox("panel", "CardPanel", _padded(PLATE_HI, EDGE, 1, 9.0, 8.0, 4))

	# 通栏状态条：只有上缘一条线，不四边描边。
	theme.set_type_variation("FooterPanel", "PanelContainer")
	theme.set_stylebox("panel", "FooterPanel", _top_rule(Color("#080f15"), EDGE, 1, 8.0, 3.0))

	# 预览台左下的"对战预览"浮标：压在机器下缘上，所以要半透明。
	theme.set_type_variation("ChipPanel", "PanelContainer")
	theme.set_stylebox("panel", "ChipPanel", _padded(Color(0.03, 0.06, 0.09, 0.82), Color(CYAN, 0.35), 1, 10.0, 7.0, 4))

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

	# 品牌锁形：中文主标走金属金字 + 深描边，拉丁副标拉开字距压在绶带下方。
	_register_label_variant(theme, "LogoWordLabel", Color("#ffe9a8"), 38, 9, Color("#04070b"))
	_register_label_variant(theme, "LogoLatinLabel", Color("#eef5fb"), 15, 4, Color("#04070b"))
	_register_label_variant(theme, "LogoKickerLabel", Color("#8fb4cf"), 10, 2, Color("#04070b"))

	# 左栏辅助文字
	_register_label_variant(theme, "TaglineLabel", Color("#d5e4f2"), 13)
	_register_label_variant(theme, "SummaryCaptionLabel", TEXT_FAINT, 10)
	_register_label_variant(theme, "SummaryValueLabel", TEXT, 13)

	# 右侧页面
	_register_label_variant(theme, "PageHeadLabel", Color("#e8f2fb"), 22, 4, Color("#05080c"))
	_register_label_variant(theme, "FieldCaptionLabel", TEXT_DIM, 14)
	_register_label_variant(theme, "HelpHeadLabel", GOLD, 15)
	_register_label_variant(theme, "HelpBodyLabel", TEXT_DIM, 14)

	# 预览台浮标
	_register_label_variant(theme, "ChipTitleLabel", GOLD, 11)
	_register_label_variant(theme, "ChipDescLabel", Color("#a9c2d6"), 11)
	_register_label_variant(theme, "ChipTagLabel", Color("#7fa8c4"), 10)

	# 通栏状态条
	_register_label_variant(theme, "FooterLabel", Color("#8ea7bc"), 12)
	_register_label_variant(theme, "FooterStrongLabel", Color("#c8dced"), 12)

	return theme
