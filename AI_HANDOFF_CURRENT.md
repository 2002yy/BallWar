# AI Handoff Current

Last updated: 2026-05-06 (v2.1.2 SaveFlowController first cut, local baseline green)

## Current Headline

The current safe split is now:

- `GameStateCoordinator`
  - low-risk state-flow helper layer
- `SaveFlowController`
  - low-risk save/load orchestration layer
- `Main.gd`
  - still owns scene start and deep restore sequencing
- `SaveStateApplier`
  - still owns the current object-restore boundary

## v2.1.2 SaveFlowController First Cut

Recent work after the earlier `GameStateCoordinator` phase:

Boundary of `v2.1.2`:

- save-side split
- continue-game pre-start preparation
- does **not** enter restore-chain application

- added `scripts/SaveFlowController.gd`
  - current covered scope:
    - save path generation
    - slot normalization
    - save existence check
    - save slot summaries
    - slot selection status text
    - menu slot button refresh
    - save write orchestration
    - raw load / JSON parse / legacy slot-1 fallback
    - continue payload preparation
    - continue runtime normalization
    - continue `GameConfig` apply helper
    - continue start values helper
    - continue selection-state helper
    - continue banner config helper
    - continue start plan

- added `scripts/tests/SaveFlowControllerTestRunner.gd`
  - focused save/load orchestration helper verification

- added `README_SAVE_LOAD_FLOW_AUDIT.md`
  - audits the current read/load chain

- added `README_v2_1_2_save_flow_controller.md`
  - phase summary for the first SaveFlowController split

- effective continue flow is now:
  - `_continue_saved_game()`
  - `SaveFlowController.prepare_continue_payload(...)`
  - `_continue_from_prepared_payload(prepared)`
  - `SaveFlowController.prepare_continue_start_plan(...)`
  - `SaveFlowController.apply_continue_selection_state(...)`
  - `_start_game(...)`
  - `_apply_saved_state(...)`
  - `_show_center_banner(...)`

- local user-verified baseline is green:
  - `SaveFlowControllerTestRunner.gd` PASS
  - `GameStateCoordinatorTestRunner.gd` PASS
  - `SmokeTestRunner.gd` PASS
  - `IntegrationTestRunner.gd` PASS
  - `LayoutSanityTestRunner.gd` PASS
  - `StartMenuSceneTestRunner.gd` PASS
  - `GameHUDSceneTestRunner.gd` PASS
  - `EventRouletteSceneTestRunner.gd` PASS
  - `SettingsPanelSceneTestRunner.gd` PASS

- still intentionally NOT split in this phase:
  - `_apply_saved_state()`
  - `_restore_bullet_states()`
  - `_process_pending_bullet_restore()`
  - `_apply_chamber_state()`
  - `_apply_turret_state()`
  - `SaveStateApplier` deep restore sequencing
  - `SaveGameCodec` compatibility policy

- recommended next step:
  - freeze the pre-start orchestration split
  - next phase should target restore-chain audit/split, not more slot UI work

Last updated: 2026-05-06 (v2.1.2 — GameStateCoordinator phase, local test baseline green)

## v2.1.1 / v2.1.2 Update

Recent work after the older v2.0.8 handoff:

- added `README_MAIN_GD_AUDIT.md`
  - full function-by-function responsibility audit for `Main.gd`
  - defines the split boundary for `GameStateCoordinator` vs `SaveFlowController`

- added `scripts/GameStateCoordinator.gd`
  - low-risk state-flow helper layer
  - `Main.gd` still keeps entry functions
  - current completed scope:
    - pause / game_over / menu_visible predicates
    - pause_overlay / winner_label state helpers
    - game over shutdown helper
    - `_process()` lightweight predicate delegation
    - `_cleanup_game_layer()` lightweight state cleanup delegation

- added `scripts/tests/GameStateCoordinatorTestRunner.gd`
  - focused state-flow helper verification

- added `README_TEST_MATRIX.md`
  - classifies scene tests / state tests / smoke / integration / layout / perf

- local user-verified baseline is green:
  - `GameStateCoordinatorTestRunner.gd` PASS
  - `SmokeTestRunner.gd` PASS
  - `IntegrationTestRunner.gd` PASS
  - `LayoutSanityTestRunner.gd` PASS
  - `StartMenuSceneTestRunner.gd` PASS
  - `GameHUDSceneTestRunner.gd` PASS
  - `EventRouletteSceneTestRunner.gd` PASS
  - `SettingsPanelSceneTestRunner.gd` PASS

- still intentionally NOT touched in coordinator phase:
  - `_start_game()`
  - `_save_and_exit_to_menu()`
  - `_continue_saved_game()`
  - `_apply_saved_state()`
  - `_process_pending_bullet_restore()`

- next safe direction:
  - continue tiny `GameStateCoordinator` helpers
  - do NOT start `SaveFlowController` until explicitly chosen

## 前置必读

- `AI_HANDOFF_CURRENT.md` (本文件) — 入口
- `PROJECT_PRINCIPLES.md` — 三条工程原则
- `ROADMAP.md` — v2.0.4~v2.0.8 路线
- **`INDENTATION.md`** — 修改 .gd 文件前必须查阅
- `README_EDITOR_HANDOFF.md` — UI 组件的 .tscn 入口和编辑方法
- `README_START_MENU_TSCN_MIGRATION_PLAN.md` — 迁移图纸 + 通用模板
- **`README_TSCN_AUDIT.md`** — 4 个 .tscn 接入状态、fallback、属性边界、验收清单

### v2.0.6 (complete)

- added `scripts/LayoutCoordinator.gd` — centralized layout calculation with dynamic cell_size matching Battlefield.gd
- added `scripts/tests/LayoutSanityTestRunner.gd` — 10~60 grid strict boundary checks, bottom HUD group overflow detection
- no resolution feature — only tested default 1120×720 viewport
- fixed 23 SHADOWED_GLOBAL_IDENTIFIER warnings (removed redundant class_name preloads)
- Smoke 33 / Integration 133 / LayoutSanity 330 PASS
- Turret.gd has historical mixed indentation — do not format during other changes
- see `README_v2_0_6_layout_sanity.md`

- save version centralized: `SaveGameCodec.CURRENT_SAVE_VERSION` + `get_current_save_version()` + `is_supported_save_version()`
- added `scripts/SaveStateBuilder.gd` — collects state from objects → Dictionary
- added `scripts/SaveStateApplier.gd` — applies clean data → objects via callbacks
- `Main.gd._save_game_progress()` → `SaveStateBuilder.build_save_payload()`
- `Main.gd._apply_saved_state()` → `SaveStateApplier`
- `Main.gd` no longer hardcodes `"1.9.34"`
- `Main.gd` 42-line tab contamination fixed to spaces (historical mix)
- GDScript indentation audit: 14 tab files / 18 space files / 0 mixed (see README_v2_0_5)
- `.editorconfig` added: charset/trim/newline only; no global `indent_style` to avoid polluting old space files
- save major prefix still `"1.9"` — no version bump. Old saves remain compatible.
- SmokeTestRunner PASS 33, IntegrationTestRunner PASS 133
- see `README_v2_0_5_save_centralization.md`

### v2.0.7 (complete)

- **UI .tscn-first policy**: all new UI panels must use `.tscn` scenes (see PROJECT_PRINCIPLES.md principle 3)
- added `scenes/ui/StartMenu.tscn` — first visual scene (Godot PackedScene generated via `scripts/tools/build_start_menu_scene.gd`)
- added `scripts/StartMenu.gd` — CanvasLayer script: `get_node()` paths, `get_parts()`, `setup()`, refresh, signal wiring
- `Main.gd._create_start_menu()`: `.tscn` load first, fallback to `StartMenuView.create()`
- `StartMenuView.gd` retained as fallback (not deleted)
- added `scripts/tests/StartMenuSceneTestRunner.gd` — scene load + 6 required keys + @onready checks (18 assertions)
- 4 suites pass: Scene 18 + Smoke 33 + Integration 133 + LayoutSanity 330 = **514 total**
- see `README_v2_0_7_start_menu_scene.md`
- see `README_START_MENU_TSCN_MIGRATION_PLAN.md` (migration blueprint for future .tscn work)

## 工程原则 (必读)

见 `PROJECT_PRINCIPLES.md`。两条核心原则：

1. **每次优化减低耦合度，提高安全性，保证向后兼容。** 代码在持续改善，不是在积债。
2. **新代码出问题，优先从新代码入手。** 旧代码已有回归测试和桌面验证。v2.0.3 的 7 项修复全在新测试基础设施上，未改一行生产代码。

## 版本路线 (必读)

见 `ROADMAP.md`。v2.0.4 → v2.0.8 五步走：先稳 → 再拆 → 再加功能。当前在 v2.0.3 完成测试基建，下一步是 v2.0.4 安全解耦（抽 WinConditionEvaluator）。

## Read This First

This project is a Godot 4.6 game named `BallWar` (`project.godot`, main scene `res://scenes/Main.tscn`).

High-level gameplay:

- 4 factions fight over a square territory grid.
- Each corner has a turret.
- Each faction also has a control chamber that stores balls and converts them into turret bursts.
- Bullets paint/capture cells on the battlefield and can damage turrets.
- Win conditions depend on game mode:
  - basic: last surviving turret wins
  - occupation: first faction reaching 75 percent territory wins
  - timed: highest territory share at time limit wins
  - wild: same core loop, but chamber gate is `x3` instead of `x2`

Recent work has been focused on:

- automated smoke testing
- performance instrumentation and burst benchmarks
- visual degradation under trail pressure
- event roulette UI/presentation polish
- save/load continuity for event state

This handoff is meant to let the next AI continue without reconstructing context from dozens of versioned READMEs.

## Current Status Snapshot

The newest project-level progress docs are:

- `README_v2_0_0_tests_and_perf.md`
- `README_v2_0_0_perf_benchmark.md`
- `README_v2_0_1_trail_pressure_fix.md`
- `README_v2_0_2_ui_event_polish.md`

Actual codebase state is consistent with those themes:

- active smoke/perf scripts live under `scripts/tests/`
- old `tests/` suite was moved to `tests_legacy_disabled/`
- event roulette controller/view split is active
- perf HUD now reports extra counters such as draw calls and trail-pressure state
- chamber jam/add-ball/x2/x3 event logic is implemented

Important environment fact:

- the outer folder `BallWar_v2_0` is not a git repository
- `BallWar` also appears to be outside git here
- do not assume git history/status is available during handoff work

## Most Important Reality Checks

### 1. Chinese text encoding — NO MOJIBAKE (verified 2026-05-04)

**The previous handoff report of "mojibake in source files" was a false alarm.**

Full audit confirmed:

- ALL 26 `.gd` source files are valid UTF-8, Chinese characters are correct
- ALL 60 `.md/.txt` docs are valid UTF-8, Chinese characters are correct
- BOM removed from `BulletPool.gd` and `ControlChamber.gd` (2026-05-04)

**Why the previous report was wrong:**

The sandbox environment that runs bash/python/rg commands is not optimized for Chinese display — it lacks CJK font support. When it outputs Chinese text, the characters display as garbled symbols in the terminal. This is purely a display-layer issue in the command sandbox. The underlying file bytes are correct UTF-8 and the files themselves are not damaged in any way.

The Read tool renders Chinese correctly because it uses proper font rendering independent of the sandbox terminal.

**CRITICAL: Do NOT attempt to "fix" Chinese encoding in this project.** There is nothing to fix. If you see garbled Chinese in command output (bash, grep, python stdout), it is the sandbox display layer, not the file. Any attempt to "repair" non-broken UTF-8 files will introduce actual corruption.

**How to verify Chinese text reliably:**
- Use the **Read** tool to view source files directly — this is the ground truth, never trust terminal output for CJK
- If you need to programmatically verify Chinese strings, compare hex/bytes rather than relying on displayed text
- You can ask for hex verification of any suspect string: correct `发射` = `E5 8F 91 E5 B0 84`
- Godot editor/engine renders Chinese correctly at runtime

Files confirmed clean (the ones previously suspected):
- `scripts/Main.gd`, `scripts/GameConfig.gd`, `scripts/RuntimeHudController.gd`
- `scripts/EventRouletteController.gd`, `scripts/EventRouletteView.gd`
- `scripts/ControlChamber.gd`, `scripts/GameHudView.gd`
- `README_v2_0_2_ui_event_polish.md` and all other docs

### 2. Codex-side Godot runtime verification has been unreliable

Historical docs repeatedly state:

- editor parse/load is cleaner than before
- desktop smoke test reportedly passed before recent polish passes
- Codex environment still hits a native crash/access violation class in headless or run-mode checks

Practical consequence:

- desktop Godot runs are the authoritative verification path
- lack of Codex runtime confirmation does not necessarily imply the latest GDScript change is wrong

### 3. Save versioning is intentionally still on major prefix `1.9`

Current active save compatibility logic:

- `Main.gd` checks `SAVE_MAJOR_PREFIX = "1.9"`
- `SaveGameCodec.gd` also uses `SAVE_MAJOR_PREFIX = "1.9"`
- `Main.gd` currently writes `"save_version": "1.9.34"`

This is easy to miss because project docs are already on `v2.0.x`.

Implication:

- save compatibility is still governed by the older `1.9` major prefix
- changing save versioning casually may break continue/load behavior
- if future work touches save schema, update `Main.gd`, `SaveGameCodec.gd`, and smoke coverage together

## Code Map

### Entry and scene assembly

- `scripts/Main.gd`
  - top-level gameplay flow
  - start menu, game start, pause, save/load, win checks
  - creates battlefield, turrets, chambers, HUD, event roulette system
- `scripts/GameSceneBuilder.gd`
  - constructs battlefield, bullet pool, trail layer, turrets, chambers
- `scenes/Main.tscn`
  - main scene entry

### Core gameplay

- `scripts/Battlefield.gd`
  - grid ownership, score counting, redraw/debug metrics
- `scripts/Turret.gd`
  - burst firing, destruction, queue/lock state
- `scripts/Bullet.gd`
  - bullet movement, lifetime, trail points
- `scripts/BulletPool.gd`
  - active bullet management, recycling, debug metrics, trail-pressure decisions
- `scripts/BulletTrailLayer.gd`
  - trail rendering and redraw throttling
- `scripts/ControlChamber.gd`
  - chamber balls, release gate, jam state, queued round modifiers
- `scripts/ControlBall.gd`
  - chamber physics objects

### UI and presentation

- `scripts/GameHudView.gd`
  - runtime HUD layout, event label, control buttons
- `scripts/RuntimeHudController.gd`
  - timer/stage/leader HUD text and perf HUD text
- `scripts/StartMenuView.gd`
  - start menu and save-slot UI
- `scripts/UIFactory.gd`
  - reusable label/button/panel creation helpers
- `scripts/UIAnimationController.gd`
  - menu/title/add-ball button animation
- `scripts/BannerController.gd`
  - center banner presentation

### Event roulette

- `scripts/EventRouletteController.gd`
  - real event logic
  - countdown timing
  - faction selection weighting
  - jam / add-ball / x2 / x3 / +10 / reroll rules
  - save/import/export of event state
- `scripts/EventRouletteView.gd`
  - presentation only
  - visual roulette animation timing

### Save/load

- `scripts/SaveGameCodec.gd`
  - validation, normalization, vector serialization helpers
- `scripts/Main.gd`
  - actual save write/read and state restore flow

### Configuration/layout

- `scripts/GameConfig.gd`
  - quality thresholds, pressure thresholds, mode constants, palette constants
- `scripts/LayoutProfiles.gd`
  - 40/50/60 layout profiles

## Current Gameplay/Rules Notes

Based on active code:

- Basic mode event delay/interval: 60 seconds
- Occupation mode:
  - target: 75 percent
  - roulette interval speeds up to 30 seconds if leader reaches 65 percent
  - otherwise 40 seconds
- Timed mode:
  - default 5 minutes
  - roulette interval shortens as endgame approaches
- Wild mode:
  - gate multiplier `x3`
  - max pending count `2187`
  - roulette interval randomized in `20-30s`

Event roulette behavior:

- effects: reroll, `+10`, `x2`, `x3`, `+1 ball`, jam
- positive effects are weighted toward trailing factions
- jam is weighted toward leading factions
- positive effects queue if the chamber is currently locked
- jam cancels current burst with a 25 percent refund and jams the chamber for 5 seconds
- add-ball falls back to `+10` behavior if chamber is already full

## Testing and Benchmarking

### Active scripts

**Production:**
- `scripts/WinConditionEvaluator.gd` (v2.0.4 — pure win-condition logic)
- `scripts/SaveStateBuilder.gd` (v2.0.5 — save payload construction)
- `scripts/SaveStateApplier.gd` (v2.0.5 — save data restoration)
- `scripts/StartMenu.gd` (v2.0.7 — CanvasLayer controller for StartMenu.tscn)
- `scripts/GameHUD.gd` (v2.0.8 — CanvasLayer controller for GameHUD.tscn)

**Utility:**
- `scripts/tests/TestAssert.gd` (v2.0.3 — reusable assertion utility)
- `scripts/tests/TestFixtures.gd` (v2.0.3 — test fixture factory)

**Tests (7 suites, 557 assertions):**

| # | Test | 断言 | 类型 | 覆盖 |
|---|---|---|---|---|
| 1 | `SmokeTestRunner.gd` | 33 | 快速冒烟 | codec 边界、事件间隔/权重、chamber 事件、turret cancel |
| 2 | `IntegrationTestRunner.gd` | 133 | 中量集成 | P1 存档回环、P2 战场规则、P3 胜负条件、WCE 专项 |
| 3 | `LayoutSanityTestRunner.gd` | 330 | 布局边界 | 10~60 grid × desktop/mobile 是否越界 |
| 4 | `StartMenuSceneTestRunner.gd` | 22 | 场景加载 | StartMenu.tscn load/instantiate/nodes/parts |
| 5 | `GameHUDSceneTestRunner.gd` | 17 | 场景加载 | GameHUD.tscn load/instantiate/nodes/parts |
| 6 | `EventRouletteSceneTestRunner.gd` | 13 | 场景加载 | EventRouletteView.tscn load/instantiate/nodes |
| 7 | `SettingsPanelSceneTestRunner.gd` | 9 | 场景加载 | SettingsPanel.tscn load/show_content/hide_panel |
| — | `PerfBurstBenchmark.gd` | — | 性能探针 | FPS/p95/p99/stutter/draw_calls（不作为 correctness） |

**Scene scripts (.tscn 迁移进度):**

| 组件 | .tscn | .gd | 集成 Main.gd |
|---|---|---|---|
| 开始菜单 | `scenes/ui/StartMenu.tscn` ✓ | `StartMenu.gd` ✓ | ✓ fallback 旧版 |
| GameHUD | `scenes/ui/GameHUD.tscn` ✓ | `GameHUD.gd` ✓ | ✓ fallback 旧版 |
| 事件转盘 | `scenes/ui/EventRouletteView.tscn` ✓ | `EventRouletteView.gd` ✓ | ✓ fallback 旧版 |
| 设置面板 | `scenes/ui/SettingsPanel.tscn` ✓ | `SettingsPanel.gd` ✓ | scene ready, 独立面板 |
| 控制仓 | 暂不急 | — | — |
| 炮塔 | 暂不急 | — | — |


### Legacy scripts

- `tests_legacy_disabled/`

These are useful for historical reference, but they are not the active path right now.

### Desktop commands from project docs

Smoke test:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/SmokeTestRunner.gd"
```

Integration test:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/IntegrationTestRunner.gd"
```

Perf benchmark:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/PerfBurstBenchmark.gd"
```

### What smoke test currently covers

- save validation defaults
- event roulette interval logic
- event weighting logic
- chamber event behavior
- jam refund behavior
- turret `cancel_burst()`

### What benchmark currently records

- avg/min FPS
- p95/p99 frame time
- stutter counters
- active bullet and queue metrics
- trail segment metrics
- battlefield/trail redraw rates
- recycle/expire rates
- trail pressure level
- trail degrade reason
- draw calls
- visible canvas items estimate

## Test Coverage Matrix And Gap List

This section is intended to help the next AI quickly judge whether to extend the current smoke tests, revive legacy tests, or add new integration coverage.

### Active coverage matrix

#### `scripts/tests/SmokeTestRunner.gd`

Current role:

- lightweight logic smoke test
- fast regression guard for the most recently changed gameplay rules

What it covers well:

- save validation normalization
  - invalid `game_mode_name`
  - invalid `quality_name`
  - out-of-range timed mode value
  - malformed `bullets`
  - malformed `event_state`
  - malformed `queued_round_modifiers`
  - `chamber_jammed_time_left` defaulting
- event roulette timing helpers
  - basic interval
  - occupation interval
  - timed interval
  - wild interval range
- event roulette weighting helpers
  - positive events favor trailing factions
  - jam favors leading factions
- event roulette save-state import/export
  - countdown preservation
  - last effect preservation
- control chamber event behavior
  - `+10`
  - multiplier application
  - full chamber add-ball fallback to `+10`
  - jam on damaged chamber should not reactivate it
  - jam refund path unlocks chamber and returns reduced pending
  - queued positive modifiers while locked
- turret burst cancel behavior

What it does not really cover:

- full `Main.gd` gameplay loop
- actual scene boot and UI wiring
- battlefield ownership/capture correctness
- bullet motion/collision correctness
- save -> load -> resume full round-trip through `Main.gd`
- event roulette view animation/presentation
- pause/continue/save-exit flow
- win-condition end-to-end behavior

Confidence level:

- good as a narrow logic guard
- not sufficient as a comprehensive regression suite

#### `scripts/tests/IntegrationTestRunner.gd` (refactored v2.0.3)

Current role:

- medium integration correctness test (~57 assertions)
- uses TestAssert + TestFixtures for cleaner separation
- fills the three highest-priority coverage gaps

What it covers:

**P1 — Save/load round-trip:**
- save payload construction and field preservation
- SaveGameCodec full validation (all factions, event state, owners, game modes)
- save schema version compatibility (1.9.x accepted, 2.0.x rejected, empty rejected)
- game mode persistence and gate multiplier rules
- faction state round-trip (pending count, locked remaining, jammed time, turret health, burst state, queued modifiers)
- event state import/export (countdown, last effect, last faction, reroll count, interval)

**P2 — Battlefield rules:**
- initial territory assignment (4 quadrants, equal shares)
- same-faction bullet no-op
- enemy faction capture
- owner counts sync after capture
- world_to_cell / is_inside boundary checks
- rebuild_owner_counts after external mutation

**P3 — Win conditions:**
- basic: last surviving turret wins, all destroyed = draw
- occupation: 75% threshold triggers win, below threshold no win
- timed: score leader wins at expiry, even scores = draw
- wild: gate multiplier x3, max pending = WILD_MAX_PENDING_COUNT
- save version compatibility: 1.9.x passes, 2.0.0 rejected

What it does not cover:

- full Main.gd scene boot and UI wiring
- actual bullet physics / collisions
- chamber physics / peg / floor behavior
- turret sweep / firing kinematics
- save → load → resume through Main.gd (tests codec and logic layer, not scene orchestration)

Confidence level:

- good as a correctness guard for the three most critical gap areas
- does not replace SmokeTestRunner (fast guard) or PerfBurstBenchmark (performance probe)
- kept separate from SmokeTestRunner to avoid bloat

#### `scripts/tests/PerfBurstBenchmark.gd`

Current role:

- repeatable performance probe
- not a correctness test

What it covers well:

- heavy burst scenarios across multiple map sizes
- medium/high quality pressure behavior
- single-turret and four-turret load
- dominant-faction stress case
- trail pressure metrics
- queue pressure metrics
- redraw-rate metrics
- draw-call and visible-canvas-item estimation

What it does not cover:

- gameplay correctness
- UI correctness
- save/load correctness
- visual acceptance quality

Confidence level:

- useful for perf regression tracking
- should not be mistaken for gameplay validation

### Legacy coverage matrix

The disabled suite under `tests_legacy_disabled/` appears broader in shape than the active smoke runner.

Known legacy components:

- `TestEventRoulette.gd.disabled`
- `TestControlChamber.gd.disabled`
- `TestSaveGameCodec.gd.disabled`
- `TestBattlefield.gd.disabled`
- `TestRunner.gd.disabled`
- `PerfBurstBenchmark.gd.disabled`

Based on the legacy README and filenames, it likely covered:

- battlefield ownership/capture behavior
- chamber rule behavior
- save codec behavior
- event roulette behavior

Important nuance:

- these files are not the current canonical path
- they may still be useful as a source of assertions if the next AI wants to rebuild a broader active test suite

### Coverage summary by domain

Good coverage right now:

- save-data validation and clamping
- event interval/weight helper logic
- chamber modifier/jam refund behavior
- turret cancel-burst behavior
- performance instrumentation and metrics export

Partial coverage right now:

- event system logic
  - logic helpers are tested
  - controller/view integration is not deeply tested
- chamber behavior
  - modifier/jam edge cases are tested
  - full physics/peg/floor/gate runtime behavior is not deeply tested
- save/load
  - validation is tested
  - full in-game restore behavior is not

Weak or missing coverage right now:

- `Main.gd` orchestration
- actual runtime scene integration
- HUD/menu/pause/settings UI behavior
- layout correctness on `40 / 50 / 60`
- localization/text rendering correctness
- battlefield end-to-end combat/capture progression
- bullet lifetime and bounce behavior
- win condition flows for all game modes
- desktop-only runtime stability checks

### Gap list

Most important missing automated tests:

1. Full save/load round-trip through `Main.gd`.
   - Start game, mutate state, save, reload, verify battlefield/chambers/turrets/event state restore correctly.

2. Battlefield correctness tests in the active suite.
   - Ownership initialization
   - same-faction hit no-op behavior
   - enemy capture behavior
   - owner counts after capture

3. End-to-end win-condition tests.
   - basic elimination
   - occupation threshold
   - timed mode score winner
   - draw path

4. Event controller integration tests beyond helper methods.
   - applying resolved event payloads to real chambers
   - locked chamber modifier queue then unlock apply
   - jam against active burst with linked turret

5. UI/layout verification path.
   - At minimum, manual desktop checklist
   - ideally a lightweight scripted layout sanity pass if practical

6. Encoding/localization verification.
   - not easy as pure unit tests, but still needs a documented validation path because mojibake is an active project risk

### Recommended testing priorities for the next AI

If time is limited, the best order is:

1. Strengthen active correctness coverage before adding more perf work.
   - Highest ROI: battlefield + save/load round-trip + win conditions

2. Reuse assertions/ideas from `tests_legacy_disabled/` instead of inventing a new shape from scratch.

3. Keep `SmokeTestRunner.gd` as a fast guard, but consider adding a second active script for broader integration checks.

4. Treat perf benchmark updates as secondary unless the user is explicitly chasing FPS or trail pressure again.

## Recent Progress by Version

### `v2.0.0`

- introduced smoke runner and benchmark runner
- added read-only perf/debug counters
- improved measurement methodology with warmup/discard/repeats/order reversal

### `v2.0.1`

- tuned trail-pressure degradation earlier and harder
- specifically targeted the surprising `512 pending` underperformance case
- added benchmark fields:
  - `trail_pressure_level`
  - `trail_budget_active`
  - `trail_degrade_reason`

### `v2.0.2`

- focused on event/chamber UI text polish
- kept roulette logic in controller and presentation in view
- added extra benchmark observation fields:
  - `draw_calls`
  - `visible_canvas_items_estimate`
- repositioned/shortened event HUD text to avoid overlap

## Completion Audit For The Latest MD Files

This section cross-checks the latest `v2.0.x` README claims against the current code snapshot.

### `README_v2_0_0_tests_and_perf.md`

Status: mostly implemented in code.

Confirmed in active files:

- `scripts/tests/SmokeTestRunner.gd` exists and covers save validation, event logic, chamber rules, and turret burst cancellation
- `scripts/tests/PerfBurstBenchmark.gd` exists and contains warmup/discard/repeat/order-reversal benchmarking logic
- `scripts/BulletPool.gd`, `scripts/Battlefield.gd`, and `scripts/BulletTrailLayer.gd` expose debug metrics used by the HUD and benchmark
- `scripts/Main.gd` calls `bullet_container.set_tracked_turrets(turrets)` after turret creation

Important nuance:

- the old `tests/` suite mentioned in older `1.9.x` docs is no longer the active entry path here
- active test scripts are under `scripts/tests/`

### `README_v2_0_1_trail_pressure_fix.md`

Status: implemented in code, but final judgment still needs desktop benchmark confirmation.

Confirmed in active files:

- `scripts/GameConfig.gd` defines trail segment / FPS / redraw thresholds and redraw interval tiers
- `scripts/BulletPool.gd` computes severity from:
  - active bullets
  - total queue
  - trail segments
  - FPS
  - trail redraws
- `scripts/BulletPool.gd` exposes:
  - `trail_pressure_level`
  - `trail_pressure_severity`
  - `trail_budget_active`
  - `trail_degrade_reason`
- `scripts/tests/PerfBurstBenchmark.gd` records and summarizes those fields

Important nuance:

- code clearly contains the pressure/degrade system
- but the README's performance claims are still best treated as "implemented, desktop verification still required"

### `README_v2_0_2_ui_event_polish.md`

Status: partially implemented, partially contradicted by the current source snapshot.

Confirmed in active files:

- `scripts/EventRouletteController.gd` and `scripts/EventRouletteView.gd` are split as controller logic plus presentation-only view
- `scripts/GameHudView.gd` has a dedicated event label and positions it above the perf HUD on desktop, with a separate mobile position
- `scripts/ControlChamber.gd` uses gate labels equivalent to `x2/x3`, `发射`, and `短路`
- `scripts/RuntimeHudController.gd` and `scripts/BulletPool.gd` include the extra benchmark-facing fields documented in `v2.0.2`

Verified status (2026-05-04):

- ALL source files confirmed clean UTF-8 with correct Chinese characters
- The previous mojibake reports were terminal rendering artifacts, not file corruption
- event HUD wiring and roulette presentation work are present and code is clean
- chamber gate wording logic is present and code is clean
- Still recommend desktop inspection of runtime Chinese text rendering (font availability), but file encoding is confirmed correct

## Known Risks / Follow-up Targets

### High priority follow-up areas

1. Validate the current UI text rendering on desktop.
   - Source files confirmed clean UTF-8 (verified 2026-05-04).
   - Desktop verification still recommended: confirm runtime labels render correctly (font availability) and there's no overlap on `40 / 50 / 60` layouts.

2. Re-run desktop smoke and perf checks after any meaningful gameplay/UI change.
   - Codex-side runtime remains an unreliable judge.

3. Review save version/schema before any save-related refactor.
   - The code still writes `1.9.34`.
   - Docs/tests mention later `1.9.35` / `1.9.36`.
   - This mismatch is not necessarily fatal because only the `1.9` prefix is enforced, but it is confusing and should be handled intentionally.

### Lower priority but useful cleanup

- unify which test suite is considered canonical in docs
- decide whether old versioned READMEs should keep accumulating or whether a stable design/handoff doc should become the main entry point
- if git is later restored, capture a proper changelog/status workflow
- `scripts/Gate.gd` is dead code (zero references in codebase); ControlChamber handles gate logic internally. Can be removed if cleanup is desired.

## Suggested Starting Order For The Next AI

If the next AI is asked to continue development, the recommended order is:

1. Read this file.
2. Read `README_v2_0_2_ui_event_polish.md`.
3. Read `scripts/Main.gd`, `scripts/EventRouletteController.gd`, `scripts/BulletPool.gd`, and `scripts/tests/SmokeTestRunner.gd`.
4. If the task is performance-related, also read `scripts/tests/PerfBurstBenchmark.gd` and `README_v2_0_1_trail_pressure_fix.md`.
5. Chinese encoding is confirmed clean (verified 2026-05-04); no encoding cleanup needed.

## Assumptions Behind This Handoff

- This handoff was created from the current workspace snapshot only.
- No trustworthy git diff/history was available in this environment.
- Recent README files were treated as the main source of intended progress.
- Desktop verification commands were preserved from project docs because Codex runtime checks have been historically unreliable here.
