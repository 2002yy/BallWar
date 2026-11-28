# P3.1 生产与发射部分解耦

Date: 2026-11-28
Status: 独立实验分支 `feat/p3-production-lab`；默认关闭
Base: `feat/p26-integration@4d6602c`

## 1. 机制

`BALLWAR_PRODUCTION_MODE`：

| 模式 | 行为 |
|---|---|
| `locked`（默认） | 经典：炮台发射期间控制仓完全冻结 |
| `accumulate`（B） | 发射期间继续跑球物理/倍率门，右门不释放；解锁保留下一轮 pending |
| `extra_batch`（C） | B + 锁定期间缓存 1 个额外批次；解锁立即接续；满仓只计 overflow |

边界：缓存上限 1 批；释放时本轮火力写入 `locked_remaining`，pending 归 1；`release_ball` 与 `queued_ball` 在锁定期间不参与物理，避免重复过门；炮台被毁/对局结束清空缓存；存档保存队列、球索引和 `production_mode`。待发射火力、特殊弹账户、储备资源仍分离。

## 2. 正确性修正（本轮）

源码审查发现并修复：

1. `set_locked(true)` 原来会先清空 `queued_volley`/`queued_ball`，炮台开始下一轮时可能丢掉缓存。现在只在解锁时消费队列。
2. `release_ball` 在发射期间继续参与物理，会重复触发倍率门；现在锁定期间跳过 `release_ball` 与 `queued_ball`。
3. `queued_ball` 恢复时增加有效性检查；无效引用降级为 `null`。
4. `production_mode` 不再只靠启动环境：存档写入 `chamber_production_mode`，恢复时优先使用存档值。
5. 满仓后的过门只累计 `queue_overflow`，不排队、不重复消费。

测试：`ProductionDecouplingTestRunner` 15 checks（经典不释放、B 保留 pending、C 单批缓存/overflow/补发/重新锁定、`set_locked(true)` 保队列、释放球冻结、模式存档往返）。

## 3. 600 秒 10 种子（修正后）

F7/F8 × A/B/C × 10 种子 × 600 秒，普通弹、互撞关闭，共 60 局全部有效。

| 生产 | 模式 | 发弹 | 空弹幕 | <10 发 | <30 发 | p50 | p95 | 峰值 | 首座摧毁 | 自然终局 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| F7 | locked | 6893 | 3.9% | 37.3% | 50.5% | 56 | 624 | 834 | 193.0s | 10/10 |
| F7 | accumulate | 6075 | 4.6% | 40.3% | 53.2% | 51 | 1122 | 1471 | 179.1s | 10/10 |
| F7 | extra_batch | 8010 | 4.5% | 38.8% | 52.6% | 36 | 706 | 912 | 201.9s | 9/10 |
| F8 | locked | 9918 | 2.0% | 24.1% | 33.6% | 83 | 442 | 580 | 215.6s | 7/10 |
| F8 | accumulate | 18197 | 2.1% | 22.2% | 30.8% | 171 | 406 | 507 | 236.2s | 3/10 |
| F8 | extra_batch | 11637 | 2.7% | 23.9% | 32.2% | 122 | 448 | 546 | 226.7s | 7/10 |

## 4. 结论

1. **F8-B 的“持续弹幕”最强，但牺牲终局**：发弹 +83%、p50 83→171、<30 发 33.6→30.8%；自然终局从 7/10 降到 3/10，首座摧毁也更晚。它把火力摊薄到更长时间，但没有把优势转成炮台击杀。
2. **F8-C 是目前最平衡的候选**：发弹 +17%、p50 83→122、<30 发 32.2%、自然终局保持 7/10。它提高中位密度，没有明显损害收尾。
3. **F7-C 不改善持续弹幕**：发弹 +16%，但 p50 56→36、<30 发略升，属于“更多但更集中”，不是我们要的持续观感。F7-B 发弹 -12%、p50 51，直接降级。
4. **B/C 不是通用解**：F7 和 F8 的方向相反。当前应优先验证 F8-C；F8-B 作为“高密度但难收尾”的对照保留。
5. **空弹幕仍几乎不变**（2.0–4.6%）；修的是 10–50 发区间，不是完全空窗。要消除完全空窗，需要生产节拍或球回收机制。
6. **早期 300 秒矩阵中 F8-B p50=89 的优势包含 release_ball 继续跑物理的重复生产**；修正后 600 秒数据才是有效结论。

## 5. 裁定

- 主候选：**F8 + extra_batch（C）**。
- 对照：F8 + accumulate（B）；只用于研究“密度 vs 终局”的取舍。
- F7-B、F7-C 不再作为持续火力候选；F7 locked 仍是快节奏基线。
- 默认 `locked` 不变，不进入经典模式；不进入 P3-D / 无限缓存。

## 6. 复现与录像

```bash
GODOT_BIN=/path/to/godot RUN_WIN=/path/to/run-iso.sh JOBS=10 \
  DURATION=600 SEEDS="60001 ... 60010" PRODUCTIONS="F7_combo F8_balls2_gate3" \
  MODES="locked accumulate extra_batch" bash scripts/tests/p3a_production.sh
```

完整自然对局录像：`docs/art/p3/natural_f8_extra_batch_full.mp4`（F8 + `extra_batch`，600 秒窗口，Godot Movie Maker 直接录制，非强制齐射）。
