extends CanvasLayer
class_name StartMenu

# 主菜单：一块机械控制台，左侧约 30% 操作区，右侧约 70% 真实战场预览台。
#
# 四页导航（PAGE_*）：主菜单 → 选择玩法 → 对局配置 → 开始；继续游戏单独一页。
# 拆页之后旧的长路径绑定（RootPanel/MainVBox/ConfigPanel/ConfigVBox/...）全部
# 换成了场景唯一名（%Name），节点挪位置不再改脚本。
#
# 展示层边界：这里只读 GameConfig / Main 的已选值，只调用它们的公开入口
# （_start_game / _continue_saved_game / _select_save_slot / _save_menu_preferences）。
# 不碰 Bullet、BulletPool、武器行为或物理步规则，也不解释任何战斗数值。

const PreviewScene = preload("res://scenes/ui/PreviewScene.tscn")
const MechThemeScript = preload("res://scripts/ui/MechTheme.gd")

const PAGE_MAIN := "main"
const PAGE_MODE := "mode"
const PAGE_CONFIG := "config"
const PAGE_CONTINUE := "continue"

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

@onready var title_label: Label = $RootPanel/Columns/ActionColumn/TitleLabel
@onready var subtitle_label: Label = $RootPanel/Columns/ActionColumn/SubtitleLabel
@onready var page_host: Control = $RootPanel/Columns/ActionColumn/PageHost
@onready var main_menu_page: VBoxContainer = $RootPanel/Columns/ActionColumn/PageHost/MainMenuPage
@onready var mode_select_page: VBoxContainer = $RootPanel/Columns/ActionColumn/PageHost/ModeSelectPage
@onready var match_config_page: VBoxContainer = $RootPanel/Columns/ActionColumn/PageHost/MatchConfigPage
@onready var continue_page: VBoxContainer = $RootPanel/Columns/ActionColumn/PageHost/ContinuePage

@onready var start_button: Button = %StartButton
@onready var continue_entry_button: Button = %ContinueEntryButton
@onready var menu_hint_label: Label = %MenuHintLabel
@onready var version_label: Label = %VersionLabel
@onready var main_mode_value: Label = %MainModeValue
@onready var main_map_value: Label = %MainMapValue
@onready var main_quality_value: Label = %MainQualityValue

@onready var mode_card_host: VBoxContainer = %ModeCardHost
@onready var mode_tip_label: Label = %ModeTipLabel
@onready var mode_back_button: Button = %ModeBackButton
@onready var mode_next_button: Button = %ModeNextButton

@onready var match_summary_label: Label = %MatchSummaryLabel
@onready var size_option: OptionButton = %GridSizeOption
@onready var quality_option: OptionButton = %QualityOption
@onready var time_spin: SpinBox = %TimeSpin
@onready var palette_option: OptionButton = %PaletteOption
@onready var reset_button: Button = %ResetDefaultsButton
@onready var config_back_button: Button = %ConfigBackButton
@onready var start_match_button: Button = %StartMatchButton

@onready var save_title: Label = %SaveTitle
@onready var slot_grid: GridContainer = %SlotGrid
@onready var continue_back_button: Button = %ContinueBackButton
@onready var continue_button: Button = %ContinueButton

@onready var menu_status_label: Label = %MenuStatusLabel
@onready var mobile_hint_label: Label = $RootPanel/Columns/ActionColumn/MobileHint
@onready var stage_column: Control = $RootPanel/Columns/StageColumn
@onready var stage_chrome: Control = %StageChrome
@onready var preview_container: Control = %PreviewContainer
@onready var chamber_preview: Node2D = %ChamberPreview
@onready var stage_caption: Label = %StageCaption

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
	return "\u5f00\u59cb\u65b0\u6e38\u620f"


static func build_status_label(slot: int, has_save_data: bool) -> String:
	if has_save_data:
		return "\u5df2\u9009\u62e9\u5b58\u6863\u69fd %d\uff0c\u65b0\u6e38\u620f\u4f1a\u8986\u76d6\u8fd9\u91cc\u7684\u5b58\u6863" % slot
	return "\u5df2\u9009\u62e9\u7a7a\u5b58\u6863\u69fd %d\uff0c\u65b0\u6e38\u620f\u4f1a\u4fdd\u5b58\u5728\u8fd9\u91cc" % slot


static func build_mode_tip_text(mode_name: String, time_limit_minutes: int) -> String:
	match mode_name:
		GameConfig.GAME_MODE_BASIC:
			return "\u57fa\u7840\uff1a\u6d88\u706d\u6240\u6709\u5bf9\u624b\u70ae\u53f0\u5373\u53ef\u83b7\u80dc"
		GameConfig.GAME_MODE_OCCUPATION:
			return "\u5360\u9886\uff1a\u8fbe\u5230 75% \u9886\u571f\u5373\u53ef\u83b7\u80dc"
		GameConfig.GAME_MODE_TIMED:
			return "\u9650\u65f6\uff1a%d \u5206\u949f\u5012\u8ba1\u65f6\u7ed3\u675f\u540e\uff0c\u9886\u5730\u6700\u591a\u65b9\u83b7\u80dc" % time_limit_minutes
		GameConfig.GAME_MODE_WILD:
			return "\u72c2\u91ce\uff1a\u5168\u5c40 x3 \u500d\u7387\uff0c\u5355\u6b21\u4e0a\u9650\u66f4\u9ad8\uff0c\u4e8b\u4ef6\u66f4\u9891\u7e41"
		_:
			return ""


# ------------------------------------------------------------------ 对外入口

func get_parts() -> Dictionary:
	return {
		"menu_layer": self,
		"menu_title_label": title_label,
		"menu_start_button": start_button,
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

	_view_size = view_size
	_apply_layout(view_size)
	if not page_host.resized.is_connected(_fit_pages):
		page_host.resized.connect(_fit_pages)
	_bind_pages()
	_init_options()
	_init_slot_buttons()
	_init_mode_cards()
	_init_decor()
	_sync_options_from_owner()
	refresh_slots(save_summaries)
	menu_status_label.text = StartMenu.build_status_text(_owner.selected_save_slot)
	_refresh_menu_status_label(_owner._has_save_file(_owner.selected_save_slot))
	version_label.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
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
# 页面最小高度能飙到 757；一旦 set_size 被这个假值夹住就不会自己缩回来。
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
	for label in _wrapped_labels():
		if label == null or not is_instance_valid(label):
			continue
		label.custom_minimum_size = Vector2(width, label.custom_minimum_size.y)
		label.size = Vector2(width, maxf(label.size.y, label.custom_minimum_size.y))


func _wrapped_labels() -> Array:
	return [
		subtitle_label,
		menu_hint_label,
		mode_tip_label,
		match_summary_label,
		save_title,
		menu_status_label,
		mobile_hint_label,
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
	shade.color = Color(0.0156863, 0.027451, 0.0431373, 0.9)

	var panel_size := Vector2(963.0, 634.0)
	var panel_rect: Rect2 = layout.get("root_panel_rect", Rect2((view_size - panel_size) * 0.5, panel_size))
	root_panel.position = panel_rect.position
	root_panel.size = panel_rect.size

	# 两栏都按布局给的矩形摆，不用 HBox 协商：容器会按子节点最小宽重新分配，
	# 一旦某个按钮文字变长，预览台就会被挤窄，而预览的缩放是按布局算的，
	# 两者不同步就会露出重叠。显式矩形没有这个自由度。
	var margin: Vector2 = layout.get("columns_margin", Vector2(22.0, 18.0))
	var margin_bottom: float = float(layout.get("columns_margin_bottom", margin.y))
	columns.position = margin
	columns.size = (panel_rect.size - Vector2(margin.x * 2.0, margin.y + margin_bottom)).max(Vector2(64.0, 64.0))

	var action_rect: Rect2 = layout.get("action_column_rect", Rect2(Vector2.ZERO, Vector2(columns.size.x * 0.30, columns.size.y)))
	# 先钉标签宽度，再定列尺寸 —— 顺序反了就会被那张假的最小尺寸夹住。
	_fix_wrapped_label_widths(action_rect.size.x)
	action_column.position = action_rect.position
	action_column.size = action_rect.size

	var stage_rect: Rect2 = layout.get("stage_rect", Rect2(Vector2(action_rect.size.x + 18.0, 0.0), Vector2(columns.size.x - action_rect.size.x - 18.0, columns.size.y)))
	stage_column.position = stage_rect.position
	stage_column.size = stage_rect.size

	var header_height: float = float(layout.get("preview_header_height", 36.0))
	var footer_height: float = float(layout.get("preview_footer_height", 32.0))
	var side_pad: float = float(layout.get("preview_side_pad", 16.0))
	var preview_size: Vector2 = layout.get(
		"preview_size",
		Vector2(
			maxf(80.0, stage_rect.size.x - side_pad * 2.0),
			maxf(60.0, stage_rect.size.y - header_height - footer_height)
		)
	)

	stage_chrome.set("header_height", header_height)
	stage_chrome.set("footer_height", footer_height)
	stage_chrome.set("side_pad", side_pad)
	if stage_chrome.has_method("queue_redraw"):
		stage_chrome.queue_redraw()

	preview_container.position = Vector2(side_pad, header_height)
	preview_container.size = preview_size
	preview_container.clip_contents = true

	chamber_preview.scale = layout.get("preview_scale", Vector2(0.4, 0.4))
	chamber_preview.position = layout.get("preview_center", preview_size * 0.5)

	stage_caption.position = Vector2(side_pad, header_height + preview_size.y + 4.0)
	stage_caption.size = Vector2(preview_size.x, maxf(16.0, footer_height - 8.0))


# ------------------------------------------------------------------ 构建

func _bind_pages() -> void:
	_page_nodes.clear()
	_page_nodes[PAGE_MAIN] = main_menu_page
	_page_nodes[PAGE_MODE] = mode_select_page
	_page_nodes[PAGE_CONFIG] = match_config_page
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
		button.custom_minimum_size = Vector2(0.0, 40.0)
		# clip_text 会让按钮不再把文字宽度算进最小宽度，于是单列 GridContainer
		# 会把列宽压到内边距那么宽（实测 20px）。必须显式 EXPAND_FILL 撑满整列。
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
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
		card.custom_minimum_size = Vector2(0.0, 46.0)
		card.text = str(mode_name)
		card.clip_text = true
		card.tooltip_text = StartMenu.build_mode_tip_text(str(mode_name), int(_owner.selected_time_limit_minutes))
		mode_card_host.add_child(card)
		card.toggled.connect(Callable(self, "_on_mode_card_toggled").bind(str(mode_name)))
		# 悬停就先给规则提示，不用点了才知道这个玩法是什么。
		card.mouse_entered.connect(Callable(self, "_on_mode_card_hover").bind(str(mode_name), true))
		card.mouse_exited.connect(Callable(self, "_on_mode_card_hover").bind(str(mode_name), false))
		_mode_cards[str(mode_name)] = card
		index += 1


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


func _refresh_action_labels(has_selected_save: bool) -> void:
	start_button.text = StartMenu.build_start_button_label(_owner.selected_save_slot, has_selected_save)
	continue_button.text = StartMenu.build_continue_button_text(_owner.selected_save_slot)
	continue_button.disabled = not has_selected_save


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
	# 主菜单页只读摘要：玩家不进配置页也能确认自己要开的是哪一局。
	main_mode_value.text = mode_label
	main_map_value.text = "%s %d × %d" % [map_name, grid, grid]
	main_quality_value.text = "%s画质" % quality_label


func _refresh_stage_caption() -> void:
	var grid: int = int(_owner.selected_grid_size)
	stage_caption.text = "实时战场预览 · %d × %d" % [grid, grid]


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


func _on_page_shown(page_key: String) -> void:
	match page_key:
		PAGE_CONFIG:
			# 从"选择玩法"进来时，摘要和"恢复默认"的可用态都要重算。
			_refresh_match_summary()
			_refresh_stage_caption()
			_update_reset_button_state()
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

	if not start_button.pressed.is_connected(_on_start_pressed):
		start_button.pressed.connect(_on_start_pressed)
	if not continue_entry_button.pressed.is_connected(_on_continue_entry_pressed):
		continue_entry_button.pressed.connect(_on_continue_entry_pressed)
	if not mode_back_button.pressed.is_connected(_on_mode_back_pressed):
		mode_back_button.pressed.connect(_on_mode_back_pressed)
	if not mode_next_button.pressed.is_connected(_on_mode_next_pressed):
		mode_next_button.pressed.connect(_on_mode_next_pressed)
	if not config_back_button.pressed.is_connected(_on_config_back_pressed):
		config_back_button.pressed.connect(_on_config_back_pressed)
	if not continue_back_button.pressed.is_connected(_on_continue_back_pressed):
		continue_back_button.pressed.connect(_on_continue_back_pressed)
	if not start_match_button.pressed.is_connected(_on_start_match_pressed):
		start_match_button.pressed.connect(_on_start_match_pressed)
	if not reset_button.pressed.is_connected(_on_reset_pressed):
		reset_button.pressed.connect(_on_reset_pressed)
	if not continue_button.pressed.is_connected(Callable(_owner, "_continue_saved_game")):
		continue_button.pressed.connect(Callable(_owner, "_continue_saved_game"))


# ------------------------------------------------------------------ 页面导航

func _on_start_pressed() -> void:
	show_page(PAGE_MODE)


func _on_continue_entry_pressed() -> void:
	show_page(PAGE_CONTINUE)


func _on_mode_back_pressed() -> void:
	show_page(PAGE_MAIN)


func _on_mode_next_pressed() -> void:
	show_page(PAGE_CONFIG)


func _on_config_back_pressed() -> void:
	show_page(PAGE_MODE)


func _on_continue_back_pressed() -> void:
	show_page(PAGE_MAIN)


func _on_start_match_pressed() -> void:
	# 真正开局仍然走 Main 的既有入口，参数也只有网格大小，和旧实现一致。
	_owner._save_menu_preferences()
	_remembered_page = PAGE_MAIN
	_owner._start_game(int(_owner.selected_grid_size))


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
	# 把玩家留在"对局配置"页，而不是被弹回主菜单。
	_owner.reset_menu_preferences()


func _on_slot_pressed(slot: int) -> void:
	if _syncing:
		return
	_owner._select_save_slot(slot)
