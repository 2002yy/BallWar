# M01 主菜单 · 第一阶段（无 Shader 版）

日期：2026-11-27　分支：`feat/m01-menu`（基于 `main@30e0008`）

## 1. 这一阶段做了什么

按 H 裁定：先用**无 Shader 版**把完整流程做通，提交实机截图给设计审查，
通过之后才推进材质增强。所以本轮只做结构、导航、皮肤绘制，不做贴图与发光。

`StartMenu` 从"一块 840×684 竖排面板"改成"一台机械控制台"：

- 左侧约 **30%** 操作区（标题 / 页面宿主 / 状态栏 / 提示）
- 右侧约 **70%** 战场预览台：机械外框 + 监控窗 + **真实 PreviewScene**
- 四个页面：主菜单 / 选择玩法 / 对局配置 / 继续游戏

预览台里放的仍然是 `PreviewScene.tscn` 的实例（四个控制仓 + 四个炮台），
没有任何一张替代用的静态图。框是画出来的，战场是活的。

## 2. 结构

```
StartMenu (CanvasLayer)
├── Shade                     整屏压暗
├── RootPanel (Panel)         钢板外壳
│   ├── ShellArt (MechShell)  切角 / 螺栓 / 能源灯 / 警示斜纹
│   └── Columns (Control)     两栏都按布局矩形显式摆放
│       ├── ActionColumn (VBox)
│       │   ├── TitleLabel / SubtitleLabel / TitleRule
│       │   ├── PageHost → MainMenuPage / ModeSelectPage /
│       │   │              MatchConfigPage / ContinuePage
│       │   ├── MenuStatusLabel
│       │   └── MobileHint
│       └── StageColumn
│           ├── StageChrome (MechStage)  外框 / 四角锁扣 / 阵营色标 / 刻度条
│           ├── PreviewContainer (clip) → ChamberPreview → PreviewScene
│           └── StageCaption
```

节点绑定全部换成场景唯一名（`%Name`）。旧的
`RootPanel/MainVBox/ConfigPanel/ConfigVBox/ConfigRow1/SizeOptionBox/GridSizeOption`
这类长路径在新脚本里一个都不剩。

### 数据驱动，而不是写死

- 模式卡片由 `GameConfig.get_game_mode_names()` 生成，场景里没有四个写死的按钮。
- 存档槽由 `Main.SAVE_SLOT_COUNT` 生成，数量是业务参数，UI 只跟随。
- 地图名走 `MatchConfig.CLASSIC_MAP_ID` 查表；表里只有一张图，界面上也就只显示一张，
  不为还不存在的地图摆一排灰色按钮。

四种现有玩法（基础 / 占领 / 限时 / 狂野）完整保留，规则文案仍由
`build_mode_tip_text()` 统一产出。

## 3. 新增文件

| 文件 | 作用 |
|---|---|
| `scripts/ui/MechTheme.gd` | 纯 StyleBoxFlat 主题：金 / 深蓝钢 / 幽灵三档按钮变体、槽位与模式卡选中态、Label 变体。无 Shader、无贴图。 |
| `scripts/ui/MechShell.gd` | 外壳绘制：45° 切角、双线钢边、四角螺栓、能源灯、警示斜纹。 |
| `scripts/ui/MechStage.gd` | 预览台外框：切角监控窗、四角锁扣、阵营色标、底部刻度。 |
| `tools/capture/capture_menu.gd` | 菜单截图台：跑真 `Main.tscn`，逐页截图。 |
| `tools/capture/run_menu_capture.sh` | 四档截图一键运行。 |

`StyleBoxFlat` 只有圆角，做不出机械外壳的直角切削，所以轮廓用
`draw_colored_polygon` / `draw_polyline` / `draw_circle` 画 —— 仍然是引擎原生 UI，
不是 Shader。

## 4. 布局权威仍在 LayoutCoordinator

`_calculate_start_menu_layout()` 重写，新增键：

`columns_margin` / `columns_margin_bottom` / `column_gap` /
`action_column_rect` / `stage_rect` /
`preview_header_height` / `preview_footer_height` / `preview_side_pad` /
`preview_size` / `preview_center` / `preview_scale`

面板尺寸随视口增长但设了上下限（宽 960–1400，高 600–820）：不随视口长的话
4K 下就是一块缩略图，不设上限则一块卡片飘在大画布正中。

预览缩放由监控窗反推，并保证**内容包围盒的中心**落在窗心（`PreviewScene` 的
内容本来就不以原点对称，直接把原点放中心会歪）。

两栏用显式矩形摆放而不是 HBox 协商：容器会按子节点最小宽重新分配，一旦某个
按钮文字变长，预览台就被挤窄，而预览缩放是按布局算的 —— 两者不同步就会重叠。

## 5. 两个真实缺陷与根因（本轮踩到的）

### 5.1 自动换行标签在首帧把整列撑到上千像素

`setup()` 跑在"刚 `add_child`、还没排过版"的那一帧。此刻自动换行标签的宽度
是 0，Godot 算出来的最小高度是"一行一个字"，于是 `ActionColumn` 的最小高度
一度接近 1100 px。`Control.set_size()` 会把尺寸夹到最小尺寸，**夹上去之后
不会自己缩回来** —— 最小高度后来恢复正常也没用，整列永久偏高，
状态栏和底部提示被推到面板外面（实机截图里那一块直接是空的）。

修法两层：

1. `_fix_wrapped_label_widths()` 在设列尺寸**之前**先把标签宽度钉到列宽，
   避免首帧就按宽度 0 算最小高度；
2. `_settle_layout()` 在下一帧补一次完整重排，兜住任何残留的瞬时值。

### 5.2 隐藏页面不排版，尺寸被卡在假最小值

隐藏的 `Control` 不会被父节点重排，所以隐藏页面的子节点宽度一直是 0；
一旦 `set_size()` 在那一刻被假的最小高度夹住（实测「继续游戏」页被撑到 757），
切回来时导航行就被顶到面板外。

修法：页面**不挂锚点**，尺寸由 `PageHost` 显式铺（`_fit_pages()`），
并监听页面自身的 `resized` —— 等子节点排完版、最小尺寸回落时会再进来一次，
这次就能压回目标值；`show_page()` 另外再补一帧重排。

### 5.3 槽位按钮被压成 20 px

`clip_text = true` 让按钮不再把文字宽度算进最小宽度，单列 `GridContainer`
于是把列宽压到内边距那么宽。修法是显式 `SIZE_EXPAND_FILL`，撑满整列。

这三条都在 `StartMenuSceneTestRunner` 里有对应断言（状态栏 / 底部提示必须落在
面板内、每页每个按钮必须落在面板内），不是改完就算。

## 6. 验证证据

| 项 | 结果 |
|---|---|
| `tools/tests/run_headless_suite.sh` | **14 / 14 PASS** |
| `StartMenuSceneTestRunner` | **96 checks PASS**（原有用例的节点查找改为唯一名，业务断言一条没删；新增导航与每页几何） |
| 业务未变 | 槽位文案、开始/继续按钮文案、状态文案、`build_slot_label` / `build_continue_button_text` 签名与输出全部不变（`SaveFlowController` 直接 preload 这两个函数） |
| 玩法未变 | 未改 `Bullet` / `BulletPool` / 武器行为 / 物理步；开局仍走 `Main._start_game(grid_size)` |
| 截图 | `art_captures/menu/` 13 张：1120×720 / 1920×1080 / 3840×2160（真机路径）/ 3840×2160（原生画布压力测试） |

### 关于两档 4K

`project.godot` 是 `canvas_items + expand`，真机在 4K 上跑的是 **1280×720 的逻辑
画布再放大 3 倍**，不是 3840×2160 的逻辑画布。所以：

- `3840x2160_*` 用 `SubViewport.size_2d_override` 复现了这层拉伸，
  是**玩家在 4K 显示器上真正会看到的画面**；
- `3840x2160_native_*` 是压力测试：逻辑画布真的给到 3840×2160，
  只验证布局不塌，不代表线上画面。

## 7. 明确没做 / 留给下一阶段

- 材质增强：金属高光、玻璃控制仓的菲涅尔感、能量灯呼吸 —— 要等截图审查通过
- 图标系统：`assets/ui/game_icons_scifi` 的 SVG 还没接进按钮
- 动效：翻页过渡、选择反馈音（A4 已冻结，不动音频）
- 背景音乐：按 A4 裁定不加
- 移动端专项：`is_mobile` 分支已给出紧一档的数值，但本机没有实机验证

## 8. 已知限制

- 1920×1080 是 `canvas_items` 1.5 倍放大，文字会比 1120 略软 —— 这是线上既有行为，
  截图如实反映，没有为了好看去改投影规则。
- 左栏在中低分辨率下约剩一格空白（配置卡与版本号之间），是窄栏 + 短列表的自然结果。
- `MobileHint` 与外壳左下角警示斜纹距离较近，缩到 720p 时略挤。
