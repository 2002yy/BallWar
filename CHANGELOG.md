# Changelog / 版本脊柱

Date / 日期: 2026-05-17  
Role / 作用: condensed milestone spine / 精简版本脊柱

Detailed stage notes now live under [docs/history/](docs/history/README.md).  
详细阶段记录现已统一收敛到 [docs/history/](docs/history/README.md)。

## Release Reading Rule / Release 分层

- Latest Stable: `v2.1.11`
  - recommended public download, with Windows zip and Android debug APK assets
- Milestone Releases: `v2.1.10`, `v2.1.9`, `v2.1.8`, `v2.1.4`, `v2.0.3`
  - important checkpoints, not the default download signal
- Historical Releases: `v1.9.x`, `v0.1.0-mvp`
  - reconstructed history, not the recommended download path

## `v2.1.11` — Public Repository Hardening

- Restored corrupted Chinese UTF-8 text in key GDScript files
- Fixed Android ETC2/ASTC export configuration and added export-check helpers
- Published Windows zip and Android debug APK assets on GitHub Releases
- Continued structure cleanup through `ChamberBallPhysics`, `BulletPool` swap-remove, and `EventRouletteController` signal decoupling

**Public repository hardening (v2.1.11-public-repo-hardening):**
- Restructured README top section: Intro + Download + Screenshots + Tech Highlights for player/recruiter audience
- Added GitHub Actions CI workflow: project-load validation + 10-test matrix with artifact upload
- Fixed Android export scripts: removed hardcoded absolute paths, use `$PSScriptRoot`-relative default
- Aligned `export_presets.cfg`: English preset name, `script_export_mode=0`, version string, English export path
- All historical `README_v*.md` stage documents remain in `docs/history/` — root directory clean
- Created `docs/history/README_v2_1_11_public_repo_hardening.md`
- Updated CHANGELOG, ROADMAP, TECHNICAL_GUIDE, and history index

- Current Latest Stable / 推荐公开下载版本

## `v2.1.10`

- Added save file size limits, path traversal filtering, and nested save-data validation
- Reduced turret queue, bullet map-size lookup, dictionary iteration, and bullet recycling hot-path costs
- Improved StartMenu button prominence, text contrast, and slot readability
- Repacked Windows releases as `.exe + .pck` zip bundles

## `v2.1.9`

- Added `PlayerSettingsStore.gd`
- Added interactive `SettingsPanel`
- Added `ResultPanel` with victory reason, game duration, final territory ratio, and statistics
- Added peak active bullet and event trigger statistics
- Connected low-FX, performance HUD, and event-log settings to runtime behavior

## `v2.1.8`

- Changed `BattlefieldDecorLayer` from polling to event/dirty-marker behavior
- Extracted `ChamberState` from `ControlChamber`
- Improved StartMenu layout, preview, and slot readability
- Strengthened save recovery and continue flow coverage

## `v2.1.5` - `v2.1.7`

- Continued event explanation, menu preferences, and UI detail work
- Fixed save/restore bugs and improved continue stability
- Containerized StartMenu behavior and cleaned lifecycle/event state
- Continued asset audit and resource-boundary cleanup

## `v2.1.0` - `v2.1.4`

- Migrated `StartMenu.tscn` into an editable UI scene
- Split continue flow into `prepare_*` and `apply_*`
- Moved `restore_from_state(...)` ownership out of `Main.gd` and into runtime objects
- Clarified `Main.gd` as top-level orchestration
- Established the stable structural baseline still referenced by later work

## `v2.0.x`

- Systematized save/restore, win conditions, and layout sanity coverage
- Formed coordination layers such as `SaveFlowController` and `GameStateCoordinator`
- Introduced a more maintainable test matrix and version-note workflow
- Laid the groundwork for later v2.1.x UI scene migration

## `v1.9.x`

- Developed multi-mode rules and event systems
- Focused on bullet-pool, trail, and battlefield rendering performance
- Introduced `SmokeTestRunner`, `IntegrationTestRunner`, and `PerfBurstBenchmark`
- Moved the project from "playable" toward "maintainable"

## `v1.7.x` - `v1.8.x`

- Stabilized early battlefield, control-chamber, and turret rules
- Polished early UI and battlefield feedback
- Started accumulating versioned stage documentation

## `v0.1.0-mvp`

- Established the minimum four-faction territory-control loop
- Implemented the earliest battlefield, turret, control-chamber, and launch logic
- Preserved as the historical founding prototype, not the current release
