# GDScript 缩进审计 / Indentation Audit

日期: 2026-05-04 | 审计范围: 34 个 .gd 文件

## 规则

- **修改任何 .gd 文件前必须先查本表**，确认目标文件是 TAB 还是 SPACE
- 新增 .gd 文件默认使用 **TAB**
- 严禁同一文件内混用 tab 和 spaces
- 不要在功能修改中混入格式化

## 全审计结果

| 文件 | 风格 | tab行 | space行 | mixed | 总缩进行 |
|---|---|---|---|---|---|
| `scripts/BannerController.gd` | SPACE | 0 | 41 | 0 | 41 |
| `scripts/Battlefield.gd` | SPACE | 0 | 187 | 0 | 187 |
| `scripts/Bullet.gd` | SPACE | 0 | 188 | 0 | 188 |
| `scripts/BulletPool.gd` | TAB | 229 | 0 | 0 | 229 |
| `scripts/BulletTrailLayer.gd` | TAB | 122 | 0 | 0 | 122 |
| `scripts/ControlBall.gd` | SPACE | 0 | 16 | 0 | 16 |
| `scripts/ControlChamber.gd` | SPACE | 0 | 518 | 0 | 518 |
| `scripts/EnergyButton.gd` | SPACE | 0 | 107 | 0 | 107 |
| `scripts/EventRouletteController.gd` | TAB | 317 | 0 | 0 | 317 |
| `scripts/EventRouletteView.gd` | TAB | 221 | 0 | 0 | 221 |
| `scripts/GameConfig.gd` | SPACE | 0 | 215 | 0 | 215 |
| `scripts/GameHudView.gd` | SPACE | 0 | 239 | 0 | 239 |
| `scripts/GameSceneBuilder.gd` | SPACE | 0 | 92 | 0 | 92 |
| `scripts/Gate.gd` | SPACE | 0 | 26 | 0 | 26 |
| `scripts/HudBadge.gd` | SPACE | 0 | 14 | 0 | 14 |
| `scripts/LayoutCoordinator.gd` | TAB | 117 | 0 | 0 | 117 |
| `scripts/LayoutProfiles.gd` | SPACE | 0 | 121 | 0 | 121 |
| `scripts/Main.gd` | SPACE | 0 | 562 | 0 | 562 |
| `scripts/MenuDecor.gd` | SPACE | 0 | 65 | 0 | 65 |
| `scripts/RuntimeHudController.gd` | TAB | 155 | 0 | 0 | 155 |
| `scripts/SaveGameCodec.gd` | SPACE | 0 | 112 | 0 | 112 |
| `scripts/SaveStateApplier.gd` | TAB | 44 | 0 | 0 | 44 |
| `scripts/SaveStateBuilder.gd` | TAB | 42 | 0 | 0 | 42 |
| `scripts/StartMenuView.gd` | SPACE | 0 | 214 | 0 | 214 |
| `scripts/tests/IntegrationTestRunner.gd` | TAB | 405 | 0 | 0 | 405 |
| `scripts/tests/LayoutSanityTestRunner.gd` | TAB | 71 | 0 | 0 | 71 |
| `scripts/tests/PerfBurstBenchmark.gd` | TAB | 525 | 0 | 0 | 525 |
| `scripts/tests/SmokeTestRunner.gd` | TAB | 199 | 0 | 0 | 199 |
| `scripts/tests/TestAssert.gd` | TAB | 30 | 0 | 0 | 30 |
| `scripts/tests/TestFixtures.gd` | TAB | 183 | 0 | 0 | 183 |
| `scripts/Turret.gd` | SPACE | 0 | 236 | 0 | 236 |
| `scripts/UIAnimationController.gd` | SPACE | 0 | 36 | 0 | 36 |
| `scripts/UIFactory.gd` | SPACE | 0 | 28 | 0 | 28 |
| `scripts/WinConditionEvaluator.gd` | TAB | 57 | 0 | 0 | 57 |

**汇总: TAB 14 个 / SPACE 18 个 / MIXED 0 个**

## 已知风险

- `Turret.gd` 历史上部分函数使用 tab（`setup()`），现已在 v2.0.6 中统一为 spaces。若恢复旧备份需注意。
- `Main.gd` 曾在编辑中混入 42 行 tab（v2.0.5），已修复为 spaces。
- `SaveGameCodec.gd` 曾在新函数中混入 tab（v2.0.5），已修复为 spaces。
- `GameConfig.gd` 曾在新函数中混入 tab（v2.0.6），已修复为 spaces。

## 测试断言统计（v2.0.6 最终）

| 测试 | 断言数 | 类型 |
|---|---|---|
| `SmokeTestRunner.gd` | 33 | 快速冒烟 |
| `IntegrationTestRunner.gd` | 133 | 中量集成 |
| `LayoutSanityTestRunner.gd` | 330 | 布局边界 |
| **合计** | **496** | |
