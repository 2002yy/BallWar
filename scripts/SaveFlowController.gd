extends RefCounted
class_name SaveFlowController

static func normalize_slot(slot_index: int, selected_save_slot: int, save_slot_count: int) -> int:
	return selected_save_slot if slot_index < 1 else clampi(slot_index, 1, save_slot_count)

static func get_save_path(slot_index: int, save_path_template: String, save_slot_count: int) -> String:
	return save_path_template % clampi(slot_index, 1, save_slot_count)

static func has_save_file(slot_index: int, selected_save_slot: int, save_slot_count: int, save_path_template: String, legacy_save_path: String) -> bool:
	var slot: int = normalize_slot(slot_index, selected_save_slot, save_slot_count)
	if FileAccess.file_exists(get_save_path(slot, save_path_template, save_slot_count)):
		return true
	return slot == 1 and FileAccess.file_exists(legacy_save_path)

static func load_saved_data(slot_index: int, selected_save_slot: int, save_slot_count: int, save_path_template: String, legacy_save_path: String, allow_legacy: bool = true) -> Dictionary:
	var slot: int = normalize_slot(slot_index, selected_save_slot, save_slot_count)
	var path: String = get_save_path(slot, save_path_template, save_slot_count)

	if not FileAccess.file_exists(path):
		if allow_legacy and slot == 1 and FileAccess.file_exists(legacy_save_path):
			path = legacy_save_path
		else:
			return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}

static func prepare_continue_payload(slot_index: int, selected_save_slot: int, save_slot_count: int, save_path_template: String, legacy_save_path: String, allow_legacy: bool = true) -> Dictionary:
	var raw_data: Dictionary = load_saved_data(
		slot_index,
		selected_save_slot,
		save_slot_count,
		save_path_template,
		legacy_save_path,
		allow_legacy
	)
	if raw_data.is_empty():
		return {
			"ok": false,
			"error_message": "\u5b58\u6863\u8bfb\u53d6\u5931\u8d25\u6216\u5b58\u6863\u5df2\u635f\u574f",
		}

	var save_version: String = str(raw_data.get("save_version", ""))
	if not SaveGameCodec.is_supported_save_version(save_version):
		return {
			"ok": false,
			"error_message": "\u5b58\u6863\u7248\u672c\u4e0d\u517c\u5bb9\uFF1A%s" % save_version,
			"warning_message": "\u5b58\u6863\u7248\u672c\u4e0d\u517c\u5bb9\uFF0C\u5df2\u62d2\u7edd\u8bfb\u53d6\uFF1A%s" % save_version,
			"save_version": save_version,
		}

	var clean_data: Dictionary = SaveGameCodec.validate_save_data(raw_data)
	if clean_data.has("_invalid_reason"):
		return {
			"ok": false,
			"error_message": str(clean_data["_invalid_reason"]),
			"save_version": save_version,
		}

	if not clean_data.has("grid_size"):
		return {
			"ok": false,
			"error_message": "\u5b58\u6863\u7ed3\u6784\u4e0d\u5b8c\u6574\uFF0C\u65e0\u6cd5\u7ee7\u7eed",
			"save_version": save_version,
		}

	return {
		"ok": true,
		"data": clean_data,
		"save_version": save_version,
	}

static func build_continue_runtime_state(data: Dictionary, fallback_time_limit_minutes: int) -> Dictionary:
	var normalized: Dictionary = data.duplicate(true)
	normalized["palette_name"] = str(normalized.get("palette_name", "\u7ecf\u5178"))
	normalized["quality_name"] = str(normalized.get("quality_name", "\u4e2d"))
	normalized["game_mode_name"] = str(normalized.get("game_mode_name", GameConfig.GAME_MODE_BASIC))
	normalized["time_limit_minutes"] = clampi(
		int(normalized.get("time_limit_minutes", fallback_time_limit_minutes)),
		GameConfig.TIMED_MODE_MIN_MINUTES,
		GameConfig.TIMED_MODE_MAX_MINUTES
	)
	normalized["grid_size"] = LayoutProfiles.sanitize_grid_size(normalized.get("grid_size", 40))
	normalized["game_elapsed_time"] = maxf(0.0, float(normalized.get("game_elapsed_time", 0.0)))
	return normalized

static func build_continue_game_config_state(data: Dictionary) -> Dictionary:
	return {
		"palette_name": str(data.get("palette_name", "\u7ecf\u5178")),
		"quality_name": str(data.get("quality_name", "\u4e2d")),
		"game_mode_name": str(data.get("game_mode_name", GameConfig.GAME_MODE_BASIC)),
		"time_limit_minutes": int(data.get("time_limit_minutes", GameConfig.DEFAULT_TIMED_MODE_MINUTES)),
	}

static func apply_continue_game_config(config_state: Dictionary) -> Dictionary:
	var palette_name: String = str(config_state.get("palette_name", "\u7ecf\u5178"))
	var quality_name: String = str(config_state.get("quality_name", "\u4e2d"))
	var game_mode_name: String = str(config_state.get("game_mode_name", GameConfig.GAME_MODE_BASIC))
	var time_limit_minutes: int = int(config_state.get("time_limit_minutes", GameConfig.DEFAULT_TIMED_MODE_MINUTES))
	GameConfig.set_palette_by_name(palette_name)
	GameConfig.set_quality_by_name(quality_name)
	GameConfig.set_game_mode_by_name(game_mode_name)
	GameConfig.set_time_limit_minutes(time_limit_minutes)
	return {
		"palette_name": palette_name,
		"quality_name": quality_name,
		"game_mode_name": game_mode_name,
		"time_limit_minutes": time_limit_minutes,
	}

static func build_continue_start_values(data: Dictionary) -> Dictionary:
	return {
		"grid_size": int(data.get("grid_size", 40)),
		"game_elapsed_time": float(data.get("game_elapsed_time", 0.0)),
	}

static func build_continue_selection_state(data: Dictionary, fallback_time_limit_minutes: int) -> Dictionary:
	return {
		"selected_palette_name": str(data.get("palette_name", "\u7ecf\u5178")),
		"selected_quality_name": str(data.get("quality_name", "\u4e2d")),
		"selected_game_mode_name": str(data.get("game_mode_name", GameConfig.GAME_MODE_BASIC)),
		"selected_time_limit_minutes": int(data.get("time_limit_minutes", fallback_time_limit_minutes)),
	}

static func apply_continue_selection_state(selection_state: Dictionary, controller_ref) -> Dictionary:
	if controller_ref == null:
		return selection_state

	controller_ref.selected_palette_name = str(selection_state.get("selected_palette_name", controller_ref.selected_palette_name))
	controller_ref.selected_quality_name = str(selection_state.get("selected_quality_name", controller_ref.selected_quality_name))
	controller_ref.selected_game_mode_name = str(selection_state.get("selected_game_mode_name", controller_ref.selected_game_mode_name))
	controller_ref.selected_time_limit_minutes = int(selection_state.get("selected_time_limit_minutes", controller_ref.selected_time_limit_minutes))
	return selection_state

static func build_continue_banner_config() -> Dictionary:
	return {
		"title": "\u9886\u571f\u6218\u4e89",
		"subtitle": "\u7ee7\u7eed\u4f5c\u6218",
		"accent": Color(0.84, 0.96, 1.0),
		"auto_hide": true,
	}

static func prepare_continue_start_plan(data: Dictionary, fallback_time_limit_minutes: int) -> Dictionary:
	var normalized: Dictionary = build_continue_runtime_state(data, fallback_time_limit_minutes)
	return {
		"data": normalized,
		"game_config": build_continue_game_config_state(normalized),
		"start_values": build_continue_start_values(normalized),
		"selection_state": build_continue_selection_state(normalized, fallback_time_limit_minutes),
		"banner": build_continue_banner_config(),
	}

static func apply_continue_start_plan(plan: Dictionary, controller_ref = null) -> Dictionary:
	var selection_state: Dictionary = plan.get("selection_state", {})
	var game_config_state: Dictionary = plan.get("game_config", {})
	return {
		"selection_state": apply_continue_selection_state(selection_state, controller_ref),
		"game_config": apply_continue_game_config(game_config_state),
	}

static func build_save_slot_summaries(save_slot_count: int, load_saved_data: Callable) -> Array:
	var result: Array = []
	for slot in range(1, save_slot_count + 1):
		var data: Dictionary = {}
		if load_saved_data.is_valid():
			data = load_saved_data.call(slot, true)

		var has_data: bool = not data.is_empty()
		var title: String = "\u7a7a\u5b58\u6863"
		var detail: String = "\u70b9\u51fb\u9009\u62e9\u6b64\u69fd"
		if has_data:
			var grid_size: int = LayoutProfiles.sanitize_grid_size(data.get("grid_size", 40))
			var mode_name: String = str(data.get("game_mode_name", GameConfig.GAME_MODE_BASIC))
			var quality_name: String = str(data.get("quality_name", "\u4e2d"))
			var elapsed: float = maxf(0.0, float(data.get("game_elapsed_time", 0.0)))
			var version: String = str(data.get("save_version", ""))
			title = "%s\uFF5C%d\u00D7%d\uFF5C%s" % [mode_name, grid_size, grid_size, quality_name]
			detail = "\u8fdb\u5ea6 %s\uFF5C\u7248\u672c %s" % [RuntimeHudController.format_time_text(elapsed), version]

		result.append({
			"slot": slot,
			"has_data": has_data,
			"title": title,
			"detail": detail,
		})
	return result

static func write_game_progress(selected_save_slot: int, save_path_template: String, save_slot_count: int, chambers: Dictionary, turrets: Dictionary, battlefield, bullet_container, event_roulette_controller, game_elapsed_time: float, is_game_over: bool, winner_label) -> bool:
	if battlefield == null:
		return false

	var save_path: String = get_save_path(selected_save_slot, save_path_template, save_slot_count)
	var data: Dictionary = SaveStateBuilder.build_save_payload(
		chambers,
		turrets,
		battlefield,
		bullet_container,
		event_roulette_controller,
		game_elapsed_time,
		is_game_over,
		selected_save_slot,
		winner_label
	)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true

static func build_slot_selection_status(selected_save_slot: int, has_save_data: bool) -> String:
	if has_save_data:
		return "\u5df2\u9009\u62e9\u5b58\u6863\u69fd %d\uff0c\u53ef\u7ee7\u7eed\u6216\u8986\u76d6\u5f00\u59cb" % selected_save_slot
	return "\u5df2\u9009\u62e9\u7a7a\u5b58\u6863\u69fd %d\uff0c\u65b0\u6e38\u620f\u4f1a\u4fdd\u5b58\u5728\u8fd9\u91cc" % selected_save_slot

static func refresh_menu_slot_ui(menu_save_slot_buttons: Dictionary, selected_save_slot: int, summaries: Array, menu_continue_button, has_selected_save: bool) -> void:
	if menu_save_slot_buttons.is_empty():
		return

	for summary in summaries:
		if not (summary is Dictionary):
			continue
		var slot: int = int(summary.get("slot", 1))
		if not menu_save_slot_buttons.has(slot):
			continue
		var button: Button = menu_save_slot_buttons[slot] as Button
		var marker: String = "\u25cf " if slot == selected_save_slot else ""
		var title: String = str(summary.get("title", "\u7a7a\u5b58\u6863"))
		button.text = "%s\u69fd%d  %s" % [marker, slot, title]
		button.self_modulate = Color(0.28, 0.54, 0.88) if slot == selected_save_slot else Color(0.16, 0.22, 0.32)

	if menu_continue_button != null and is_instance_valid(menu_continue_button):
		menu_continue_button.disabled = not has_selected_save
		menu_continue_button.text = "\u8bfb\u53d6\u69fd%d" % selected_save_slot
