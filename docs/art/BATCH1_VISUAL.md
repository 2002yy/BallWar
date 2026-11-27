# 美术第一批：渲染器化 + 战场视觉减负

Date: 2026-11-27
Role: art / UI window, batch 1
Baseline: `origin/main@8bb8ad5`（已合入 #20 阶段 0A）
Evidence: `docs/art/batch1/`

这批**不是完整的视觉升级**。准确名称是「炮台与弹珠渲染器改造 + 战场视觉减负」。
控制仓、领土地图层次、HUD、结算页、音频、全屏背景都不在其中。

## 一、交付内容

### 1. 绘制从玩法脚本里拆出来

`ChamberRenderer.draw(canvas_item, snapshot)` 是本仓库既有的分工方式，新模块沿用同一契约，
没有另造第二套。

| 文件 | 性质 |
|---|---|
| `scripts/render/ArtStyle.gd` | 新增。按对象分配风格 + 金属/玻璃色阶 + 共享图元 + 低特效判断 |
| `scripts/render/TurretRenderer.gd` | 新增。机械装甲炮台 / 弹珠机炮台两套画法 + 受击 + 残骸 + 血条 |
| `scripts/render/BulletRenderer.gd` | 新增。弹珠质感，最多 5 个图元（池上限 6000），`simple` 仍单圆 |
| `scripts/Turret.gd` | 改：`_draw()` 委托；新增 `muzzle_flash` 纯视觉计时器（**净减代码**） |
| `scripts/Bullet.gd` | 改：`_draw()` 委托（**净减代码**） |
| `tools/capture/capture_battle.gd` | 新增。走菜单同一条开局路径截实机图 + 采帧时间 |

`muzzle_flash` 是唯一新增的模拟侧状态：一个 `float` 计时器 + `queue_redraw()`，
不参与发射判定、伤害、碰撞或胜负。

### 2. 按对象分配风格（混合方案）

裁定是「C 为整体视觉基础，B 为战斗机械设计语言」，因此**风格按对象解析，不是全局开关**：

| 对象 | 风格 | 状态 |
|---|---|---|
| 炮台 turret | `mechanic` 机械装甲 / 能源核心 / 粗炮管 | 已实现 |
| 弹珠 bullet | `pinball` 明亮材质 / 玻璃高光 | 已实现 |
| 控制仓 chamber | `pinball`（机械框架待 A5） | 未实现 |
| HUD | 军事控制台，不用弹珠机面板 | 未实现 |

`BALLWAR_ART_STYLE=mechanic|pinball` 仍然存在，但**只用于 A/B 对照截图**，
它会把所有槽位强制成同一风格，不参与正式出包。

### 3. 战场视觉减负（P0-A）

| 项目 | 做法 | 约束 |
|---|---|---|
| 大面积阵营水印 | 在 `BattlefieldDecorLayer` 的 `emblem_alpha_mul` 取值处置 0 | **未改 `GameConfig`**，未引入跨模块依赖；原有 `if emblem_alpha_mul > 0.01` 判断保留，喂非零值即可恢复 |
| 固定黑色十字分割线 | 删除两条 `draw_line(..., Color.BLACK, 2)` | 领土易主后仍切四块且无规则含义；外层边框与基础网格保留 |

徽记迁移到控制仓标题、顶部阵营卡与结算页（A3/A5）。

### 4. 低特效开关变成可达

`ArtStyle.low_effect()` 原先只读一个**从未被写入**的静态变量，所有低特效分支都是死代码。
现在它同时读 `BALLWAR_LOW_EFFECT=1`，低特效路径可以在实机验证（见证据 `08`）。
设置面板的正式接线在 A8。

## 二、证据

| 图 | 内容 |
|---|---|
| `01_before_battle.png` | 改造前中期（seed 12345，高画质） |
| `02_after_mechanic.png` | 机械能量风全屏 |
| `03_after_pinball.png` | 弹珠机风全屏 |
| `04_before_result.png` | 改造前限时模式结算（暴露结算页问题） |
| `05_mechanic_crop_2x.png` | 炮台 2 倍局部 |
| `06_hybrid_1120.png` | **正式混合方案**，1120×720 |
| `07_hybrid_1920.png` | **正式混合方案**，1920×1080 |
| `08_low_effect_pair.png` | 低特效开/关同一炮台局部 |

`06`/`07` 中可确认：水印与十字线都已消失，四个炮台从领土上分离出来。

## 三、性能（同条件 A/B，vsync 关闭）

**先说明为什么必须关 vsync**：默认开着 vsync 时，改造前后都报 `frame_ms_avg = 4.166`、
`fps = 240.1`——240 Hz 上限把两者都钉住了，测的是上限而不是成本，**这种数字不能用**。

关 vsync 后（`CAPTURE_NO_VSYNC=1`，`--max-fps 0`，40×40、高画质、seed 12345、1120×720、gl_compatibility、30 s 窗口）：

| | 平均 | p50 | p95 | p99 | fps | 样本 |
|---|---|---|---|---|---|---|
| 改造前 `8bb8ad5` | 2.466 ms | 2.352 ms | 3.347 ms | 4.121 ms | 405.6 | 7234 |
| 改造后（本分支） | 2.917 ms | 2.789 ms | 3.849 ms | 5.060 ms | 342.8 | 6109 |

**结论：渲染器化有真实代价，平均帧时间 +0.45 ms（+18%），帧率 −15%。**
不是零成本。当前 342 fps 对 60/120 Hz 仍有 2.8–5.7 倍余量，可以接受，
但 A2 全屏机械底板会继续增加填充率开销，必须带着这个数字做预算。

**读数限制**：两轮用的是同一 seed，但模拟尚未确定（阶段 0B/0C 未完成），
采样期间屏幕上的弹丸数量不完全相同。因此这组数字应读作量级参考，不是精确增量。

## 四、已验证与未验证

**已验证**

- 1120×720 与 1920×1080：实机运行 0 SCRIPT ERROR、0 WARNING
- 与 #24（移除炮台 FPS 分支）合并后：无冲突，`muzzle_flash` 与新的发射节奏共存，
  实机 0 报错。两处改动在 `Turret.gd` 中位置不相邻（#24 在 `_burst_interval_multiplier` /
  `_max_shots_this_frame`，本分支在 `_spawn_bullet` / `_draw`）
- 低特效开/关有可见差异

**未验证 / 做不到**

- **3840×2160 没测成。** 请求 3840×2160 时窗口被系统裁到 2564×1570（`--resolution`
  生效了，是窗口管理器/屏幕尺寸限制）。这台机器无法验证真 4K，不冒充已验证。
- 模拟非确定性导致同 seed 两轮的弹丸分布不同，性能数字非严格同屏压力。
- 没有录像。

## 五、已确认但本批未修的缺陷

1. **HUD 比分条最小宽度**：`RuntimeHudController.gd` 用 `segment.size.x = maxf(50.0, seg_w)`，
   某个阵营 0% 时仍占 50 px，四阵营极端情况下总宽超出容器。→ A3
2. **外围大面积纯黑**：1920 下左右各约 150 px 与 250 px 黑带，战场约占窗口面积 31%。→ A2
3. **加球按钮浮在控制仓外侧**，与所属控制仓失去视觉连接。→ A2/A5
4. **设置/暂停/退出悬在面板外的黑底上**。→ A2/A3
5. **调试条常驻**占满底边（`FPS 240 | 子弹 1/6000 | 队列 0 | …`），正式模式应默认隐藏。→ A3
6. **结算页无独立面板**：横幅压在战场上，底部另有一行被裁掉的「绿方 胜利！」，
   `ResultPanel.tscn` 存在但未被这条路径使用。→ A3
7. 控制仓仍是点阵圆盘，未做玻璃盖板/金属边框。→ A5
8. 领土无动态边界层次。→ A6

## 六、复现

```bash
export GODOT_BIN=/path/to/Godot_v4.7.1-stable_win64_console.exe

# 正式混合方案截图
CAPTURE_OUT=/tmp/shots CAPTURE_SHOTS="mid:11" CAPTURE_SECONDS=14 CAPTURE_SEED=12345 \
  "$GODOT_BIN" --path . --script res://tools/capture/capture_battle.gd

# 低特效
BALLWAR_LOW_EFFECT=1 ...（同上）

# 可比的帧时间（必须关 vsync，否则读到的是刷新率上限）
CAPTURE_PERF=1 CAPTURE_NO_VSYNC=1 ... "$GODOT_BIN" --max-fps 0 --path . \
  --script res://tools/capture/capture_battle.gd
```
