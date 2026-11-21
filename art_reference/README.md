# Art reference / 素材来源备查

此目录保存历史素材下载包、解压后的候选资源、授权与来源调研材料，**不是游戏运行时资源目录**。

- 游戏真正使用的资源放在 `assets/` 下，并由场景或脚本引用。
- `.gdignore` 会让 Godot 编辑器跳过此目录，避免把约 500 个候选/原始素材当作运行期资源扫描和导入。
- 本目录内容仍保留在 Git 中，方便追溯素材来源、授权与替换过程；`.gdignore` **不会缩小 Git 仓库，也不会删除任何素材**。
- 如果某素材需要进入游戏，请先确认来源授权，再复制选中的最终文件至 `assets/`，在正式资源路径中引用。不要直接在脚本或场景中依赖 `res://art_reference/`。
- 如果确有必要对本目录素材做编辑器预览，可以从文件管理器查看原文件；不要为浏览而删除 `.gdignore` 并重新导入整个历史目录。

Godot 官方说明：https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
