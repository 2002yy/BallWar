# BallWar Validation Policy

## Purpose

This document defines how BallWar should be validated during development, especially when work is split between:

- Codex automation
- desktop local verification

The goal is to avoid misdiagnosing environment-specific Godot crashes as project logic bugs, while still keeping feature delivery disciplined and test-backed.

## Core rule

Codex-side `headless` or scripted Godot crashes do not automatically mean the project is broken.

Validation priority is:

1. desktop local smoke/perf results
2. editor parse/load results
3. Codex static analysis and script scanning
4. Codex runtime results

## Responsibility split

### Codex side

Codex is responsible for:

- editing code
- static script scanning
- duplicate `class_name` checks
- `load/preload` reference checks
- editor parse/load checks
- smoke test authoring
- perf benchmark authoring
- README and validation note updates

### Desktop local side

Desktop local verification is responsible for:

- final smoke test execution
- final perf benchmark execution
- actual play verification
- UI readability checks
- visual quality checks
- event presentation checks
- crash reproduction confirmation

## Ground truth rules

### Logic regression

Logic regression is considered valid when desktop local `SmokeTestRunner` passes.

Current standard command:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/SmokeTestRunner.gd"
```

### Performance regression

Performance regression is considered valid when desktop local `PerfBurstBenchmark` completes and writes its reports.

Current standard command:

```cmd
"E:\Godot\Godot_\Godot_console.exe" --path "C:\Users\96967\Desktop\Marble Dominion Ricochet War\BallWar_v2_0\BallWar" --script "res://scripts/tests/PerfBurstBenchmark.gd"
```

### Parse / script health

Project parse health is considered valid when editor/script scan shows no new:

- `Parse Error`
- `SCRIPT ERROR`
- missing script/class load failures

## Codex environment limitation rule

If Codex environment `headless` or scripted runtime crashes, but:

- there is no clear `Parse Error`
- there is no clear `SCRIPT ERROR`
- desktop local `SmokeTestRunner` passes

then Codex must not keep rewriting project code speculatively.

Instead, record it as:

`Codex runtime environment limitation; wait for desktop local verification.`

## Crash escalation rule

Only escalate crash debugging as a project bug when desktop local environment also reproduces a crash in a stable way.

Useful evidence includes:

- full Godot console log
- repro log tail
- Windows Event Viewer crash record
- crash dump if one exists
- exact launch command

Without desktop-local repro, do not assume a project logic fault.

## Testing policy for new features

Every new feature should ship with reasonable validation coverage.

Minimum expectation:

- smoke test coverage where practical
- performance safety check where practical
- leak/cleanup awareness for created nodes/resources
- manual acceptance boundaries written down

If a feature is too UI-heavy for full automation, still provide:

- controller / logic tests
- perf-safe benchmark hooks if needed
- explicit manual verification checklist

## Preferred test entrypoints

Prefer dedicated safe entrypoints such as:

- `SmokeTestRunner.gd`
- `PerfBurstBenchmark.gd`
- focused logic test scripts
- UI-light benchmark scripts

Avoid using these as the default automation path:

- direct `Main.tscn` runtime
- full `Play/F5` equivalent automation
- full menu + full battlefield + full roulette UI boot just to test logic

## Test safety principles

### 1. Keep logic tests UI-light

Prefer testing:

- `EventRouletteController`
- `SaveGameCodec`
- `ControlChamber` public event interfaces
- `Turret.cancel_burst()`
- `GameConfig`

Avoid requiring heavy UI just to validate logic.

### 2. Keep controller and view separated

Controller logic should remain testable in automation.
View behavior can rely more on:

- desktop local manual verification
- lightweight create/free tests

Do not make logic tests depend on:

- full roulette animation
- heavy `CanvasLayer` trees
- font/render/window side effects

### 3. Release created test objects

All test-created nodes/resources should be explicitly cleaned up.

If a node was added to the tree:

- `queue_free()`
- wait at least one frame

If it was never added:

- free directly when safe

### 4. Avoid full-scene validation by default

Full playable scene validation is useful, but should not be the default path for every automated test.

## Recommended future safety improvements

These are recommended patterns for later implementation when needed:

- safe wrappers for `DisplayServer` / `Window` queries
- explicit test-mode command line flag such as `--ballwar-test`
- skipping nonessential UI boot in test mode
- skipping automatic save-load flows in test mode

This document does not require those systems immediately; it defines the preferred direction.

## Delivery checklist for future work

When a feature is finished, verify:

1. script parse/load health
2. smoke test impact
3. perf benchmark impact when relevant
4. leak/cleanup safety when relevant
5. manual acceptance notes documented

## Current project interpretation

At the current stage of BallWar development:

- desktop smoke test is the trusted logic baseline
- desktop perf benchmark is the trusted performance baseline
- Codex editor/script checks are useful and expected
- Codex runtime crashes alone are not treated as proof of project failure
