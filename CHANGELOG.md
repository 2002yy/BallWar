# Changelog / 版本脊柱

Date / 日期: 2026-05-16
Role / 作用: condensed milestone spine / 精简版本脊柱

Detailed stage notes now live under [docs/history/](docs/history/README.md).
详细阶段记录现已统一收敛到 [docs/history/](docs/history/README.md)。

## Reading Rule / 阅读方式

- `CHANGELOG.md`
  - 只保留每个阶段最重要的 3 到 6 条变化
- `docs/history/README.md`
  - 作为历史阶段索引
- `docs/history/README_v*.md`
  - 作为每个阶段的详细记录

## `v2.1.9`

- 新增设置系统与 `PlayerSettingsStore.gd`
- 新增 `ResultPanel` 结算页
- 增加最高活跃子弹和事件次数统计
- 低特效、性能条、事件日志开关接入运行时
- `v2.1.x` 当前最近的完整文档化里程碑

## `v2.1.8`

- `BattlefieldDecorLayer` 改为事件/脏标记模式
- `ChamberState` 从 `ControlChamber` 外提
- `StartMenu` 布局、预览和槽位信息进一步定型
- 存档恢复与 continue 端到端测试补强

## `v2.1.5` - `v2.1.7`

- 事件说明层、菜单偏好与 UI 细节继续补全
- save/restore bug 修复与 continue 稳定性提升
- 开始菜单容器化与细节修正
- 生命周期清理、事件状态整理与资源审计推进

## `v2.1.0` - `v2.1.4`

- `StartMenu.tscn` 迁移为可编辑 UI 场景
- continue 流程拆成 `prepare_*` / `apply_*`
- `restore_from_state(...)` 归属从 `Main.gd` 下沉到运行时对象
- `Main.gd` 明确转向顶层编排层
- 这一段构成当前可引用的稳定结构基线

## `v2.0.x`

- 保存/恢复、胜负规则与布局 sanity 开始系统化
- `SaveFlowController`、`GameStateCoordinator` 等协调层逐步成形
- 测试矩阵和版本说明开始更规范地配套推进
- UI 场景化迁移为后续 `v2.1.x` 奠定基础

## `v1.9.x`

- 多模式与事件系统逐步成型
- 子弹池、拖尾和战场绘制性能成为重点
- `SmokeTestRunner`、`IntegrationTestRunner`、`PerfBurstBenchmark` 等开始承担回归和基线职责
- 项目从“能玩”走向“可持续维护”

## `v1.7.x` - `v1.8.x`

- 基础玩法、控制仓与炮台规则逐步定型
- 早期 UI 和战场反馈持续打磨
- 历史阶段文档开始累积

## `v0.1.0-mvp`

- 建立四阵营领土争夺的最小玩法闭环
- 实现基础战场、炮台、控制仓和发射逻辑
- 作为后续 BallWar 主线的历史起点保留
