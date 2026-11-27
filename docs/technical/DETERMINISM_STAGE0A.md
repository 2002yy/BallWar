# 确定性故障定位报告（阶段 0A）

Date: 2026-11-27
Role: 故障定位报告 / 只做测量与归因，未改玩法逻辑
Baseline: `origin/main@3a02eb5`（分支 `feat/determinism-probe`）
Prerequisite: `docs/design/SIMULATION_QUALITY_SEPARATION.md` §9（阶段 0 的由来）

## 一句话结论

**首次分歧发生在 tick 544、阵营 2 的炮塔，字段是 `burst_timer`（连带 `burst_remaining`）。
根因是 `Turret._next_burst_interval()` 调用的 `_burst_interval_multiplier()` 读取了
`Engine.get_frames_per_second()`；而 headless + `--fixed-fps` 下该值是墙钟测量值，
前 7–13 秒恒为 1，各进程跳出该窗口的时刻不同。**

对 11 轮基线做 55 对两两比较：**18 对分歧，且恰好是"一方 fps 已恢复、另一方仍为 1"的全部 18 对**，
无一例外、无一遗漏。与随机种子、帧对齐、画质都无关。

## 一、测量工具（本轮修正）

`scripts/tests/MatchBaselineRunner.gd` 相对 v1 改了四处。方向都是让"找不到分歧"变成
"分歧无处可藏"，不是让结果变得好看：

| 修正 | 原因 |
| --- | --- |
| 每 tick 输出一行，替代 10s 采样 | 10s 采样会把 544 这种单 tick 分歧直接跨过去 |
| `sim_hash` 只由 5 个子哈希组成，`proc`/`phys`/`fps` 独立成列 | 原摘要混入 FPS，等于用不确定量当指纹，任何比较必然不等 |
| `turret_sig` 增加 `burst_timer`(%.4f) 与 `burst_index` | 只哈希 `burst_remaining` 会把分歧报**晚一 tick**（实测旧摘要报 545，实际 544） |
| `end_reason` 区分 `game_over` / `time_cap` | 原逻辑把"到达时间上限"也当成对局结束 |

另外两件事：

* 每次启动创建全新的隔离 APPDATA。探针校验标记与实际 user:// 路径，并拒绝使用已有文件的用户数据目录。开局后仍断言实际生效配置（不匹配退出码 2）。
* 控制仓摘要和明细包含每颗控制球的位置、速度、半径、停留时间和卡球状态。以下历史统计来自当时记录的状态摘要。
* 明细窗口（`BALLWAR_DETAIL_FROM`/`_TO`）输出每个对象的原始签名，所以下文表格里的
  `0.1193` / `0.0153` 是读出来的，不是推算的。

## 二、实验条件

```
--headless --fixed-fps 60 --path <worktree> --script res://scripts/tests/MatchBaselineRunner.gd
BALLWAR_MATCH_SEED=12345   画质=中   模式=基础模式   网格=40   面板=经典   时长=15/45/90s
```

每轮使用独立 `APPDATA`（`runs_0a/<label>`），互不共享 `user://`。
实测 `process delta` 与 `physics delta` 均为 min=max=0.01667、`p/physics=1.001`、
`proc`/`phys` 计数在所有轮中一致（902/901）——**引擎侧确实是定步长，帧对齐稳定**，
可以排除"delta 抖动"与"帧错位"这两层。

## 三、首次分歧（tick 544）

tick 543 两轮的五个子哈希全部相同（`owners_h`、`turret_h`、`chamber_h`、`bullet_h`、`event_h`），
tick 544 同时裂开。明细如下（两轮都在 544 打出同一发弹，位置 `2:350.33:605.20` 完全相同）：

| 运行 | tick 544 的 fps | 阵营2炮塔 `burst_timer` | `burst_index` |
| --- | --- | --- | --- |
| r1 | 1 | **0.1193** | 1 |
| r2 | 444 | **0.0153** | 1 |

同一发弹，`_next_burst_interval()` 的返回值相差 0.104 秒。代入公式可反推倍率：

```
pulse_pattern[1] = 0.032   前值 -delta = -0.0167
r1: 0.032 × 4.25 - 0.0167 =  0.1193   → mul = 4.25（fps < 10 分支）
r2: 0.032 × 1.00 - 0.0167 =  0.0153   → mul = 1.00（fps ≥ 50 分支）
```

于是下一 tick（545）：

* r1：`0.1193 - 0.0167 = 0.1027 > 0` → 不发射，`burst_remaining` 仍为 1。
* r2：`0.0153 - 0.0167 = -0.0013 ≤ 0` → 发射第二颗，`burst_remaining → 0`、`burst_index → 2`。

这就是首次分歧的全部内容：**不是发射时机差半帧，而是两轮用了不同的发射节拍。**

## 四、为什么各进程的 fps 不同

`--fixed-fps` 固定的是 delta，**不固定 `Engine.get_frames_per_second()`**——后者是墙钟测量。
headless 下实时同步被关闭，早期没有测量样本，实测前 7–13 秒恒为 **1**，之后一次性跳到真实值。

首个弹在 tick 208（3.47s），完全落在 fps=1 窗口内。也就是说：
**只要一次爆发横跨"fps 由 1 跳到真实值"的那一刻，这次爆发就会在中途改变节拍。**

## 五、相关性（11 轮基线，55 对）

tick 544 时的 fps 只有两种取值：`1`（仍在窗口内）或真实值（444/483）：

| 运行 | fps 恢复 tick | tick 544 的 fps | 归类 |
| --- | --- | --- | --- |
| r2 | 442 | 444 | 已恢复 |
| s45a | 481 | 483 | 已恢复 |
| r1 | 548 | 1 | 未恢复 |
| r6 | 588 | 1 | 未恢复 |
| r5 | 672 | 1 | 未恢复 |
| s90b | 735 | 1 | 未恢复 |
| s45c | 738 | 1 | 未恢复 |
| r4 | 744 | 1 | 未恢复 |
| s90a | 758 | 1 | 未恢复 |
| r3 | 761 | 1 | 未恢复 |
| s45b | 816 | 1 | 未恢复 |

* 已恢复组 2 轮 × 未恢复组 9 轮 = **18 对跨组**，全部在 **tick 544** 分歧。
* 组内比较 37 对（1 对已恢复组 + 36 对未恢复组），**共享 tick 的模拟摘要一致**。其中 s90a 与 s90b 比到 **5400 tick / 90 秒**。
* 55 对中 18 对分歧，18 正好等于跨组对数，**零例外**。

## 六、对照实验（因果验证）

把 `_burst_interval_multiplier()` 的 fps 分支固定为 `mul = 1.0`、
`_max_shots_this_frame()` 去掉 fps 门限，其余一字不改，重跑 14 轮：

| 组 | 轮数 | tick 544 时 fps 分布 | 跨桶对数 | 实际分歧对数 |
| --- | --- | --- | --- | --- |
| 基线 | 11 | 2 轮真实 / 9 轮为 1 | 18 | **18（100%）** |
| 对照 | 14 | 3 轮真实（341/465/431）/ 11 轮为 1 | 33 | **0 / 91 对** |

需要说明 `ctl12` 的 fps 是 2 —— 仍落在 `fps < 10` 同一分支，不算跨桶，因此对照组真正的
跨桶对是 3 × 11 = 33。

对照组里 fps 依然每轮不同、跳出窗口的时刻依然不同（339–801），但 **91 对共享 tick 的模拟摘要一致**。
说明分歧确实由这两处 fps 读取产生，而不是由"fps 这件事发生过"产生。
补丁已回滚，`git status` 只剩探针脚本一个改动。

## 七、顺带发现：这是与确定性无关的机器差异

`_burst_interval_multiplier()` 在 fps<10 时把间隔乘 **4.25**，`_max_shots_this_frame()`
在 fps<24 时每帧只准发 **1** 颗。叠加效果是：

> 同一份存档、同一套配置，低帧机器上的"爆发"节奏比高帧机器慢 4 倍以上，发射密度上限也不同。

即使完全不做确定性工作，这也是玩法层面的机器差异（低端机被隐性削弱）。
0B 先拿掉这两处墙钟依赖，固定步长的调度改造留在 0C。

## 八、本阶段的边界（未证明的部分）

1. **只钉住了 Turret 这一个已证实的分歧源。** 15 秒窗口内事件转盘从未触发
   （`first_event_start = none`），`EventRouletteController/View` 的时钟耦合**未被本次覆盖**，
   不能说它无害。
2. **90 秒内未发现第二个分歧源，但不等于不存在。** s90a 与 s90b 一致只能说明"在这条
   状态轨迹上、这两轮之间"没有额外分歧；换种子或跑到 5 分钟完整对局仍需重测。
3. **`Bullet._physics_process(delta)` 与 `ControlChamber._process` 未单独消融。**
   `proc`/`phys` 计数全轮一致是"未观察到错位"，不是"已证明无关"。
4. **存档恢复未测。** `restore_from_state()` 里的 `turret_burst_timer` 被 `clampf(0,1)`，
   与运行中累计出的值能否对齐，尚未对照。
5. **对照组只做到 15 秒 / 900 tick。**

## 九、下一步（按依赖顺序）

1. **0B**：单独去掉炮塔发射间隔和每帧弹量预算对实际 FPS 的依赖，保留队列调节和高 FPS 时的发射规则，重跑同种子对照。
2. **0C**：再处理渲染帧与物理 tick 的调度差异，检查事件转盘生效时刻和动画的关系。
3. **0D**：按系统拆分随机数流。
4. **0E**：分级验证。同机同配置与同机不同帧率分开验收，后续再覆盖画质、存档恢复与跨机器差异。

## 十、复现方式

启动脚本在 Windows Git Bash + Godot 4.7.1 Console 验证。每次生成唯一输出目录，后续比较时传入两轮输出的实际 TSV 路径。

```bash
export GODOT_BIN=/path/to/Godot_v4.7.1-stable_win64_console.exe
bash scripts/tests/determinism_probe.sh t1 15
bash scripts/tests/determinism_probe.sh t2 15
bash scripts/tests/compare_traces.sh <traceA.tsv> <traceB.tsv>
```

比较从 tick 0 开始，并校验 tick 连续性、实际长度、请求长度和结束原因。退出码 0 表示模拟摘要与结束信息一致，1 表示模拟摘要或结束信息不同，2 表示输入缺失或格式不完整。FPS 等诊断列不参与比较。探针拒绝未隔离的用户数据环境，退出码 5。

复现记录（本机 2026-11-27，用上面这两个脚本跑出，未用任何临时脚本）：

```
t1: tick 544 时 fps = 62   →  mul = 1.00
t2: tick 544 时 fps =  1   →  mul = 4.25
compare_traces.sh → DIVERGES at tick 544
```

`trace` 列：`tick, sim_hash, owners_h, turret_h, chamber_h, bullet_h, event_h,
bullets, leader, health_total, proc, phys, fps`。
**前 10 列为状态，后 3 列为性能，不参与哈希。**
