# .gd 耦合拆分路线图 / GDScript Refactor Roadmap

日期: 2026-05-06

## 1. 目标

这份路线图只解决两个问题：
- `Main.gd` 过重
- UI / 保存 / 运行时状态的职责边界还不够清楚

原则：
- 不做一口气大重构
- 先拆低风险纯逻辑
- 再拆中风险 UI 编排
- 最后才碰高风险玩法节点

## 2. 当前已经拆得好的部分

以下文件方向正确，应继续沿用这种拆法：
- `scripts/WinConditionEvaluator.gd`
- `scripts/SaveGameCodec.gd`
- `scripts/SaveStateBuilder.gd`
- `scripts/SaveStateApplier.gd`
- `scripts/LayoutCoordinator.gd`
- `scripts/StartMenu.gd`
- `scripts/GameHUD.gd`
- `scripts/SettingsPanel.gd`
- `scripts/EventRouletteView.gd`

其中最值得复制的模式是：
- `WinConditionEvaluator.gd`

理由：
- 纯逻辑
- 低耦合
- 容易测试
- 不直接依赖场景树

## 3. Main.gd 现状审计

`Main.gd` 目前仍同时承担这些责任：
- 启动和场景生命周期
- 开始游戏 / 继续游戏 / 返回菜单
- 保存和读取流程编排
- UI 创建与引用保存
- HUD 刷新调度
- 事件系统接线
- 玩法节点信号接线
- 胜负结算入口

它仍然像：
- 总导演
- 场务
- UI 工人
- 存档员
- 裁判

理想状态下，`Main.gd` 应只保留：
- 创建/销毁场景
- 调用 builder / controller / evaluator
- 连接顶层信号
- 保存跨系统共享的少量入口引用

## 4. 下一步优先级

| 优先级 | 目标 | 说明 |
|---|---|---|
| 1 | `Main.gd` 职责审计 | 先把现有职责列清楚，再拆 |
| 2 | `GameStateCoordinator.gd` | 负责开始 / 暂停 / 结束 / 返回菜单流程 |
| 3 | `SaveFlowController.gd` | 负责保存 / 读取 / 恢复编排 |
| 4 | `UIRegistry.gd` 或 `SceneRefs.gd` | 统一保存 UI 节点引用 |
| 5 | `EventIntegrationTest` | 补事件系统真实集成测试 |
| 6 | `TrailPressurePolicy.gd` | 性能策略拆分，暂缓 |
| 7 | `ControlChamber` / `Turret` 解耦 | 高风险，暂缓 |

## 5. 推荐拆分顺序

### 第 1 阶段：只做审计和归位

目标：
- 不改玩法
- 不改节点关系
- 只把职责分区写清楚

动作：
- 给 `Main.gd` 标记责任区块
- 列出哪些函数属于流程、哪些属于 save、哪些属于 HUD、哪些属于 restore
- 清理已经外移但旧注释还停留在 `Main.gd` 的内容

产出：
- 一份 `Main.gd` 职责清单

### 第 2 阶段：拆流程编排

目标：
- 把“状态流程”从 `Main.gd` 中拿出去

新增文件建议：
- `scripts/GameStateCoordinator.gd`

职责：
- `start_game`
- `toggle_pause`
- `save_and_exit_to_menu`
- `return_to_menu`
- `show_game_over`

保留在 `Main.gd` 的内容：
- 调用 coordinator
- 响应 coordinator 回调

### 第 3 阶段：拆 save 流程

新增文件建议：
- `scripts/SaveFlowController.gd`

职责：
- 选择存档槽
- 读取摘要
- 触发保存
- 触发读档
- 驱动 `SaveStateBuilder` / `SaveStateApplier`
- 驱动延迟恢复子弹和控制球

这样分开后：
- `SaveStateBuilder.gd` 继续只管“拼数据”
- `SaveStateApplier.gd` 继续只管“落数据”
- `SaveFlowController.gd` 负责“什么时候拼、什么时候落、失败怎么回退”

### 第 4 阶段：统一 UI 引用

新增文件建议：
- `scripts/UIRegistry.gd`

职责：
- 收集 `StartMenu` / `GameHUD` / `SettingsPanel` / `EventRouletteView` 暴露出来的引用
- 给 `Main.gd` 提供统一入口，而不是散落字典字段

说明：
- 这一步是中风险，但收益很大
- 它能减少 `Main.gd` 的大量“拿节点、存节点、传字典”

### 第 5 阶段：再碰性能和玩法节点

暂缓对象：
- `TrailPressurePolicy.gd`
- `ControlChamber.gd`
- `Turret.gd`

原因：
- 都直接影响运行时行为
- 一旦拆坏，回归面会很大

## 6. Main.gd 的最终目标形态

理想结构：

```text
Main.gd
├── 创建/销毁场景
├── 调用 GameSceneBuilder
├── 调用 GameStateCoordinator
├── 调用 SaveFlowController
├── 调用 WinConditionEvaluator
├── 调用 UI 场景控制器
└── 连接信号
```

`Main.gd` 不应继续亲自做：
- 手写大量 UI 节点
- 拼复杂 save dictionary
- 直接写胜负规则
- 直接写布局计算
- 直接处理性能降级策略

## 7. 需要补的测试

优先补：
- `EventIntegrationTest`
- `SaveFlowController` 相关流程测试
- `GameStateCoordinator` 的暂停/退出/返回菜单测试

维持现有测试：
- `StartMenuSceneTestRunner`
- `GameHUDSceneTestRunner`
- `EventRouletteSceneTestRunner`
- `SettingsPanelSceneTestRunner`
- `SmokeTestRunner`

## 8. 缩进约束

从这份路线图开始，所有新增的重构 `.gd` 文件统一使用 `TAB`。

原因：
- 项目已有明确规范：新增 `.gd` 默认用 `TAB`
- 重构新增文件应当先做到风格统一，避免继续扩散旧文件的 space/tab 分裂

注意：
- 旧文件保持原文件风格，不为了“统一”去做大面积无意义空白改动
- 新文件统一 `TAB`
- 单个文件内部严禁混用
