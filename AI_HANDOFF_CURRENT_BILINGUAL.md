# AI Handoff Current / 当前交接说明

Last updated / 最后更新: 2026-05-04

## Purpose / 文档目的

EN: This document is a bilingual handoff summary for both the human reader and the next AI. It explains what the project is, what has already been completed, what the active tests currently cover, and what still needs attention.

中文：这是一份给人类阅读者和下一个 AI 共用的双语交接摘要，说明项目是什么、目前已经完成了什么、现有测试覆盖了哪些内容，以及后续还需要关注哪些问题。

## Project Overview / 项目概述

EN: `BallWar` is a Godot 4.6 territory-combat game. Four factions fight on a square grid. Each faction has:

- a corner turret
- a control chamber
- bullets that capture or repaint territory cells

Win conditions depend on the selected mode:

- `basic`: last surviving turret wins
- `occupation`: first faction reaching 75% territory wins
- `timed`: highest territory share at time limit wins
- `wild`: same core loop, but the chamber multiplier gate becomes `x3`

中文：`BallWar` 是一个基于 Godot 4.6 的领土争夺游戏。四个阵营在方格地图上战斗。每个阵营都有：

- 一个角落炮塔
- 一个控制仓
- 用于占领或重涂地块的子弹

胜利条件取决于游戏模式：

- `basic`：最后存活的炮塔获胜
- `occupation`：率先达到 75% 领土占有率获胜
- `timed`：限时结束时领土占比最高者获胜
- `wild`：核心玩法相同，但控制仓倍率门变为 `x3`

## Current Code Structure / 当前代码结构

EN: Main files to understand first:

- `scripts/Main.gd`: top-level game flow, save/load, start/pause/continue, winner checks
- `scripts/GameSceneBuilder.gd`: builds battlefield, turrets, chambers, bullet pool
- `scripts/EventRouletteController.gd`: real event roulette logic
- `scripts/EventRouletteView.gd`: event roulette presentation only
- `scripts/BulletPool.gd`: bullet management and trail-pressure logic
- `scripts/ControlChamber.gd`: chamber state, jam, modifiers, ball release
- `scripts/tests/SmokeTestRunner.gd`: active logic smoke test
- `scripts/tests/PerfBurstBenchmark.gd`: active performance benchmark

中文：优先理解的关键文件：

- `scripts/Main.gd`：顶层游戏流程、存档读档、开始/暂停/继续、胜负判定
- `scripts/GameSceneBuilder.gd`：创建战场、炮塔、控制仓、子弹池
- `scripts/EventRouletteController.gd`：事件轮盘真实逻辑
- `scripts/EventRouletteView.gd`：事件轮盘纯表现层
- `scripts/BulletPool.gd`：子弹管理和拖尾压力控制
- `scripts/ControlChamber.gd`：控制仓状态、短路、修饰器、放球
- `scripts/tests/SmokeTestRunner.gd`：当前启用的逻辑冒烟测试
- `scripts/tests/PerfBurstBenchmark.gd`：当前启用的性能基准脚本

## Recent Progress / 最近进展

EN: Recent `v2.0.x` work mainly focused on:

- smoke testing
- performance benchmark infrastructure
- trail-pressure degradation tuning
- event roulette UI/presentation polish
- save-state support for event roulette

中文：最近 `v2.0.x` 阶段的工作主要集中在：

- 冒烟测试
- 性能基准设施
- 拖尾压力降级策略调优
- 事件轮盘 UI / 表现层打磨
- 事件轮盘状态存档支持

## Completion Audit / 完成情况核对

### `README_v2_0_0_tests_and_perf.md`

EN: Mostly implemented.

- Active smoke test exists
- Active performance benchmark exists
- HUD/perf counters exist
- benchmark metrics export exists

中文：大部分已经落地。

- 已有活跃的冒烟测试
- 已有活跃的性能基准脚本
- 已有 HUD / 性能计数器
- 已有 benchmark 指标导出

### `README_v2_0_1_trail_pressure_fix.md`

EN: Implemented in code, but the actual performance improvement still needs desktop verification.

- trail pressure thresholds exist
- queue/FPS/trail-segment/trail-redraw logic exists
- benchmark fields for pressure state exist

中文：代码里已经实现，但实际性能收益仍需要桌面环境验证。

- 拖尾压力阈值已经存在
- 基于队列 / FPS / 拖尾段数 / 拖尾重绘的逻辑已经存在
- benchmark 中已有压力状态字段

### `README_v2_0_2_ui_event_polish.md`

EN: Partially implemented.

- event HUD wiring exists
- event controller/view split exists
- chamber gate label logic exists
- extra benchmark observation fields exist

But:

- many source strings are still mojibake/garbled in the current workspace snapshot
- so “Chinese UI fully restored” should not yet be considered fully complete

中文：部分实现，部分仍有疑点。

- 事件 HUD 接线已经存在
- 事件控制器/视图拆分已经存在
- 控制仓门标签逻辑已经存在
- 额外 benchmark 观察字段已经存在

但是：

- 当前工作区里仍有大量中文源码字符串是乱码状态
- 所以“中文 UI 已完全恢复”这件事还不能视为彻底完成

## Test Coverage Matrix / 现有测试覆盖矩阵

### Active tests / 当前活跃测试

#### `scripts/tests/SmokeTestRunner.gd`

EN: This is a narrow but useful logic smoke test.

It currently covers:

- save validation normalization
- event roulette interval logic
- event weighting logic
- event state import/export preservation
- chamber `+10`, multiplier, add-ball fallback behavior
- jam refund behavior
- queued modifier behavior while chamber is locked
- turret `cancel_burst()`

It does not fully cover:

- full `Main.gd` gameplay loop
- battlefield correctness end to end
- save/load full round-trip
- UI wiring and layout
- event roulette view animation
- win conditions end to end

中文：这是一个覆盖面不大但很有价值的逻辑冒烟测试。

当前覆盖：

- 存档字段清洗与归一化
- 事件轮盘间隔逻辑
- 事件权重逻辑
- 事件状态导入/导出保留
- 控制仓 `+10`、倍率、加球回退行为
- `jam` 返还逻辑
- 控制仓锁定时的排队修饰器行为
- 炮塔 `cancel_burst()`

当前没有完整覆盖：

- `Main.gd` 整体游戏流程
- 战场规则的端到端正确性
- 完整的存档 -> 读档回放
- UI 接线和布局
- 事件轮盘视图动画
- 各模式胜负条件的端到端流程

#### `scripts/tests/PerfBurstBenchmark.gd`

EN: This is a performance probe, not a correctness test.

It currently measures:

- avg/min FPS
- p95/p99 frame time
- stutter counters
- active bullets
- queue pressure
- trail segments
- redraw rates
- recycle/expire rates
- trail pressure level
- draw calls
- visible canvas items estimate

中文：这是性能探针，不是功能正确性测试。

当前测量：

- 平均/最低 FPS
- p95/p99 帧时间
- 卡顿帧计数
- 活跃子弹数
- 队列压力
- 拖尾段数
- 重绘频率
- recycle / expire 速率
- 拖尾压力等级
- draw calls
- 可见 canvas item 估算值

### Legacy tests / 遗留测试

EN: The old suite under `tests_legacy_disabled/` appears broader, but it is currently disabled.

It includes:

- `TestEventRoulette.gd.disabled`
- `TestControlChamber.gd.disabled`
- `TestSaveGameCodec.gd.disabled`
- `TestBattlefield.gd.disabled`
- `TestRunner.gd.disabled`

中文：`tests_legacy_disabled/` 下的旧测试套件看起来更宽，但目前是禁用状态。

其中包括：

- `TestEventRoulette.gd.disabled`
- `TestControlChamber.gd.disabled`
- `TestSaveGameCodec.gd.disabled`
- `TestBattlefield.gd.disabled`
- `TestRunner.gd.disabled`

## Coverage Summary / 覆盖总结

EN: Current automated coverage is good for recent rule changes, but not comprehensive.

Strong coverage:

- save-data validation/clamping
- event helper logic
- chamber jam/modifier edge cases
- turret cancel-burst logic
- performance metrics collection

Weak or missing coverage:

- full gameplay integration
- battlefield end-to-end correctness
- complete save/load restore through `Main.gd`
- UI/layout validation
- localization/text correctness
- full win-condition tests

中文：当前自动化覆盖对最近改动的规则比较有保护力，但还远远谈不上全面。

当前较强的覆盖：

- 存档字段校验/钳制
- 事件辅助逻辑
- 控制仓短路/修饰器边界情况
- 炮塔 cancel-burst 逻辑
- 性能指标采集

当前较弱或缺失的覆盖：

- 完整玩法集成
- 战场规则端到端正确性
- 通过 `Main.gd` 的完整存档恢复流程
- UI / 布局验证
- 本地化 / 文本正确性
- 完整胜负条件测试

## Main Risks / 当前主要风险

### 1. Mojibake / 乱码问题

EN: Many active files still contain garbled Chinese text. This may be a true runtime issue, a source encoding issue, or both. It should be treated as an active risk.

中文：很多活跃脚本里仍然有乱码中文。这可能是真实运行时问题、源码编码问题，或两者兼有，应该视为一个当前风险。

### 2. Desktop verification is still important / 仍需桌面验证

EN: Historical notes say Codex-side Godot runtime checks are unreliable. Desktop Godot runs remain the authoritative path for smoke/perf confirmation.

中文：历史文档多次提到 Codex 环境下的 Godot 运行验证不稳定，因此桌面环境的 Godot 运行结果仍然是最终依据。

### 3. Save version is still `1.9`-prefixed / 存档版本仍沿用 `1.9` 前缀

EN: Docs are already `v2.0.x`, but save compatibility is still checked with prefix `1.9`, and `Main.gd` still writes `1.9.34`.

中文：虽然文档版本已经来到 `v2.0.x`，但存档兼容仍然按 `1.9` 前缀检查，`Main.gd` 当前写入的版本号仍是 `1.9.34`。

## Recommended Next Testing Priorities / 建议下一个 AI 优先补的测试

EN:

1. Add full save/load round-trip coverage through `Main.gd`
2. Add active battlefield correctness tests
3. Add end-to-end win-condition tests
4. Expand event controller integration tests
5. Keep perf benchmark as secondary unless FPS is the main concern

中文：

1. 增加通过 `Main.gd` 的完整存档/读档回环测试
2. 增加活跃的战场规则正确性测试
3. 增加端到端胜负条件测试
4. 扩展事件控制器集成测试
5. 如果当前不是在追 FPS，性能 benchmark 继续放在次优先级

## Recommended Reading Order / 建议阅读顺序

EN:

1. `AI_HANDOFF_CURRENT.md`
2. `README_v2_0_2_ui_event_polish.md`
3. `scripts/Main.gd`
4. `scripts/EventRouletteController.gd`
5. `scripts/BulletPool.gd`
6. `scripts/tests/SmokeTestRunner.gd`
7. `scripts/tests/PerfBurstBenchmark.gd`

中文：

1. `AI_HANDOFF_CURRENT.md`
2. `README_v2_0_2_ui_event_polish.md`
3. `scripts/Main.gd`
4. `scripts/EventRouletteController.gd`
5. `scripts/BulletPool.gd`
6. `scripts/tests/SmokeTestRunner.gd`
7. `scripts/tests/PerfBurstBenchmark.gd`

