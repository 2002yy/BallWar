# .tscn 迁移审计 / Scene Migration Audit

日期: 2026-05-05 | version: v2.0.8

## 1. 运行时接入确认

| 场景 | Main.gd 加载位置 | 加载方式 | 运行时验证 |
|---|---|---|---|
| `StartMenu.tscn` | `_create_start_menu()` L136 | `load → instantiate → setup() → get_parts()` | ✓ `[StartMenu] Loaded scene` |
| `GameHUD.tscn` | `_create_ui()` L221 | `load → instantiate → create_dynamic_ui() → get_static_parts()` | ✓ `[GameHUD] Loaded scene` |
| `EventRouletteView.tscn` | `_create_event_roulette_system()` L263 | `load → instantiate → setup()` | ✓ `[EventRoulette] Loaded scene` |
| `SettingsPanel.tscn` | `GameHUD._ready()` L14 | `load → instantiate → add_child()` | ✓ `[GameHUD] Loaded SettingsPanel.tscn` |

**无孤儿 .tscn**：4 个场景全部接入真实运行流。

## 2. Fallback 机制

| 场景 | .tscn 存在时 | .tscn 不存在时 |
|---|---|---|
| `StartMenu.tscn` | load .tscn | `StartMenuView.create()` (old code) |
| `GameHUD.tscn` | load .tscn + `create_dynamic_ui()` | `GameHudView.create_runtime_ui()` (old code) |
| `EventRouletteView.tscn` | load .tscn | `event_view_script.new()` + setup |
| `SettingsPanel.tscn` | load .tscn | `Panel.new()` code-generated fallback |

**旧代码未删除**：`StartMenuView.gd`、`GameHudView.create_runtime_ui()` 均保留为 fallback。

## 3. 重复来源检查

| 场景 | 内置节点 | 外部 .tscn | 状态 |
|---|---|---|---|
| StartMenu | — | `StartMenu.tscn` ✓ | 单一来源 |
| GameHUD | 已移除内置 SettingsPanel | `SettingsPanel.tscn` ✓ | 单一来源 |
| EventRouletteView | stage_panel 由 .tscn 提供 | `EventRouletteView.tscn` ✓ | 单一来源 |
| SettingsPanel | — | 由 GameHUD 加载 | 单一来源 |

**无重复节点**：v2.0.8 已验证（dupe check 27 PASS）。

## 4. 属性控制边界

| 场景 | .tscn 控制 | 代码覆盖 |
|---|---|---|
| **StartMenu** | Position, Size, 颜色, 字体, StartButton.text | ContinueButton/SlotButton/StatusLabel text (by `_refresh_slots()`), OptionButton 选项 (by `_init_options()`) |
| **GameHUD** | fps_label/event_label Position, Size, 颜色, 字体, 侧按钮 Position/颜色 | fps_label.text (by perf debug), event_label.text (by event controller), 按钮 disabled (by pause state) |
| **EventRouletteView** | stage_panel 初始 Size, 子节点 Position, 颜色, 字体, 指针颜色 | stage_panel.position (by _layout_stage, depends grid_size), value_label.text (by animation), result_label.text/visible (by animation) |
| **SettingsPanel** | Panel Size/颜色, ContentLabel 字体/颜色 | ContentLabel.text (by `show_content()`) |

详细表参见 `README_v2_0_7_start_menu_scene.md`。

## 5. 人工验收清单

### StartMenu
- [ ] 打开游戏 → 看到开始菜单
- [ ] 控制台输出 `[StartMenu] Loaded scene StartMenu.tscn`
- [ ] 切换地图大小/模式/画质/限时/配色正常
- [ ] 点击"开始 / 覆盖存档" → 游戏启动
- [ ] 存档槽 1~5 选中高亮正确
- [ ] 点击"读取槽N" → 继续游戏
- [ ] 游戏中暂停 → 退出 → 返回菜单仍正常

### GameHUD
- [ ] 控制台输出 `[GameHUD] Loaded scene` 和 `[GameHUD] Loaded SettingsPanel.tscn`
- [ ] fps_label 右下角显示 perf 文本
- [ ] event_label 显示事件倒计时
- [ ] settings/pause/exit 按钮可点击
- [ ] 暂停弹出 overlay，显示"继续"/"保存退出"
- [ ] 60×60 地图底部 HUD 不越界

### EventRouletteView
- [ ] 事件转盘从上方正确下降出现
- [ ] 双轮盘（阵营/效果）文字位置正确
- [ ] 指针对齐轮盘
- [ ] 加速/减速动画正常
- [ ] 最终结果文字显示
- [ ] 事件结束后隐藏
- [ ] 游戏过程中不遮挡关键 HUD
- [ ] 10×10 小地图转盘位置正常

### SettingsPanel
- [ ] 点击"设置"按钮 → 面板弹出
- [ ] 面板显示画质/布局说明文字
- [ ] 再次点击 → 面板隐藏
- [ ] 控制台输出 `[GameHUD] Loaded SettingsPanel.tscn`

## 6. 测试覆盖

```
GameHUDSceneTest        19 PASS   (load + 8 keys + null + type check)
SettingsPanelSceneTest   9 PASS   (load + nodes + show/hide methods)
StartMenuSceneTest      22 PASS   (load + 6 keys + type + 4 visual nodes)
EventRouletteSceneTest  13 PASS   (load + StagePanel + 7 sub-nodes)
SmokeTestRunner         33 PASS
IntegrationTestRunner  133 PASS
LayoutSanityTestRunner 330 PASS
合计                   559 PASS
```
