# 显示变换契约：显示不能改变模拟

Date: 2026-11-27
Status: 已实施并实测（`art/layout-space`）
Scope: 分辨率适配、镜头缩放、战场自定义的共同约束

## 一、契约

> **任何显示变换（缩放、平移、分辨率、DPR）都不得改变模拟状态的演化。**

违反它的表现不是报错，而是同一份逻辑在 4:3 窗口上跑出不同战况、同一份存档在另一台
机器上恢复错位——这两种都极难在事后归因。

## 二、问题：Node2D 父节点缩放会污染模拟坐标

`Bullet`、`Turret`、`SaveGameCodec` 全部在**全局坐标**下工作：

| 位置 | 代码 |
|---|---|
| `Bullet.gd:34` / `:159` | `global_position + direction * speed * delta`，再 `battlefield.to_local()` |
| `Bullet.gd:194` | `battlefield.world_to_cell(global_position)`（占格） |
| `Turret.gd:269` | `global_position + shot_direction * muzzle_distance`（炮口） |
| `SaveGameCodec.gd:132` | `vec2_to_arr(node.global_position)`（存档） |

把棋盘放进一个**缩放的 Node2D** 后，这些都变了。实测（`tools/tests/coord_semantics_probe.gd`）：

| 载体 | `child.global_position` | 全局 +3 px 对应的局部位移 |
|---|---|---|
| Node2D 父节点 scale 1.45 | `(225, 158)` | **2.069** |
| CanvasLayer transform 1.45 | `(100, 100)` | 1.0 |

Node2D 那一行意味着：**显示放大 1.45 倍，子弹在模拟里慢了 1.45 倍**，同时炮口距离、
碰撞半径、占格判定相对变小。

## 三、解法：用 CanvasLayer 承载显示变换

`board_root` 由 `Node2D` 改为 `CanvasLayer`，`transform` 照旧设置。

CanvasLayer 的变换在**绘制阶段**生效，不属于 Node2D 父链，因此子节点的
`global_position` / `global_transform` 仍停留在设计空间坐标：

```
canvas=(1120, 899)  board_scale=1.1252  battlefield.global_position=(300, 108)
canvas=(1120, 720)  board_scale=1.0000  battlefield.global_position=(300, 108)
canvas=(1280, 720)  board_scale=1.0000  battlefield.global_position=(300, 108)
```

同一份代码，`board_scale` 变了，`global_position` 没变。控制仓：

```
canvas=(1120, 899) chamber(BLUE) draw_origin=(154.9, 173.7) draw_scale=0.9002 sim_position=(200, 104)
canvas=(1120, 720) chamber(BLUE) draw_origin=(200.0, 117.0) draw_scale=0.8000 sim_position=(200, 104)
```

`draw_scale = 0.8 × 1.1252`，`sim_position` 恒定——**渲染与拾取被缩放，模拟没有**。
`get_global_transform_with_canvas()` 是 Control 拾取用的变换，它包含 layer 变换，
所以点击位置与画面一致。

**Bullet / Turret / SaveGameCodec 一行未改。**

## 四、回归测试

### 尺度不变性（模拟侧）

同一 seed、同一固定步长，比较 1.0× 与 1.45× 的逐 tick 模拟哈希：

```bash
export GODOT_BIN=/path/to/Godot_v4.7.1-stable_win64_console.exe

BALLWAR_BOARD_SCALE=1.0  bash scripts/tests/determinism_probe.sh sc10  15
BALLWAR_BOARD_SCALE=1.45 bash scripts/tests/determinism_probe.sh sc145 15
bash scripts/tests/compare_traces.sh \
  determinism_runs/sc10.*/Godot/app_userdata/*/trace_sc10.tsv \
  determinism_runs/sc145.*/Godot/app_userdata/*/trace_sc145.tsv
```

结果：**`SIMULATION HASHES MATCH (ticks 0..900, time_cap)`**

### 负对照（证明测试有鉴别力）

把 `board_root` 临时换回 `Node2D`，同样 1.45×：

```
DIVERGES at tick 208
```

**208 正是第一发子弹的 tick。** 说明这个测试确实能抓到坐标污染，不是无效测试。

`BALLWAR_BOARD_SCALE` 只用于这条回归，不属于游戏功能。

## 五、跨分辨率坐标偏移：实测归因（并更正上一版我的错误说法）

上一版本文档写「偏移先于 A2 存在」，**这个说法是错的**，因为没有旧版实测就下了结论。
补测三个版本，同一采集器、同一 `CAPTURE_DIAG` 输出：

| 版本 | 1120 画布（逻辑 1120×720） | 1920 窗口（逻辑 1280×720） |
|---|---|---|
| `3b9b04b` #22 合并态，A2 之前 | 300 | **300** |
| `7f41d02` 仅 A2.1 视口修正 | 300 | **380** |
| `5ef0544` A2.2 + CanvasLayer | 300 | **300** |

结论修正为：

- **A2 之前没有这个问题。** 旧代码把常数 `Vector2(1120, 720)` 传给布局，
  战场原点恒为 300，与窗口无关。
- **偏移是 A2.1 引入的**：一旦传入真实视口，`bf_x = (viewport.x - 520) / 2`
  就随画布宽度变化，1280 画布下变成 380。
- **A2.2 的 CanvasLayer 消除了它**：棋盘坐标固定在设计空间。

也就是说，这个缺陷**全程存在于本 PR 内部，从未进入 main**，历史存档不受影响。

**这一节只证明坐标基准不再随分辨率变化，不证明存档链路端到端正确。** 端到端的验证见下一节。

## 五之二、跨分辨率存档往返实测（对 #29 的独立交叉核对）

工具：`tools/capture/run_save_restore_probe.sh`。两个独立进程 —— 进程 1 在 A 分辨率
打完 15 秒并写入真实 `.save` 文件，进程 2 用 B 分辨率 `_continue_saved_game()` 恢复，
在同一帧内排空恢复队列（不跨帧，否则测的是「恢复后飞了 N 帧」），再比对每颗炮弹
**相对战场**的位置。

`SaveFlowController` 会把越界槽号**静默钳位**到最大槽位（请求槽 6 → 实际写槽 5，即玩家槽），
探针现在比较解析后的路径并直接拒绝，runner 也在跑前备份、跑后还原玩家槽位。

**正向（当前分支 `5ef0544`）**

| 项 | 值 |
|---|---|
| 画布 | 1120×840（4:3 窗口）→ 1280×720（16:9） |
| 棋盘缩放 | **1.1252** → 1.0000 |
| 战场原点 | (300,108) → (300,108) |
| 比对炮弹 | **24 / 24** |
| 局部最大偏差 | **0.0000 px** |
| 全局最大偏差 | 0.0000 px |
| 恢复后对局时钟 | 15.002s（与保存时一致） |

**负对照（`7f41d02`，仅 A2.1）**

| 项 | 值 |
|---|---|
| 战场原点 | (300,108) → **(380,108)** |
| 比对炮弹 | 39 / 39 |
| 局部最大偏差 | **80.0000 px** |
| 全局最大偏差 | 0.0000 px |
| 退出码 | 4（FAIL） |

**80.0000 正好等于原点位移 380−300。** 这条负对照的意义在于：正向的 `global_max` 也是 0，
所以「全部通过」本身不能证明测试有效；只有在旧版本上**必然失败**、且失败量等于理论位移，
才能说明这个测试测的是它声称要测的东西。最差样本：
`saved_local=(4.904, 174.813) → restored_local=(-75.096, 174.813)`，只有 x 偏了 80。

**与 #29 的分工（避免重复）**

PR #29（`fix/a2-simulation-coordinates`，base 为本分支）已提供跨分辨率存档的**主**验证：
真窗口 1920×1080 保存 → 1120×720 恢复，含拖尾与旧 schema 记录，21 项专项通过，
并引入 schema 2.1.0 的 `position_space`（战场局部坐标）。**它是权威测试，本探针不替代它。**

本探针的增量只有三点，都不在 #29 的覆盖内：

1. **缩放 ≠ 1 的档位**：4:3 画布下棋盘缩放 1.1252，而 #29 的两档都是 1.00；
2. **负对照**：证明这条测试会失败（80.0000 px），#29 的 body 未提及负对照；
3. **跨进程**：走真实 `.save` 文件、两次独立启动，不是同进程内构造状态。

样本量说明：新开 40×40 对局任意时刻只有 1–4 发炮弹存活，比对样本过薄。
探针用玩家同一个 `add_control_ball()` 把四仓填满（+28 球）后才得到 24 发；
这是测试夹具，不改任何规则。**重复运行时样本数会变**（同配置两次实测 24 与 20 发），
因为夹具填仓与发射节奏受帧时间影响，窗口化运行不是固定步长；
两次的局部偏差都是 0.0000 px，样本数波动不影响结论。

## 六、仍留给内核的决定

本方案只保证「显示不改变模拟」，没有改动内核的坐标约定。若 Codex 希望进一步把
Bullet/Turret 统一到**战场局部坐标**，那是独立的价值（减少对节点层级的隐式依赖），
不是本契约的必需项。两种方案可以共存：CanvasLayer 保证显示层不越界，局部坐标改进内核内聚。

事实上 Codex 已在 #29 中选择了后者，两者已叠加验证（见 §五之二 与 #29）。

## 七、未覆盖

- 触屏：只有桌面鼠标环境，没有 Android 设备。拾取变换走的是同一条
  `get_global_transform_with_canvas()`，但未实机验证。
- 4K：窗口被裁到 2564×1570，未验证。离屏 `SubViewport` 只作为**布局与清晰度**的替代证据，
  不等于真实 4K 窗口、输入或整机性能验收。
- **跨版本存档兼容**：本探针的保存与恢复都由同一构建完成，只证明「同一版本内换分辨率不出偏移」。
  由旧构建写出的 1.9 / 2.0 记录在新构建里的恢复，属 #29 的专项（含旧记录用例），不由本探针覆盖。
- 恢复队列的**逐帧分批**行为只在单帧内排空验证过；真实玩家路径下队列跨帧排空期间的观感未测。
