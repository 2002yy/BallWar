# AI Handoff Current

Last updated: 2026-05-04

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

### 1. Chinese text is still in a mojibake state in many active files

Examples are visible in:

- `scripts/Main.gd`
- `scripts/GameConfig.gd`
- `scripts/RuntimeHudController.gd`
- `scripts/EventRouletteController.gd`
- `README_v2_0_2_ui_event_polish.md`

This matters because:

- the code intent is clearly "Chinese UI restored/polished"
- but many strings currently render as garbled text in source
- the next AI should treat text encoding/display consistency as an ongoing issue, not automatically as a new regression from the latest pass

Relevant historical context:

- `README_v1_9_35.md` and `README_v1_9_36_tests_and_perf.md` mention earlier UTF-8 cleanup work
- despite that, mojibake still exists in the current `v2.0.x` code/docs snapshot

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

- `scripts/tests/SmokeTestRunner.gd`
- `scripts/tests/PerfBurstBenchmark.gd`

### Legacy scripts

- `tests_legacy_disabled/`

These are useful for historical reference, but they are not the active path right now.

### Desktop commands from project docs

Smoke test:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/SmokeTestRunner.gd"
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

Contradictions / caveats:

- the README says Chinese UI was restored, but several active source files still show mojibake text in this workspace snapshot
- some event/chamber strings are clean Chinese in source now, but many other labels in `Main.gd`, `GameConfig.gd`, `GameHudView.gd`, and `EventRouletteView.gd` are still garbled
- this suggests the pass was only partially normalized, or later file encoding drift reintroduced corruption

Bottom line:

- event HUD wiring and roulette presentation work are present
- chamber gate wording logic is present
- "Chinese UI fully restored" should not be treated as complete without desktop inspection

## Known Risks / Follow-up Targets

### High priority follow-up areas

1. Validate the current UI text state on desktop.
   - Because source files and docs still show mojibake, the next AI should confirm whether runtime labels are also broken or whether this is primarily a source-encoding artifact.

2. Re-run desktop smoke and perf checks after any meaningful gameplay/UI change.
   - Codex-side runtime remains an unreliable judge.

3. Decide whether to normalize text encoding globally.
   - This likely needs a deliberate pass across `GameConfig`, `Main`, HUD scripts, event scripts, and versioned docs.
   - It should not be mixed casually into unrelated gameplay work.

4. Review save version/schema before any save-related refactor.
   - The code still writes `1.9.34`.
   - Docs/tests mention later `1.9.35` / `1.9.36`.
   - This mismatch is not necessarily fatal because only the `1.9` prefix is enforced, but it is confusing and should be handled intentionally.

### Lower priority but useful cleanup

- unify which test suite is considered canonical in docs
- decide whether old versioned READMEs should keep accumulating or whether a stable design/handoff doc should become the main entry point
- if git is later restored, capture a proper changelog/status workflow

## Suggested Starting Order For The Next AI

If the next AI is asked to continue development, the recommended order is:

1. Read this file.
2. Read `README_v2_0_2_ui_event_polish.md`.
3. Read `scripts/Main.gd`, `scripts/EventRouletteController.gd`, `scripts/BulletPool.gd`, and `scripts/tests/SmokeTestRunner.gd`.
4. If the task is performance-related, also read `scripts/tests/PerfBurstBenchmark.gd` and `README_v2_0_1_trail_pressure_fix.md`.
5. If the task is UI/localization-related, inspect current runtime labels first before mass-editing strings.

## Assumptions Behind This Handoff

- This handoff was created from the current workspace snapshot only.
- No trustworthy git diff/history was available in this environment.
- Recent README files were treated as the main source of intended progress.
- Desktop verification commands were preserved from project docs because Codex runtime checks have been historically unreliable here.
