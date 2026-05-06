# Main.gd 职责审计 / Main.gd Responsibility Audit

日期: 2026-05-06  
版本目标: v2.1.1  
范围: 仅审计 `scripts/Main.gd` 当前职责，不改玩法，不立即拆文件

## 1. 审计目标

这份文档的目的不是立刻重构 `Main.gd`，而是先把它现在承担的责任完整摊开，作为后续拆分：
- `GameStateCoordinator.gd`
- `SaveFlowController.gd`
- `UIRegistry.gd`

的前置地图。

当前 `Main.gd` 仍同时承担：
- 游戏启动
- 开始菜单
- HUD 创建
- 场景创建
- 暂停/继续
- 保存/读取
- 胜负判断入口
- 事件系统连接
- 设置面板开关
- 返回菜单
- 游戏结束处理

## 2. 分类标准

按 6 类归档：

- A. 生命周期入口
- B. UI 创建/切换
- C. 游戏状态流程
- D. 存档流程
- E. 事件系统流程
- F. 临时兼容/旧逻辑

## 3. 总体结论

### 应长期保留在 Main.gd 的入口

- `_ready()`
- `_process()`
- `_create_start_menu()`
- `_create_ui()`
- `_create_event_roulette_system()`

说明：
- 这些函数更像顶层编排入口，适合保留在 `Main.gd`
- 但它们内部依赖的具体逻辑应继续向 controller / scene script 下放

### 后续最适合外移的职责

- 开始/暂停/结束/返回菜单流程
- 保存/读档流程
- restore 编排流程
- UI 引用管理

### 暂缓外移的职责

- `ControlChamber` / `Turret` 直接状态恢复
- 事件系统 controller/view 的运行时细节
- 游戏结束后对现有玩法节点的直接停机处理

## 4. 函数审计表

| 函数名 | 分类 | 当前职责 | 是否保留在 Main.gd | 建议迁移目标 | 风险等级 | 是否需要测试保护 | 备注 |
|---|---|---|---|---|---|---|---|
| `_ready()` | A | 初始化 process mode、随机种子、布局模式、背景、开始菜单 | 是 | — | 低 | 是 | 顶层入口；依赖 `_detect_mobile_layout()`、`_create_background()`、`_create_start_menu()` |
| `_process(delta)` | A | 驱动 UI 动画、恢复队列、计时、perf HUD、meta HUD、胜负检测 | 是 | 部分后续可拆到 `GameStateCoordinator.gd` | 中 | 是 | 依赖 `pending_restore_bullets`、`chambers`、`RuntimeHudController`、`UIAnimationController` |
| `_detect_mobile_layout()` | A | 根据平台和屏幕判断是否移动布局 | 是 | — | 低 | 否 | 纯工具型入口，依赖 `OS`、`DisplayServer`、`GameConfig` |
| `_toggle_settings_panel()` | B | 设置面板显示/隐藏切换 | 暂缓 | 后续可并入 `UIRegistry.gd` 或 `GameStateCoordinator.gd` | 低 | 是 | 依赖 `settings_panel`、`GameConfig.get_quality_name()`、`is_mobile_layout` |
| `_create_background()` | B | 创建主背景色块 | 是 | — | 低 | 否 | 简单顶层初始化，适合保留 |
| `_create_start_menu()` | B | 加载 `StartMenu.tscn` 或 fallback，收集菜单引用 | 是 | 后续配合 `UIRegistry.gd` 瘦身 | 低 | 是 | 已将细节委托给 `StartMenu.gd` / `StartMenuView.gd` |
| `_start_game(grid_size, suppress_banner, clear_save)` | C | 规范地图尺寸、应用配置、清菜单、清游戏层、重建全部运行时系统 | 否 | `GameStateCoordinator.gd` | 中 | 是 | 当前是最大流程函数之一；依赖布局、存档清理、场景创建、HUD、事件、banner |
| `_create_battlefield(grid_size)` | C | 调 `GameSceneBuilder` 创建战场和子弹容器 | 暂缓 | 后续可由 `GameStateCoordinator.gd` 调用 | 低 | 是 | 已较薄；主要是 builder 入口 |
| `_create_turrets()` | C | 调 `GameSceneBuilder` 创建炮塔并回填到子弹容器 | 暂缓 | 后续可由 `GameStateCoordinator.gd` 调用 | 低 | 是 | 依赖 `bullet_container.set_tracked_turrets()` |
| `_create_control_chambers()` | C | 调 `GameSceneBuilder` 创建控制舱并同步时间 | 暂缓 | 后续可由 `GameStateCoordinator.gd` 调用 | 低 | 是 | 依赖 `current_layout`、`chamber_scale`、`_sync_chamber_game_elapsed_time()` |
| `_create_ui()` | B | 加载 `GameHUD.tscn` 或 fallback，收集 HUD 引用，初始化比分显示 | 是 | 后续配合 `UIRegistry.gd` 瘦身 | 中 | 是 | 当前仍收集大量零散引用；适合作为 UI 入口保留 |
| `_create_event_roulette_system()` | E | 创建事件 view/controller 并连接到 HUD 和玩法节点 | 是 | 后续配合 `UIRegistry.gd` 或事件 facade 瘦身 | 中 | 是 | 入口应保留；内部 wiring 未来可再薄 |
| `_create_control_buttons()` | B | 创建 `+球` 按钮并收集引用 | 否 | `GameHUD.gd` 或 `UIRegistry.gd` | 中 | 是 | 仍依赖旧 `GameHudView.create_control_buttons()`，是明显的半迁移点 |
| `_add_ball_to_chamber(faction_id)` | C | 响应加球按钮，直接向控制舱加球 | 暂缓 | 后续 `GameStateCoordinator.gd` | 中 | 是 | 依赖 `chambers` 和 `_refresh_add_ball_button()` |
| `_on_ball_count_changed(faction_id, _count)` | C | 监听球数变化后刷新按钮 | 暂缓 | `GameStateCoordinator.gd` 或 `UIRegistry.gd` | 低 | 否 | 轻量信号回调 |
| `_refresh_add_ball_button(faction_id)` | B | 刷新某个 `+球` 按钮状态 | 否 | `GameHUD.gd` / `UIRegistry.gd` | 低 | 是 | 仍直接依赖 `GameHudView.refresh_add_ball_button()` |
| `_on_chamber_release_requested(faction_id, bullet_count, chamber)` | C | 响应控制舱释放请求，处理锁定与炮塔发射 | 否 | `GameStateCoordinator.gd` | 中 | 是 | 连接玩法节点的关键回调；依赖 `turrets`、`chambers`、`is_game_over` |
| `_on_turret_burst_progress(faction_id, remaining)` | C | 根据炮塔连发进度更新控制舱和按钮 | 暂缓 | `GameStateCoordinator.gd` | 低 | 否 | 信号转发型函数 |
| `_on_turret_burst_lock_changed(faction_id, locked)` | C | 根据炮塔锁定状态更新控制舱和按钮 | 暂缓 | `GameStateCoordinator.gd` | 低 | 否 | 信号转发型函数 |
| `_on_turret_destroyed(faction_id)` | C | 处理炮塔毁坏后的控制舱状态和胜负检测 | 暂缓 | `GameStateCoordinator.gd` | 中 | 是 | 直接连接玩法后果和胜负入口 |
| `_check_winner()` | C | 汇总胜负输入并委托 `WinConditionEvaluator` | 暂缓 | 未来可并入 `GameStateCoordinator.gd` | 低 | 是 | 已经很瘦，是好的入口型函数 |
| `_get_occupation_winner()` | F | 旧版占领模式胜负逻辑，保留回滚用 | 否 | 删除或归档 | 低 | 否 | 已废弃；注释明确说明由 `WinConditionEvaluator` 取代 |
| `_get_score_winner()` | F | 旧版比分胜负逻辑，保留回滚用 | 否 | 删除或归档 | 低 | 否 | 已废弃；与上同类 |
| `_finish_with_winner(faction_id, sub_text)` | C | 设置 game over、停机、显示胜利 banner | 否 | `GameStateCoordinator.gd` | 中 | 是 | 典型状态流函数；依赖 `winner_label`、`BannerController` |
| `_finish_as_draw(sub_text)` | C | 设置平局结束状态并显示 banner | 否 | `GameStateCoordinator.gd` | 中 | 是 | 与 `_finish_with_winner()` 应成对迁移 |
| `_stop_all_actions_for_game_over()` | C | 停止炮塔连发、清子弹、解锁控制舱、刷新按钮 | 暂缓 | `GameStateCoordinator.gd` | 高 | 是 | 高风险；直接改玩法节点运行态 |
| `_on_scores_changed(counts)` | C | 更新缓存分数、刷新顶栏和 meta HUD | 暂缓 | `UIRegistry.gd` + `GameStateCoordinator.gd` | 低 | 是 | 现在已委托 `RuntimeHudController`，本体不重 |
| `_show_center_banner(title_text, sub_text, accent, auto_hide)` | B | 顶层 banner 展示入口 | 是 | — | 低 | 否 | 已委托 `BannerController.show()`，适合保留入口 |
| `_sync_chamber_game_elapsed_time()` | C | 同步 `game_elapsed_time` 到所有控制舱 | 暂缓 | `GameStateCoordinator.gd` | 低 | 否 | 小型协调函数 |
| `_toggle_pause()` | C | 暂停/继续、保存暂停现场、切换 overlay/button 文案 | 否 | `GameStateCoordinator.gd` | 中 | 是 | 明确属于状态流程，不应长期留在 Main |
| `_save_and_exit_to_menu()` | C / D | 保存当前进度、退出到菜单 | 否 | `GameStateCoordinator.gd` + `SaveFlowController.gd` | 中 | 是 | 横跨状态流与存档流，是后续拆分重点 |
| `_cleanup_menu()` | B | 销毁菜单层并清空菜单引用 | 暂缓 | `UIRegistry.gd` | 低 | 否 | 可保留为顶层清理入口，也可后续交给 registry |
| `_cleanup_game_layer()` | C | 销毁游戏层并清空玩法/UI/恢复态引用 | 暂缓 | `GameStateCoordinator.gd` | 中 | 是 | 涉及大量运行时引用清理，拆时需小心遗漏 |
| `_get_save_path(slot_index)` | D | 生成存档路径 | 否 | `SaveFlowController.gd` | 低 | 否 | 纯存档工具函数 |
| `_has_save_file(slot_index)` | D | 判断槽位是否存在存档，兼容 legacy 路径 | 否 | `SaveFlowController.gd` | 低 | 是 | 被菜单状态和继续游戏流程复用 |
| `_get_save_slot_summaries()` | D | 生成菜单存档摘要列表 | 否 | `SaveFlowController.gd` | 中 | 是 | 同时依赖读档、格式化、布局/模式名展示 |
| `_clear_bullets()` | D | 清空当前子弹容器 | 暂缓 | `SaveFlowController.gd` 或恢复子系统 | 中 | 是 | 被 game over 和 restore 复用，职责有交叉 |
| `_restore_bullet_states(states)` | D | 初始化待恢复子弹队列 | 否 | `SaveFlowController.gd` | 中 | 是 | 属于典型 restore 编排 |
| `_process_pending_bullet_restore()` | D | 分帧恢复子弹实例和 trail 状态 | 否 | `SaveFlowController.gd` | 高 | 是 | 高风险；涉及对象池、fallback、坐标、trail 和性能节流 |
| `_save_game_progress()` | D | 组装并写入当前存档 | 否 | `SaveFlowController.gd` | 中 | 是 | 已委托 `SaveStateBuilder`，但写盘和时机仍在 Main |
| `_load_saved_data(slot_index, allow_legacy)` | D | 读盘、解析 JSON、兼容 legacy 存档路径 | 否 | `SaveFlowController.gd` | 低 | 是 | 纯存档 IO 流程 |
| `_select_save_slot(slot_index)` | D | 选择槽位、更新菜单状态文案 | 否 | `SaveFlowController.gd` | 低 | 是 | 强依赖菜单 UI，但本质属于存档入口 |
| `_refresh_menu_save_slots()` | D | 根据存档摘要刷新菜单按钮显示 | 否 | `SaveFlowController.gd` + `StartMenu.gd` | 中 | 是 | 目前 Main 仍直接写菜单 UI |
| `_show_menu_status(message)` | B / D | 更新菜单状态文案或发出 warning | 暂缓 | `StartMenu.gd` 或 `SaveFlowController.gd` | 低 | 否 | 横跨菜单 UI 与存档流 |
| `_continue_saved_game()` | D | 读取、校验、应用配置、启动游戏、恢复状态 | 否 | `SaveFlowController.gd` | 高 | 是 | 当前是最重的存档流程函数之一 |
| `_apply_saved_state(data)` | D | 应用地图归属、阵营状态、事件状态、子弹、game over | 否 | `SaveFlowController.gd` | 中 | 是 | 已部分委托 `SaveStateApplier`，但仍是总编排 |
| `_apply_chamber_state(chamber, state)` | D | 恢复单个控制舱完整内部状态 | 暂缓 | `SaveStateApplier.gd` 后续继续吸收 | 高 | 是 | 高风险；直接操作 balls、jam、modifier、label、release_ball |
| `_apply_turret_state(turret, state)` | D | 恢复单个炮塔完整内部状态 | 暂缓 | `SaveStateApplier.gd` 后续继续吸收 | 高 | 是 | 高风险；直接操作 health、rotation、burst lock、destroy 状态 |

## 5. 建议的第一批拆分边界

### 适合先拆到 `GameStateCoordinator.gd`

- `_start_game()`
- `_toggle_pause()`
- `_finish_with_winner()`
- `_finish_as_draw()`
- `_save_and_exit_to_menu()`
- `_cleanup_game_layer()`

原因：
- 都是“状态流程”函数
- 会跨多个系统，但大多不直接编解码存档结构
- 拆完后 `Main.gd` 会明显瘦一圈

### 适合先拆到 `SaveFlowController.gd`

- `_get_save_path()`
- `_has_save_file()`
- `_get_save_slot_summaries()`
- `_restore_bullet_states()`
- `_process_pending_bullet_restore()`
- `_save_game_progress()`
- `_load_saved_data()`
- `_select_save_slot()`
- `_refresh_menu_save_slots()`
- `_continue_saved_game()`
- `_apply_saved_state()`

原因：
- 这些函数要么是存档 IO，要么是恢复编排
- 它们天然可以围绕“save flow”形成单独模块

### 暂缓拆分

- `_apply_chamber_state()`
- `_apply_turret_state()`
- `_stop_all_actions_for_game_over()`

原因：
- 直接写玩法节点内部状态
- 改坏后回归面很大
- 适合等前两批 coordinator/controller 稳住后再继续瘦身

## 6. 测试保护建议

在正式拆文件前，建议优先确保这些测试或等价覆盖存在：

- `SmokeTestRunner`
- `StartMenuSceneTestRunner`
- `GameHUDSceneTestRunner`
- `EventRouletteSceneTestRunner`
- 至少一条保存/读取/继续游戏集成测试
- 至少一条暂停/继续/返回菜单流程测试

尤其在拆以下函数前必须先有保护：
- `_start_game()`
- `_toggle_pause()`
- `_save_and_exit_to_menu()`
- `_continue_saved_game()`
- `_apply_saved_state()`
- `_process_pending_bullet_restore()`

## 7. 最终目标形态

后续理想结构：

```text
Main.gd
├── 生命周期入口
├── UI 入口创建
├── SceneBuilder 调用
├── GameStateCoordinator 调用
├── SaveFlowController 调用
├── Event 系统顶层接线
└── 少量全局信号连接
```

`Main.gd` 不应继续长期亲自承担：
- 复杂存档流程
- 暂停/结束/返回菜单细节
- 玩法节点内部恢复细节
- 大量零散 UI 引用管理

## 8. 本版本结论

v2.1.1 的重点不是“马上拆”，而是先完成职责摊开。

这份文档确认了三件事：
- `Main.gd` 仍是当前最大耦合中心
- 下一步最安全的拆分方向是 `GameStateCoordinator.gd` 与 `SaveFlowController.gd`
- `ControlChamber` / `Turret` 的深层状态恢复应继续暂缓，先用测试和文档把边界守住
