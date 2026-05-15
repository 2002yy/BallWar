extends RefCounted
class_name PlayerSettingsStore

const SETTINGS_PATH := "user://player_settings.json"

static func default_settings() -> Dictionary:
	return {
		"show_performance_info": OS.is_debug_build(),
		"low_effect_mode": false,
		"show_event_log": true,
	}

static func load_settings() -> Dictionary:
	var defaults := default_settings()
	if not FileAccess.file_exists(SETTINGS_PATH):
		return defaults
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return defaults
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return defaults
	var result := defaults.duplicate()
	for key in defaults.keys():
		if parsed.has(key):
			result[key] = parsed[key]
	return result

static func save_settings(settings: Dictionary) -> void:
	var clean := default_settings()
	for key in clean.keys():
		if settings.has(key):
			clean[key] = settings[key]
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(clean, "\t"))
	file.close()
