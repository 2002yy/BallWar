# Technical Guide / 技术指南

Date / 日期: 2026-05-16
Role / 作用: live engineering guide / 当前工程协作与技术边界

This file replaces scattered historical audit and handoff notes.  
这份文档用于替代零散的历史审计、迁移说明和交接附页。

Keep it current, short, and operational.  
请把它维护成“当前有效”的短文档，而不是继续堆历史过程稿。

## 1. Canonical Docs / 主文档分工

- `README.md`
  - project overview, current line, and entry links
- `ROADMAP.md`
  - current progress, what is done, what is next, what is deferred
- `README_TEST_MATRIX.md`
  - correctness baseline, performance probes, and when to run which tests
- `AI_HANDOFF_CURRENT.md`
  - fast session takeover card for the next AI / Codex run
- `CHANGELOG.md`
  - condensed version spine
- `docs/history/README.md`
  - history index for stage documents
- `docs/history/README_v*.md`
  - detailed historical stage notes, intentionally preserved
- `assets/ASSET_SOURCES_AND_LICENSES.md`
  - asset provenance and redistribution notes

## 2. Repo Scope And Entry Scenes / 仓库范围与入口场景

- Git mainline scope:
  - `BallWar/`
- root runtime entry scene:
  - `scenes/Main.tscn`
- current human-editable UI scenes:
  - `scenes/ui/StartMenu.tscn`
  - `scenes/ui/GameHUD.tscn`
  - `scenes/ui/EventRouletteView.tscn`
  - `scenes/ui/SettingsPanel.tscn`
  - `scenes/ui/ResultPanel.tscn`
  - `scenes/ui/PreviewScene.tscn`

Use the editor for layout, fonts, spacing, colors, and scene wiring where a `.tscn` already exists.  
凡是已经存在 `.tscn` 的可见 UI，优先在编辑器里改布局、字体、配色和节点连接。

Do not recreate those surfaces in code unless there is a clear runtime-only reason.  
除非有明确的运行时理由，否则不要把这些界面重新改回纯代码生成。

## 3. Current Architecture Boundaries / 当前架构边界

- `Main.gd`
  - top-level lifecycle and orchestration
  - should keep shrinking away from deep restore-field mutation
- `SaveFlowController.gd`
  - owns the continue/load flow split between `prepare_*` and `apply_*`
- `RestorePlan.gd`
  - active restore planning data passed through the continue path
- `SaveGameCodec.gd`
  - validates and normalizes save data only
  - should not directly mutate runtime objects
- `SaveStateApplier.gd`
  - applies cleaned data to runtime objects and systems
- `ControlChamber.gd`, `Turret.gd`, `Bullet.gd`
  - own `restore_from_state(...)` for their internal restore mutation
- bullet restore path
  - still needs deferred handling because pooling, trails, and pressure behavior are runtime-heavy

## 4. UI And Scene Policy / UI 与场景规则

- new visible UI should be `.tscn`-first
- scripts should prefer logic, signals, and lightweight coordination
- avoid rebuilding large node trees in `_ready()` when a reusable scene is the better fit
- if a scene has been manually tuned in the editor, do not overwrite it with generator-style scripts
- runtime-heavy systems can stay code-driven when editor scenes add little value:
  - `Battlefield.gd`
  - `BulletPool.gd`
  - pooled bullet/trail internals
  - control-chamber internal ball runtime state

## 5. Validation Policy / 验证规则

Priority / 优先级:

1. desktop local smoke/perf evidence
2. editor parse/load health
3. static script scanning and targeted headless checks
4. Codex runtime observations

Working rules / 工作规则:

- correctness baseline lives in `README_TEST_MATRIX.md`
- performance probes are not correctness proof
- if Codex runtime crashes but there is no clear parse/script failure and desktop local does not reproduce it, record it as an environment limitation instead of rewriting code speculatively
- when feature work is UI-heavy, still leave either:
  - controller/logic tests
  - a lightweight benchmark hook
  - or a clear manual verification checklist

## 6. Asset Boundary / 资源边界

- `assets/`
  - curated, import-ready, redistribution-aware files only
- `art_reference/free_ui_assets/`
  - research material, raw downloads, and source capture artifacts

Before shipping or mirroring third-party material, check `assets/ASSET_SOURCES_AND_LICENSES.md`.  
任何第三方资源在正式提交或分发前，都先看 `assets/ASSET_SOURCES_AND_LICENSES.md`。

## 7. Maintenance Rule / 维护规则

- if a doc is about the current truth, fold it into one of the live docs above
- if a doc is only a temporary process log, do not let it become permanent root clutter
- detailed stage history belongs under `docs/history/`
- when a new version gets its own stage note, keep the live docs aligned instead of copying status text into many places

## 8. Android Export Boundary / Android 导出边界

- public-facing export notes should stay summarized in `README.md`
- operational export checklist and helper scripts can live in `README_ANDROID_EXPORT.md` and `tools/`
- `project.godot` must keep:
  - `[rendering]`
  - `textures/vram_compression/import_etc2_astc=true`
