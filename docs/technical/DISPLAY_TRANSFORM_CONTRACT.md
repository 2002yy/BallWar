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

## 五、顺带修复：跨分辨率存档偏移

`bf_x = (viewport.x - 520) / 2` 意味着**在 A2 之前**，战场原点就随窗口宽度变化：

| 画布 | 旧战场原点 x | 现在 |
|---|---|---|
| 1120×720 | 300 | 300 |
| 1280×720（1920 窗口） | **380** | 300 |

所以「1920 存档、1120 恢复出现偏移」是一个**先于 A2 存在的问题**，不是 A2 引入的。
A2 的第一版（Node2D）会让它更糟；改用 CanvasLayer 后，棋盘坐标固定在设计空间，
该问题**按构造被消除**（上表三档实测均为 `(300, 108)`）。

## 六、仍留给内核的决定

本方案只保证「显示不改变模拟」，没有改动内核的坐标约定。若 Codex 希望进一步把
Bullet/Turret 统一到**战场局部坐标**，那是独立的价值（减少对节点层级的隐式依赖），
不是本契约的必需项。两种方案可以共存：CanvasLayer 保证显示层不越界，局部坐标改进内核内聚。

## 七、未覆盖

- 触屏：只有桌面鼠标环境，没有 Android 设备。拾取变换走的是同一条
  `get_global_transform_with_canvas()`，但未实机验证。
- 4K：窗口被裁到 2564×1570，未验证。
