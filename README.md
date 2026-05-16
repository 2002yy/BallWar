# BallWar / 领土战争

`BallWar`（领土战争 / Marble Dominion Ricochet War）是一个基于 **Godot 4.6 + GDScript** 开发的 2D 四阵营领土争夺游戏原型。

四个阵营从战场四角持续施压，子弹在中心网格中弹射、碰撞并改写地块归属。玩家不直接瞄准炮台，而是通过外部控制仓影响发射节奏：控制球进入倍率口会放大待发射数量，进入发射口后炮台释放弹幕。胜负由占领比例、炮台存活、模式规则和事件系统共同决定。

This repository preserves the reconstructed development history of the project, including gameplay milestones, architecture refactors, UI iterations, save/load work, testing notes, and Android export notes.

---

## 当前状态 / Current Status

当前公开主线建议按 **`v2.1.9`** 理解：

- 完整对局体验已形成稳定闭环
- 设置系统、结算页、事件日志和统计链路已接线
- `BattlefieldDecorLayer` 与 `ControlChamber` 正在继续去耦和收口
- 主 README 负责“当前入口”，`README_v*.md` 保留为历史阶段记录

当前阶段重点：

- 四阵营中心战场与角落炮台玩法闭环
- 外部控制仓：控制球、倍率口、发射口、待发射数
- 多模式支持：基础模式、占领模式、限时模式、狂野模式
- 事件转盘与事件日志
- 开始菜单 `.tscn` 化与存档槽 UI
- 保存 / 读取 / 继续游戏链路
- 设置系统：性能信息、低特效模式、事件日志开关
- 结算页：胜利原因、游戏时长、最终占领率、事件次数、最高活跃子弹
- `BattlefieldDecorLayer` 从轮询改为事件/脏标记模式
- `ChamberState.gd` 从 `ControlChamber.gd` 中外提

仍在推进：

- Android APK 导出流程固化
- `ControlChamber` 后续拆分：物理、几何、绘制、保存适配
- 性能基线归档，尤其是低端显卡和高压弹幕场景
- 仓库入口文档与 Release 版本对应关系继续整理

## 游戏核心玩法 / Gameplay

### 1. 战场占领

中心区域是由网格组成的战场。不同阵营的子弹进入战场后，会将经过或碰撞影响到的格子染成己方颜色，占领比例会实时反映在 HUD 顶部占领条中。

### 2. 炮台发射

四个阵营分别位于战场四角。炮台不由玩家直接瞄准，而是根据控制仓积累出的待发射数量进行发射。

### 3. 控制仓机制

每个阵营拥有一个控制仓，控制仓中有控制球、钉柱、倍率口和发射口。

- 控制球在仓内弹跳
- 进入 `x2 / x3` 倍率口会提升本次待发射数
- 进入发射口后，炮台释放当前待发射数量
- jam、lock 和事件修正会临时改变控制仓行为

### 4. 模式规则

| 模式 | 说明 |
|---|---|
| 基础模式 | 以压制对手和扩大占领为主要目标 |
| 占领模式 | 达到指定占领比例后获胜 |
| 限时模式 | 时间结束时，占领比例最高者获胜 |
| 狂野模式 | 更高倍率、更高发射压力、更强随机事件节奏 |

### 5. 事件系统

游戏中会周期性触发事件转盘。事件可能影响某个阵营的待发射数量、倍率、控制球或干扰状态。事件日志会记录关键变化，帮助玩家理解战局转折。

## 主要功能 / Features

### 已实现

- 四阵营战场争夺
- 控制仓驱动发射节奏
- 子弹池与弹幕压力控制
- 战场格子占领与占领条
- 多模式规则
- 事件转盘
- 事件 HUD / 事件日志
- 开始菜单与存档槽
- 本地保存、读取、继续游戏
- 设置面板
- 结算页与对局统计
- Headless 测试脚本
- Godot Android 导出排错文档化

### 开发中 / Planned

- `ControlChamber` 继续拆分
- 更完整的性能基线报告
- 新手引导 / 模式说明页
- Android 试玩包导出流程固定
- UI / 音效 / 素材替换与美术统一

## 操作说明 / Controls

当前版本以鼠标操作为主：

| 操作 | 说明 |
|---|---|
| 点击 `+球` | 向对应阵营控制仓增加控制球 |
| 开始菜单按钮 | 新开一局、读取存档或覆盖当前存档槽 |
| 设置按钮 | 打开性能信息、低特效、事件日志开关 |
| 暂停按钮 | 暂停当前对局 |
| 退出按钮 | 返回开始菜单，按流程保存或结束当前局 |

移动端 / Android 适配仍在推进，建议优先横屏测试。

## 项目结构 / Project Structure

```text
BallWar/
├─ assets/                     # 图片、UI、素材资源与授权记录
├─ scenes/                     # Godot 场景
│  └─ ui/                      # StartMenu、HUD、Settings、ResultPanel 等
├─ screenshots/                # 仓库展示截图
├─ scripts/                    # 核心 GDScript
│  ├─ Main.gd
│  ├─ Battlefield.gd
│  ├─ BattlefieldDecorLayer.gd
│  ├─ Bullet.gd
│  ├─ BulletPool.gd
│  ├─ ControlChamber.gd
│  ├─ ChamberState.gd
│  ├─ EventRouletteController.gd
│  ├─ GameHUD.gd
│  ├─ RuntimeHudController.gd
│  ├─ PlayerSettingsStore.gd
│  ├─ SettingsPanel.gd
│  ├─ ResultPanel.gd
│  └─ tests/
├─ AI_HANDOFF_CURRENT.md       # AI/协作交接卡片
├─ CHANGELOG.md                # 精简版本主线
├─ README.md                   # 项目入口
├─ README_TEST_MATRIX.md       # 测试矩阵
├─ README_v*.md                # 历史阶段记录
├─ ROADMAP.md                  # 当前方向
└─ TECHNICAL_GUIDE.md          # 技术与协作说明
```

## 版本脉络 / Version History

建议按“阶段”理解项目，而不是只看单个 Release。

### `v0.1.0-mvp`

历史补录标签，用于标记最早可运行原型。

- 建立四阵营领土争夺概念
- 实现基础战场、炮台、控制仓和弹球发射
- 形成“控制仓积累 -> 炮台发射 -> 战场占领”的最小玩法闭环

注：这是历史起点，不代表当前最新版本。

### `v1.7.x` - `v1.8.x`

早期玩法整理与视觉稳定阶段。

- 基础战场、炮台、控制仓规则逐步定型
- 早期 UI、按钮和战场反馈持续打磨
- 版本化 README 开始累积

### `v1.9.x`

事件、性能与测试体系成型阶段。

- 多模式与事件系统逐步落地
- 子弹压力、拖尾和战场绘制性能成为重点
- `PerfBurstBenchmark`、`SmokeTestRunner`、`IntegrationTestRunner` 等测试脚本进入主线
- 保存、恢复、胜负流程开始系统化

### `v2.0.x`

结构重构与稳定性阶段。

- 战场、UI、事件、保存、恢复的职责边界逐步清晰
- `SaveFlowController`、`GameStateCoordinator` 等协调层开始承担稳定编排
- 开始菜单和 HUD 迁移到更稳定的结构

### `v2.1.0` - `v2.1.4`

菜单 `.tscn` 化与恢复链条收口阶段。

- `StartMenu.tscn` 可视化迁移
- continue 流程拆为 `prepare_*` / `apply_*`
- `restore_from_state(...)` 归属边界更明确
- `Main.gd` 逐步收缩为顶层编排层

### `v2.1.8`

DecorLayer 事件化、`ChamberState` 外提、开始菜单定型。

- `BattlefieldDecorLayer` 从每帧轮询改为事件/脏标记模式
- `ControlChamber` 状态提取到 `ChamberState.gd`
- 开始菜单布局、预览和存档槽可读性提升
- 存档恢复 bug 修复与 continue 测试补强

### `v2.1.9`

设置系统、结算页与统计接线阶段。

- `PlayerSettingsStore.gd` 持久化玩家设置
- `SettingsPanel` 成为真实可交互设置面板
- `ResultPanel` 提供胜利原因、时长、占领率和统计
- `BulletPool` 与 `EventRouletteController` 增加对局统计

更完整的阶段说明见 [CHANGELOG.md](CHANGELOG.md) 和对应的 `README_v*.md`。

## 测试 / Testing

项目包含多类 Headless 测试与性能探针，当前以 [README_TEST_MATRIX.md](README_TEST_MATRIX.md) 为准。

主要类型：

| 类型 | 作用 |
|---|---|
| Scene Wiring Tests | 验证 `.tscn` 场景能加载，关键节点路径不变 |
| Coordinator / Restore Tests | 验证保存、恢复、协调器边界 |
| Smoke Test | 快速确认核心系统没有大面积回归 |
| Integration Test | 验证保存、战场规则、胜负条件等跨系统逻辑 |
| Layout Boundary Test | 验证不同网格与布局边界 |
| Performance Probes | 性能探针，不等同于 correctness 测试 |

代表性脚本：

- `scripts/tests/StartMenuSceneTestRunner.gd`
- `scripts/tests/GameHUDSceneTestRunner.gd`
- `scripts/tests/EventRouletteSceneTestRunner.gd`
- `scripts/tests/SettingsPanelSceneTestRunner.gd`
- `scripts/tests/GameStateCoordinatorTestRunner.gd`
- `scripts/tests/SaveFlowControllerTestRunner.gd`
- `scripts/tests/RestorePlanTestRunner.gd`
- `scripts/tests/SmokeTestRunner.gd`
- `scripts/tests/IntegrationTestRunner.gd`
- `scripts/tests/LayoutSanityTestRunner.gd`
- `scripts/tests/PerfBurstBenchmark.gd`

## 性能策略 / Performance Strategy

项目当前把低端显卡和高压弹幕场景作为重要参考对象。

核心方向：

- 子弹池复用，减少频繁实例化
- 拖尾集中绘制，降低每个子弹独立绘制成本
- 战场装饰层事件化，避免每帧无意义刷新
- 低特效模式降低高成本视觉开销
- 性能 HUD 展示 FPS、活跃子弹、队列与绘制负载等调试信息

推荐性能理解：

| 场景 | 目标 |
|---|---|
| 常规网格 + 基础/占领模式 | 稳定可玩，维持清晰 HUD 和对局反馈 |
| 更大网格 + 狂野模式 | 不死机，恢复与 HUD 状态正确 |
| 高压保存/读取 | 继续游戏链路不丢状态、不错误复盘 |

## Android 导出说明 / Android Export Notes

Android 导出需要特别注意 Godot 项目设置中的 ETC2/ASTC 纹理压缩。

`project.godot` 中需要存在：

```ini
[rendering]
textures/vram_compression/import_etc2_astc=true
```

建议导出排错顺序：

1. 先导出 Debug APK，不先处理 Release 签名
2. preset 使用英文名，例如 `Android`
3. 输出路径使用英文路径
4. `package/signed=false`
5. `script_export_mode=0`
6. `gradle_build/use_gradle_build=false`
7. 确认资源已重新导入后再导出

更具体的工程协作边界见 [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md)。

## 文档分工 / Documentation Map

| 文档 | 作用 |
|---|---|
| `README.md` | 项目入口，介绍玩法、当前状态、结构和版本脉络 |
| `CHANGELOG.md` | 精简版本主线 |
| `ROADMAP.md` | 当前方向、已完成、下一步 |
| `README_TEST_MATRIX.md` | 测试矩阵与运行建议 |
| `TECHNICAL_GUIDE.md` | 技术结构、编辑器协作边界、导出说明 |
| `AI_HANDOFF_CURRENT.md` | AI / 协作交接摘要 |
| `README_v*.md` | 历史阶段详细记录，不作为当前真相入口 |

## 后续路线 / Roadmap

短期重点：

- 固化 Android APK 导出流程
- 整理 Release 与 README 的版本对应关系
- 补充性能基线记录
- 继续拆分 `ControlChamber`
- 保持 `Main.gd` 作为顶层编排层，而不是深层状态写回中心

中期候选：

- 新手引导
- 模式说明页
- 更完整的结算统计
- 音效系统
- 移动端按钮布局
- 美术资源替换与统一风格

## Screenshots

| 开始界面 | 游戏初始 |
|:--:|:--:|
| ![](screenshots/%E5%BC%80%E5%A7%8B%E7%95%8C%E9%9D%A2.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E5%88%9D%E5%A7%8B.png) |

| 游戏中场 | 事件画面 |
|:--:|:--:|
| ![](screenshots/%E6%B8%B8%E6%88%8F%E4%B8%AD%E5%9C%BA.png) | ![](screenshots/%E4%BA%8B%E4%BB%B6%E7%94%BB%E9%9D%A2.png) |

| 一方胜利结果 |
|:--:|
| ![](screenshots/%E4%B8%80%E6%96%B9%E8%83%9C%E5%88%A9%E7%BB%93%E6%9E%9C.png) |

## License

This repository is released under the [MIT License](LICENSE).
