extends RefCounted
class_name LayoutCoordinator

const TURRET_MARGIN: float = 16.0
const SIDE_BUTTON_WIDTH: float = 96.0
const SIDE_BUTTON_HEIGHT: float = 42.0
const SIDE_MARGIN: float = 10.0
const SIDE_GAP: float = 6.0
const CHAMBER_TOP_TURRET_GAP: float = 18.0
const CHAMBER_BOTTOM_TURRET_GAP: float = 8.0
const FPS_LABEL_SIZE: Vector2 = Vector2(702.0, 24.0)
const EVENT_LABEL_SIZE: Vector2 = Vector2(332.0, 24.0)
const ROULETTE_STAGE_WIDTH: float = 420.0
const ROULETTE_STAGE_HEIGHT: float = 160.0

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

	var button_size: Vector2 = profile.get("button_size", Vector2(88.0, 46.0))
	var button_gap: float = profile.get("button_gap", 11.0)
	var add_ball_positions := _calculate_add_ball_positions(chamber_positions, chamber_size, button_size, button_gap, viewport_size)

	var side_button_size: Vector2 = Vector2(114.0, 46.0) if is_mobile else Vector2(SIDE_BUTTON_WIDTH, SIDE_BUTTON_HEIGHT)
	var side_x: float = viewport_size.x - side_button_size.x - SIDE_MARGIN
	var side_button_positions := _calculate_side_buttons(side_x, side_button_size)

	var hud_positions := _calculate_hud_positions(viewport_size)

	var roulette := _calculate_roulette(viewport_size)

	return {
		"viewport_size": viewport_size,
		"grid_size": grid_size,
		"is_mobile": is_mobile,
		"battlefield_rect": bf_rect,
		"turret_positions": turret_positions,
		"chamber_positions": chamber_positions,
		"chamber_size": chamber_size,
		"add_ball_positions": add_ball_positions,
		"side_button_positions": side_button_positions,
		"side_button_size": side_button_size,
		"hud_positions": hud_positions,
		"roulette_stage_rect": roulette,
	}

static func _calculate_turret_positions(bf_rect: Rect2) -> Dictionary:
	var size := bf_rect.size.x
	var m := TURRET_MARGIN
	return {
		GameConfig.Faction.BLUE: bf_rect.position + Vector2(m, m),
		GameConfig.Faction.RED: bf_rect.position + Vector2(size - m, m),
		GameConfig.Faction.GREEN: bf_rect.position + Vector2(m, size - m),
		GameConfig.Faction.YELLOW: bf_rect.position + Vector2(size - m, size - m),
	}

static func _calculate_chamber_positions(bf_rect: Rect2, turret_positions: Dictionary, chamber_size: Vector2, chamber_gap: float) -> Dictionary:
	var blue_turret: Vector2 = turret_positions.get(GameConfig.Faction.BLUE, Vector2.ZERO)
	var red_turret: Vector2 = turret_positions.get(GameConfig.Faction.RED, Vector2.ZERO)
	var green_turret: Vector2 = turret_positions.get(GameConfig.Faction.GREEN, Vector2.ZERO)
	var yellow_turret: Vector2 = turret_positions.get(GameConfig.Faction.YELLOW, Vector2.ZERO)

	var left_x: float = blue_turret.x - chamber_size.x - chamber_gap
	if left_x < 0.0:
		left_x = SIDE_MARGIN
	var right_x: float = red_turret.x + chamber_gap

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
		x_pos = clampf(x_pos, SIDE_MARGIN, viewport_size.x - button_size.x - SIDE_MARGIN)
		y_pos = clampf(y_pos, 64.0, viewport_size.y - button_size.y - 12.0)
		result[faction_id] = Vector2(x_pos, y_pos)
	return result

static func _calculate_side_buttons(side_x: float, side_button_size: Vector2) -> Dictionary:
	return {
		"settings": Vector2(side_x, 84.0),
		"pause": Vector2(side_x, 84.0 + side_button_size.y + SIDE_GAP),
		"exit": Vector2(side_x, 84.0 + (side_button_size.y + SIDE_GAP) * 2.0),
	}

static func _calculate_hud_positions(viewport_size: Vector2) -> Dictionary:
	var right_margin: float = 24.0
	var fps_rect := Rect2(Vector2(402.0, 649.0), FPS_LABEL_SIZE)
	var event_w: Vector2 = EVENT_LABEL_SIZE
	var event_pos := Vector2(
		fps_rect.position.x + fps_rect.size.x - event_w.x,
		fps_rect.position.y - event_w.y - 4.0
	)
	var event_rect := Rect2(event_pos, event_w)
	var bottom_group_max_x: float = maxf(fps_rect.position.x + fps_rect.size.x, event_rect.position.x + event_rect.size.x)
	if bottom_group_max_x + right_margin > viewport_size.x:
		var overflow: float = bottom_group_max_x + right_margin - viewport_size.x
		fps_rect.position.x -= overflow
		event_rect.position.x -= overflow

	var bottom_hud_rect := Rect2(
		Vector2(minf(fps_rect.position.x, event_rect.position.x), event_rect.position.y),
		Vector2(maxf(fps_rect.size.x, event_rect.size.x), fps_rect.position.y + fps_rect.size.y - event_rect.position.y)
	)

	return {
		"fps_label_rect": fps_rect,
		"event_label_rect": event_rect,
		"bottom_hud_rect": bottom_hud_rect,
	}

static func _calculate_roulette(viewport_size: Vector2) -> Rect2:
	var w := ROULETTE_STAGE_WIDTH
	var h := ROULETTE_STAGE_HEIGHT
	return Rect2((viewport_size.x - w) * 0.5, viewport_size.y * 0.25, w, h)
