# Art reference / 素材来源备查

此目录保存历史素材原始压缩包、来源页、授权备查与少量保留的差异文件，**不是游戏运行时资源目录**。原始压缩包内的 235 份可无损恢复音频候选不再以解压副本形式持续跟踪。

- 游戏真正使用的资源放在 `assets/` 下，并由场景或脚本引用。
- `.gdignore` 会让 Godot 编辑器跳过此目录，避免把原始候选素材当作运行期资源扫描和导入。
- 原始压缩包、许可证备份和非等价文本差异仍保留在 Git；`.gdignore` 只影响 Godot 导入，不改变 Git 历史体积。
- 如果某素材需要进入游戏，请先确认来源授权，再复制选中的最终文件至 `assets/`，在正式资源路径中引用。不要直接在脚本或场景中依赖 `res://art_reference/`。
- 如果确有必要对本目录素材做编辑器预览，可以从文件管理器查看原文件；不要为浏览而删除 `.gdignore` 并重新导入整个历史目录。

## 原始音频包与解压副本去重（2026-11-22）

本次先在 [GitHub Actions 审计](https://github.com/2002yy/BallWar/actions/runs/44925925275) 中，用**文件名（不区分大小写）+ 未压缩字节长度 + SHA-256** 多重集合，比较七份原始音频归档与现有解压文件。校验结果 **7/7 归档的音频内容全部一致**，然后才删除 **235 个**可从保留压缩包恢复的音频副本，总计 **31,629,497 字节（约 30.16 MiB）**。此审计工作流是一次性迁移检查，不在正式代码中保留。

| 原始压缩包（仍保留在 `audio_cc0/`） | 历史解包目录（`audio_cc0_extracted/`） | 内容验证及已退役数量 |
|---|---|---:|
| `opengameart_10_clicks_and_switches.zip` | `oga_10_clicks_and_switches/` | 11 |
| `opengameart_50_cc0_scifi_sfx.zip` | `oga_50_cc0_scifi_sfx/` | 50 |
| `opengameart_beeps.zip` | `oga_interface_beeps/` | 16 |
| `opengameart_interface_sounds_kenney.zip` | `oga_interface_sounds_kenney/` | 100 |
| `opengameart_ui_sounds.zip` | `oga_ui_sounds/` | 11 |
| `opengameart_win_jingle.zip` | `oga_win_jingle/` | 34 |
| `opengameart_gui_sound_effects.7z` | `oga_gui_sound_effects/` | 13 |

**三个例外必须保留**：`oga_interface_sounds_kenney/License.txt`、`oga_interface_sounds_kenney/Kenney.url`、`oga_interface_sounds_kenney/Patreon.url` 的内容与 ZIP 中同名文件有字节差异。这些文件没有删除或被归档版覆盖；离线许可证网页仍在 `asset_gap_downloads/licenses/`。

需要试听旧候选时，可使用 ZIP 解压工具或 7-Zip，将原始包解压到**独立临时目录**，不要直接覆盖三个保留的差异文件。确定可分发许可后再把最终候选复制到 `assets/sfx/`。原本已在 `assets/sfx/` 的游戏素材完全不变。此次仅减少 Git 检出工作区文件，不清理历史 Git blobs，因此不能将节省空间理解为 Git 仓库历史体积下降。

## 退役的 Godot 导入元数据（2026-11-22）

Git 历史中曾有 **239 个** `art_reference/**/*.import` 文件，是 Godot 自动生成的导入映射（例如 `res://.godot/imported/...` 缓存路径），**不含原始音频字节，也不是许可证凭证**。本次删除这些已跟踪侧车文件，并由根目录 `.gitignore` 阻止它们再被提交。上批已经删除的三个音乐源文件也各留有一个失效的 `.import`，在本次一并清理。

原始压缩包、来源页及许可证文件继续保留；本节是此前删除 `.import` 文件时的历史记录。后续已验证并退役可还原的解压音频副本，详见下一节。正式运行资源位于 `assets/`，本次完全未修改。此清理减少 Git 工作区中的 239 个非资源文件（约 115 KiB），但不会重写 Git 历史。**不要对 `assets/` 下的 `.import` 元数据套用此规则**，它们属于正式资源而非归档备查目录。

## 已去重的音乐源文件（2026-11-22）

以下三份单独下载的音乐/环境音在 `assets/sfx/` 中已有**字节完全相同**的副本。为减少普通检出目录的重复文件，只删除了 `art_reference/asset_gap_downloads/music_candidates/` 下的三条路径，**没有删除正式音频，也没有修改源许可证页**。以下 Git Blob SHA 可以验证文件内容一致：

| 历史下载文件名 | 当前保留的文件 | Git Blob SHA |
|---|---|---|
| `opengameart_space_dungeon_bpm100.mp3` | `assets/sfx/music/battle_loop_space_dungeon_bpm100.mp3` | `028c102606b972286992f823ae87ba3498eaffcc` |
| `opengameart_space_echo.ogg` | `assets/sfx/music/menu_loop_space_echo.ogg` | `ec547783f2e69819dfda15e279d21a6b738ff5d0` |
| `opengameart_scifi_background_noise.ogg` | `assets/sfx/ambient/battle_ambient_scifi_noise.ogg` | `21497080f6cac545fbe4562f12579ba1701b5765` |

各来源作者、许可证与离线来源页仍记录于 [素材来源与许可证](../assets/ASSET_SOURCES_AND_LICENSES.md)，来源页备份在 `asset_gap_downloads/licenses/`。删除路径不会立即缩小 Git 历史或 Packfile；这里减少的是检出工作区的冗余副本。

Godot 官方说明：https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
