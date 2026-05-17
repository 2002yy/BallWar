# Roadmap / 路线图

Role / 作用: main progress board / 主进度板

This file is the single place for project direction and phase status.  
这份文档只回答项目“已经完成了什么、正在推进什么、接下来做什么、哪些内容暂缓”。

## 1. Current Line / 当前主线

- Current line: `v2.1.x`
- Latest Stable release: `v2.1.11.1`
- Previous stable milestone: `v2.1.11`
- Stable structural baseline: `v2.1.4`
- Current theme:
  - UI hotfix release (complete)
  - visual and audio polish (next)
  - mobile layout verification
  - performance baseline archiving

## 2. Completed / 已完成

### Gameplay loop / 玩法闭环

- 四阵营战场争夺、角落炮台、控制仓发射节奏已经形成稳定闭环
- 基础模式、占领模式、限时模式、狂野模式已接入主流程
- 事件转盘、事件日志、胜负判断和对局结束流程已打通

### Save/load and orchestration / 保存恢复与编排

- `SaveFlowController` 已拆成 `prepare_*` / `apply_*`
- `RestorePlan.gd` 已进入主动恢复链路
- `ControlChamber.gd`、`Turret.gd`、`Bullet.gd` 各自拥有 `restore_from_state(...)`
- `Main.gd` 已明显收缩，主要承担顶层生命周期编排

### UI and product surfaces / UI 与用户面

- `StartMenu.tscn`、`GameHUD.tscn`、`SettingsPanel.tscn`、`ResultPanel.tscn` 已形成当前主 UI 结构
- 设置系统已接入：
  - 显示性能信息
  - 低特效模式
  - 事件日志显示开关
- 结算页已接入：
  - 胜利原因
  - 游戏时长
  - 最终占领率
  - 最高活跃子弹
  - 事件次数

### Runtime cleanup / 运行时收口

- `BattlefieldDecorLayer.gd` 从每帧轮询改为事件/脏标记模式
- `BulletPool.gd` 已维护峰值活跃子弹统计
- `EventRouletteController.gd` 已维护事件触发计数
- `ChamberState.gd` 已从 `ControlChamber.gd` 外提为纯状态容器

### Documentation cleanup / 文档收口

- `README.md` 作为仓库入口（9 个精选区块，链接到 `docs/`）
- `CHANGELOG.md` 作为精简版本脊柱
- `docs/`: `ARCHITECTURE.md`, `TESTING.md`, `PERFORMANCE.md`, `SAVE_SYSTEM.md`, `ANDROID_EXPORT.md`, `RELEASE_PROCESS.md`, `ROADMAP.md`
- `docs/history/` — 历史阶段记录
- `docs/technical/`, `docs/design/`, `docs/performance/` — 工程、设计、性能附录

### Public repository hardening / 公开仓库收口

- README 顶部重构：面向玩家/招聘官，30 秒看懂项目价值
- GitHub Actions CI workflow：validate + 10 测试并行 matrix，日志 artifact
- Android 导出脚本去本机绝对路径（`$PSScriptRoot` 相对路径）
- `export_presets.cfg` 三处不对齐修复（preset 名称、script_export_mode、version）
- 版本叙事三处统一（README / CHANGELOG / Releases 页面）
- 历史版本文档全部归档到 `docs/history/`，根目录保持干净

## 3. In Progress / 当前进行中

### Android export hardening / Android 导出固化

- 导出配置与资源压缩设置已基本对齐
- Debug APK 已进入 release 资产流；后续重点是签名包和可重复交付流程

### Chamber refactor phase 2 / 控制仓第二阶段拆分

- 当前已完成状态外提与 `ChamberBallPhysics.gd` 初步拆分
- 配套补充 `ChamberBallPhysicsTestRunner.gd`
- 后续再继续拆出几何、绘制和保存适配边界

### Public repo hygiene / 公开仓库整理

- Release 与主 README 已按 Latest Stable / Milestone / Historical 分层对齐
- 根目录已收束为外部入口，过程文档归入 `docs/`
- 已完成，转入下一阶段视觉与音效收口

### Performance evidence capture / 性能证据归档

- 性能探针脚本已存在
- 仍需要补齐更成体系的基线记录，尤其是高压弹幕与较大网格场景

## 4. Next / 下一步

1. **素材实际接入**：菜单背景、按钮皮肤、顶部占领条视觉增强（参考 `docs/design/ASSET_GAP_PLAN.md`）
2. **音效系统第一版**：按钮点击、子弹发射、格子占领、事件触发、胜负判定全链路音效
3. **移动端真机布局验证**：确保所有 UI 在真实 Android 设备上可用
4. **性能基线归档**：覆盖常规模式、高压弹幕（满配四阵营同时发射）、较大网格场景
5. **ControlChamber 第二阶段拆分**：继续拆出 `ChamberBallPhysics.gd` 的几何和绘制边界

## 5. Later / 中期候选

- 新手引导
- 模式说明页
- 更完整的结算统计
- Android 签名包与商店发布流程

## 6. Not Now / 暂不处理

- 在性能基线不稳定前继续扩大弹幕规模
- 把 UI 重新塞回纯代码动态生成
- 把 `docs/history/README_v*.md` 当成当前真相入口
- 在没有边界设计前大规模增加复杂特殊事件或特殊球

## 7. Canonical Doc Split / 文档分工

- `README.md`
  - 项目入口，9 个区块链接到 `docs/`
- `CHANGELOG.md`
  - 精简版本脊柱
- `docs/ARCHITECTURE.md`
  - 系统分层、归属规则、架构原则
- `docs/TESTING.md`
  - 10 个测试 runner、分类说明、运行建议
- `docs/PERFORMANCE.md`
  - 性能探针概览与基线摘要
- `docs/SAVE_SYSTEM.md`
  - 存档槽、备份恢复、版本校验、输入清洗
- `docs/ANDROID_EXPORT.md`
  - Android 导出检查清单
- `docs/RELEASE_PROCESS.md`
  - 打包与发布流程
- `docs/ROADMAP.md`
  - 当前方向、已完成、下一步、暂缓项
- `docs/history/README.md`
  - 历史阶段索引
- `docs/technical/AI_HANDOFF_CURRENT.md`
  - AI / Codex 接管卡片
