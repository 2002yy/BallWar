# 项目路线图 / Project Roadmap

BallWar 领土战争 — 从 v2.0.3 出发的工程路线。

---

## 一、总方向：先稳，再拆，再加功能

当前项目不是"缺玩法"，而是玩法能跑后工程复杂度上升。后续优先级：

1. 工程安全 → 机制建立
2. 存档安全 → 版本集中
3. 测试安全 → 覆盖分层
4. 纯逻辑解耦 → WinCondition、Save Builder/Applier
5. 布局解耦 → LayoutCoordinator
6. 性能策略 → TrailPressurePolicy、MX330 基线
7. 再做新功能 → 渲染分辨率等

**不要反过来。**

---

## 二、工程安全（先建立"不会越改越乱"的机制）

### 2.1 版本快照安全

没有可靠 git，每轮固定流程：

- 修改前：`BallWar_snapshot_before_v2_0_x.zip`
- 修改后：`BallWar_v2_0_x_xxx.zip`
- 附带：`README_v2_0_x_xxx.md`（文件清单 + 测试结果 + 桌面验证清单）

### 2.2 存档安全

当前状态：文档是 v2.0.x，存档仍 `SAVE_MAJOR_PREFIX = "1.9"`、`save_version = "1.9.34"`。

规划：v2.0.5 将版本常量集中到 `SaveGameCodec.gd`：
```
const SAVE_MAJOR_PREFIX := "1.9"
const CURRENT_SAVE_VERSION := "1.9.34"
```
`Main.gd` 不再硬编码 `"1.9.34"`，改为调用 `SaveGameCodec.get_current_save_version()`。

这不是升级到 2.0，是把"1.9 兼容策略"集中管理。

### 2.3 测试安全（固定分工）

| 测试 | 类型 | 跑多久 | 角色 |
|---|---|---|---|
| `SmokeTestRunner.gd` | 快速冒烟 | <1s | 最关键规则边界 |
| `IntegrationTestRunner.gd` | 中量集成 | <5s | 存档/战场/胜负/事件 |
| `PerfBurstBenchmark.gd` | 性能探针 | ~60s | 性能退化检测 |
| `LayoutSanityTestRunner.gd` | 布局冒烟 | 未来 | 边界盒检测 |

**禁止把所有测试塞进 SmokeTestRunner。**

---

## 三、部件解耦：先拆纯逻辑，不拆复杂运行时

当前最大耦合点是 `Main.gd`，它同时负责：菜单、开始、暂停、保存、读取、胜负、场景创建、HUD 创建、事件连接、布局应用。

后续不是重写 Main.gd，是让它逐步从"亲自干活"变成"调用模块"。

### v2.0.4：WinConditionEvaluator.gd

第一刀，因为纯逻辑、不依赖 UI/渲染/物理、极易测试。

接口草案：
```gdscript
extends RefCounted
class_name WinConditionEvaluator

static func evaluate(mode_name: String, turrets: Array, owner_counts: Dictionary, total_cells: int, time_left: float) -> Dictionary
```

Main.gd 的 `_check_winner()` 改为调用 `WinConditionEvaluator.evaluate(...)`。

### v2.0.5：SaveStateBuilder + SaveStateApplier

三个文件分工：
- `SaveStateBuilder.gd`：采集状态 → 生成 Dictionary → 写入 save_version
- `SaveGameCodec.gd`：校验 + 补默认值 + clamp 非法值（已有）
- `SaveStateApplier.gd`：把 clean save data 应用回对象

### v2.0.6：LayoutCoordinator.gd

输入 viewport_size / map_size / is_mobile → 输出所有元素位置。Main.gd 只做 `var layout = LayoutCoordinator.calculate_layout(...)`。

**布局协调器做完之前，不要加分辨率功能。**

---

## 四、性能方向：不以 FPS 为唯一指标

### 4.1 MX330 性能基线

`README_v2_0_7_mx330_perf_baseline.md` 记录地图 40/50/60 × 质量低/中/高 × 分辨率档位下的 FPS、p95/p99、stutter、draw_calls、trail_pressure 等。

MX330 推荐默认分辨率：1366×768 或 1600×900，不默认 1920×1080。

### 4.2 TrailPressurePolicy.gd

从 `BulletPool.gd` 中抽离 trail pressure 判断逻辑。BulletPool 只做子弹生命周期和对象池，TrailPressurePolicy 做性能降级判断。

### 4.3 性能功能开关

先作为开发工具，暂不放玩家设置：
- 显示/隐藏拖尾
- 拖尾降级状态
- 性能 HUD
- draw call 估算
- 压力模拟

---

## 五、UI / 布局：先验证边界盒，不做像素对比

新增 `LayoutSanityTestRunner.gd`，不测截图，测边界盒：
1. battlefield_rect 在 viewport 内
2. turret/chamber 位置不越界
3. +球按钮不越界
4. pause/exit 按钮不越界
5. event_hud 和 perf_hud 不重叠
6. roulette_stage_rect 在中央
7. 40/50/60 地图都能算出合法布局

---

## 六、事件系统：补控制器 + 真实控制仓集成测试

IntegrationTestRunner 未来可新增 P4：

P4 — Event integration：
- resolved +10 应用到真实 chamber
- x2/x3 modifier 在 locked 时入队列
- unlock 后 queued modifier 生效
- jam 命中 burst 触发 cancel_burst
- jam refund 25% 正确
- add-ball 在 chamber full 时 fallback 到 +10
- reroll 不改变非法状态

---

## 七、代码清理：Gate.gd 分三步

- v2.0.4：README 标记 dead code
- v2.0.5：搜索确认零引用
- v2.0.6：删除

**不要现在删。** 没有 git，误删恢复成本高。

---

## 八、版本路线总表

| 版本 | 主题 | 新增 | 不改 |
|---|---|---|---|
| **v2.0.4** | 安全解耦 | WinConditionEvaluator.gd，测试，Main 调用 | 胜负规则、分辨率、BulletPool、save version、Gate.gd |
| **v2.0.5** | 存档 + Main 瘦身 | SaveGameCodec 版本集中，SaveStateBuilder/Applier，集成测试 | save major 不改 2.0 |
| **v2.0.6** | 布局准备 | LayoutCoordinator.gd，LayoutSanityTestRunner.gd，测 40/50/60 | 不加分辨率 |
| **v2.0.7** | 性能策略 | MX330 基线，TrailPressurePolicy.gd，PerfBurst 对比 | 不删 Gate.gd |
| **v2.0.8** | 渲染分辨率 | 自动/1280×720/1366×768/1600×900/1920×1080，LayoutCoordinator 调用 | MX330 不默认 1920×1080 |

---

## 附：当前已知约束

- 无 git，每次必出 zip + README
- 桌面 Godot 验证仍是权威路径
- 存档兼容 1.9 前缀
- 生产代码不可因测试失败而改动（v2.0.3 7 项修复全在测试基建）
- `PROJECT_PRINCIPLES.md` 的三条原则（低耦合/安全/向后兼容 + 新代码优先排查 + UI .tscn 优先）
- **组件分类**（见 `PROJECT_PRINCIPLES.md` 原则 3）：人类调外观 → .tscn，Agent 跑逻辑 → .gd，数量巨大 → 代码/对象池
