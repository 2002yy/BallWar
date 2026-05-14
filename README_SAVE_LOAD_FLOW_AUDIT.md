# Save / Load Flow Audit

Date: 2026-05-06
Scope: audit only, no logic changes

## Goal

This document explains the current save/load chain before further refactors.

Focus:
- where load starts
- where clean data is produced
- when battlefield / chamber / turret / event / bullet state is restored
- why bullet restore is deferred
- which parts are high-risk and should not be moved casually

This document is intentionally about the **read/load path**, not the already-started low-risk save-write split.

## Current Read Path Overview

Current read flow starts in `Main.gd` and still stays there for most of the chain:

```text
_continue_saved_game()
├── _load_saved_data()
├── SaveGameCodec.is_supported_save_version()
├── SaveGameCodec.validate_save_data()
├── _start_game(..., suppress_banner=true, clear_save=false)
├── _apply_saved_state()
│   ├── SaveStateApplier.apply_owners()
│   ├── SaveStateApplier.apply_factions()
│   │   ├── _apply_chamber_state()
│   │   └── _apply_turret_state()
│   ├── SaveStateApplier.apply_event_state()
│   ├── _restore_bullet_states()
│   └── SaveStateApplier.apply_game_over_state()
└── _show_center_banner(...)
```

Important consequence:
- read path is still a **Main.gd-centered orchestration flow**
- `SaveStateApplier.gd` is only a **partial applier**, not the full read controller

## 1. Where Does Load Start?

Load entry starts at:
- `Main.gd::_continue_saved_game()`

This function currently does all of the following:
- load raw data from disk
- reject unsupported save version
- validate and clean raw data
- push config back into runtime singletons
- start a fresh game scene
- apply restored runtime state
- show resume banner

So `_continue_saved_game()` is not just “continue” UI logic.
It is currently:
- load coordinator
- validation gate
- runtime config loader
- restore orchestrator

This is why it is still high-risk and should remain frozen for now.

## 2. When Is Clean Data Produced?

Clean data is produced here:
- `SaveGameCodec.validate_save_data(data)`

This happens inside:
- `Main.gd::_continue_saved_game()`

The chain is:

1. `_load_saved_data()` returns raw parsed JSON dictionary
2. `SaveGameCodec.is_supported_save_version(save_version)` rejects incompatible major version
3. `SaveGameCodec.validate_save_data(data)` duplicates and normalizes the payload

`validate_save_data()` currently normalizes:
- `grid_size`
- `quality_name`
- `game_mode_name`
- `time_limit_minutes`
- `owners`
- `bullets`
- `event_state`
- `factions`
- queued round modifiers
- capped control ball arrays

It can also inject:
- `_invalid_reason`

Important boundary:
- `SaveGameCodec` produces a **cleaned dictionary**
- it does **not** apply state to runtime objects

## 3. When Are Battlefield Owners Restored?

Battlefield owners are restored in:
- `SaveStateApplier.apply_owners(battlefield, data, on_scores_changed)`

This is called from:
- `Main.gd::_apply_saved_state(data)`

What happens there:
- `owners` array is read from cleaned save data
- it is validated against `battlefield.grid_size`
- `battlefield.owners` is replaced
- owner counts are rebuilt
- visual update is flushed or redraw queued
- `_on_scores_changed()` is called with fresh score counts

Important timing:
- battlefield restore happens **before faction objects** and **before bullets**

Why this order matters:
- restored bullets later depend on restored map context
- score UI should already reflect restored territory before later systems update

## 4. When Are Chamber / Turret States Restored?

Faction state restore begins in:
- `SaveStateApplier.apply_factions(...)`

This is called from:
- `Main.gd::_apply_saved_state(data)`

`SaveStateApplier.apply_factions()` loops faction records and delegates to:
- `Main.gd::_apply_chamber_state(chamber, state)`
- `Main.gd::_apply_turret_state(turret, state)`

### Chamber restore currently includes

`_apply_chamber_state()` restores:
- existing ball cleanup
- stuck state cleanup
- release ball reset
- damage / lock reset
- pending count
- locked remaining
- jammed time
- queued round modifiers
- control ball instances and their position / velocity / radius / stay_time
- fallback ball-count restore when detailed control-ball array is absent
- release ball index
- final label / locked state refresh

### Turret restore currently includes

`_apply_turret_state()` restores:
- health
- destroyed flag
- damage flash / destroy anim reset
- sweep phase
- rotation
- burst remaining
- burst total
- burst index
- burst timer
- burst lock state

If turret is destroyed, it force-clears burst state again.

Important boundary:
- chamber / turret restore is **not yet inside `SaveStateApplier`**
- `SaveStateApplier` only decides **when** to call those callbacks
- the heavy object-state mutation still lives in `Main.gd`

This is one of the main reasons the read path remains risky.

## 5. When Is Event State Restored?

Event restore happens in:
- `SaveStateApplier.apply_event_state(event_roulette_controller, data)`

This is called from:
- `Main.gd::_apply_saved_state(data)`

What happens:
- `data["event_state"]` is read
- dictionary is passed to `event_roulette_controller.import_save_state(...)`

Important boundary:
- event restore is already relatively cleanly delegated
- but it still depends on `event_roulette_controller` already existing and already being wired

This means:
- `_start_game()` must finish scene creation first
- only then can event state be imported safely

## 6. When Are Bullets Restored?

Bullets are not fully restored in one step.

The chain is:

1. `Main.gd::_apply_saved_state(data)`
2. `Main.gd::_restore_bullet_states(data.get("bullets", []))`
3. later, during `_process(delta)`, `Main.gd::_process_pending_bullet_restore()`

`_restore_bullet_states()` only:
- clears active bullets
- clears pending queue
- caps total restore count by `GameConfig.get_restore_bullet_limit()`
- pushes cleaned bullet dictionaries into `pending_restore_bullets`

Actual bullet instance creation happens later in:
- `_process_pending_bullet_restore()`

There:
- restore is spread per frame using `GameConfig.get_restore_per_frame()`
- bullets may use object-pool `spawn_bullet()` if available
- otherwise fallback to `Bullet.new()`
- age / last_cell / trail_points are restored

Important timing:
- bullet restore happens **after owners / factions / event state import**
- and happens **incrementally**, not immediately

## 7. Why Does The Pending Restore Queue Exist?

The pending restore queue exists to avoid a heavy one-frame spike during load.

Without it, large saves could restore too many bullets at once and cause:
- long frame hitch during resume
- extra redraw pressure
- higher object allocation burst
- more risk around pooled vs non-pooled bullet creation

Current design:
- `_restore_bullet_states()` is the queue initializer
- `_process_pending_bullet_restore()` is the frame-budgeted worker

This is a deliberate performance-safety mechanism, not accidental complexity.

That makes it high-risk to refactor casually.

## 8. What Should Not Be Moved Lightly?

These areas are high-risk and should not be migrated casually:

### `_continue_saved_game()`

Why risky:
- mixes disk IO, validation, runtime config restore, scene restart, state apply, resume banner
- any ordering mistake can break continue flow in subtle ways

### `_apply_saved_state()`

Why risky:
- it is the central restore sequencing point
- owners / factions / event state / bullets / game-over state all depend on order

### `_process_pending_bullet_restore()`

Why risky:
- depends on pooled and fallback bullet creation
- depends on battlefield existing
- depends on per-frame throttling
- depends on trail restoration

### `_apply_chamber_state()`

Why risky:
- deeply mutates chamber internals
- recreates runtime child objects
- rebinds release-ball semantics

### `_apply_turret_state()`

Why risky:
- mixes visual state, burst state, destruction state
- incorrect ordering can resurrect or freeze a destroyed turret incorrectly

### `SaveGameCodec.validate_save_data()`

Why risky:
- it is the only central clean-data gate
- changing it affects both load safety and backward compatibility assumptions

## 9. What Is The Next Safe Split?

The next safe split is **not** full load orchestration yet.

Recommended next step:
- continue `SaveFlowController` only on the **read-side audit / helper boundary**
- do not yet move restore execution

Best next low-risk targets:

1. move `_load_saved_data()` into `SaveFlowController`
   - pure disk read / JSON parse / legacy path choice

2. move “slot exists / slot summaries / slot UI” fully out of `Main.gd`
   - this is already partly underway

3. introduce a small read-side helper for:
   - version rejection
   - clean-data production
   - but still let `Main.gd` keep final orchestration

### Not yet recommended

- moving `_continue_saved_game()` whole
- moving `_apply_saved_state()` whole
- moving bullet restore worker
- moving chamber/turret deep state mutation

## Current Long-Term Boundary

The healthier long-term architecture should look like this:

### SaveFlowController
- save path
- save existence
- save slot summaries
- write orchestration
- raw load / parse
- continue-flow orchestration later

### SaveGameCodec
- version support gate
- clean-data normalization
- array/vector conversion helpers
- state collection helpers

### SaveStateApplier
- apply clean data to runtime systems
- gradually absorb chamber/turret restore logic over time

### Main.gd
- top-level entry and coordination
- should eventually stop directly mutating deep chamber/turret restore state

## Current Status Summary

Today the load chain is:
- functionally working
- heavily ordered
- partially delegated
- still `Main.gd`-centric

That means:
- it is stable enough to audit
- not yet safe enough for broad refactor
- best next move is another narrow split, not a big migration
