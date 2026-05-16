# Roadmap / 路线图

Role / 作用: main progress board / 主进度板

This file is the single place for project direction and phase status.  
这份文档只回答项目“已经完成了什么、正在推进什么、接下来做什么、哪些内容暂缓”。

## 1. Current Line / 当前主线

- Current stable line: `v2.1.9`
- Current theme:
  - settings system + result panel + statistics
  - decor-layer event-driven cleanup
  - chamber-state extraction
  - public repo entrance cleanup

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

- `README.md` 作为仓库入口
- `CHANGELOG.md` 作为精简历史主线
- `README_v*.md` 保留为历史阶段记录
- `README_TEST_MATRIX.md` 作为测试矩阵
- `TECHNICAL_GUIDE.md` 作为工程协作说明

## 3. In Progress / 当前进行中

### Android export hardening / Android 导出固化

- 导出配置与资源压缩设置已基本对齐
- 仍需把 Debug APK 导出流程整理成更稳定的重复步骤

### Chamber refactor phase 2 / 控制仓第二阶段拆分

- 当前已完成状态外提
- 下一步是继续拆出物理、几何、绘制和保存适配边界

### Public repo hygiene / 公开仓库整理

- Release 与主 README 的版本叙事正在对齐
- 目标是让仓库首页描述当前主线，而不是停留在旧稳定点

### Performance evidence capture / 性能证据归档

- 性能探针脚本已存在
- 仍需要补齐更成体系的基线记录，尤其是高压弹幕与较大网格场景

## 4. Next / 下一步

1. 固化 Android APK 导出流程，并补一份更稳定的导出检查顺序。
2. 继续拆分 `ControlChamber.gd`，优先物理与保存适配边界。
3. 归档一轮新的性能基线，覆盖常规模式与高压模式。
4. 保持 `Main.gd` 作为顶层编排层，不把深层恢复写回逻辑重新塞回去。
5. 继续整理公开仓库入口，让 README、CHANGELOG、Release 三者版本指向一致。

## 5. Later / 中期候选

- 新手引导
- 模式说明页
- 更完整的结算统计
- 音效系统
- 移动端按钮布局
- UI / 音效 / 素材统一美术方向

## 6. Not Now / 暂不处理

- 在性能基线不稳定前继续扩大弹幕规模
- 把 UI 重新塞回纯代码动态生成
- 把 `README_v*.md` 当成当前真相入口
- 在没有边界设计前大规模增加复杂特殊事件或特殊球

## 7. Canonical Doc Split / 文档分工

- `README.md`
  - 项目入口、当前状态、玩法和结构说明
- `ROADMAP.md`
  - 当前方向、已完成、下一步、暂缓项
- `CHANGELOG.md`
  - 精简版本主线
- `README_TEST_MATRIX.md`
  - 测试职责与运行建议
- `TECHNICAL_GUIDE.md`
  - 工程边界、编辑器协作、导出与验证说明
- `AI_HANDOFF_CURRENT.md`
  - 下一次 AI / Codex 接管卡片
- `README_v*.md`
  - 历史阶段详细记录
