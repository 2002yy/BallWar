# 测试分类矩阵 / Test Matrix

日期: 2026-05-06

## 目标

这份文档的作用是把当前测试按职责分组，避免后续重构时“想到什么跑什么”。

重点是先区分：
- 哪些是场景接线测试
- 哪些是轻量状态/逻辑测试
- 哪些是集成测试
- 哪些是布局边界测试
- 哪些只是性能探针

## A. 场景接线测试

用途：
- 验证 `.tscn` 能加载
- 验证关键节点路径没漂
- 验证 `setup()` / `setup_static()` 不会覆盖约定好的布局边界

文件：
- `scripts/tests/StartMenuSceneTestRunner.gd`
- `scripts/tests/GameHUDSceneTestRunner.gd`
- `scripts/tests/EventRouletteSceneTestRunner.gd`
- `scripts/tests/SettingsPanelSceneTestRunner.gd`

适用时机：
- 改 `.tscn`
- 改场景脚本
- 改节点路径
- 改 UI 引用收集逻辑

## B. 轻量状态/逻辑单测

用途：
- 验证新拆分 helper / coordinator 的边界行为
- 不依赖完整战场运行

文件：
- `scripts/tests/GameStateCoordinatorTestRunner.gd`

适用时机：
- 新增 coordinator / controller helper
- 把 `Main.gd` 的局部状态职责外移

## C. 冒烟测试

用途：
- 快速确认关键系统还活着
- 覆盖 save codec、事件规则、控制舱事件、炮塔 burst 取消等高频风险点

文件：
- `scripts/tests/SmokeTestRunner.gd`

适用时机：
- 任意中型改动后
- 不确定是否破坏基础行为时

## D. 集成测试

用途：
- 验证保存/读取、战场规则、胜负条件这些跨系统流程

文件：
- `scripts/tests/IntegrationTestRunner.gd`

适用时机：
- 改战场规则
- 改 save/load
- 改胜负判定

## E. 布局边界测试

用途：
- 验证布局 profile 和边界约束
- 防止 UI 或地图布局越界

文件：
- `scripts/tests/LayoutSanityTestRunner.gd`

适用时机：
- 改布局 profile
- 改 chamber / map / HUD 位置规则

## F. 性能探针

用途：
- 做性能采样和回归观察
- 不作为 correctness 测试

文件：
- `scripts/tests/PerfBurstBenchmark.gd`

适用时机：
- 调优发射/性能策略
- 评估对象池或绘制压力变化

## G. 测试基础设施

用途：
- 断言工具
- 夹具和测试辅助

文件：
- `scripts/tests/TestAssert.gd`
- `scripts/tests/TestFixtures.gd`

## 建议运行顺序

### 改 UI / `.tscn`

1. 场景接线测试
2. 布局边界测试
3. 冒烟测试

### 改状态流转

1. 轻量状态/逻辑单测
2. 冒烟测试
3. 相关场景接线测试

### 改 save/load

1. 集成测试
2. 冒烟测试
3. 必要时场景接线测试

### 改布局

1. 布局边界测试
2. 对应场景接线测试
3. 冒烟测试

## 当前 correctness 基线

当前默认应保持通过的测试：
- `StartMenuSceneTestRunner.gd`
- `GameHUDSceneTestRunner.gd`
- `EventRouletteSceneTestRunner.gd`
- `SettingsPanelSceneTestRunner.gd`
- `GameStateCoordinatorTestRunner.gd`
- `SmokeTestRunner.gd`
- `IntegrationTestRunner.gd`
- `LayoutSanityTestRunner.gd`

`PerfBurstBenchmark.gd` 不列入“必须全绿”的 correctness 基线。

## PASS 分类

建议统一使用 3 种口径：

- `PASS`
说明断言通过，且测试退出干净。

- `PASS with cleanup warnings`
说明断言通过，但退出时仍有对象/RID/资源清理告警。

- `FAIL`
说明断言失败、脚本报错，或测试无法完成。

后续目标：
- 场景接线测试尽量达到真正干净的 `PASS`
- 不接受长期积累的 cleanup warning

## 2026-05-06 Baseline

Local Godot verification reported:
- `GameStateCoordinatorTestRunner.gd` PASS
- `SmokeTestRunner.gd` PASS
- `IntegrationTestRunner.gd` PASS
- `LayoutSanityTestRunner.gd` PASS
- `StartMenuSceneTestRunner.gd` PASS
- `GameHUDSceneTestRunner.gd` PASS
- `EventRouletteSceneTestRunner.gd` PASS
- `SettingsPanelSceneTestRunner.gd` PASS

Current recommendation:
- treat the above eight scripts as the active correctness baseline
- run `GameStateCoordinatorTestRunner.gd` first for state-flow refactors
- run scene tests first for `.tscn` or UI-node changes
