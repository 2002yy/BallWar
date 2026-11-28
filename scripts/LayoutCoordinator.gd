extends RefCounted
class_name LayoutCoordinator

const TURRET_MARGIN: float = 16.0
const SAFE_MARGIN: float = 10.0
const SIDE_BUTTON_WIDTH: float = 96.0
const SIDE_BUTTON_HEIGHT: float = 42.0
const SIDE_MARGIN: float = 10.0
const SIDE_GAP: float = 6.0
const CHAMBER_TOP_TURRET_GAP: float = 18.0
const CHAMBER_BOTTOM_TURRET_GAP: float = 8.0
const FPS_BG_SIZE: Vector2 = Vector2(714.0, 30.0)
const FPS_LABEL_SIZE: Vector2 = Vector2(702.0, 24.0)
const EVENT_LABEL_SIZE: Vector2 = Vector2(332.0, 24.0)
const EVENT_LOG_WIDTH: float = 290.0
const EVENT_LOG_MAX_HEIGHT: float = 230.0
const EVENT_LOG_LINE_HEIGHT: float = 20.0

# 四角 → 阵营 ID 的唯一权威映射。正式战斗的炮台/控制仓坐标与主菜单预览的
# 四象限/炮台/控制仓都从这里取，避免两处各写一份导致角落错位。
# 顺序固定为：左上、右上、左下、右下。
const CORNER_KEYS := ["top_left", "top_right", "bottom_left", "bottom_right"]

static func corner_factions() -> Dictionary:
	return {
		"top_left": GameConfig.Faction.BLUE,
		"top_right": GameConfig.Faction.RED,
		"bottom_left": GameConfig.Faction.GREEN,
		"bottom_right": GameConfig.Faction.YELLOW,
	}

static func corner_faction_order() -> Array:
	var factions := corner_factions()
	var order: Array = []
	for key in CORNER_KEYS:
		order.append(int(factions[key]))
	return order

static func get_cell_size(grid_size: int) -> float:
	match grid_size:
		10:
			return 34.0
		20:
			return 22.0
		30:
			return 16.0
		40:
			return 13.0
		50:
			return 11.0
		60:
			return 9.0
		_:
			return 13.0

static func get_chamber_base_size() -> Vector2:
	return Vector2(115.0, 286.0)

static func calculate_layout(grid_size: int, viewport_size: Vector2, is_mobile: bool = false) -> Dictionary:
	var cell_size: float = get_cell_size(grid_size)
	var profile := LayoutProfiles.get_profile(grid_size)
	var map_pixel_size: float = float(grid_size) * cell_size
	var bf_x: float = (viewport_size.x - map_pixel_size) * 0.5
	var bf_y: float = profile.get("map_y", 96.0)
	var bf_rect := Rect2(Vector2(bf_x, bf_y), Vector2(map_pixel_size, map_pixel_size))

	var turret_positions := _calculate_turret_positions(bf_rect)

	var chamber_base_size := get_chamber_base_size()
	var chamber_scale: float = profile.get("chamber_scale", 0.80)
	var chamber_size := chamber_base_size * chamber_scale
	var chamber_gap: float = profile.get("chamber_gap", 10.0)
	var chamber_positions := _calculate_chamber_positions(bf_rect, turret_positions, chamber_size, chamber_gap)
	# Blend profile manual Y values with calculated positions:
	# profile values have been hand-tuned per grid size; only override if
	# they would cause the chamber to overlap the battlefield vertically.
	var profile_top_y: float = profile.get("left_chamber_y_top", chamber_positions[GameConfig.Faction.BLUE].y)
	var profile_bottom_y: float = profile.get("left_chamber_y_bottom", chamber_positions[GameConfig.Faction.GREEN].y)
	var calc_top_y: float = chamber_positions[GameConfig.Faction.BLUE].y
	var calc_bottom_y: float = chamber_positions[GameConfig.Faction.GREEN].y
	var top_y: float = minf(profile_top_y, calc_top_y)
	var bottom_y: float = maxf(profile_bottom_y, calc_bottom_y)
	chamber_positions[GameConfig.Faction.BLUE] = Vector2(chamber_positions[GameConfig.Faction.BLUE].x, top_y)
	chamber_positions[GameConfig.Faction.RED] = Vector2(chamber_positions[GameConfig.Faction.RED].x, top_y)
	chamber_positions[GameConfig.Faction.GREEN] = Vector2(chamber_positions[GameConfig.Faction.GREEN].x, bottom_y)
	chamber_positions[GameConfig.Faction.YELLOW] = Vector2(chamber_positions[GameConfig.Faction.YELLOW].x, bottom_y)

	var button_size: Vector2 = profile.get("button_size", Vector2(88.0, 46.0))
	if is_mobile:
		button_size += Vector2(16.0, 10.0)
	var button_gap: float = profile.get("button_gap", 11.0) + (4.0 if is_mobile else 0.0)
	var add_ball_button_positions := _calculate_add_ball_positions(chamber_positions, chamber_size, button_size, button_gap, viewport_size)

	var side_button_size: Vector2 = Vector2(114.0, 46.0) if is_mobile else Vector2(SIDE_BUTTON_WIDTH, SIDE_BUTTON_HEIGHT)
	var side_x: float = viewport_size.x - side_button_size.x - SIDE_MARGIN
	var side_button_positions := _calculate_side_buttons(side_x, side_button_size)

	var hud_positions := _calculate_hud_positions(viewport_size, profile, is_mobile, side_button_positions, side_button_size)
	var roulette_stage_rect := _calculate_roulette(grid_size, viewport_size, is_mobile, bf_rect)
	var start_menu_layout := _calculate_start_menu_layout(viewport_size, is_mobile)

	return {
		"viewport_size": viewport_size,
		"grid_size": grid_size,
		"is_mobile": is_mobile,
		"cell_size": cell_size,
		"safe_margin": SAFE_MARGIN,
		"battlefield_rect": bf_rect,
		"turret_positions": turret_positions,
		"chamber_positions": chamber_positions,
		"chamber_size": chamber_size,
		"add_ball_positions": add_ball_button_positions,
		"add_ball_button_positions": add_ball_button_positions,
		"add_ball_button_size": button_size,
		"side_button_positions": side_button_positions,
		"side_button_size": side_button_size,
		"hud_positions": hud_positions,
		"roulette_stage_rect": roulette_stage_rect,
		"start_menu_layout": start_menu_layout,
	}

static func _calculate_turret_positions(bf_rect: Rect2) -> Dictionary:
	var size := bf_rect.size.x
	var m := TURRET_MARGIN
	var c := corner_factions()
	return {
		c["top_left"]: bf_rect.position + Vector2(m, m),
		c["top_right"]: bf_rect.position + Vector2(size - m, m),
		c["bottom_left"]: bf_rect.position + Vector2(m, size - m),
		c["bottom_right"]: bf_rect.position + Vector2(size - m, size - m),
	}

static func _calculate_chamber_positions(bf_rect: Rect2, turret_positions: Dictionary, chamber_size: Vector2, chamber_gap: float) -> Dictionary:
	var blue_turret: Vector2 = turret_positions.get(GameConfig.Faction.BLUE, Vector2.ZERO)
	var red_turret: Vector2 = turret_positions.get(GameConfig.Faction.RED, Vector2.ZERO)
	var green_turret: Vector2 = turret_positions.get(GameConfig.Faction.GREEN, Vector2.ZERO)
	var _yellow_turret: Vector2 = turret_positions.get(GameConfig.Faction.YELLOW, Vector2.ZERO)

	var left_x: float = blue_turret.x - chamber_size.x - chamber_gap
	var bf_left: float = bf_rect.position.x
	if left_x + chamber_size.x > bf_left - chamber_gap:
		left_x = bf_left - chamber_gap - chamber_size.x
	if left_x < SIDE_MARGIN:
		left_x = SIDE_MARGIN

	var right_x: float = red_turret.x + chamber_gap
	var bf_right: float = bf_rect.position.x + bf_rect.size.x
	if right_x < bf_right + chamber_gap:
		right_x = bf_right + chamber_gap

	var top_y: float = blue_turret.y - CHAMBER_TOP_TURRET_GAP
	var bottom_y: float = green_turret.y - chamber_size.y - CHAMBER_BOTTOM_TURRET_GAP

	return {
		GameConfig.Faction.BLUE: Vector2(left_x, top_y),
		GameConfig.Faction.RED: Vector2(right_x, top_y),
		GameConfig.Faction.GREEN: Vector2(left_x, bottom_y),
		GameConfig.Faction.YELLOW: Vector2(right_x, bottom_y),
	}

static func _calculate_add_ball_positions(chamber_positions: Dictionary, chamber_size: Vector2, button_size: Vector2, button_gap: float, viewport_size: Vector2) -> Dictionary:
	var result: Dictionary = {}
	for faction_id in chamber_positions.keys():
		var chamber_pos: Vector2 = chamber_positions[faction_id]
		var y_pos: float = chamber_pos.y + chamber_size.y * 0.5 - button_size.y * 0.5
		var x_pos: float
		if faction_id == GameConfig.Faction.BLUE or faction_id == GameConfig.Faction.GREEN:
			x_pos = chamber_pos.x - button_size.x - button_gap
		else:
			x_pos = chamber_pos.x + chamber_size.x + button_gap
		x_pos = clampf(x_pos, SAFE_MARGIN, viewport_size.x - button_size.x - SAFE_MARGIN)
		y_pos = clampf(y_pos, 64.0, viewport_size.y - button_size.y - 12.0)
		result[faction_id] = Vector2(x_pos, y_pos)
	return result

static func _calculate_side_buttons(side_x: float, side_button_size: Vector2) -> Dictionary:
	return {
		"settings": Vector2(side_x, 84.0),
		"pause": Vector2(side_x, 84.0 + side_button_size.y + SIDE_GAP),
		"exit": Vector2(side_x, 84.0 + (side_button_size.y + SIDE_GAP) * 2.0),
	}

static func _calculate_hud_positions(
	viewport_size: Vector2,
	profile: Dictionary,
	is_mobile: bool,
	side_button_positions: Dictionary,
	side_button_size: Vector2
) -> Dictionary:
	var top_panel_w: float = float(profile.get("top_panel_w", 710.0))
	var top_panel_h: float = float(profile.get("top_panel_h", 90.0))
	if is_mobile:
		top_panel_w = minf(top_panel_w, 660.0)
		top_panel_h = 98.0

	var top_panel_rect := Rect2(Vector2((viewport_size.x - top_panel_w) * 0.5, 8.0), Vector2(top_panel_w, top_panel_h))
	var leader_label_rect := Rect2(top_panel_rect.position + Vector2(16.0, 4.0), Vector2(176.0, 24.0))
	var timer_label_rect := Rect2(top_panel_rect.position + Vector2((top_panel_rect.size.x - 110.0) * 0.5, 1.0), Vector2(110.0, 26.0))
	var stage_label_rect := Rect2(top_panel_rect.position + Vector2(top_panel_rect.size.x - 182.0, 4.0), Vector2(168.0, 24.0))
	var bar_bg_rect := Rect2(top_panel_rect.position + Vector2(18.0, 31.0), Vector2(top_panel_rect.size.x - 36.0, float(profile.get("bar_h", 36.0))))
	var bar_inner_rect := Rect2(bar_bg_rect.position + Vector2(3.0, 3.0), bar_bg_rect.size - Vector2(6.0, 6.0))
	var badge_rect := Rect2(top_panel_rect.position + Vector2(top_panel_rect.size.x * 0.5 - 118.0, 60.0), Vector2(28.0, 28.0))
	var title_rect := Rect2(top_panel_rect.position + Vector2(0.0, top_panel_rect.size.y - 26.0), Vector2(top_panel_rect.size.x, 28.0))
	var palette_rect := Rect2(top_panel_rect.position + Vector2(top_panel_rect.size.x - 166.0, 66.0), Vector2(152.0, 22.0))
	var winner_label_rect := Rect2(Vector2(0.0, float(profile.get("winner_y", 666.0))), Vector2(viewport_size.x, 34.0))

	var fps_bg_rect := Rect2(Vector2(viewport_size.x - FPS_BG_SIZE.x - SAFE_MARGIN, viewport_size.y - FPS_BG_SIZE.y - 38.0), FPS_BG_SIZE)
	var fps_label_rect := Rect2(Vector2(fps_bg_rect.position.x + 6.0, fps_bg_rect.position.y - 3.0), FPS_LABEL_SIZE)

	var event_label_size: Vector2 = Vector2(260.0, 22.0) if is_mobile else EVENT_LABEL_SIZE
	var event_label_pos := Vector2(
		fps_label_rect.position.x + fps_label_rect.size.x - event_label_size.x,
		fps_label_rect.position.y - event_label_size.y - 4.0
	)
	if is_mobile:
		event_label_pos = Vector2(viewport_size.x - event_label_size.x - 12.0, viewport_size.y - 84.0)
	var event_label_rect := Rect2(event_label_pos, event_label_size)

	var bottom_hud_rect := Rect2(
		Vector2(minf(fps_bg_rect.position.x, event_label_rect.position.x), minf(event_label_rect.position.y, fps_bg_rect.position.y)),
		Vector2(
			maxf(fps_bg_rect.position.x + fps_bg_rect.size.x, event_label_rect.position.x + event_label_rect.size.x) - minf(fps_bg_rect.position.x, event_label_rect.position.x),
			maxf(fps_bg_rect.position.y + fps_bg_rect.size.y, event_label_rect.position.y + event_label_rect.size.y) - minf(event_label_rect.position.y, fps_bg_rect.position.y)
		)
	)

	# Tall enough for the three volume rows added in A4. The panel hangs below the
	# exit button, so the size is bounded by the viewport height rather than by a
	# fixed constant.
	var settings_panel_size: Vector2 = Vector2(278.0, 236.0) if is_mobile else Vector2(300.0, 244.0)
	var exit_button_pos: Vector2 = side_button_positions.get("exit", Vector2.ZERO)
	var settings_panel_x: float = clampf(
		exit_button_pos.x - settings_panel_size.x + side_button_size.x,
		SAFE_MARGIN,
		viewport_size.x - settings_panel_size.x - SAFE_MARGIN
	)
	var settings_panel_top: float = exit_button_pos.y + side_button_size.y + 10.0
	var settings_panel_height: float = minf(settings_panel_size.y, viewport_size.y - settings_panel_top - SAFE_MARGIN)
	var settings_panel_rect := Rect2(
		Vector2(settings_panel_x, settings_panel_top),
		Vector2(settings_panel_size.x, maxf(settings_panel_height, 120.0))
	)

	var event_log_rect := Rect2(
		Vector2(viewport_size.x - EVENT_LOG_WIDTH - SIDE_MARGIN, top_panel_rect.position.y + top_panel_rect.size.y + 8.0),
		Vector2(EVENT_LOG_WIDTH, EVENT_LOG_MAX_HEIGHT)
	)
	if is_mobile:
		event_log_rect.size.x = minf(event_log_rect.size.x, 260.0)
		event_log_rect.position.x = viewport_size.x - event_log_rect.size.x - 6.0

	return {
		"top_panel_rect": top_panel_rect,
		"leader_label_rect": leader_label_rect,
		"timer_label_rect": timer_label_rect,
		"stage_label_rect": stage_label_rect,
		"bar_bg_rect": bar_bg_rect,
		"bar_inner_rect": bar_inner_rect,
		"badge_rect": badge_rect,
		"title_rect": title_rect,
		"palette_rect": palette_rect,
		"winner_label_rect": winner_label_rect,
		"fps_bg_rect": fps_bg_rect,
		"fps_label_rect": fps_label_rect,
		"event_label_rect": event_label_rect,
		"bottom_hud_rect": bottom_hud_rect,
		"settings_panel_rect": settings_panel_rect,
		"event_log_rect": event_log_rect,
	}

static func _calculate_roulette(grid_size: int, viewport_size: Vector2, is_mobile: bool, battlefield_rect: Rect2) -> Rect2:
	var compact: bool = grid_size >= 40
	var stage_size: Vector2 = Vector2(500.0, 182.0)
	if compact:
		stage_size = Vector2(448.0, 168.0)
	elif grid_size <= 20:
		stage_size = Vector2(540.0, 194.0)

	if is_mobile:
		stage_size = Vector2(minf(stage_size.x, 430.0), stage_size.y + 10.0)

	var stage_y: float = battlefield_rect.position.y - stage_size.y - 10.0
	stage_y = clampf(stage_y, 92.0, 126.0)
	return Rect2(Vector2((viewport_size.x - stage_size.x) * 0.5, stage_y), stage_size)

# PreviewScene 的内容包围盒：机身 672×540（含上下仪表带、左右散热带、
# 四控制仓、四炮台），节点原点就是机身中心。这两个常数只用于把预览台居中，
# 不参与任何战场坐标换算 —— 战场坐标仍然只在 Main / 模拟层里算。
const START_MENU_PREVIEW_CONTENT := Vector2(672.0, 540.0)
const START_MENU_PREVIEW_CONTENT_CENTER := Vector2.ZERO


static func _calculate_start_menu_layout(viewport_size: Vector2, is_mobile: bool) -> Dictionary:
	# 主菜单 = 一块机械控制台，整屏利用率优先。
	#
	# 旧的算法把面板缩到视口的 86%×88% 并夹在 1400×820 以内，结果 1120×720 上
	# 四边各留 78px 纯黑，中心棋盘只剩 291px —— 读作"飘在背景上的一张卡片"，
	# 而不是一台占满屏幕的机器。现在外留白只留一圈机框：桌面 26px、手机 14px，
	# 面板直接等于视口减两倍留白，不再设上限。
	var outer_margin: float = 14.0 if is_mobile else 26.0
	outer_margin = clampf(outer_margin, 8.0, minf(viewport_size.x, viewport_size.y) * 0.06)
	var panel_size := (viewport_size - Vector2(outer_margin, outer_margin) * 2.0).max(Vector2(480.0, 360.0))
	panel_size.x = minf(panel_size.x, viewport_size.x - outer_margin * 2.0)
	panel_size.y = minf(panel_size.y, viewport_size.y - outer_margin * 2.0)

	var pad: float = 14.0 if is_mobile else 16.0
	var footer_h: float = 22.0 if is_mobile else 26.0
	var footer_gap: float = 8.0
	var inner := Vector2(
		maxf(320.0, panel_size.x - pad * 2.0),
		maxf(240.0, panel_size.y - pad * 2.0)
	)
	# 双栏之上再切一条通栏状态条：版本号、操作提示、平台说明都归它，
	# 不再挤在左栏最底部（那正是旧版左下角空一大块的原因之一）。
	var columns_h: float = maxf(200.0, inner.y - footer_h - footer_gap)

	# 左栏约 30%，右栏吃掉剩下的全部。不设 1400 上限之后这里不用再防"太宽"。
	var action_width: float = clampf(round(inner.x * 0.30), 248.0, 420.0)
	var column_gap: float = 12.0 if is_mobile else 16.0
	var stage_width: float = maxf(240.0, inner.x - action_width - column_gap)

	var columns_rect := Rect2(Vector2(pad, pad), Vector2(inner.x, columns_h))
	var footer_rect := Rect2(
		Vector2(pad, pad + columns_h + footer_gap),
		Vector2(inner.x, footer_h)
	)
	var action_column_rect := Rect2(Vector2.ZERO, Vector2(action_width, columns_h))
	var stage_rect := Rect2(Vector2(action_width + column_gap, 0.0), Vector2(stage_width, columns_h))

	# 预览台内部：表头放标题，底部只留一条细刻度（全局状态条已经承担了版本号）。
	var header_height: float = 30.0 if is_mobile else 34.0
	var footer_height: float = 10.0 if is_mobile else 12.0
	var side_pad: float = 8.0 if is_mobile else 10.0
	var preview_size := Vector2(
		maxf(80.0, stage_width - side_pad * 2.0),
		maxf(60.0, columns_h - header_height - footer_height)
	)

	# 预览缩放由监控窗决定，保证整台机器完整可见再留一点气口。
	var fit: float = minf(
		preview_size.x / START_MENU_PREVIEW_CONTENT.x,
		preview_size.y / START_MENU_PREVIEW_CONTENT.y
	)
	var preview_scale_value: float = clampf(fit * 0.97, 0.30, 2.20)
	# 内容包围盒以机身中心为原点，所以直接把原点放到监控窗中心即可。
	var preview_center := Vector2(
		preview_size.x * 0.5 - START_MENU_PREVIEW_CONTENT_CENTER.x * preview_scale_value,
		preview_size.y * 0.5 - START_MENU_PREVIEW_CONTENT_CENTER.y * preview_scale_value
	)

	return {
		"shade_rect": Rect2(Vector2.ZERO, viewport_size),
		"root_panel_rect": Rect2(Vector2(outer_margin, outer_margin), panel_size),
		"outer_margin": outer_margin,
		"panel_pad": pad,
		"columns_rect": columns_rect,
		"footer_rect": footer_rect,
		"footer_height": footer_h,
		"columns_margin": columns_rect.position,
		"columns_margin_bottom": footer_h + footer_gap,
		"column_gap": column_gap,
		"action_column_rect": action_column_rect,
		"stage_rect": stage_rect,
		"preview_header_height": header_height,
		"preview_footer_height": footer_height,
		"preview_side_pad": side_pad,
		"preview_size": preview_size,
		"preview_center": preview_center,
		"preview_scale": Vector2(preview_scale_value, preview_scale_value),
	}
