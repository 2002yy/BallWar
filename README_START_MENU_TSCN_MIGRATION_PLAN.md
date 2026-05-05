# StartMenu.tscn 迁移方案

日期: 2026-05-04 | 状态: 图纸阶段，不实际迁移

## 目标

将 `StartMenuView.gd` 中的硬编码 UI 创建迁移到 `scenes/StartMenu.tscn`，使菜单布局可在 Godot 编辑器中可视化编辑。`StartMenuView.gd` 保留纯逻辑（选项回调、save slot 刷新、状态管理）。

## 节点清单

StartMenu.tscn 根节点为 `CanvasLayer`，以下为完整节点树：

```
CanvasLayer (MenuLayer)
├── ColorRect (Shade)
│   color = Color(0.02, 0.03, 0.05, 0.72)
│   size = full viewport
│
├── Panel (MainPanel)                              — 840×670, 居中偏上
│   │   position = 使用 anchor 居中
│   │   self_modulate = Color(0.98, 0.99, 1.0, 0.96)
│   │
│   ├── ColorRect (PanelBg)
│   │   position = (8, 8)    size = 824×654
│   │   color = Color(0.08, 0.12, 0.18)
│   │
│   ├── Label (TitleLabel)
│   │   position = (150, 16)  size = (540, 56)
│   │   text = "领土战争"
│   │   font_size = 44     color = gold(#F2D8B8)
│   │
│   ├── Label (SubtitleLabel)
│   │   position = (180, 72)  size = (480, 24)
│   │   text = "四控制仓 · 四角炮台 · 领土争夺"
│   │   font_size = 18     color = light blue
│   │
│   ├── Label (MobileHintLabel)
│   │   position = (180, 98)  size = (480, 22)
│   │   text = "电脑 / 安卓均可游玩"
│   │   font_size = 15
│   │
│   ├── MenuDecor (ChamberPreview)                  — 装饰性控制仓预览
│   │   position = (420, 260)  scale = (0.78, 0.78)
│   │
│   ├── Panel (ConfigPanel)                         — 设置区域
│   │   │   position = (48, 372)  size = (744, 168)
│   │   │
│   │   ├── ColorRect (ConfigBg)
│   │   │   position = (4, 4)  size = (736, 160)
│   │   │   color = Color(0.12, 0.16, 0.23)
│   │   │
│   │   ├── Label "地图大小"    (18, 14)  (88, 24)   font_size=17
│   │   ├── OptionButton (SizeOption)  (104, 10)  (126, 36)
│   │   │   选项: 10×10 ~ 60×60 (id=grid_size)
│   │   │   默认 select(3) → 40×40
│   │   │
│   │   ├── Label "游戏模式"    (258, 14)  (76, 24)
│   │   ├── OptionButton (ModeOption)  (340, 10)  (136, 36)
│   │   │   选项: 基础/占领/限时/狂野
│   │   │   默认 select(0) → 基础模式
│   │   │
│   │   ├── Label "画质"        (506, 14)  (42, 24)
│   │   ├── OptionButton (QualityOption)  (548, 10)  (60, 36)
│   │   │   选项: 低/中/高
│   │   │   默认 select(1) → 中
│   │   │
│   │   ├── Label "限时"        (626, 14)  (44, 24)
│   │   ├── SpinBox (TimeSpin)  (668, 10)  (58, 36)
│   │   │   min=5  max=15  step=1  value=5
│   │   │
│   │   ├── Label "配色方案"    (18, 58)  (88, 24)
│   │   ├── OptionButton (PaletteOption)  (104, 54)  (162, 36)
│   │   │   选项: 默认随机 + 调色板列表
│   │   │   默认 select(0)
│   │   │
│   │   ├── Label (ModeTipLabel)
│   │   │   (288, 52)  (270, 76)  autowrap
│   │   │   多行文字: 占领/限时/狂野 规则说明
│   │   │
│   │   └── Button (StartButton)
│   │       (590, 72)  (134, 52)
│   │       text = "开始 / 覆盖存档"
│   │       font_size = 18
│   │       self_modulate = blue
│   │
│   ├── Panel (SavePanel)                           — 存档选择区域
│   │   │   position = (48, 548)  size = (744, 82)
│   │   │
│   │   ├── ColorRect (SaveBg)
│   │   │   position = (4, 4)  size = (736, 74)
│   │   │
│   │   ├── Label (SaveTitle)
│   │   │   (14, 6)  (300, 22)
│   │   │   text = "选择存档槽..."
│   │   │
│   │   ├── Button (SlotButton_1)  (14, 32)   (136, 36)   font_size=12
│   │   ├── Button (SlotButton_2)  (158, 32)  (136, 36)
│   │   ├── Button (SlotButton_3)  (302, 32)  (136, 36)
│   │   ├── Button (SlotButton_4)  (446, 32)  (136, 36)
│   │   └── Button (SlotButton_5)  (590, 32)  (136, 36)
│   │
│   ├── Button (ContinueButton)
│   │   (648, 500)  (120, 44)
│   │   text = "读取槽1" (动态更新)
│   │   font_size = 18     self_modulate = green
│   │
│   └── Label (MenuStatusLabel)
│       (120, 636)  (600, 22)
│       text = "当前存档槽：1"
│       font_size = 15     color = orange
│       outline_size = 2
```

## 信号连接表

| 节点 | 信号 | 连接到 |
|---|---|---|
| SizeOption | `item_selected(index)` | `owner._on_size_selected(index)` → 根据 `get_item_id(index)` 设置 `owner.selected_grid_size` |
| ModeOption | `item_selected(index)` | `owner._on_mode_selected(index)` → `owner.selected_game_mode_name = get_item_text(index)` |
| QualityOption | `item_selected(index)` | `owner._on_quality_selected(index)` → `owner.selected_quality_name = get_item_text(index)` |
| TimeSpin | `value_changed(value)` | `owner._on_time_changed(value)` → `owner.selected_time_limit_minutes = clampi(int(value), 5, 15)` |
| PaletteOption | `item_selected(index)` | `owner._on_palette_selected(index)` → `owner.selected_palette_name = get_item_text(index)` |
| StartButton | `pressed()` | `owner._start_game(owner.selected_grid_size)` |
| SlotButton_1~5 | `pressed()` | `owner._select_save_slot(1~5)` |
| ContinueButton | `pressed()` | `owner._continue_saved_game()` |

## StartMenuView.gd 迁移后职责

脚本改为绑定 `.tscn` 的 `CanvasLayer` 根节点，保留以下纯逻辑方法：

```gdscript
extends CanvasLayer
class_name StartMenuView

@onready var size_option: OptionButton = $MainPanel/ConfigPanel/SizeOption
@onready var mode_option: OptionButton = $MainPanel/ConfigPanel/ModeOption
# ... (其余 @onready)
@onready var save_slot_buttons: Array = [$MainPanel/SavePanel/SlotButton_1, ...]

func _ready() -> void:
    _init_defaults()      # 设置 owner.selected_* 默认值
    _connect_signals()    # 连接所有信号到 owner 方法
    _refresh_slots()      # 根据 save_summaries 刷新按钮文字

func _refresh_slots(save_summaries: Array) -> void:
    # 更新 5 个 SlotButton 的 text/tooltip/self_modulate
    # 更新 ContinueButton.text = "读取槽%d"
    # 更新 MenuStatusLabel.text
    # 逻辑从原代码 line 183-226 移入
```

## 不迁移的部分

- **MenuDecor** — 装饰性控制仓预览（`MenuDecor.gd`），保留 `instance` 方式加载，仍是 `_draw()` 自定义绘制
- **存档数据获取** — `_get_save_slot_summaries()` 仍在 `Main.gd` 中，通过 `owner` 引用调用
- **开始游戏流程** — `_start_game()` 仍在 `Main.gd` 中，StartMenuView 只负责 UI 和点击转发

## 迁移步骤（建议顺序）

1. 在 Godot 编辑器中新建 `scenes/StartMenu.tscn`
2. 建 CanvasLayer 根节点，挂 `StartMenuView.gd`
3. 按节点清单手动放置所有 Control 子节点
4. 在 Inspector 中为每个 OptionButton 添加 item（可暂不写代码）
5. 修改 `Main.gd`：从 `StartMenuView.create()` 调用改为 `load("res://scenes/StartMenu.tscn").instantiate()`
6. 运行烟冒测试，确认菜单可渲染、按钮可点击
7. 逐步把信号连接从代码移到 `.tscn` 的 Node → Signals 面板
8. 清理 `StartMenuView.gd` 中已移到 .tscn 的节点创建代码

## 风险与注意事项

- **不本轮迁移**：目前仅为图纸阶段
- **Owner 引用**：开始菜单的按钮回调大量依赖 `owner` (Main.gd)，迁移后需确认 `owner` 引用在 `.tscn` 实例化后仍然有效
- **动态节点**：5 个 SlotButton 目前是 for-loop 动态创建；迁移后可改为 5 个静态节点 → `@onready` 数组
- **向后兼容**：迁移后旧存档、所有玩法规则、事件规则均不受影响
