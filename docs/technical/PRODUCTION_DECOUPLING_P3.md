# P3.1 生产与发射部分解耦

Date: 2026-11-28
Status: 独立实验分支 `feat/p3-production-lab`；默认关闭
Base: `feat/p26-integration@4d6602c`（含 P2 生产参数与实验探针）

## 1. 机制

三种模式，`BALLWAR_PRODUCTION_MODE`：

| 模式 | 行为 |
|---|---|
| `locked`（默认） | 经典：炮台发射期间控制仓完全冻结，发射结束才恢复生产 |
| `accumulate`（P3-B） | 发射期间控制仓继续跑球物理与倍率门，但右门不释放；解锁后保留已积累的下一轮火力 |
| `extra_batch`（P3-C） | 在 B 的基础上，锁定期间允许缓存 1 个额外批次；解锁后立即接续发射；满仓后的过门只计 overflow，不排队 |

边界规则：

- 缓存容量固定 1 批；`queued_volley` 上限 `GameConfig.get_max_pending_count()`。
- 释放时把本轮火力写入 `locked_remaining`，`pending_count` 归 1，下一轮从 1 重新积累，避免重复消费。
- 炮台被毁 / 对局结束：清空 `queued_volley` 与 `queued_ball`，不补发。
- 存档：保存 `chamber_queued_volley`、`chamber_queue_ball_index`、`chamber_queue_overflow`；恢复时按球索引重新绑定。
- 三个账户保持独立：待发射火力（`pending_count`/`locked_remaining`/`queued_volley`）、特殊弹火力（`FireLedger`）、玩家储备资源（#35–#38）不合并。

## 2. 实验

F2/F3/F7/F8 × {locked, accumulate, extra_batch} × 3 种子 × 300 秒，纯普通弹、互撞关闭。共 36 局，全部有效。

| 生产 | 模式 | 发弹 | 空弹幕 | <10 发 | <30 发 | p50 | p95 | 峰值 | 最长空窗 |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| F2 | locked | 4734 | 1.2% | 38.8% | 68.5% | 12 | 134 | 191 | 2.00s |
| F2 | accumulate | 3620 | 1.6% | 41.3% | 73.2% | 11 | 142 | 247 | 2.00s |
| F2 | extra_batch | 3990 | 1.2% | 31.1% | 71.4% | 14 | 109 | 160 | 2.00s |
| F3 | locked | 3518 | 13.0% | 55.5% | 64.4% | 6 | 242 | 330 | 4.22s |
| F3 | accumulate | 2268 | 16.6% | 63.1% | 74.1% | 6 | 124 | 223 | 5.43s |
| F3 | extra_batch | 3289 | 14.7% | 57.2% | 70.8% | 7 | 139 | 186 | 5.83s |
| F7 | locked | 6917 | 4.5% | 36.7% | 51.2% | 43 | 537 | 744 | 2.25s |
| F7 | accumulate | 8022 | 3.9% | 38.6% | 55.2% | 23 | 693 | 850 | 2.85s |
| F7 | extra_batch | 8474 | 3.4% | 32.3% | 44.9% | 55 | 772 | 948 | 2.72s |
| F8 | locked | 6529 | 3.7% | 33.8% | 46.4% | 42 | 220 | 268 | 2.19s |
| F8 | accumulate | 9114 | 3.3% | 23.9% | 34.6% | 89 | 266 | 340 | 2.75s |
| F8 | extra_batch | 7516 | 2.2% | 28.8% | 41.0% | 68 | 340 | 397 | 2.19s |

## 3. 结论

1. **B 对高节拍生产有效**：F7 发弹 +16%、p95 +29%；F8 发弹 +40%、p50 42→89、<10 发 33.8%→23.9%、<30 发 46.4%→34.6%。B 解决的是“10–50 发区间”的密度，不是零弹幕。
2. **C 只在高节拍上再加一档爆发**：F7 发弹 +22%、峰值 948；F8 反而低于 B（7516 vs 9114）。C 不是稳定优于 B 的升级。
3. **B/C 对 F2/F3 是负收益**：F2 发弹 -23%/-16%，F3 -36%/-7%，峰值与低弹幕都变差。继续跑球物理会让释放球在锁定期间处于不同的轨迹/卡球状态，反而破坏原本的节奏；这不是“生产越多越好”。
4. **空弹幕时间几乎不变**（F7 4.5%→3.9%→3.4%，F8 3.7%→3.3%→2.2%）；真正改善的是 <10/<30 的比例。若目标是消除完全空窗，还需要生产节拍或球回收机制，而不是只加缓存。
5. **300 秒自然终局仍少**：36 局只有 F7 locked 1/3 终局，其余 0/3；P3 机制不解决终局突破，终局仍要靠 F7/F3 + 穿透等纵深手段。

## 4. 裁定

- `accumulate` 作为 P3 的主候选，先在 F7/F8 上扩种子验证；`extra_batch` 暂不推广，只保留对照。
- F2/F3 不应直接套用 B/C；它们的瓶颈不是发射等待，而是球/门的节奏。
- 默认 `locked` 不变；所有模式都是环境开关，实验结束不进入经典模式。

## 5. 复现

```bash
GODOT_BIN=/path/to/godot RUN_WIN=/path/to/run-iso.sh JOBS=8 \
  DURATION=300 SEEDS="50001 50002 50003" bash scripts/tests/p3a_production.sh
GODOT_BIN=/path/to/godot bash scripts/tests/ProductionDecouplingTestRunner.gd
```

测试覆盖：经典锁定不释放、B 保留下一轮 pending、C 只缓存一批、二次过门计 overflow、解锁补发、缓存批次重新锁定。

真实运行录像（非强制齐射、非单帧）：`docs/art/p3/natural_f7_accumulate_25s.mp4`。F7 生产参数 + `accumulate`，1120×720、60 FPS、25 秒，Godot Movie Maker 直接录制。
