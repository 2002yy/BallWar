# 编辑器交接指南 / Editor Handoff

日期: 2026-05-04

## 入口场景

```
res://scenes/Main.tscn
```

**只有一个场景文件**。内容仅 4 行：一个 `Node2D` 挂载 `Main.gd`。**全部 UI 由代码动态生成，无静态 .tscn 子场景。**

## UI 组件创建方式

| 组件 | 创建脚本 | 创建方式 | 方法 |
|---|---|---|---|
| 背景 | `Main.gd` | 代码 `ColorRect.new()` | `_ready()` |
| **开始菜单** | `StartMenuView.gd` | 代码静态工厂 | `StartMenuView.create(...)` |
| **战场** | `GameSceneBuilder.gd` | 代码静态工厂 | `GameSceneBuilder.create_battlefield(...)` |
| **炮塔** | `GameSceneBuilder.gd` | 代码静态工厂 | `GameSceneBuilder.create_turrets(...)` |
| **控制仓** | `GameSceneBuilder.gd` | 代码静态工厂 | `GameSceneBuilder.create_control_chambers(...)` |
| **运行时 HUD** (计时器/stage/leader/fps/event_label) | `GameHudView.gd` | 代码静态工厂 | `GameHudView.create_runtime_ui(...)` |
| **+球按钮** | `GameHudView.gd` | 代码静态工厂 | `GameHudView.create_control_buttons(...)` |
| **暂停面板** | `GameHudView.gd` | 代码静态工厂 | `GameHudView.create_pause_overlay(...)` |
| **事件转盘 View** | `EventRouletteView.gd` | 代码 `EventRouletteView.new()` | `Main.gd._start_game()` |
| **事件转盘 Controller** | `EventRouletteController.gd` | 代码 `EventRouletteController.new()` | `Main.gd._start_game()` |
| **Banner 弹窗** | `BannerController.gd` | 代码静态工厂 | `BannerController.show(...)` |

## 场景树结构（运行时）

```
Main (Node2D)
├── ColorRect (background)
├── Control (menu_layer)           ← 开始菜单期间存在
│   ├── Panel (装饰)
│   ├── Label "领土战争"
│   ├── Button "开始新游戏"
│   ├── Button "继续游戏"
│   ├── Button "网格大小"
│   ├── ... (选项控件)
│   └── Label (存档槽状态)
├── Node2D (game_layer)            ← 游戏中存在
│   ├── Battlefield
│   ├── BulletPool (子弹容器)
│   ├── BulletTrailLayer (拖尾)
│   ├── Turret_蓝方 / 红方 / 绿方 / 黄方
│   ├── Chamber_蓝方 / 红方 / 绿方 / 黄方
│   │   └── ControlBall × N
│   ├── EventRouletteController
│   └── EventRouletteView
├── Control (ui_canvas)            ← HUD 层
│   ├── Panel (top_panel)
│   │   ├── Label (计时器)
│   │   ├── Label (stage)
│   │   └── Label (leader)
│   ├── Label (fps_label / perf)
│   ├── Label (event_info_label)
│   ├── Button (设置)
│   ├── Button (暂停)
│   ├── Button (退出)
│   ├── EnergyButton × 4 (+球按钮)
│   ├── Panel (settings_panel)
│   └── Banner (弹窗)
```

## 如何在 Remote 场景树中查看

1. 在 Godot 编辑器中打开 `scenes/Main.tscn`
2. 点击 **运行项目** (F5) 或在桌面 `Godot_console.exe` 运行
3. 切换回编辑器窗口
4. 点击 **Remote** 标签（场景树面板顶上 `Scene` / `Remote` 两个标签）
5. 展开 `Main` → 展开 `game_layer` / `ui_canvas`
6. 可在 Inspector 中查看任意节点的运行时属性（position, text, modulate 等）

## 当前 UI 限制

- 所有 UI 字体、位置、大小、颜色均为**代码中硬编码**
- 修改 UI 必须改 `.gd` 脚本，无法在编辑器中拖拽调整
- 没有预制的 `.tscn` 子场景用于隔离 UI 组件

## 后续建议（不改本轮）

若未来将 UI 拆分为 .tscn，建议结构：

```
scenes/
  Main.tscn              ← 顶层入口（已有）
  StartMenu.tscn         ← 开始菜单独立场景，绑定 StartMenuView.gd
  GameHUD.tscn           ← HUD 独立场景，绑定 GameHudView.gd
  ControlChamber.tscn    ← 控制仓独立场景，绑定 ControlChamber.gd
  EventRouletteView.tscn ← 转盘独立场景，绑定 EventRouletteView.gd
```

这样可在编辑器中直接编辑 UI 布局、字体、颜色、信号连接，无需每次改代码重新运行。
