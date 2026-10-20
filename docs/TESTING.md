# Testing / 测试

Date: 2026-05-17
Role: test matrix and run guidance / 测试矩阵与运行建议

## Correctness Baseline / 正确性基线

10 headless test runners, verified via GitHub Actions CI (`Headless Tests` workflow).

| Runner | Checks | Category |
|---|---|---|
| `LayoutSanityTestRunner.gd` | 376 | Layout boundary |
| `SmokeTestRunner.gd` | 218 | Smoke / fast regression |
| `SaveFlowControllerTestRunner.gd` | 190 | Save/load orchestration |
| `IntegrationTestRunner.gd` | 133 | Cross-system correctness |
| `StartMenuSceneTestRunner.gd` | 55 | Scene wiring |
| `GameStateCoordinatorTestRunner.gd` | 50 | Gameplay state flow |
| `GameHUDSceneTestRunner.gd` | 27 | Scene wiring |
| `EventRouletteSceneTestRunner.gd` | 14 | Scene wiring |
| `RestorePlanTestRunner.gd` | 11 | Restore planning |
| `SettingsPanelSceneTestRunner.gd` | 9 | Scene wiring |

**Total: 1083 expected checks** across 10 runners.

## Categories / 测试分类

### Scene Wiring Tests / 场景接线测试

Verify `.tscn` scenes load, node paths stay stable, setup code does not break layout.

Files: `StartMenuSceneTestRunner`, `GameHUDSceneTestRunner`, `EventRouletteSceneTestRunner`, `SettingsPanelSceneTestRunner`

Run after: editing `.tscn`, changing scene scripts, changing node paths.

### Coordinator & Restore Helper Tests / 协调器与恢复辅助测试

Verify extracted helper logic without full runtime boot.

Files: `GameStateCoordinatorTestRunner`, `SaveFlowControllerTestRunner`, `RestorePlanTestRunner`

Run after: splitting `Main.gd`, changing save/load orchestration, changing restore boundaries.

### Smoke Test / 冒烟测试

Fast regression guard. Confirms major systems work at high level.

Files: `SmokeTestRunner`

Run after: almost any medium-sized gameplay or system change.

### Integration Test / 集成测试

Medium-weight cross-system correctness. Save/load, battlefield rules, win conditions.

Files: `IntegrationTestRunner`

Run after: touching save/load, battlefield rules, win-condition logic.

### Layout Boundary Test / 布局边界测试

Verify layout profiles, catch overflow and placement regressions.

Files: `LayoutSanityTestRunner`

Run after: changing layout profiles, HUD/chamber/map placement.

## Performance Probes / 性能探针

Not correctness tests. Measure performance and pressure behavior.

- `PerfBurstBenchmark.gd` — full suite
- `PerfBurstBenchmarkSingleTurret.gd` — single-turret half
- `PerfBurstBenchmarkMultiTurret.gd` — multi-turret half

Run when: tuning firing or performance policies, collecting benchmark evidence.

## Test Infrastructure / 测试基础设施

- `scripts/tests/TestAssert.gd`
- `scripts/tests/TestFixtures.gd`

## What To Run / 改动后跑什么

### Editing `.tscn` or UI wiring
1. Scene wiring tests
2. Layout boundary test
3. Smoke test

### Editing save/load or continue orchestration
1. `SaveFlowControllerTestRunner`
2. `RestorePlanTestRunner`
3. `IntegrationTestRunner`
4. `SmokeTestRunner`

### Editing restore ownership or sequencing
1. `RestorePlanTestRunner`
2. `SaveFlowControllerTestRunner`
3. `SmokeTestRunner`
4. `IntegrationTestRunner`

### Editing gameplay state flow
1. `GameStateCoordinatorTestRunner`
2. `SmokeTestRunner`
3. `IntegrationTestRunner` if save/win flow involved

### Adding a new gameplay feature
1. Most relevant helper/scene tests
2. `SmokeTestRunner`
3. `IntegrationTestRunner` if rules/save/win flow changed
4. Performance probe only if runtime pressure or rendering cost changes

## CI / GitHub Actions

The `Headless Tests` workflow in `.github/workflows/test.yml` runs validate + all 10 runners in parallel on every push. Artifacts uploaded even on failure.
