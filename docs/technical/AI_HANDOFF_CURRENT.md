# AI_HANDOFF_CURRENT

Last updated: 2026-05-17
Role / 作用: handoff card only / 仅作快速接管卡片

### 2026-10-21 Review: preserve manually collapsed event log

- PR #7 finding4328062474有效：面板每个checkbox都发完整偏好，Main无条件重设日志visible，导致改性能/低特效也展开玩家已折叠的日志。现在比较show_event_log偏好，仅该偏好改变时更新日志可见性；启动/开局仍按已保存设置初始化，事件历史不删除。
- 回归通过真实HUD按钮折叠→面板性能/低特效切换→日志仍折叠，再显式关开事件日志偏好才显示，保留历史。旧代码实际exit1（negative日志ballwar-collapse-review-negative-20261021）；修复后12/12隔离原生runner exit0且无SCRIPT ERROR/ERROR，SettingsAndResult **40 checks PASS**。证据D:/study-agent-validation/ballwar-collapse-review-final-20261021。目标Godot4.7不变，无存档schema/玩法/玩家数据变化；候选SHA由本段提交恢复，推送后仅查一次新head CI，不借ecd582d旧绿灯。

### 2026-10-21 Latest main integration / 当前主线绑定

- 设置修复PR #8已以merge afb59014326472e318df734641f8925e232bf2bf进入4.7候选。随后核实main已更新到7c0a426101b6adf32e5fd09d5a7b07617c3e38a2，包含运行修复、文档迁移和新增CI；本分支吸收main为merge517a98a，代码自动合并，仅README冲突保留新main结构与4.7目标。当前权威交接路径随main迁到本文件，未复活根目录旧文档。
- 重绑后重新导入并在每runner独立且经探针确认的user://目录跑完整12个现役runner，全部退出0、无SCRIPT ERROR/ERROR；SettingsAndResult 34断言通过。当前main上的原生4.7.1窗口也验证开关前后，1120×720截图与marker PASS，无脚本错误，证据ballwar-settings-latest-main/native-20261021。
- CI来自已合main，现同步使用官方已核实存在的4.7.1-stable Linux资产，纳入SettingsAndResult和EndToEndContinueMain共12项；运行日志先拒绝SCRIPT ERROR/ERROR/FAIL再认可PASS，避免原先“exit0加PASS掩盖脚本错误”。每runner独立XDG_DATA_HOME，mktemp失败即阻断。当前PR #7仍须最新head的CI通过再合main，不把旧分支无CI当当前豁免。
- 仅此文档/CI收口在验证后变化，不重复跑相同原生测试；最终commit由本段恢复，CI以推送后精确head查询为准。已关闭设置接口测试阻塞，Android模板/导出/签名/发布与长程性能仍未验收。

### 2026-10-21 Settings wiring fix / 迁移阻塞修复

- 当前设置阻塞已修复：独立branch codex/ballwar-settings-wiring-20261021，基于自身4.7候选3b602f90。不是只删旧断言；Main启动读取PlayerSettingsStore，HUD创建后接settings_changed，开局后应用性能/事件日志显示；面板打开时刷新不会发出伪用户更改或覆写其他偏好。
- 新回归先在旧产品上真实FAIL（退出1、9条失败日志），证明缺的是产品接线。修复后测试通过真实CheckButton切换→保存→Main→HUD/事件控制器；隐藏日志仍记录历史，重显不改历史。SettingsAndResult **34 checks PASS**，无SCRIPT ERROR/ERROR；现役12个runner全部无错误通过（每runner独立APPDATA/LOCALAPPDATA，先由引擎user://探针验证隔离）。
- 实际Godot4.7.1原生窗口1120×720截图验证：性能栏/事件模式日志在关闭后消失、开启后显示；面板至少168高，关闭按钮与三个既有开关完整可见，native marker通过，无脚本错误。证据在本地ballwar-settings-final-20261021与ballwar-settings-{hidden,enabled}-20261021.png。
- 仅补性能/事件日志的显示链路及HUD引用，事件效果、存档codec/字段和玩法未改。low_effect_mode仍保持原有持久化语义，本片不另造特效/性能模式。496项导入CRLF元数据在新工作树恢复，原6项WIP与真实玩家数据不再触碰。
- 当前修复commit由本段提交恢复。合并时先将本修复独立审阅进入4.7迁移父候选，再解除Draft；必须比较最终runtime树与已验树，不借其他SHA的资格。Android模板/签名/发布/长程性能仍未验收；本次仅关闭设置接口与4.7源代码迁移测试阻塞。

### 2026-10-21 Engine target correction / 引擎目标修正

- 用户纠正后，后续目标为 **Godot 4.7.x**（覆盖此前4.6要求）。project.godot与入口README已同步；本机实际二进制4.7.1.stable.official.a13da4feb。Android导出模板仍需匹配4.7.x，本片未安装模板、签名或发布。
- 独立候选codex/godot-47-20261021，从main fedc0c6695c8730c8f4eaa4640b92a44faea30af建立；原工作树6项改动原样保留。只改目标版本/当前说明，不改游戏规则或迁移真实存档。
- 4.7.1导入成功，无脚本错误；现役10项核心runner均通过，EndToEndContinueMain也通过。扩展SettingsAndResult虽退出0并打印PASS，仍有2条SCRIPT ERROR：测试向Main写已不存在的player_settings，随后旧_apply_*调用也不对应当前接口；故整体11/12，不宣称迁移完整PASS，保留NO-GO。
- 首次兼容检查未隔离user://，历史测试会写/清理玩家设置，旧内容无法从该测试核实；后续已用独立APPDATA/LOCALAPPDATA并先通过真实引擎globalize_path探针证明隔离，再复验12个runner，结果仍11/12。后续所有存档/设置测试须先隔离，不得只凭exit0判定通过。
- 导入生成的496项CRLF元数据状态在本候选工作树恢复，不混入版本切换提交。原工作树未操作。日志与隔离探针在本地ballwar-godot47-evidence-20261021目录。
- 下一门：单独修复当前设置能力与扩展测试的接口合同，保留真实断言并再次无SCRIPT ERROR通过；该缺口关闭前不合并/发布本迁移候选，不把禁用的历史测试当现役测试。

## 1. Current Version / 当前版本

- Current line: `v2.1.x`
- Latest documented milestone: `v2.1.9`
- Last stable structural baseline: `v2.1.4`
- Current theme:
  - settings system + result panel + statistics
  - decor-layer event-driven cleanup
  - chamber-state extraction
  - repo entrance and history-doc cleanup

## 2. Current Status / 当前状态

- `SaveFlowController` owns the `prepare_*` vs `apply_*` split for continue flow.
- `RestorePlan.gd` is in the active restore path.
- `ControlChamber.gd`, `Turret.gd`, and `Bullet.gd` own `restore_from_state(...)`.
- `Main.gd` stays at top-level sequencing and should keep shrinking away from deep restore mutation, deep event logic, and draw/physics details.
- `BattlefieldDecorLayer.gd` is event/dirty-flag driven instead of per-frame polled.
- `ChamberState.gd` is extracted as a pure state container.
- `EventRouletteController.gd` now emits UI requests by signal instead of calling `Main` private helpers directly.
- `GameSceneBuilder.gd` has an explicit owner callback contract comment; treat it as the current runtime interface seam.
- `PlayerSettingsStore.gd`, `SettingsPanel`, and `ResultPanel` are wired into the active product flow.

## 3. Just Completed / 刚完成的内容

- refreshed root `README.md` so it describes the current `v2.1.x` line instead of treating `v2.1.4` as the latest version
- moved all stage reports from root `README_v*.md` into `docs/history/`
- compressed `CHANGELOG.md` into a true milestone spine
- aligned live docs so the repo root keeps only current-truth documents

## 4. Next Steps / 下一步

1. Keep Release naming, README wording, and milestone docs aligned as `v2.1.x` continues.
2. When performance evidence is needed, run and archive:
   - `scripts/tests/PerfBurstBenchmark.gd`
   - `scripts/tests/PerfBurstBenchmarkSingleTurret.gd`
   - `scripts/tests/PerfBurstBenchmarkMultiTurret.gd`
3. Continue shrinking `ControlChamber` and `Main.gd` without pushing deep restore mutation, event-effect details, or draw/physics logic back into `Main.gd`.
4. If more history notes are added, place them under `docs/history/` instead of the repo root.

## 5. Do Not Do / 不要做什么

- do not turn this file into a roadmap or architecture diary
- do not put roadmap content into `docs/technical/README_TEST_MATRIX.md`
- do not claim performance validation is complete unless there is either:
  - a recorded probe result, or
  - a clearly labeled manual observation
- do not move deep restore-field mutation back into `Main.gd`
- do not add new direct controller-to-`Main` private method calls when a signal seam is sufficient
- do not treat `docs/history/README_v*.md` as the current source of truth; they are stage records

## 6. Required Tests / 当前必跑测试

Current active correctness baseline:

- `StartMenuSceneTestRunner.gd`
- `GameHUDSceneTestRunner.gd`
- `EventRouletteSceneTestRunner.gd`
- `SettingsPanelSceneTestRunner.gd`
- `GameStateCoordinatorTestRunner.gd`
- `SaveFlowControllerTestRunner.gd`
- `RestorePlanTestRunner.gd`
- `SmokeTestRunner.gd`
- `IntegrationTestRunner.gd`
- `LayoutSanityTestRunner.gd`

Latest documented broader baseline:

- `SettingsAndResultTestRunner.gd`
- `EndToEndContinueMainTestRunner.gd`
- plus the correctness baseline above when the touched area warrants it

Performance probes are separate from correctness:

- `PerfBurstBenchmark.gd`
- `PerfBurstBenchmarkSingleTurret.gd`
- `PerfBurstBenchmarkMultiTurret.gd`

## 7. Canonical Docs / 主文档分工

- `docs/technical/AI_HANDOFF_CURRENT.md`
  - quick takeover card for the next AI / Codex session / 下一次 AI/Codex 快速接管卡
- `README.md`
  - current project entrypoint / 项目入口
- `docs/ROADMAP.md`
  - main progress board and development direction / 进度板与开发方向
- `docs/TESTING.md`
  - test ownership, baseline, and run guidance / 测试职责、基线和运行建议
- `docs/technical/TECHNICAL_GUIDE.md`
  - current architecture, editor, validation, and repo-boundary rules / 架构、编辑器协作、验证规则
- `CHANGELOG.md`
  - condensed version spine / 精简版本脊柱
- `docs/history/README.md`
  - historical stage index / 历史阶段索引
