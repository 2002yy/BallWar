# Changelog / 变更记录

Date / 日期: 2026-05-15  
Role / 作用: condensed history spine / 精简历史主线

Detailed stage notes remain in `README_v*.md`.  
详细阶段记录继续保留在 `README_v*.md`。  
This file only keeps the short history spine, latest stable-line summary, and where to look next.  
这份文件只保留简明历史脉络、当前稳定线摘要，以及该去哪里继续看。

## Current Stable Line / 当前稳定主线

- Version / 版本: `v2.1.10`
- Date / 日期: `2026-05-16`
- Theme / 主题:
  - save-system security hardening
  - performance-path optimization
  - start-menu UI clarity

Key points / 重点:

- Save file size limit (1MB), path traversal filter, nested array validation
- Turret O(n²) queue total → O(1), has_method cache, cached map_size
- keys() → direct iteration, find+remove_at → erase, const priority dictionary
- StartButton full-width prominence, text contrast improvements
- All Windows exports switched to embed_pck=false + zip bundle

Detailed stage writeup in `README_v2_1_10.md`.

## Milestone Spine / 里程碑主线

### `v2.1.10`

- focus: security hardening (save file size, path traversal, validation), performance optimization (O(n²)→O(1), cache, erase, const), start-menu UI clarity, export packaging stability
- detailed notes: `README_v2_1_10.md`

### `v2.1.7`

- focus: containerized start menu, leader tie fix, chamber blur fix, event status refactor, lifecycle cleanup, asset audit
- detailed notes: `README_v2_1_7_ui_polish_and_fixes.md`

### `v2.1.5` - `v2.1.6`

- focus: event explanation layer, menu preferences persistence, save/restore bug fix, end-to-end continue test
- detailed notes:
  - `README_v2_1_5_event_log_and_menu_prefs.md`
  - `README_v2_1_6_save_restore_fix_and_e2e_test.md`

### `v2.1.1` - `v2.1.4`

- focus: continue/save-load orchestration cleanup, restore ownership clarification, performance-path cleanup
- detailed notes:
  - `README_v2_1_1_game_state_coordinator.md`
  - `README_v2_1_2_save_flow_controller.md`
  - `README_v2_1_3_restore_chain_audit.md`
  - `README_v2_1_4_restore_interfaces_and_perf_cleanup.md`

### `v2.0.3` - `v2.0.7`

- focus: test audit, save system centralization, win-condition extraction, layout sanity coverage, UI scene migration
- detailed notes:
  - `README_v2_0_3_fix_log.md`
  - `README_v2_0_3_test_audit.md`
  - `README_v2_0_4_win_condition_refactor.md`
  - `README_v2_0_5_save_centralization.md`
  - `README_v2_0_6_layout_sanity.md`
  - `README_v2_0_7_start_menu_scene.md`

### `v1.9.31` - `v2.0.2`

- focus: save-slot flow, event/UI polish, smoke/perf baselines, benchmark hardening
- detailed notes:
  - `README_v1_9_31.md`
  - `README_v1_9_32.md`
  - `README_v1_9_33.md`
  - `README_v1_9_34.md`
  - `README_v1_9_35.md`
  - `README_v1_9_36_tests_and_perf.md`
  - `README_v1_9_37_perf_benchmark.md`
  - `README_v2_0_0_perf_benchmark.md`
  - `README_v2_0_0_tests_and_perf.md`
  - `README_v2_0_1_trail_pressure_fix.md`
  - `README_v2_0_2_ui_event_polish.md`

### `v1.9.22` - `v1.9.30`

- focus: performance stabilization, adaptive pressure handling, HUD/perf observability, flow cleanup
- detailed notes remain in the corresponding `README_v1_9_*` files

### Early Prototype Patches / 早期原型补丁 (`v1.1` - `v1.6`)

- `v1.1`
  - switched bullets away from `Area2D`-driven collision setup to avoid physics-query flush errors
- `v1.2`
  - moved turrets toward corners and constrained rotation to inward-facing arcs
  - chamber bottom routing was simplified to deterministic `x2` / `R` exits
- `v1.3`
  - added the start menu, grid-size selection, and Chinese UI text
- `v1.4`
  - improved bullet readability and chamber text visibility
- `v1.5`
  - added smooth turret sweeping, add-ball buttons, turret health/destruction, and turret-hit bullet logic
- `v1.5.1` / `v1.5.2`
  - cleaned `:=` inference-related warnings by switching to explicit `=`
- `v1.6`
  - polished the menu, top HUD, chamber labels, add-ball buttons, and code-drawn preview visuals

## How To Read History / 历史阅读方式

- `README_v*.md`
  - detailed stage notes, kept for continuity
- `CHANGELOG.md`
  - quick spine only
- Git tags
  - best entry point when you want to jump between reconstructed milestones

## Notes / 说明

- `README_v*.md` are preserved on purpose; they are the detailed historical trail.
- older one-off audit, migration, patch-note, and folder-note Markdown files were consolidated into fewer live docs.
- current live document roles are summarized in `TECHNICAL_GUIDE.md`.
