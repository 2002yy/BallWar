# T2.1 经典存档确定性定位

Date: 2026-11-28
Status: `feat/t2-save-main`，独立于实验玩法
Base: `main@61b80a5`

## 1. 方法

在经典模式（无特殊弹、无互撞、无 P3）上给探针加 `BALLWAR_SAVE_RESUME_AT=<秒>`：跑到存档点，写槽 5、退菜单、继续，再保持同一个 tick 编号。与不中断运行逐 tick 比较。

同一 tick、同一阶段取四个位置，全部打印原始位模式（`var_to_bytes().hex_encode()`），而不是只看十进制字符串：

1. 存档前内存中的值（`SaveGameCodec.collect_control_ball_states`）。
2. 实际写入文件的文本（读 `stay_time_text` / `__f64` 标记）。
3. 读取后、赋值前的值（`ChamberSaveAdapter._sanitize_control_ball_state`）。
4. 恢复后第一次物理更新前后的值（`ControlChamber._physics_process`）。

另外用 `BALLWAR_DETAIL_FROM/TO` 输出存档点前后每个炮台/控制仓的签名，找第一处真实差异。

## 2. 结论：`stay_time` 不是根因

四点的位模式全部一致（存档点 `03000100464444444444f43f` = `1.266666666666667`）。之前看到的 `1.266666666666667` vs `1.2666666666666673` 来自 `var_to_str()` 的十进制打印差异，不是数值差异；把字符串当证据会误判。

真正的原因是**所有浮点字段**都经过 Godot 的 JSON 数字序列化：

| 写法 | 9 个样本里丢失位模式的个数 |
|---|---:|
| `JSON.stringify(data)` | 6 / 9 |
| `JSON.stringify(data, "", true, true)`（full_precision） | 2 / 9 |

典型受害者是 `1/60`（`0.016666666666666666`）：写出的文本是 17 位十进制，解析回来却差 1 ULP。`hex` 承载（`var_to_bytes`）9 / 9 精确。

炮台 `turret_burst_timer` / `turret_sweep_phase` 就是这样在存档点分叉的：文件里是 `-0.0166666666666667`，内存里是 `-0.01666666666666667`。

## 3. 修法：文件边界逐位承载浮点

`SaveGameCodec.encode_floats()` / `decode_floats()` 在写文件前把每个 float 换成 `{"__f64": "<hex>"}`，读文件后还原。数字字段不再承担精度责任，结构、整数和字符串保持原样。旧存档没有标记，按普通数字读入，行为与之前一致。

同时清理了两处叠加损耗：

- `win_check_timer_text` / `game_elapsed_time_text` 原来用 `var_to_str` 写、`to_float` 读，又丢一次精度，还会覆盖已经精确的数值字段。现在文本用 hex 写，恢复时**优先用数值字段**，文本只作旧档回退。
- `ChamberSaveAdapter._float_text` 同样改为数值优先、文本回退。

## 4. 第二处真实差异：`pending_count` 影子字段与状态不同步

修完浮点后，20s 切点对齐，但 30s/45s 在存档点之后 69 / 148 tick 才分叉。逐 tick 追踪（`[T21Q]`）显示：

```
t=1799  BASE pending=2 cs_pending=1
t=1800  RES  pending=2 cs_pending=2   <- 存档写影子 2，恢复写状态 2
t=1869  BASE pending=1 ...            <- 解锁时状态被写成 1
        RES  pending=2 ...            <- 两侧从此不同
```

`_on_left_gate()` 直接乘影子字段 `pending_count`，没有同步 `chamber_state.pending_count`。存档写的是影子，恢复同时写影子和状态，两个值从此分叉。

修复：左门倍率改走 `chamber_state.apply_pending_multiplier()`，再回写影子，与 `apply_pending_bonus` 的既有写法一致。

## 5. `burst_timer` 合法范围

`_next_burst_interval()` 取 `pulse_pattern * multiplier`，上界 `0.040 * 4.50 = 0.18`；每 tick 减 `1/60`，`<= 0` 时立即补发并加回一个间隔，`< -0.10` 时归零。

所以正常运行的取值区间约为 `[-0.10, 0.18]`，负值只表示“本 tick 已过发射点”。恢复时的 `[-1.0, 1.0]` 包络不会截断合法值，也不会放过异常值。

## 6. 结果

| 切点 | 结果 |
|---|---|
| 20s | SIMULATION HASHES MATCH（tick 0..3600，time_cap） |
| 30s | SIMULATION HASHES MATCH（tick 0..3600，time_cap） |
| 45s | SIMULATION HASHES MATCH（tick 0..3600，time_cap） |

存档点不再分叉，也没有“存档后 1–2 秒才分叉”。

## 7. 回归

`SaveBitExactnessTestRunner`（26 checks，已加入 CI 的 State persistence and integration 组）：

- 编解码 9 个代表性 float 逐位一致，嵌套结构、整数、字符串不变。
- 真实 `_write_json_atomically` / `_read_save_dictionary` 往返后 float 逐位一致。
- 旧式纯数字 JSON 存档仍可读。
- 左门倍率后影子与 `chamber_state` 保持一致。

## 8. 本分支改动

- `SaveGameCodec.gd`：`encode_floats` / `decode_floats` / `hex_to_float`。
- `SaveFlowController.gd`：写文件前编码、读文件后解码。
- `ChamberSaveAdapter.gd`、`Main.gd`、`SaveStateBuilder.gd`：数值字段优先，文本只作旧档回退。
- `ControlChamber.gd`：左门倍率同步状态；可选 `BALLWAR_T21_TRACE` 位模式追踪。
- `Turret.gd`：负 `burst_timer` 夹到 `[-1,1]`，`burst_origin_angle` 入档并恢复。
- `MatchBaselineRunner.gd`：`BALLWAR_SAVE_RESUME_AT`、`BALLWAR_DETAIL_FROM/TO` 细节窗口。

## 9. 未做

- 不新增 `release_generation` / `pending_at_release`。
- 不迁移二进制存档；仍然是可读 JSON，只是浮点用 hex 标记承载。
- 不做每 tick 量化，不放宽哈希比较。

## 10. 复现

```bash
GODOT_BIN=... BALLWAR_MATCH_SEED=12345 BALLWAR_SAVE_RESUME_AT=20 \
  bash scripts/tests/determinism_probe.sh t21_20 60
bash scripts/tests/compare_traces.sh <base.tsv> <t21_20.tsv>   # 期望 0..3600 MATCH

# 位模式追踪（可选）
BALLWAR_T21_TRACE=1 ...  # 打印 [T21P1]/[T21P3]/[T21P4]
```

细节窗口：`BALLWAR_DETAIL_FROM=1200 BALLWAR_DETAIL_TO=1201`。
