# T2.1 经典存档确定性定位

Date: 2026-11-28
Status: `feat/t2-save-main`，独立于实验玩法
Base: `main@61b80a5`

## 1. 方法

在经典模式（无特殊弹、无互撞、无 P3）上给探针加 `BALLWAR_SAVE_RESUME_AT=<秒>`：跑到存档点，写槽 5、退菜单、继续，再保持同一个 tick 编号。与不中断运行逐 tick 比较。

用 `BALLWAR_DETAIL_FROM/TO` 输出存档点前后每个炮台/控制仓的原始签名，找第一处真实差异，而不是只看哈希。

## 2. 找到的真实差异

### 2.1 炮台 `burst_timer` 负值被夹成 0

存档里 `turret_burst_timer` 可能是负数（本 tick 已到发射点、正在追赶）。旧 `Turret.restore_from_state()` 用 `clampf(..., 0.0, 1.0)`，恢复后变成 0，炮台发射节拍从存档 tick 就分叉。

修复：夹到 `[-1.0, 1.0]`，保留负的追赶状态。

### 2.2 `burst_origin_angle` 没有存档

`Turret.restore_from_state()` 直接把 `burst_origin_angle = rotation`，而 base 的 burst 起始角可能不同。存档里没有这个字段，所以炮台签名在存档 tick 就不同。

修复：存档增加 `turret_burst_origin_angle`，恢复时优先使用存档值。

### 2.3 控制球 `stay_time` 浮点末位

控制球 `stay_time` 在 JSON 往返后可能差 1 ULP。尝试了 `String.num(...,17)`、`var_to_str` 和 `float_to_text`（`var_to_bytes().hex_encode()` 逐位保存），但探针仍在存档 tick 看到 `1.266666666666667` vs `1.2666666666666673`。

这不是“缺字段”，而是**存档读取与探针记录之间的浮点状态时机差**；目前未用每 tick 量化掩盖。下一步应在存档前后同时导出 `stay_time` 的原始字节，确认是哪一步多推/少推了一个浮点运算。

## 3. 结果

- 修复 2.1/2.2 后，炮台签名在存档 tick 对齐；首个剩余差异缩小到控制球 `stay_time` 的 1 ULP。
- 完整跨进程在 20s/30s/45s 切点仍在存档 tick 分叉；没有出现“存档后 1–2 秒才分叉”的历史问题——在这一版 main 上，第一处差异就在存档 tick。
- 内存/JSON 层对照在 #49 上已经做过；本分支先把可独立于 #34/#39/P3 的修复提取出来。

## 4. 本分支改动

- `Turret.gd`：负 `burst_timer`、`burst_origin_angle` 恢复。
- `SaveStateBuilder.gd`：存 `turret_burst_origin_angle`、`match_seed`、`match_random_states`、`win_check_timer`、时钟文本。
- `Main.gd`：续局恢复 RNG 状态；`win_check_timer` 文本恢复。
- `SaveGameCodec.gd`：`stay_time_text`、RNG 字段净化；逐位 float 文本工具。
- `ChamberSaveAdapter.gd`：优先读 `stay_time_text`。
- `MatchBaselineRunner.gd`：`BALLWAR_SAVE_RESUME_AT` 支持。

## 5. 未做

- 不新增 `release_generation` / `pending_at_release`；没有证实它们就是根因。
- 不迁移二进制存档，不每 tick 量化。
- 没有把 #49 的 P3/#39 相关字段带进本分支。

## 6. 复现

```bash
GODOT_BIN=... BALLWAR_MATCH_SEED=12345 BALLWAR_SAVE_RESUME_AT=20 \
  bash scripts/tests/determinism_probe.sh t21_20 60
# 对照：不带 BALLWAR_SAVE_RESUME_AT
```

细节窗口：`BALLWAR_DETAIL_FROM=1200 BALLWAR_DETAIL_TO=1201`。
