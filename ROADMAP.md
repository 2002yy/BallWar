# Roadmap / 路线图

Role / 作用: main progress board / 主进度板

This file is the single place for project direction and phase status.  
这份文件只回答项目“已经完成了什么、正在推进什么、接下来做什么、哪些内容暂缓”。

## 1. Current Line / 当前主线

- Current stable version: `v2.1.4`
- Current focus:
  - architecture cleanup
  - restore ownership clarification
  - documentation hygiene
  - repo hygiene

## 2. Completed / 已完成

### Architecture cleanup / 架构收口

- `SaveFlowController` now has a true `prepare_*` and `apply_*` split
- `RestorePlan.gd` is in the active restore path
- `ControlChamber.gd`, `Turret.gd`, and `Bullet.gd` own `restore_from_state(...)`
- `Main.gd` has been reduced toward orchestration instead of deep restore mutation

### Runtime cleanup / 运行时收口

- `BulletPool.gd` moved key pressure metrics to incremental tracking
- `ControlChamber.gd` uses a lighter peg-collision path
- `Battlefield.gd` split static decoration into `BattlefieldDecorLayer.gd`

### Documentation cleanup / 文档收口

- preserved `README_v*.md` as the detailed historical stage trail
- added `CHANGELOG.md` as the condensed history spine
- added `TECHNICAL_GUIDE.md` as the live engineering guide
- kept `AI_HANDOFF_CURRENT.md` as handoff-only
- kept `README_TEST_MATRIX.md` as test-only

## 3. In Progress / 当前进行中

### Repo hygiene / 仓库卫生

- some line-ending cleanup was done
- before a formal commit, the repo may still need `git add --renormalize .` if Git shows line-ending-only changes

### Performance evidence capture / 性能证据补全

- split probe scripts now exist:
  - `PerfBurstBenchmarkSingleTurret.gd`
  - `PerfBurstBenchmarkMultiTurret.gd`
- fresh split reports have not been archived yet

## 4. Next / 下一步

1. Decide whether the current hygiene/doc/probe slice should become `v2.1.5 engineering hygiene`.
2. When performance validation is needed, run and archive:
   - `PerfBurstBenchmarkSingleTurret.gd`
   - `PerfBurstBenchmarkMultiTurret.gd`
3. If more restore-related refactors happen, keep them inside object-owned restore entry points instead of pushing logic back into `Main.gd`.
4. Before any public or long-lived commit, verify the Git diff is free of line-ending-only noise.

## 5. Later / 后续候选

- stronger automated reporting for performance probes
- more explicit restore interfaces for future runtime objects that join the save/load path
- additional UI/layout guardrails only if feature work starts touching supported resolutions again

### UX information layer / 信息与引导层

The next product-facing slice should be treated as one grouped UX package instead of scattered one-off UI work.  
下一组更偏体验的功能，建议作为一整个“信息与引导层”包推进，而不是零散补几个界面。

Recommended order / 建议顺序:

1. mode guide page
2. onboarding / first-time tutorial
3. in-match hint layer
4. event log
5. results screen

Initial scope rule / 范围规则:

- start with static or lightly dynamic information first
- avoid mixing this slice with large gameplay-rule refactors
- keep wording and labels consistent across all five surfaces

## 6. Not Now / 暂不处理

- do not start broad new feature work before perf evidence and doc boundaries are stable
- do not use `README_TEST_MATRIX.md` as a roadmap
- do not treat `README_v*.md` notes as the live source of truth
- do not expand `Main.gd` back into a deep mutation hub

## 7. Canonical Doc Split / 主文档分工

- `AI_HANDOFF_CURRENT.md`
  - quick session takeover
- `ROADMAP.md`
  - master direction and progress
- `README_TEST_MATRIX.md`
  - test ownership and run guidance
- `TECHNICAL_GUIDE.md`
  - live architecture, validation, editor, and repo-boundary rules
- `CHANGELOG.md`
  - condensed history spine
- `README_v*.md`
  - historical stage notes
