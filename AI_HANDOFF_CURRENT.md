# AI_HANDOFF_CURRENT

Last updated: 2026-05-16
Role / 作用: handoff card only / 仅作快速接管卡片

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
- `Main.gd` stays at top-level sequencing and should keep shrinking away from deep restore mutation.
- `BattlefieldDecorLayer.gd` is event/dirty-flag driven instead of per-frame polled.
- `ChamberState.gd` is extracted as a pure state container.
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
3. Continue the second-stage `ControlChamber` split without pushing deep restore mutation back into `Main.gd`.
4. If more history notes are added, place them under `docs/history/` instead of the repo root.

## 5. Do Not Do / 不要做什么

- do not turn this file into a roadmap or architecture diary
- do not put roadmap content into `README_TEST_MATRIX.md`
- do not claim performance validation is complete unless there is either:
  - a recorded probe result, or
  - a clearly labeled manual observation
- do not move deep restore-field mutation back into `Main.gd`
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

- `AI_HANDOFF_CURRENT.md`
  - quick takeover card for the next AI / Codex session
- `README.md`
  - current project entrypoint
- `ROADMAP.md`
  - main progress board and development direction
- `README_TEST_MATRIX.md`
  - test ownership, baseline, and run guidance only
- `TECHNICAL_GUIDE.md`
  - current architecture, editor, validation, and repo-boundary rules
- `CHANGELOG.md`
  - condensed version spine
- `docs/history/README.md`
  - historical stage index
