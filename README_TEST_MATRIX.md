# Test Matrix

Date: 2026-05-06

## Goal

This document classifies the active test scripts by responsibility so future
refactors do not drift into "run whatever seems related".

## A. Scene Wiring Tests

Purpose:
- verify `.tscn` scenes load
- verify required node paths stay stable
- verify scene scripts do not accidentally stomp intended layout/state on setup

Files:
- `scripts/tests/StartMenuSceneTestRunner.gd`
- `scripts/tests/GameHUDSceneTestRunner.gd`
- `scripts/tests/EventRouletteSceneTestRunner.gd`
- `scripts/tests/SettingsPanelSceneTestRunner.gd`

Run these when:
- editing `.tscn`
- changing scene scripts
- changing node paths / exported references

## B. Coordinator / Helper Unit Tests

Purpose:
- verify new extracted helper/coordinator logic without needing full runtime scene boot

Files:
- `scripts/tests/GameStateCoordinatorTestRunner.gd`
- `scripts/tests/SaveFlowControllerTestRunner.gd`

Run these when:
- splitting responsibilities out of `Main.gd`
- changing state-flow helpers
- changing save/load orchestration helpers

## C. Smoke Test

Purpose:
- fast regression guard
- confirms the most important systems still behave correctly at a high level

Files:
- `scripts/tests/SmokeTestRunner.gd`

Run this when:
- almost any medium-sized gameplay/system change lands

## D. Integration Test

Purpose:
- medium-weight cross-system correctness
- especially save/load, battlefield rules, and win conditions

Files:
- `scripts/tests/IntegrationTestRunner.gd`

Run this when:
- touching save/load
- touching battlefield rules
- touching win-condition logic

## E. Layout Boundary Test

Purpose:
- verify layout profile boundaries
- catch overflow / placement regressions across supported grid sizes

Files:
- `scripts/tests/LayoutSanityTestRunner.gd`

Run this when:
- changing layout profiles
- changing HUD/chamber/map placement logic

## F. Performance Probe

Purpose:
- measure performance and pressure behavior
- not a correctness test

Files:
- `scripts/tests/PerfBurstBenchmark.gd`

Run this when:
- tuning firing/perf policies
- checking trail-pressure / pool-pressure changes

## G. Test Infrastructure

Purpose:
- shared assertion and fixture utilities

Files:
- `scripts/tests/TestAssert.gd`
- `scripts/tests/TestFixtures.gd`

## Recommended Run Order

### If editing `.tscn` / UI wiring

1. scene wiring tests
2. layout boundary test
3. smoke test

### If editing coordinator/helper logic

1. relevant helper test
2. smoke test
3. related scene tests if UI/state is involved

### If editing save/load orchestration

1. `SaveFlowControllerTestRunner.gd`
2. `IntegrationTestRunner.gd`
3. `SmokeTestRunner.gd`

### If editing gameplay state flow

1. `GameStateCoordinatorTestRunner.gd`
2. `SmokeTestRunner.gd`
3. `IntegrationTestRunner.gd` if save/win flow is touched

## Active Correctness Baseline

These should normally stay green:

- `StartMenuSceneTestRunner.gd`
- `GameHUDSceneTestRunner.gd`
- `EventRouletteSceneTestRunner.gd`
- `SettingsPanelSceneTestRunner.gd`
- `GameStateCoordinatorTestRunner.gd`
- `SaveFlowControllerTestRunner.gd`
- `SmokeTestRunner.gd`
- `IntegrationTestRunner.gd`
- `LayoutSanityTestRunner.gd`

`PerfBurstBenchmark.gd` is useful, but not part of the strict correctness baseline.

## PASS Labels

Use these consistently:

- `PASS`
  - assertions passed and test exits cleanly
- `PASS with cleanup warnings`
  - assertions passed, but there are resource/object cleanup warnings on exit
- `FAIL`
  - assertion failure, script error, parse error, or incomplete run

## 2026-05-06 Local Baseline

User-verified local Godot runs passed:

- `StartMenuSceneTestRunner.gd`
- `GameHUDSceneTestRunner.gd`
- `EventRouletteSceneTestRunner.gd`
- `SettingsPanelSceneTestRunner.gd`
- `GameStateCoordinatorTestRunner.gd`
- `SaveFlowControllerTestRunner.gd`
- `SmokeTestRunner.gd`
- `IntegrationTestRunner.gd`
- `LayoutSanityTestRunner.gd`

## Current Recommendation

- treat the nine scripts above as the active correctness baseline
- run `GameStateCoordinatorTestRunner.gd` first for state-flow refactors
- run `SaveFlowControllerTestRunner.gd` first for save/load orchestration refactors
- run scene tests first for `.tscn` and UI-node changes
