# BallWar / 领土战争

`BallWar` 是一个基于 Godot 4.6 的 2D 领土争夺原型。四个阵营围绕中央方形战场展开对抗：角落炮台负责发射，外部控制仓决定节奏，子弹会占领或重涂格子，胜负由模式与局势共同决定。

This repository preserves the reconstructed local development history from `v1.7` to the current mainline, including tags for key snapshots and refactor milestones.

## 当前状态 / Current Status

- 当前主线标签：`v2.1.4`
- 日期：2026-05-14
- 阶段性质：结构稳定性版本，不是玩法大扩展版本
- 当前重点：继续把 `Main.gd` 从深层恢复/状态写回中收缩成顶层编排层

`v2.1.4` 的主要变化：

- 完成 continue 流程 `prepare_*` / `apply_*` 两段式边界
- `ControlChamber.gd`、`Turret.gd`、`Bullet.gd` 补齐 `restore_from_state(...)`
- `Main.gd` 不再直接写 chamber / turret / bullet 的内部恢复细节
- `BulletPool.gd` 改为增量维护 burst queue 与 trail segment 统计
- `Battlefield.gd` 拆出 `BattlefieldDecorLayer.gd`

## 核心玩法 / Core Loop

- 四个阵营在方形网格战场上争夺地块
- 每个阵营拥有一个角落炮台和一个独立控制仓
- 控制球进入不同门口会影响发射倍率和发射时机
- 子弹命中异色格会占领地块，命中炮台会造成伤害
- 支持多种胜利模式：`basic`、`occupation`、`timed`、`wild`

## 游戏截图 / Screenshots

| 开始界面 | 游戏初始 |
|:--:|:--:|
| ![](screenshots/%E5%BC%80%E5%A7%8B%E7%95%8C%E9%9D%A2.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E5%88%9D%E5%A7%8B.png) |

| 游戏中场 | 事件画面 |
|:--:|:--:|
| ![](screenshots/%E6%B8%B8%E6%88%8F%E4%B8%AD%E5%9C%BA.png) | ![](screenshots/%E4%BA%8B%E4%BB%B6%E7%94%BB%E9%9D%A2.png) |

| 胜利结果 |
|:--:|
| ![](screenshots/%E4%B8%80%E6%96%B9%E8%83%9C%E5%88%A9%E7%BB%93%E6%9E%9C.png) |

## 运行方式 / Running The Project

推荐使用 Godot 4.6 打开仓库根目录下的 `project.godot`。

如果你要跑现有 headless 测试，请把下面的 `<godot_console>` 替换成你本机的 Godot 控制台可执行文件：

```powershell
<godot_console> --path . --script res://scripts/tests/SmokeTestRunner.gd
<godot_console> --path . --script res://scripts/tests/SaveFlowControllerTestRunner.gd
<godot_console> --path . --script res://scripts/tests/IntegrationTestRunner.gd
<godot_console> --path . --script res://scripts/tests/GameStateCoordinatorTestRunner.gd
```

## 测试分层 / Test Layers

当前活跃的正确性基线主要分成几类：

- 场景接线测试：`StartMenuSceneTestRunner.gd`、`GameHUDSceneTestRunner.gd`、`EventRouletteSceneTestRunner.gd`、`SettingsPanelSceneTestRunner.gd`
- 协调器/辅助层测试：`GameStateCoordinatorTestRunner.gd`、`SaveFlowControllerTestRunner.gd`
- 冒烟测试：`SmokeTestRunner.gd`
- 集成测试：`IntegrationTestRunner.gd`
- 布局边界测试：`LayoutSanityTestRunner.gd`
- 性能探针：`PerfBurstBenchmark.gd`

更完整的分层说明见 [README_TEST_MATRIX.md](README_TEST_MATRIX.md)。

## 先读哪些文档 / Recommended Docs

- [README_SESSION_CHANGES.md](README_SESSION_CHANGES.md)：最新阶段摘要、验证结果、当前风险
- [AI_HANDOFF_CURRENT.md](AI_HANDOFF_CURRENT.md)：给下一位开发者或 AI 的高密度交接
- [README_TEST_MATRIX.md](README_TEST_MATRIX.md)：测试职责与推荐运行顺序
- [README_v2_1_4_restore_interfaces_and_perf_cleanup.md](README_v2_1_4_restore_interfaces_and_perf_cleanup.md)：最新结构改动说明
- [ROADMAP.md](ROADMAP.md)：后续方向

## 版本历史 / Version History

这个仓库不是从早期就自然使用 Git 演进出来的，而是从本地版本文件夹人工重建历史。现在你可以直接通过 tags 回看关键节点，例如：

- `v1.7`
- `v1.9.13`
- `v1.9.19`
- `v2.0.1`
- `v2.0.4`
- `v2.0.7`
- `v2.1.0`
- `v2.1.1`
- `v2.1.4`

## 已知注意事项 / Known Notes

- 部分旧文档在某些终端里会出现中文显示乱码，这通常是显示/编码环境问题，不代表源码或文档主体已经损坏
- 仓库里保留了较多阶段性 README 和附属文档，因为这个项目本身就是边开发边审计、边重构推进的
- `art_reference/free_ui_assets` 目录中的下载残留默认被忽略；仓库只保留集成计划文档，不跟踪抓取过程文件
