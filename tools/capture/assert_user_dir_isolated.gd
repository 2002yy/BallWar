extends SceneTree

# 采集工具的隔离前置断言，只做一件事：在任何存档读写发生之前，确认本进程的
# user:// 确实落在本次 mktemp 创建的隔离目录内。
#
# 为什么必须由 Godot 自己解析：Windows 上隔离靠 APPDATA，但 Linux 用
# XDG_DATA_HOME / HOME、macOS 用 ~/Library/Application Support，
# APPDATA 在那里不生效。若只靠 shell 里的 APPDATA 变量，脚本会以为自己
# 是隔离的，实际却写进玩家的真实存档 —— 这正是要防的静默失败。
#
# 因此：解析结果不在隔离目录内就立刻退出（非 0），由调用脚本 abort。
# 这是开发工具的保护，不修改正式存档系统，也不改任何玩法逻辑。
#
# Environment:
#   CAPTURE_ISOLATED_ROOT  本次采集的隔离根目录（与 APPDATA 同一路径）
# Exit: 0 隔离成立; 3 未设置或 user:// 解析到隔离目录之外。

func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	var expected: String = OS.get_environment("CAPTURE_ISOLATED_ROOT").strip_edges()
	var actual: String = ProjectSettings.globalize_path("user://")
	print("[UserDirGuard] expected_root=%s" % expected)
	print("[UserDirGuard] user_dir=%s" % actual)
	if expected == "" or actual == "":
		print("[UserDirGuard] FAIL: missing isolated root or user dir")
		quit(3)
		return
	if _is_within(actual, expected):
		print("[UserDirGuard] OK: user:// is inside the isolated root")
		quit(0)
	else:
		print("[UserDirGuard] FAIL: user:// resolves outside the isolated root; refusing to touch saves")
		quit(3)


func _is_within(actual: String, root: String) -> bool:
	# 统一分隔符、去掉尾斜杠、忽略盘符大小写；只接受「相等」或「子目录」，
	# 避免 /tmp/iso 与 /tmp/iso-evil 这种前缀误判。
	var a: String = actual.replace("\\", "/").trim_suffix("/").to_lower()
	var r: String = root.replace("\\", "/").trim_suffix("/").to_lower()
	return a == r or a.begins_with(r + "/")
