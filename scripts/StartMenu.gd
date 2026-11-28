extends CanvasLayer
class_name StartMenu

# 主菜单：一台机械控制台的正面。
#
# 结构（对齐 M01-R02 主参考图）：
#   左栏（约 30%，常驻）= 品牌锁形 + 标语 + 五项主导航 + 当前配置摘要
#   右栏（约 70%）= 页面宿主。主菜单页是整台战场预览，其余页是各自的设置面板
#   底部通栏状态条 = 存档槽提示 / 平台说明 / 版本号
#
# 为什么导航常驻而不是把"继续游戏 / 设置 / 说明 / 退出"塞进某一页：
# 参考图的左栏是一排全宽导航条，占满整列高度；旧版左栏只有两个按钮，
# 下半部分必然空出一大块。导航常驻之后左栏是满的，右栏也只剩真正的战场。
#
# 展示层边界：这里只读 GameConfig / Main 的已选值，只调用它们的公开入口
# （_start_game / _continue_saved_game / _select_save_slot / _save_menu_preferences /
# _has_save_file / reset_menu_preferences）。不碰 Bullet、BulletPool、武器行为
# 或物理步规则，也不解释任何战斗数值。

const PreviewScene = preload("res://scenes/ui/PreviewScene.tscn")
const MechThemeScript = preload("res://scripts/ui/MechTheme.gd")

const PAGE_MAIN := "main"
const PAGE_MODE := "mode"
const PAGE_CONFIG := "config"
const PAGE_HELP := "help"
const PAGE_CONTINUE := "continue"

# 退出时的平台惯例：桌面直接退出；安卓/iOS 先确认，且**只有**在根页按返回键
# 才询问退出 —— 内页的返回键一律先回上一级（见 _handle_back）。
const MOBILE_PLATFORMS := ["Android", "iOS"]

# 地图显示名。MatchConfig 目前只有一张图，这里也就只有一条：
# 数据接口先留好，但不为还不存在的地图摆一排灰色按钮。
const MAP_DISPLAY_NAMES := {
	"classic_plains": "经典平原",
}

# 重建菜单时（例如"恢复默认"会重建整层）记住上一页，否则玩家点一下
# 恢复默认就被弹回主菜单。开新局时清空，所以打完一局回菜单仍然落在主页。
static var _remembered_page: String = PAGE_MAIN

@onready var shade: ColorRect = $Shade
@onready var root_panel: Panel = %RootPanel
@onready var columns: Control = %Columns
@onready var action_column: VBoxContainer = $RootPanel/Columns/ActionColumn

@onready var brand_title: Label = $RootPanel/Columns/ActionColumn/LogoBlock/BrandTitle
@onready var tagline_label: Label = $RootPanel/Columns/ActionColumn/TaglinePill/TaglineLabel
@onready var sub_tagline_label: Label = $RootPanel/Columns/ActionColumn/SubTagline

@onready var nav_start_button: Button = %NavStartButton
@onready var nav_continue_button: Button = %NavContinueButton
@onready var nav_config_button: Button = %NavConfigButton
@onready var nav_help_button: Button = %NavHelpButton
@onready var nav_quit_button: Button = %NavQuitButton

@onready var main_mode_value: Label = %MainModeValue
@onready var main_map_value: Label = %MainMapValue
@onready var main_quality_value: Label = %MainQualityValue

@onready var stage_column: Control = %StageColumn
@onready var page_host: Control = %PageHost
@onready var main_menu_page: Control = %MainMenuPage
@onready var mode_select_page: PanelContainer = %ModeSelectPage
@onready var match_config_page: PanelContainer = %MatchConfigPage
@onready var help_page: PanelContainer = %HelpPage
@onready var continue_page: PanelContainer = %ContinuePage

@onready var stage_chrome: Control = %StageChrome
@onready var stage_header_title: Label = %StageHeaderTitle
@onready var stage_header_sub: Label = %StageHeaderSub
@onready var preview_container: Control = %PreviewContainer
@onready var chamber_preview: Node2D = %ChamberPreview
@onready var preview_chip: PanelContainer = %PreviewChip
@onready var chip_tags: Label = %ChipTags

@onready var mode_card_host: VBoxContainer = %ModeCardHost
@onready var mode_page_hint: Label = %ModePageHint
@onready var mode_tip_label: Label = %ModeTipLabel
@onready var mode_detail_summary: Label = %ModeDetailSummary
@onready var mode_compare_label: Label = %ModeCompareLabel
@onready var mode_back_button: Button = %ModeBackButton
@onready var mode_next_button: Button = %ModeNextButton

@onready var match_summary_label: Label = %MatchSummaryLabel
@onready var config_mode_value: Label = %ConfigModeValue
@onready var config_map_value: Label = %ConfigMapValue
@onready var config_quality_value: Label = %ConfigQualityValue
@onready var config_slot_value: Label = %ConfigSlotValue
@onready var config_time_value: Label = %ConfigTimeValue
@onready var config_palette_value: Label = %ConfigPaletteValue
@onready var config_version_value: Label = %ConfigVersionValue
@onready var config_platform_value: Label = %ConfigPlatformValue
@onready var config_rule_label: Label = %ConfigRuleLabel
@onready var size_option: OptionButton = %GridSizeOption
@onready var quality_option: OptionButton = %QualityOption
@onready var time_spin: SpinBox = %TimeSpin
@onready var palette_option: OptionButton = %PaletteOption
@onready var reset_button: Button = %ResetDefaultsButton
@onready var config_back_button: Button = %ConfigBackButton
@onready var start_match_button: Button = %StartMatchButton

@onready var help_back_button: Button = %HelpBackButton
@onready var help_start_button: Button = %HelpStartButton

@onready var save_title: Label = %SaveTitle
@onready var slot_detail_label: Label = %SlotDetailLabel
@onready var slot_grid: GridContainer = %SlotGrid
@onready var continue_back_button: Button = %ContinueBackButton
@onready var continue_button: Button = %ContinueButton

@onready var footer_bar: PanelContainer = %FooterBar
@onready var menu_status_label: Label = %MenuStatusLabel
@onready var mobile_hint_label: Label = %MobileHint
@onready var version_label: Label = %VersionLabel

@onready var quit_dialog: ConfirmationDialog = %QuitDialog
@onready var overwrite_dialog: ConfirmationDialog = %OverwriteDialog

var _owner
var _menu_layout: Dictionary = {}
var _current_page: String = PAGE_MAIN
var _page_nodes: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _mode_cards: Dictionary = {}
var _view_size: Vector2 = Vector2(1120.0, 720.0)
var _fitting: bool = false
# 程序化同步选中态时会触发 toggled，用它挡掉回写，免得每次 setup 都落一次偏好。
var _syncing: bool = false


# ------------------------------------------------------------------ 静态文案
# 这些 helper 被 SaveFlowController 直接 preload 调用（写成 StartMenuUi），
# 属于对外契约：改文案可以，改签名会连存档流一起断。

static func compact_slot_title(title_text: String) -> String:
	var compact_text: String = title_text
	compact_text = compact_text.replace("基础模式", "基础")
	compact_text = compact_text.replace("占领模式", "占领")
	compact_text = compact_text.replace("限时模式", "限时")
	compact_text = compact_text.replace("狂野模式", "狂野")
	compact_text = compact_text.replace(GameConfig.GAME_MODE_BASIC, "基础")
	compact_text = compact_text.replace(GameConfig.GAME_MODE_OCCUPATION, "占领")
	compact_text = compact_text.replace(GameConfig.GAME_MODE_TIMED, "限时")
	compact_text = compact_text.replace(GameConfig.GAME_MODE_WILD, "狂野")
	return compact_text


static func build_slot_label(slot: int, summary: Dictionary, selected_save_slot: int = -1) -> String:
	var marker: String = "● " if slot == selected_save_slot else ""
	var state: String = str(summary.get("state", "empty"))
	if state == "empty":
		return "%s槽%d｜空" % [marker, slot]
	if state == "incompatible":
		return "%s槽%d｜不兼容" % [marker, slot]
	if state == "damaged":
		return "%s槽%d｜损坏" % [marker, slot]
	var title_text: String = compact_slot_title(str(summary.get("title", "")))
	if title_text == "":
		return "%s槽%d｜空" % [marker, slot]
	return "%s槽%d｜%s" % [marker, slot, title_text]


static func build_start_button_text(slot: int) -> String:
	return "新局覆盖槽%d" % slot


static func build_continue_button_text(slot: int) -> String:
	return "读取槽%d" % slot


static func build_status_text(slot: int) -> String:
	return "当前存档槽：%d" % slot


static func build_start_button_label(_slot: int, _has_save_data: bool = false) -> String:
	return "开始新游戏"


static func build_status_label(slot: int, has_save_data: bool) -> String:
	if has_save_data:
		return "已选择存档槽 %d，新游戏会覆盖这里的存档" % slot
	return "已选择空存档槽 %d，新游戏会保存在这里" % slot


static func build_mode_tip_text(mode_name: String, time_limit_minutes: int) -> String:
	match mode_name:
		GameConfig.GAME_MODE_BASIC:
			return "基础：消灭所有对手炮台即可获胜"
		GameConfig.GAME_MODE_OCCUPATION:
			return "占领：达到 75% 领土即可获胜"
		GameConfig.GAME_MODE_TIMED:
			return "限时：%d 分钟倒计时结束后，领地最多方获胜" % time_limit_minutes
		GameConfig.GAME_MODE_WILD:
			return "狂野：全局 x3 倍率，单次上限更高，事件更频繁"
		_:
			return ""


static func build_mode_rule_text(mode_name: String) -> String:
	# 模式卡片上的第二行：一句话说清胜负条件，不重复玩法名。
	match mode_name:
		GameConfig.GAME_MODE_BASIC:
			return "消灭所有对手炮台"
		GameConfig.GAME_MODE_OCCUPATION:
			return "领土达到 75% 即胜"
		GameConfig.GAME_MODE_TIMED:
			return "时间到，领土最多者胜"
		GameConfig.GAME_MODE_WILD:
			return "全局 x3 倍率，事件更频繁"
		_:
			return ""


# ------------------------------------------------------------------ 对外入口

func get_parts() -> Dictionary:
	return {
		"menu_layer": self,
		"menu_title_label": brand_title,
		"menu_start_button": nav_start_button,
		"menu_continue_button": continue_button,
		"menu_save_slot_buttons": _slot_buttons.duplicate(),
		"menu_status_label": menu_status_label,
	}


func setup(p_owner, view_size: Vector2, save_summaries: Array, current_layout: Dictionary = {}) -> void:
	_owner = p_owner
	_owner.selected_save_slot = clampi(int(_owner.selected_save_slot), 1, int(_owner.SAVE_SLOT_COUNT))
	_owner.selected_grid_size = LayoutProfiles.sanitize_grid_size(int(_owner.selected_grid_size))
	_menu_layout = current_layout.get("start_menu_layout", {})

	# 主题必须早于布局：容器的尺寸是按字号算出来的，先布局再换主题会差一档。
	# 挂在 RootPanel 上而不是自己身上 —— CanvasLayer 不是 Control，没有 theme；
	# 挂在面板根节点后，所有 Control 后代都会继承。
	root_panel.theme = MechThemeScript.build()
	# 退出确认框与覆盖存档确认框都是 Window，不是 Control 后代，
	# 不会继承 RootPanel 的主题，得单独挂。
	quit_dialog.theme = root_panel.theme
	overwrite_dialog.theme = root_panel.theme

	_view_size = view_size
	_apply_layout(view_size)
	if not page_host.resized.is_connected(_fit_pages):
		page_host.resized.connect(_fit_pages)
	_bind_pages()
	_init_options()
	_init_slot_buttons()
	_init_mode_cards()
	_init_nav_group()
	_init_decor()
	_sync_options_from_owner()
	refresh_slots(save_summaries)
	menu_status_label.text = StartMenu.build_status_text(_owner.selected_save_slot)
	_refresh_menu_status_label(_owner._has_save_file(_owner.selected_save_slot))
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	config_version_value.text = version_label.text
	config_platform_value.text = "安卓 / iOS" if _is_mobile_platform() else "桌面"
	_connect_signals()
	show_page(_remembered_page)
	# setup 跑在"刚 add_child、还没排过版"的那一帧：自动换行标签此刻宽度是 0，
	# 它们的最小高度会被算成"一行一个字"，把整列撑到上千像素，而 set_size 一旦
	# 被这个假的最小值夹住就不会自己缩回来。所以下一帧再按真实宽度重排一次。
	call_deferred("_settle_layout")


func refresh_slots(save_summaries: Array) -> void:
	_refresh_slots(save_summaries)


func current_page() -> String:
	return _current_page


func show_page(page_key: String) -> void:
	var target: String = page_key if _page_nodes.has(page_key) else PAGE_MAIN
	_current_page = target
	_remembered_page = target
	_fit_pages()
	for key in _page_nodes:
		var node: Control = _page_nodes[key]
		if is_instance_valid(node):
			node.visible = key == target
	_on_page_shown(target)
	_sync_nav_state(target)
	_fit_pages()
	# 刚显示的页面在这一帧里还没排过版（子节点宽度为 0），下一帧再铺一次。
	call_deferred("_refit_pages_next_frame")


func _refit_pages_next_frame() -> void:
	await get_tree().process_frame
	_fit_pages()


# 页面自己不挂锚点，尺寸完全由 PageHost 决定。原因：隐藏的 Control 不会被
# 父节点重排，用锚点的话它会把"上一次可见时"的尺寸一直留着，切回来就错位。
# 显式铺一遍，任何时刻打开都是对的。
#
# 还要接住 resized：页面是容器，它的最小尺寸取决于子节点，而子节点又取决于
# 宽度。隐藏期间子节点宽度是 0，自动换行标签的最小高度会被算成一行一个字，
# 页面最小高度能飙到上千；一旦 set_size 被这个假值夹住就不会自己缩回来。
# 等子节点排完版、最小尺寸回落，resized 会再进来一次，这次就能压回目标值。
func _fit_pages() -> void:
	if _fitting or not is_instance_valid(page_host):
		return
	var target: Vector2 = page_host.size
	if target.x <= 0.0 or target.y <= 0.0:
		return
	_fitting = true
	for key in _page_nodes:
		var node: Control = _page_nodes[key]
		if not is_instance_valid(node):
			continue
		node.position = Vector2.ZERO
		node.size = target
	_fitting = false


# 自动换行标签的最小高度取决于"当前宽度"，而宽度要等容器排完版才知道。
# 首帧里宽度还是 0，最小高度会被算成一行一个字，把整列撑爆；撑爆之后
# set_size 被夹住，就算最小高度后来恢复正常，尺寸也不会自己缩回来。
# 这里先按已知的列宽把宽度定死，再在下一帧补一次完整重排。
func _fix_wrapped_label_widths(width: float) -> void:
	for label in _left_wrapped_labels():
		if label == null or not is_instance_valid(label):
			continue
		label.custom_minimum_size = Vector2(width, label.custom_minimum_size.y)
		label.size = Vector2(width, maxf(label.size.y, label.custom_minimum_size.y))


func _left_wrapped_labels() -> Array:
	# 只列左栏这层"永远可见"的换行标签。右栏页面里的换行标签由 _fit_pages
	# 的 resized 回路收敛，不能在这里按左栏宽度去钉 —— 那会把它们压扁。
	return [
		sub_tagline_label,
	]


func _settle_layout() -> void:
	# 等一帧让容器按真实宽度重算一次最小尺寸，再把显式矩形重新压回去。
	await get_tree().process_frame
	_apply_layout(_view_size)
	_fit_pages()


# ------------------------------------------------------------------ 布局

func _apply_layout(view_size: Vector2) -> void:
	var layout: Dictionary = _menu_layout
	if layout.is_empty():
		layout = LayoutCoordinator.calculate_layout(40, view_size, false).get("start_menu_layout", {})

	# 遮罩永远是整屏：它盖的是真实视口，不是设计画布。
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0117647, 0.0215686, 0.0333333, 0.92)

	var panel_size := view_size - Vector2(52.0, 52.0)
	var panel_rect: Rect2 = layout.get("root_panel_rect", Rect2(Vector2(26.0, 26.0), panel_size))
	root_panel.position = panel_rect.position
	root_panel.size = panel_rect.size

	var pad := float(layout.get("panel_pad", 16.0))
	var columns_rect: Rect2 = layout.get(
		"columns_rect",
		Rect2(Vector2(pad, pad), panel_rect.size - Vector2(pad * 2.0, pad * 2.0))
	)
	columns.position = columns_rect.position
	columns.size = columns_rect.size

	# 两栏都按布局给的矩形摆，不用 HBox 协商：容器会按子节点最小宽重新分配，
	# 一旦某个按钮文字变长，预览台就会被挤窄，而预览的缩放是按布局算的，
	# 两者不同步就会露出重叠。显式矩形没有这个自由度。
	var action_rect: Rect2 = layout.get(
		"action_column_rect",
		Rect2(Vector2.ZERO, Vector2(columns_rect.size.x * 0.30, columns_rect.size.y))
	)
	# 先钉标签宽度，再定列尺寸 —— 顺序反了就会被那张假的最小尺寸夹住。
	_fix_wrapped_label_widths(action_rect.size.x)
	action_column.position = action_rect.position
	action_column.size = action_rect.size

	var gap: float = float(layout.get("column_gap", 16.0))
	var stage_rect: Rect2 = layout.get(
		"stage_rect",
		Rect2(
			Vector2(action_rect.size.x + gap, 0.0),
			Vector2(columns_rect.size.x - action_rect.size.x - gap, columns_rect.size.y)
		)
	)
	stage_column.position = stage_rect.position
	stage_column.size = stage_rect.size

	var footer_height: float = float(layout.get("footer_height", 26.0))
	var footer_rect: Rect2 = layout.get(
		"footer_rect",
		Rect2(
			Vector2(pad, pad + columns_rect.size.y + 8.0),
			Vector2(columns_rect.size.x, footer_height)
		)
	)
	footer_bar.position = footer_rect.position
	footer_bar.size = footer_rect.size

	var header_height: float = float(layout.get("preview_header_height", 34.0))
	var stage_footer: float = float(layout.get("preview_footer_height", 12.0))
	var side_pad: float = float(layout.get("preview_side_pad", 10.0))
	var preview_size: Vector2 = layout.get(
		"preview_size",
		Vector2(
			maxf(80.0, stage_rect.size.x - side_pad * 2.0),
			maxf(60.0, stage_rect.size.y - header_height - stage_footer)
		)
	)

	stage_chrome.set("header_height", header_height)
	stage_chrome.set("footer_height", stage_footer)
	stage_chrome.set("side_pad", side_pad)
	if stage_chrome.has_method("queue_redraw"):
		stage_chrome.queue_redraw()

	# 表头：标题贴左，副标跟在后面。右侧留给 MechStage 画的档位刻度。
	stage_header_title.position = Vector2(side_pad + 4.0, 0.0)
	stage_header_title.size = Vector2(146.0, header_height - 3.0)
	var sub_x: float = side_pad + 4.0 + 150.0
	stage_header_sub.position = Vector2(sub_x, 0.0)
	stage_header_sub.size = Vector2(
		maxf(60.0, stage_rect.size.x - sub_x - side_pad - 56.0),
		header_height - 3.0
	)

	preview_container.position = Vector2(side_pad, header_height)
	preview_container.size = preview_size
	preview_container.clip_contents = true

	chamber_preview.scale = layout.get("preview_scale", Vector2(0.96, 0.96))
	chamber_preview.position = layout.get("preview_center", preview_size * 0.5)

	# 浮标压在机器左下角，和参考图一致：不占布局，只盖在预览台上。
	var chip_size := Vector2(206.0, preview_chip.get_combined_minimum_size().y)
	preview_chip.size = chip_size
	preview_chip.position = Vector2(
		side_pad + 16.0,
		header_height + preview_size.y - chip_size.y - 10.0
	)


# ------------------------------------------------------------------ 构建

func _bind_pages() -> void:
	_page_nodes.clear()
	_page_nodes[PAGE_MAIN] = main_menu_page
	_page_nodes[PAGE_MODE] = mode_select_page
	_page_nodes[PAGE_CONFIG] = match_config_page
	_page_nodes[PAGE_HELP] = help_page
	_page_nodes[PAGE_CONTINUE] = continue_page
	for key in _page_nodes:
		var node: Control = _page_nodes[key]
		if not node.resized.is_connected(_fit_pages):
			node.resized.connect(_fit_pages)


func _init_options() -> void:
	if size_option.item_count == 0:
		for gs in [10, 20, 30, 40, 50, 60]:
			size_option.add_item("%d × %d" % [gs, gs], gs)

	if quality_option.item_count == 0:
		for quality_name in GameConfig.get_quality_names():
			quality_option.add_item(quality_name)

	if palette_option.item_count == 0:
		palette_option.add_item("默认随机")
		for palette_name in GameConfig.get_palette_names():
			palette_option.add_item(palette_name)


func _init_slot_buttons() -> void:
	_clear_children(slot_grid)
	_slot_buttons.clear()
	# 槽位数量来自 Main 的 SAVE_SLOT_COUNT，不在场景里硬写五个按钮：
	# 存档槽数量是业务参数，UI 只跟随。
	var count: int = int(_owner.SAVE_SLOT_COUNT)
	var group := ButtonGroup.new()
	for i in range(count):
		var slot: int = i + 1
		var button := Button.new()
		button.name = "SlotButton_%d" % slot
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = &"SlotButton"
		button.custom_minimum_size = Vector2(0.0, 44.0)
		# clip_text 会让按钮不再把文字宽度算进最小宽度，于是单列 GridContainer
		# 会把列宽压到内边距那么宽（实测 20px）。必须显式 EXPAND_FILL 撑满整列。
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_grid.add_child(button)
		button.pressed.connect(Callable(self, "_on_slot_pressed").bind(slot))
		_slot_buttons[slot] = button


func _init_mode_cards() -> void:
	_clear_children(mode_card_host)
	_mode_cards.clear()
	# 四种玩法来自 GameConfig.get_game_mode_names()，不在场景里写死四个按钮：
	# 以后加玩法只改这一处数据源，UI 自动长出来。
	var group := ButtonGroup.new()
	var index: int = 0
	for mode_name in GameConfig.get_game_mode_names():
		var card := Button.new()
		card.name = "ModeCard_%d" % (index + 1)
		card.toggle_mode = true
		card.button_group = group
		card.theme_type_variation = &"ModeCard"
		card.custom_minimum_size = Vector2(0.0, 92.0)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = str(mode_name)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.clip_text = true
		card.tooltip_text = StartMenu.build_mode_tip_text(str(mode_name), int(_owner.selected_time_limit_minutes))

		# 卡片第二行：胜负条件。用子 Label 而不是把两行塞进 Button.text ——
		# Button 只有一种字号，而且 text 要留给玩法名做断言匹配。
		var rule := Label.new()
		rule.name = "Rule"
		rule.theme_type_variation = &"HintLabel"
		rule.text = StartMenu.build_mode_rule_text(str(mode_name))
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.clip_text = true
		rule.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		rule.offset_left = 17.0
		rule.offset_right = -16.0
		rule.offset_top = -32.0
		rule.offset_bottom = -13.0
		card.add_child(rule)

		mode_card_host.add_child(card)
		card.toggled.connect(Callable(self, "_on_mode_card_toggled").bind(str(mode_name)))
		# 悬停就先给规则提示，不用点了才知道这个玩法是什么。
		card.mouse_entered.connect(Callable(self, "_on_mode_card_hover").bind(str(mode_name), true))
		card.mouse_exited.connect(Callable(self, "_on_mode_card_hover").bind(str(mode_name), false))
		_mode_cards[str(mode_name)] = card
		index += 1


func _init_nav_group() -> void:
	# 三个可选中导航项共用一个 ButtonGroup：同一时刻只能有一项是"当前页"。
	# 开始游戏和退出游戏是动作，不是页，所以不进组、也不 toggle。
	var group := ButtonGroup.new()
	for button in [nav_continue_button, nav_config_button, nav_help_button]:
		button.button_group = group
		button.toggle_mode = true


func _init_decor() -> void:
	_clear_children(chamber_preview)
	var decor: Node2D = PreviewScene.instantiate()
	decor.position = Vector2.ZERO
	decor.scale = Vector2.ONE
	chamber_preview.add_child(decor)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		# 先摘再排队释放：queue_free 要到帧末才生效，只调它会让 get_child_count()
		# 在重建后翻倍。remove_child 立刻生效，free 仍然走延迟，两者都要。
		node.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------------ 状态同步

func _sync_options_from_owner() -> void:
	_syncing = true

	for i in range(size_option.item_count):
		if size_option.get_item_id(i) == _owner.selected_grid_size:
			size_option.select(i)
			break

	for i in range(quality_option.item_count):
		if quality_option.get_item_text(i) == _owner.selected_quality_name:
			quality_option.select(i)
			break

	time_spin.value = float(_owner.selected_time_limit_minutes)

	for i in range(palette_option.item_count):
		if palette_option.get_item_text(i) == _owner.selected_palette_name:
			palette_option.select(i)
			break

	for mode_name in _mode_cards:
		var card: Button = _mode_cards[mode_name]
		card.button_pressed = mode_name == str(_owner.selected_game_mode_name)

	_syncing = false

	_update_reset_button_state()
	_update_mode_tip()
	_refresh_match_summary()
	_refresh_stage_caption()
	_refresh_action_labels(_owner._has_save_file(_owner.selected_save_slot))


func _refresh_slots(save_summaries: Array) -> void:
	var selected_summary: Dictionary = {}
	var count: int = int(_owner.SAVE_SLOT_COUNT)

	# 程序化改 button_pressed 会不会连带触发 pressed 在不同 Godot 版本里不一致，
	# 一旦触发就会走 _select_save_slot → 再刷新 → 再赋值，形成回环。
	# 用 _syncing 把它挡在外面，行为就不依赖引擎内部的信号顺序了。
	_syncing = true
	for i in range(count):
		var slot: int = i + 1
		var button: Button = _slot_buttons.get(slot, null)
		if button == null:
			continue

		var summary: Dictionary = {
			"slot": slot,
			"state": "empty",
			"has_data": false,
			"is_playable": false,
			"title": "空存档",
			"detail": "点击选择此槽",
		}
		for item in save_summaries:
			if item is Dictionary and int(item.get("slot", 0)) == slot:
				summary = item
				break

		if slot == _owner.selected_save_slot:
			selected_summary = summary

		button.text = StartMenu.build_slot_label(slot, summary, _owner.selected_save_slot)
		button.tooltip_text = str(summary.get("detail", "点击选择此槽"))
		# 选中态走 toggle + ButtonGroup，由主题的 pressed 样式画金框。
		# 旧实现是给按钮叠 self_modulate，那会把描边和文字一起染色，
		# 选中槽和"危险存档槽"就分不出来了。
		button.button_pressed = slot == _owner.selected_save_slot

	_syncing = false

	_refresh_action_labels(bool(selected_summary.get("is_playable", false)))
	_refresh_menu_status_label(bool(selected_summary.get("has_data", false)))
	_refresh_slot_detail(selected_summary)
	# 槽位变了，设置页概要里的"存档槽"也要跟着变。
	_refresh_match_summary()


func _refresh_slot_detail(summary: Dictionary) -> void:
	var detail: String = str(summary.get("detail", "点击选择此槽"))
	slot_detail_label.text = "槽 %d · %s" % [int(_owner.selected_save_slot), detail]
	slot_detail_label.tooltip_text = detail


func _refresh_action_labels(has_selected_save: bool) -> void:
	continue_button.text = StartMenu.build_continue_button_text(_owner.selected_save_slot)
	continue_button.disabled = not has_selected_save
	# 主导航的"开始游戏"是常驻入口，不随槽位改文案；覆盖语义交给底部状态条
	# 和"继续游戏"页的槽位列表说明，避免一个按钮同时承担两件事。
	nav_start_button.tooltip_text = "选择玩法后开局（存档槽 %d）" % int(_owner.selected_save_slot)


func _refresh_menu_status_label(has_save_data: bool) -> void:
	menu_status_label.text = StartMenu.build_status_label(_owner.selected_save_slot, has_save_data)


func _update_mode_tip() -> void:
	mode_tip_label.text = StartMenu.build_mode_tip_text(
		str(_owner.selected_game_mode_name),
		int(_owner.selected_time_limit_minutes)
	)


func _refresh_match_summary() -> void:
	var grid: int = int(_owner.selected_grid_size)
	var map_name: String = str(MAP_DISPLAY_NAMES.get(MatchConfig.CLASSIC_MAP_ID, "经典"))
	var mode_label: String = _compact_mode_name(str(_owner.selected_game_mode_name))
	var quality_label: String = str(_owner.selected_quality_name)
	match_summary_label.text = "%s · %d × %d · %s · %s画质" % [
		map_name, grid, grid, mode_label, quality_label
	]
	# 左栏摘要是三张小卡，位置只够放短值；完整地图名留给设置页的概要面板。
	main_mode_value.text = mode_label
	main_map_value.text = "%d × %d" % [grid, grid]
	main_quality_value.text = quality_label

	# 设置页 / 选择玩法页的概要由同一份 owner 状态生成，避免两处各写一套数字。
	var full_map: String = "%s %d × %d" % [map_name, grid, grid]
	var slot: int = int(_owner.selected_save_slot)
	config_mode_value.text = str(_owner.selected_game_mode_name)
	config_map_value.text = full_map
	config_quality_value.text = "%s画质" % quality_label
	config_slot_value.text = "槽 %d" % slot
	config_time_value.text = "%d 分钟" % int(_owner.selected_time_limit_minutes)
	config_palette_value.text = str(_owner.selected_palette_name)
	config_rule_label.text = "%s\n地图：%s" % [
		StartMenu.build_mode_tip_text(
			str(_owner.selected_game_mode_name),
			int(_owner.selected_time_limit_minutes)
		),
		full_map
	]
	mode_detail_summary.text = "战场：%s\n画质：%s · 配色：%s\n存档槽：%d" % [
		full_map, quality_label, str(_owner.selected_palette_name), slot
	]
	# 玩法一览由 GameConfig 长出来，选中的那一行打箭头，不硬写四个名字。
	var compare_lines: PackedStringArray = PackedStringArray()
	for mode_name in GameConfig.get_game_mode_names():
		var marker: String = "▶ " if str(mode_name) == str(_owner.selected_game_mode_name) else "   "
		compare_lines.append(marker + str(mode_name))
	mode_compare_label.text = "\n".join(compare_lines)


func _refresh_stage_caption() -> void:
	var grid: int = int(_owner.selected_grid_size)
	chip_tags.text = "◆ 4 人对战   ◆ %d × %d" % [grid, grid]


func _is_default_config() -> bool:
	return int(_owner.selected_grid_size) == 40 \
		and str(_owner.selected_game_mode_name) == GameConfig.GAME_MODE_BASIC \
		and str(_owner.selected_quality_name) == GameConfig.QUALITY_MEDIUM \
		and str(_owner.selected_palette_name) == "默认随机" \
		and int(_owner.selected_time_limit_minutes) == GameConfig.DEFAULT_TIMED_MODE_MINUTES


func _update_reset_button_state() -> void:
	if _is_default_config():
		reset_button.text = "已是默认"
		reset_button.disabled = true
	else:
		reset_button.text = "恢复默认"
		reset_button.disabled = false


func _compact_mode_name(mode_name: String) -> String:
	return StartMenu.compact_slot_title(mode_name)


func _sync_nav_state(page_key: String) -> void:
	_syncing = true
	nav_continue_button.button_pressed = page_key == PAGE_CONTINUE
	nav_config_button.button_pressed = page_key == PAGE_CONFIG
	nav_help_button.button_pressed = page_key == PAGE_HELP
	_syncing = false


func _on_page_shown(page_key: String) -> void:
	match page_key:
		PAGE_CONFIG:
			# 从"选择玩法"进来时，摘要和"恢复默认"的可用态都要重算。
			_refresh_match_summary()
			_refresh_stage_caption()
			_update_reset_button_state()
			_update_mode_tip()
		PAGE_MODE:
			var grid: int = int(_owner.selected_grid_size)
			mode_page_hint.text = "四种玩法共用同一张 %d × %d 战场 —— 规则不同，胜负条件不同。" % [grid, grid]
			_update_mode_tip()
		PAGE_CONTINUE:
			_refresh_action_labels(_owner._has_save_file(_owner.selected_save_slot))
		_:
			pass


# ------------------------------------------------------------------ 信号

func _connect_signals() -> void:
	if not size_option.item_selected.is_connected(_on_size_option_selected):
		size_option.item_selected.connect(_on_size_option_selected)
	if not quality_option.item_selected.is_connected(_on_quality_option_selected):
		quality_option.item_selected.connect(_on_quality_option_selected)
	if not time_spin.value_changed.is_connected(_on_time_spin_changed):
		time_spin.value_changed.connect(_on_time_spin_changed)
	if not palette_option.item_selected.is_connected(_on_palette_option_selected):
		palette_option.item_selected.connect(_on_palette_option_selected)

	if not nav_start_button.pressed.is_connected(_on_nav_start_pressed):
		nav_start_button.pressed.connect(_on_nav_start_pressed)
	if not nav_continue_button.pressed.is_connected(_on_nav_continue_pressed):
		nav_continue_button.pressed.connect(_on_nav_continue_pressed)
	if not nav_config_button.pressed.is_connected(_on_nav_config_pressed):
		nav_config_button.pressed.connect(_on_nav_config_pressed)
	if not nav_help_button.pressed.is_connected(_on_nav_help_pressed):
		nav_help_button.pressed.connect(_on_nav_help_pressed)
	if not nav_quit_button.pressed.is_connected(_on_nav_quit_pressed):
		nav_quit_button.pressed.connect(_on_nav_quit_pressed)

	if not mode_back_button.pressed.is_connected(_on_mode_back_pressed):
		mode_back_button.pressed.connect(_on_mode_back_pressed)
	if not mode_next_button.pressed.is_connected(_on_mode_next_pressed):
		mode_next_button.pressed.connect(_on_mode_next_pressed)
	if not config_back_button.pressed.is_connected(_on_config_back_pressed):
		config_back_button.pressed.connect(_on_config_back_pressed)
	if not continue_back_button.pressed.is_connected(_on_continue_back_pressed):
		continue_back_button.pressed.connect(_on_continue_back_pressed)
	if not help_back_button.pressed.is_connected(_on_help_back_pressed):
		help_back_button.pressed.connect(_on_help_back_pressed)
	if not help_start_button.pressed.is_connected(_on_nav_start_pressed):
		help_start_button.pressed.connect(_on_nav_start_pressed)
	if not start_match_button.pressed.is_connected(_on_start_match_pressed):
		start_match_button.pressed.connect(_on_start_match_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if not continue_button.pressed.is_connected(Callable(_owner, "_continue_saved_game")):
		continue_button.pressed.connect(Callable(_owner, "_continue_saved_game"))

	if not quit_dialog.confirmed.is_connected(_on_quit_confirmed):
		quit_dialog.confirmed.connect(_on_quit_confirmed)
	if not overwrite_dialog.confirmed.is_connected(_on_overwrite_confirmed):
		overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)


# ------------------------------------------------------------------ 页面导航

func _on_nav_start_pressed() -> void:
	show_page(PAGE_MODE)


func _on_nav_continue_pressed() -> void:
	show_page(PAGE_CONTINUE)


func _on_nav_config_pressed() -> void:
	show_page(PAGE_CONFIG)


func _on_nav_help_pressed() -> void:
	show_page(PAGE_HELP)


func _on_mode_back_pressed() -> void:
	show_page(PAGE_MAIN)


func _on_mode_next_pressed() -> void:
	show_page(PAGE_CONFIG)


func _on_config_back_pressed() -> void:
	show_page(PAGE_MODE)


func _on_continue_back_pressed() -> void:
	show_page(PAGE_MAIN)


func _on_help_back_pressed() -> void:
	show_page(PAGE_MAIN)


func _on_start_match_pressed() -> void:
	# Main._start_game(clear_save=true) 会删掉当前槽的存档、备份与临时文件。
	# 底部状态栏那行小字不足以构成确认，所以槽里已有存档时必须再确认一次；
	# 空槽不打扰玩家，仍按原来的路径直接开局。
	if _owner != null and _owner.has_method("_has_save_file") \
			and bool(_owner._has_save_file(int(_owner.selected_save_slot))):
		var slot: int = int(_owner.selected_save_slot)
		overwrite_dialog.dialog_text = "槽 %d 已有存档。开始新对局会删除该存档、备份与临时文件，且无法恢复。" % slot
		overwrite_dialog.popup_centered()
		return
	_begin_new_match()


func _on_overwrite_confirmed() -> void:
	_begin_new_match()


func _begin_new_match() -> void:
	# 真正开局仍然走 Main 的既有入口，参数也只有网格大小，和旧实现一致。
	_owner._save_menu_preferences()
	_remembered_page = PAGE_MAIN
	_owner._start_game(int(_owner.selected_grid_size))


# ------------------------------------------------------------------ 退出

func _on_nav_quit_pressed() -> void:
	_request_quit()


func _request_quit() -> void:
	# 平台惯例：桌面与移动端都先确认一次。移动端不提供"直接杀掉"的快捷键 ——
	# 安卓/iOS 上用户的习惯是用系统手势退到后台，我们只在这个显式入口里退出。
	if _is_mobile_platform():
		quit_dialog.dialog_text = "确定要退出游戏吗？安卓上也可以直接从最近任务上滑关闭。"
	else:
		quit_dialog.dialog_text = "确定要退出游戏吗？进行中的对局会保存到当前槽位。"
	quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	# 先落一次偏好，再退出：玩家在设置页改过的选项不该因为退出而丢。
	if _owner != null and _owner.has_method("_save_menu_preferences"):
		_owner._save_menu_preferences()
	get_tree().quit()


func _is_mobile_platform() -> bool:
	return OS.get_name() in MOBILE_PLATFORMS


func _notification(what: int) -> void:
	# 安卓返回键 / Esc：内页先回上一级，只有停在主菜单页时才询问退出。
	# 这才是安卓的惯例 —— 返回键不等于"杀进程"。
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _handle_back():
			get_viewport().set_input_as_handled()


func _handle_back() -> bool:
	match _current_page:
		PAGE_MODE:
			show_page(PAGE_MAIN)
			return true
		PAGE_CONFIG:
			show_page(PAGE_MODE)
			return true
		PAGE_HELP:
			show_page(PAGE_MAIN)
			return true
		PAGE_CONTINUE:
			show_page(PAGE_MAIN)
			return true
		_:
			_request_quit()
			return true


# ------------------------------------------------------------------ 配置项

func _on_size_option_selected(index: int) -> void:
	_owner.selected_grid_size = size_option.get_item_id(index)
	_owner._save_menu_preferences()
	_update_reset_button_state()
	_refresh_match_summary()
	_refresh_stage_caption()


func _on_quality_option_selected(index: int) -> void:
	_owner.selected_quality_name = quality_option.get_item_text(index)
	_owner._save_menu_preferences()
	_update_reset_button_state()
	_refresh_match_summary()


func _on_time_spin_changed(value: float) -> void:
	_owner.selected_time_limit_minutes = clampi(
		int(round(value)),
		GameConfig.TIMED_MODE_MIN_MINUTES,
		GameConfig.TIMED_MODE_MAX_MINUTES
	)
	_owner._save_menu_preferences()
	_update_reset_button_state()
	_update_mode_tip()


func _on_palette_option_selected(index: int) -> void:
	_owner.selected_palette_name = palette_option.get_item_text(index)
	_owner._save_menu_preferences()
	_update_reset_button_state()


func _on_mode_card_toggled(pressed: bool, mode_name: String) -> void:
	if _syncing or not pressed:
		return
	_owner.selected_game_mode_name = mode_name
	_update_mode_tip()
	_update_reset_button_state()
	_refresh_match_summary()
	_owner._save_menu_preferences()


func _on_mode_card_hover(mode_name: String, entered: bool) -> void:
	if entered:
		mode_tip_label.text = StartMenu.build_mode_tip_text(
			mode_name,
			int(_owner.selected_time_limit_minutes)
		)
	else:
		_update_mode_tip()


func _on_reset_pressed() -> void:
	# Main 的 reset_menu_preferences 会重建整层菜单；靠 _remembered_page
	# 把玩家留在"对局设置"页，而不是被弹回主菜单。
	_owner.reset_menu_preferences()


func _on_slot_pressed(slot: int) -> void:
	if _syncing:
		return
	_owner._select_save_slot(slot)
