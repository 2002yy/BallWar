# AI_HANDOFF_CURRENT

Last updated: 2026-05-15  
Role / 作用: handoff card only / 仅作快速接管卡片

## 1. Current Version / 当前版本

- Current stable code line: `v2.1.4`
- Current theme:
  - restore interfaces cleanup
  - `Main.gd` shrinkage
  - performance-path cleanup
  - engineering and documentation hygiene

## 2. Current Status / 当前状态

- `SaveFlowController` now has a real `prepare_*` vs `apply_*` split for continue flow.
- `RestorePlan.gd` is in the active restore path.
- `ControlChamber.gd`, `Turret.gd`, and `Bullet.gd` own `restore_from_state(...)`.
- `Main.gd` still owns top-level sequencing, but no longer deep-mutates most restore internals.
- `BulletPool.gd` tracks queue and trail metrics incrementally.
- `Battlefield.gd` uses `BattlefieldDecorLayer.gd` for static decoration.
- `.gitattributes` exists for line-ending normalization; run `git add --renormalize .` before a clean commit if line-ending noise appears.

## 3. Just Completed / 刚完成的内容

- removed stale dead-code branches and deprecated helpers from `Main.gd`
- finished the save/continue boundary cleanup so prepare returns data and apply performs side effects
- moved restore mutation ownership into runtime objects instead of keeping it in `Main.gd`
- added split performance probe entry points:
  - `scripts/tests/PerfBurstBenchmarkSingleTurret.gd`
  - `scripts/tests/PerfBurstBenchmarkMultiTurret.gd`
- added curated asset staging under `assets/`
- completed the Markdown cleanup:
  - preserved `README_v*.md` as historical stage notes
  - introduced `CHANGELOG.md` as the condensed history spine
  - introduced `TECHNICAL_GUIDE.md` as the live engineering guide

## 4. Next Steps / 下一步

1. Decide whether the current documentation/hygiene slice should be tagged as `v2.1.5 engineering hygiene`, or remain part of `v2.1.4` follow-up cleanup.
2. When performance evidence is needed, run and archive:
   - `PerfBurstBenchmarkSingleTurret.gd`
   - `PerfBurstBenchmarkMultiTurret.gd`
3. Before a formal commit, run `git add --renormalize .` if Git still shows line-ending-only noise.
4. Keep the live docs aligned:
   - `AI_HANDOFF_CURRENT.md` = handoff only
   - `ROADMAP.md` = main progress and direction
   - `README_TEST_MATRIX.md` = tests only
   - `TECHNICAL_GUIDE.md` = active engineering boundaries
   - `CHANGELOG.md` = condensed history spine
5. If the next product-facing feature slice starts, treat these as one grouped UX package in this order:
   - mode guide page
   - onboarding / first-time tutorial
   - in-match hint layer
   - event log
   - results screen

## 5. Do Not Do / 不要做什么

- do not turn this file into a roadmap or architectural diary
- do not put roadmap content into `README_TEST_MATRIX.md`
- do not claim performance validation is complete unless there is either:
  - a recorded probe result, or
  - a clearly labeled manual observation
- do not move deep restore-field mutation back into `Main.gd`
- do not treat versioned `README_v*.md` files as the current source of truth; they are stage records

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

Latest local headless baseline recorded on `2026-05-15`:

- `StartMenuSceneTestRunner.gd` PASS `35`
- `GameHUDSceneTestRunner.gd` PASS `27`
- `EventRouletteSceneTestRunner.gd` PASS `14`
- `SettingsPanelSceneTestRunner.gd` PASS `9`
- `GameStateCoordinatorTestRunner.gd` PASS `50`
- `SaveFlowControllerTestRunner.gd` PASS `75`
- `RestorePlanTestRunner.gd` PASS `11`
- `SmokeTestRunner.gd` PASS `60`
- `IntegrationTestRunner.gd` PASS `133`
- `LayoutSanityTestRunner.gd` PASS `330`

Performance probes are separate from correctness:

- `PerfBurstBenchmark.gd`
- `PerfBurstBenchmarkSingleTurret.gd`
- `PerfBurstBenchmarkMultiTurret.gd`

## 7. Canonical Docs / 主文档分工

- `AI_HANDOFF_CURRENT.md`
  - quick takeover card for the next AI / Codex session
- `ROADMAP.md`
  - main progress board and development direction
- `README_TEST_MATRIX.md`
  - test ownership, baseline, and run guidance only
- `TECHNICAL_GUIDE.md`
  - current architecture, editor, validation, and repo-boundary rules
- `CHANGELOG.md`
  - condensed history spine and latest stable-line summary
- `README_v*.md`
  - historical stage reports, not the live control panel
