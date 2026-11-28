extends RefCounted

static func is_fresh(token_key: String, marker_name: String) -> bool:
	if OS.get_name() != "Windows":
		return false
	var root: String = OS.get_environment("APPDATA").replace("\\", "/").simplify_path()
	var token: String = OS.get_environment(token_key)
	var marker: String = root.path_join(marker_name)
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/").simplify_path()
	return (root.is_absolute_path() and not token.is_empty() and root.get_file() == token
		and user_dir.get_base_dir().nocasecmp_to(root.path_join("Godot/app_userdata")) == 0
		and FileAccess.file_exists(marker) and FileAccess.get_file_as_string(marker) == token
		and DirAccess.get_files_at(user_dir).is_empty())
