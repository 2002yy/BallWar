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
	return sanitize_settings(parsed)

static func save_settings(settings: Dictionary) -> void:
	_write_settings_atomically(SETTINGS_PATH, sanitize_settings(settings))


static func _write_settings_atomically(path: String, clean: Dictionary) -> bool:
	# Stage a complete JSON file next to the current settings file; never
	# truncate the authoritative file before the replacement succeeds.
	var temp_path: String = "%s.tmp" % path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(clean, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false

	var temp_absolute: String = ProjectSettings.globalize_path(temp_path)
	var final_absolute: String = ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(temp_absolute, final_absolute) != OK:
		DirAccess.remove_absolute(temp_absolute)
		return false
	return true

static func sanitize_settings(settings: Dictionary) -> Dictionary:
	var defaults := default_settings()
	return {
		"show_performance_info": _coerce_bool(settings.get("show_performance_info", defaults["show_performance_info"]), bool(defaults["show_performance_info"])),
		"low_effect_mode": _coerce_bool(settings.get("low_effect_mode", defaults["low_effect_mode"]), bool(defaults["low_effect_mode"])),
		"show_event_log": _coerce_bool(settings.get("show_event_log", defaults["show_event_log"]), bool(defaults["show_event_log"])),
	}

static func _coerce_bool(value, default_value: bool) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	if value is String:
		var normalized: String = value.strip_edges().to_lower()
		match normalized:
			"1", "true", "yes", "on":
				return true
			"0", "false", "no", "off", "":
				return false
			_:
				return default_value
	return default_value
