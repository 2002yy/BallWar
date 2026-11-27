# 美术第一批：渲染器化与两个候选方向

Date: 2026-11-27
Role: art / UI window, batch 1（验证方向与实现路线，不追求全量完工）
Baseline: `origin/main@3a02eb5`
Evidence: `docs/art/batch1/`

## 这批做了什么

把**战斗视觉从玩法脚本里拆出来**，做成可整体替换的渲染模块，然后交付两个可在实机
切换的候选方向。没有改任何玩法规则。

| 文件 | 性质 |
|---|---|
| `scripts/render/ArtStyle.gd` | 新增。风格表：金属/玻璃色阶、低特效开关、能量环与分段环的共享图元 |
| `scripts/render/TurretRenderer.gd` | 新增。炮台两套画法 + 受击 + 残骸 + 血条 |
| `scripts/render/BulletRenderer.gd` | 新增。弹珠两套画法，含 `simple` 单圆兜底路径 |
| `scripts/Turret.gd` | 改：`_draw()` 改为委托（净减 ~55 行）；新增 `muzzle_flash` 纯视觉计时器 |
| `scripts/Bullet.gd` | 改：`_draw()` 改为委托（净减 ~15 行） |
| `tools/capture/capture_battle.gd` | 新增。实机截图/帧时间采集器 |

### 为什么这样切

`ChamberRenderer.draw(canvas_item, snapshot)` 已经是这个仓库既有的分工方式，新模块沿用
同一契约，没有另造第二套。**共享文件（Turret/Bullet）的净改动是减少的**，所以与
Codex 的后端重构并行时不构成冲突面。

炮口闪光是唯一新增的状态，只有 `float` 计时器 + `queue_redraw()`，不参与任何判定。

### 风格切换

```
BALLWAR_ART_STYLE=mechanic  # 机械能量风（默认）
BALLWAR_ART_STYLE=pinball   # 精致弹珠机风
```

批次一先做成环境变量覆盖，避免在选型未定时就把开关塞进设置面板。

## 证据

| 图 | 内容 |
|---|---|
| `01_before_battle.png` | 改造前，中期（种子 12345，高画质） |
| `02_after_mechanic.png` | 改造后，机械能量风，同一场景条件 |
| `03_after_pinball.png` | 改造后，弹珠机风，同一场景条件 |
| `04_before_result.png` | 改造前，限时模式结算 |
| `05_mechanic_crop_2x.png` | 炮台 2 倍局部 |

### 帧时间（同配置：40×40、高画质、seed=12345、1120×720、gl_compatibility）

| | 采样帧数 | 平均 | p50 | p95 | p99 |
|---|---|---|---|---|---|
| 改造前 | 10278 | 4.166 ms | 4.165 ms | 4.525 ms | 5.048 ms |

改造后未采到可比的完整样本（见「未完成」），因此这张表只作基线登记，**不作为
"改造没有性能代价"的结论**。

## 观察到的、尚未修的问题

1. **结算页没有结构化面板。** 实际是压在地图中央的横幅，底部另有一行被屏幕边缘裁掉的
   "绿方 胜利！"。`ResultPanel.tscn` 存在但未被这条路径使用。
2. **调试条常驻**（`FPS / 子弹 / 队列 / 生成 …`），占满底部一行且右侧被裁。
3. **右侧 设置/暂停/退出 悬在面板外**的底色上，与整体不属一套。
4. **领土仍有巨型表情水印**（笑脸 / 五角星 / 十字），与机械炮台质感冲突。
5. **炮台在饱和色块上阵营识别偏弱**：已加阵营弧与装甲染色，仍需一轮迭代。

## 未完成（下一批，不冒充已完成）

- 控制仓玻璃/钉柱/门（`ChamberRenderer` 未改）
- 领土边界与层次（`Battlefield` 未改）
- 爆炸/粒子反馈
- **音频系统：本轮未开始**。已核实 `assets/sfx/` 下 39 个已授权音频**零引用**，
  且全仓无 `AudioServer` 调用，属从零接入
- HUD 层次重排、音量设置面板、低特效模式开关
- 改造后帧时间对照、录像

## 复现

```bash
export GODOT_BIN=/path/to/Godot_v4.7.1-stable_win64_console.exe
BALLWAR_ART_STYLE=mechanic CAPTURE_OUT=/tmp/shots \
CAPTURE_SHOTS="start:0,mid:11" CAPTURE_SECONDS=14 CAPTURE_SEED=12345 CAPTURE_PERF=1 \
  "$GODOT_BIN" --path . --script res://tools/capture/capture_battle.gd
```
