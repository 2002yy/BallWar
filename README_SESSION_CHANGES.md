# 会话改动记录 / Session Changes

最近更新 / Latest update: 2026-05-14

## 工程原则（必读）/ Project Principles

详见 `PROJECT_PRINCIPLES.md`。当前这条 BallWar 线的核心原则是：

1. 每次重构优先降低耦合、提高安全性、保证向后兼容。
2. 新代码出问题时，优先从新边界和新接线处排查。
3. 文档要以代码现状为准，不把“计划中的结构”写成“已经完成的结构”。

See `PROJECT_PRINCIPLES.md`. The main principles for this BallWar line are:

1. Favor lower coupling, higher safety, and backward compatibility in each refactor.
2. When regressions appear, inspect the newly introduced boundaries first.
3. Keep docs aligned with live code, not with intended future architecture.

## 历史记录摘要 / Historical Summary

### v2.0.3

- 完成中文编码审计，确认主要 `.gd` / `.md` 文件本体没有损坏。
- 补齐测试基础设施：`TestAssert.gd`、`TestFixtures.gd`、`IntegrationTestRunner.gd`。
- 形成 `README_v2_0_3_fix_log.md` 和 `README_v2_0_3_test_audit.md` 两份配套记录。

- Completed encoding audit and confirmed the main `.gd` / `.md` files were not actually corrupted.
- Added foundational test infrastructure: `TestAssert.gd`, `TestFixtures.gd`, and `IntegrationTestRunner.gd`.
- Produced `README_v2_0_3_fix_log.md` and `README_v2_0_3_test_audit.md`.

### v2.0.4 - v2.1.3

- `WinConditionEvaluator`、`SaveStateBuilder`、`SaveStateApplier`、`SaveFlowController` 逐步成型。
- `Main.gd` 开始从“大总管 + 深层恢复写回”向“顶层编排”收缩。
- 产出了 `README_v2_0_4_*`、`README_v2_0_5_*`、`README_v2_1_1_*`、`README_v2_1_2_*`、`README_v2_1_3_*` 等阶段文档。

- `WinConditionEvaluator`, `SaveStateBuilder`, `SaveStateApplier`, and `SaveFlowController` were introduced in stages.
- `Main.gd` started shrinking from a deep mutation hub toward a top-level coordinator.
- Stage docs were added across `README_v2_0_4_*`, `README_v2_0_5_*`, `README_v2_1_1_*`, `README_v2_1_2_*`, and `README_v2_1_3_*`.

## 当前已知风险 / Current Known Risks

| 风险 / Risk | 当前判断 / Status |
|---|---|
| 旧文档较多，部分历史文档存在编码显示问题 | 终端中可能乱码，但当前新增文档应继续保持 UTF-8 双语可读 |
| BallWar 外层目录不是主要 Git 根 | 当前 Git 范围应继续限定在 `BallWar/` |
| `Main.gd` 仍是总编排层 | 已明显收缩，但继续游戏入口的端到端运行时测试仍值得补 |
| 性能验证主要来自结构分析与 headless 回归 | 需要时仍建议做真实局面下的人工 / 运行时压测 |

## 桌面验证命令 / Local Verification Commands

```text
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/SmokeTestRunner.gd"
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/SaveFlowControllerTestRunner.gd"
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/IntegrationTestRunner.gd"
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/GameStateCoordinatorTestRunner.gd"
```

## 本次更新：v2.1.4 / This Update: v2.1.4

日期 / Date: 2026-05-14

### 本轮重点 / Highlights

- 完成 continue 流程 `prepare_*` / `apply_*` 两段式边界。
- `ControlChamber.gd`、`Turret.gd`、`Bullet.gd` 分别补齐 `restore_from_state(...)`。
- `Main.gd` 不再直接写 chamber / turret / bullet 的多处内部字段。
- `BulletPool.gd` 改为增量维护 burst queue 与 trail segment 统计。
- `ControlChamber.gd` peg 碰撞改为轴向预筛 + 平方距离判断。
- `Battlefield.gd` 将静态装饰层拆分到 `BattlefieldDecorLayer.gd`。
- 清理 `Main.gd` 中继续游戏、胜负收尾附近残留的 `return` 后死代码。

- Finished the `prepare_*` / `apply_*` split for continue flow.
- Added explicit `restore_from_state(...)` ownership to `ControlChamber.gd`, `Turret.gd`, and `Bullet.gd`.
- Removed direct chamber / turret / bullet internal-state mutation from `Main.gd`.
- Switched `BulletPool.gd` to incremental burst-queue and trail-segment tracking.
- Optimized peg collision in `ControlChamber.gd` with axis pre-check + squared distance.
- Split static battlefield decoration into `BattlefieldDecorLayer.gd`.
- Removed leftover dead code after early `return` branches around continue and win/game-over handling in `Main.gd`.

### 主要涉及文件 / Main Files

- `scripts/Main.gd`
- `scripts/SaveFlowController.gd`
- `scripts/SaveStateApplier.gd`
- `scripts/ControlChamber.gd`
- `scripts/Turret.gd`
- `scripts/Bullet.gd`
- `scripts/BulletPool.gd`
- `scripts/Battlefield.gd`
- `scripts/BattlefieldDecorLayer.gd`
- `scripts/tests/SmokeTestRunner.gd`
- `scripts/tests/SaveFlowControllerTestRunner.gd`
- `README_v2_1_4_restore_interfaces_and_perf_cleanup.md`

### 验证结果 / Validation

```text
SmokeTestRunner.gd               PASS 60 checks
SaveFlowControllerTestRunner.gd  PASS 75 checks
IntegrationTestRunner.gd         PASS 133 checks
GameStateCoordinatorTestRunner   PASS 50 checks
```

### 对当前结构的结论 / Structural Outcome

- `Main.gd` 继续朝“总编排层”收缩。
- restore 链的对象边界比 `v2.1.3` 明确很多。
- 这轮是结构稳定性版本，不是玩法功能版本。

- `Main.gd` is now closer to a true orchestration layer.
- Restore ownership is much clearer than in `v2.1.3`.
- This is a structural stability pass, not a feature pass.

### 相关文档 / Related Docs

- `README_v2_1_4_restore_interfaces_and_perf_cleanup.md`
- `README_v2_1_3_restore_chain_audit.md`
- `README_v2_1_2_save_flow_controller.md`
- `README_SAVE_LOAD_FLOW_AUDIT.md`
- `README_MAIN_GD_AUDIT.md`
