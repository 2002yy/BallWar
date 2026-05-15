# BallWar / 领土战争

`BallWar` 是一个基于 Godot 4.6 的 2D 领土争夺原型。四个阵营围绕中心方格战场展开对抗：角落炮台负责发射，外部控制仓决定节奏，子弹会占领或重涂格子，胜负由模式与局势共同决定。  
`BallWar` is a Godot 4.6 2D territory-control prototype built around four factions, corner turrets, chamber-driven firing rhythm, and map ownership pressure.

This repository preserves the reconstructed local development history from `v1.7` to the current mainline, with tags for key milestones and versioned `README_v*.md` notes for detailed stage history.

## 当前状态 / Current Status

- 主线版本 / Stable line: `v2.1.4`
- 当前重点 / Current focus:
  - `Main.gd` 继续向顶层编排层收缩
  - continue / save-load 恢复链边界更清晰
  - 性能路径和文档结构继续收口

`v2.1.4` 的主要变化 / Main changes in `v2.1.4`:

- continue 流程完成 `prepare_*` / `apply_*` 两段式边界
- `ControlChamber.gd`、`Turret.gd`、`Bullet.gd` 各自接管 `restore_from_state(...)`
- `Main.gd` 不再深度写回 chamber / turret / bullet 的内部恢复字段
- `BulletPool.gd` 改为增量维护 burst queue 与 trail 统计
- `Battlefield.gd` 拆出 `BattlefieldDecorLayer.gd`

## 核心玩法 / Core Loop

- 四个阵营在方格战场上争夺领地
- 每个阵营拥有一个角落炮台和一个控制仓
- 控制球经过不同出口会影响发射倍数和发射时机
- 子弹命中异色格会改写归属，命中炮台会造成伤害
- 支持多种胜利模式：`basic`、`occupation`、`timed`、`wild`

## 运行方式 / Running The Project

推荐使用 Godot 4.6 打开仓库根目录下的 `project.godot`。  
For headless checks, replace `<godot_console>` with your local Godot console executable.

```powershell
<godot_console> --path . --script res://scripts/tests/SmokeTestRunner.gd
<godot_console> --path . --script res://scripts/tests/SaveFlowControllerTestRunner.gd
<godot_console> --path . --script res://scripts/tests/IntegrationTestRunner.gd
<godot_console> --path . --script res://scripts/tests/GameStateCoordinatorTestRunner.gd
```

## 文档入口 / Documentation

- [ROADMAP.md](ROADMAP.md)
  - 当前进度、下一步与暂缓项
- [README_TEST_MATRIX.md](README_TEST_MATRIX.md)
  - 测试基线、性能探针与推荐运行顺序
- [TECHNICAL_GUIDE.md](TECHNICAL_GUIDE.md)
  - 当前有效的架构边界、编辑器协作规则与验证策略
- [AI_HANDOFF_CURRENT.md](AI_HANDOFF_CURRENT.md)
  - 下一位 AI / Codex 的快速接管卡片
- [CHANGELOG.md](CHANGELOG.md)
  - 精简历史主线与最新稳定线摘要
- [README_v2_1_4_restore_interfaces_and_perf_cleanup.md](README_v2_1_4_restore_interfaces_and_perf_cleanup.md)
  - 最新详细阶段说明
- [assets/ASSET_SOURCES_AND_LICENSES.md](assets/ASSET_SOURCES_AND_LICENSES.md)
  - 资源来源、授权与可分发边界

## 版本历史 / Version History

- 详细历史保留在 `README_v*.md`
- Git tags 对应重建后的关键里程碑
- `CHANGELOG.md` 只保留精简主线，不替代版本阶段文档

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

## 说明 / Notes

- 部分终端里中文可能显示乱码，这通常是显示编码问题，不代表文件本体损坏。
- 历史版本 `README_v*.md` 会继续保留；其余临时审计、迁移、补丁和目录说明类 Markdown 已尽量收敛到更少的常驻文档中。
- `art_reference/free_ui_assets/` 保留原始研究与下载痕迹，`assets/` 只保留整理后的可用资源。
