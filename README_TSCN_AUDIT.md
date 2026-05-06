# .tscn 迁移审计 / Scene Migration Audit

日期: 2026-05-06

## 1. 当前接入状态

| 组件 | 场景 | 运行入口 | 当前状态 | 人类可调性 |
|---|---|---|---|---|
| 开始菜单 | `scenes/ui/StartMenu.tscn` | `Main.gd._create_start_menu()` | 已接入 | 高 |
| 预览插画 | `scenes/ui/PreviewScene.tscn` | `StartMenu.gd._init_decor()` | 已接入 | 高 |
| 游戏 HUD | `scenes/ui/GameHUD.tscn` | `Main.gd._create_ui()` | 已接入 | 中 |
| 设置面板 | `scenes/ui/SettingsPanel.tscn` | `GameHUD.gd._load_settings_panel()` | 已接入 | 高 |
| 事件转盘 | `scenes/ui/EventRouletteView.tscn` | `Main.gd._create_event_roulette_system()` | 已接入 | 中 |

结论：
- 目前 5 个 UI 场景都进入了真实运行流。
- `PreviewScene.tscn` 已经不是代码画板，而是可在编辑器中直接拖节点的预览子场景。
- `GameHUD.tscn` 和 `EventRouletteView.tscn` 仍有较多运行时布局代码，属于“已迁入场景，但还没完全把布局控制权交给 `.tscn`”。

## 2. Fallback 现状

| 组件 | 优先路径 | fallback |
|---|---|---|
| `StartMenu.tscn` | `load -> instantiate -> setup() -> get_parts()` | `StartMenuView.create()` |
| `PreviewScene.tscn` | `StartMenu.gd` 中实例化场景 | `MenuDecor.gd` |
| `GameHUD.tscn` | `load -> instantiate -> setup_static() -> get_static_parts()` | `GameHudView.create_runtime_ui()` |
| `EventRouletteView.tscn` | `load -> instantiate -> setup()` | `event_view_script.new() + setup()` |
| `SettingsPanel.tscn` | `load -> instantiate -> add_child()` | `Panel.new()` |

说明：
- fallback 仍然保留，目的是防止场景文件丢失时直接崩。
- 但新的 UI 调整应当默认以 `.tscn` 为唯一编辑入口，不再回到旧代码路径做布局。

## 3. 哪些属性应由 `.tscn` 控制

### StartMenu / PreviewScene

`.tscn` 控制：
- `RootPanel`
- `ConfigPanel`
- `ModeTip`
- `StartButton`
- `ContinueButton`
- `SavePanel`
- `MenuStatusLabel`
- `ChamberPreview`
- `PreviewScene` 内部的 `Board` / `Chamber*` / `Turret*`

代码动态更新：
- `OptionButton` 的条目和选中值
- `ContinueButton.text`
- 各存档按钮的 `text` / `tooltip_text` / `self_modulate`
- `MenuStatusLabel.text`
- `PreviewScene` 的加载与挂接

约束：
- `StartMenu.gd` 不应覆盖上述节点的 `position / size / scale`
- `build_start_menu_scene.gd` 已加保护，默认禁止重新覆盖人工调整过的 `StartMenu.tscn`

### GameHUD

`.tscn` 控制：
- 顶栏节点结构
- 各标签/按钮/背景的默认样式
- 暂停面板层级与默认外观

代码动态更新：
- `fps_label.text`
- `event_label.text`
- 顶栏百分比条数值与颜色填充
- 暂停、设置、退出按钮的信号连接
- 根据布局配置做运行时位置微调

当前限制：
- `GameHUD.gd.setup_static()` 仍在大量写入 `position / size`
- 这意味着 `GameHUD.tscn` 还不是完全的人类所见即所得场景

### EventRouletteView

`.tscn` 控制：
- `StagePanel` 节点存在
- 标题、左右标签、结果标签、指针等初始层级

代码动态更新：
- 下落/抬升动画
- 紧凑模式下的尺寸切换
- 文案滚动与结果显示

当前限制：
- `_layout_stage()` 仍会统一改写 `stage_panel` 及子节点尺寸和位置

## 4. 仍建议继续迁 `.tscn` 的部件

优先继续迁移：
- `GameHUD` 的运行时布局参数
- `EventRouletteView` 的 stage 布局参数
- `+球` 控制按钮的可视容器

继续保持代码：
- `Battlefield`
- `Bullet`
- `BulletPool`
- `ControlBall`

后续再评估：
- `ControlChamber`
- `Turret`

判断标准：
- 人要频繁拖位置、改视觉、调间距：继续迁 `.tscn`
- 节点数量巨大或纯运行时生成：保留代码

## 5. 现在最像“人类可用”的入口

直接在 Godot 编辑器里调这些场景：
- `scenes/ui/StartMenu.tscn`
- `scenes/ui/PreviewScene.tscn`
- `scenes/ui/SettingsPanel.tscn`

谨慎修改：
- `scenes/ui/GameHUD.tscn`
- `scenes/ui/EventRouletteView.tscn`

原因：
- 后两者虽然已经接入场景，但仍有较多运行时布局覆盖，人工修改后不一定完全按编辑器所见运行。

## 6. 下一阶段目标

### 低风险
- 继续把 `GameHUD.gd` / `EventRouletteView.gd` 中的固定布局常量搬回 `.tscn`
- 让脚本只负责 `text / visible / disabled / selected / signal`

### 中风险
- 给 `GameHUD` 增加统一的 `SceneRefs` 或 `UIRegistry`
- 让 `Main.gd` 不再四处保存零散 UI 引用

### 高风险
- `ControlChamber` / `Turret` 解耦
- 玩法节点信号和状态流重组
