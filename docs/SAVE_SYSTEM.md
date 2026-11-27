# Save System / 存档系统

Date: 2026-05-17, revised 2026-11-27 (claims re-verified against `main@3153d11`)
Role: save/load architecture reference / 存档架构参考

## Overview / 概览

Slot-based save system with backup recovery, version gating, payload-hash integrity checks, and centralized save-data normalization.

## Architecture / 架构

```
Main.gd (orchestration)
  ├─ SaveFlowController     — prepare_* / apply_* split for continue flow
  │   ├─ SaveGameCodec      — validate & normalize save data (no runtime mutation)
  │   └─ SaveStateApplier   — apply cleaned data to runtime objects
  └─ RestorePlan            — active restore planning data passed through continue path
```

## Components / 组件

### SaveFlowController.gd

Owns the continue/load flow. Split into two phases:
- `prepare_*` — collect save data from runtime objects
- `apply_*` — restore runtime objects from save data

### SaveGameCodec.gd

Validates and normalizes save data. Responsibilities:
- Version gate: accepts `1.9.x` and `2.0.x` schemas, rejects other prefixes and non-numeric patches
- Field normalization: `grid_size`, mode/quality names, time limit, owners shape, bullet cap, event state, faction fields, control-ball cap
- Payload hash: Godot `hash()` over the normalized JSON with the hash key removed

Does **not** directly mutate runtime objects.

### SaveStateApplier.gd

Takes cleaned/normalized data from `SaveGameCodec` and applies it to runtime objects and systems.

### RestorePlan.gd

Active restore planning data carried through the continue path. Used by runtime objects that own `restore_from_state(...)`:
- `ControlChamber.gd`
- `Turret.gd`
- `Bullet.gd` (currently needs deferred handling)

### Verified Behavior / 实测行为

Verified against source at `main@3153d11` on 2026-11-27.  
下表为按源码逐项核对后的实际行为，取代此前“Size limits / Path traversal filtering”的表述。

| Behavior | Actual implementation |
|---|---|
| Read size limit | **None.** `_read_save_dictionary()` reads the whole file before JSON parsing |
| Path traversal filter | **None**, and none is reachable: the path is a constant template in `Main.gd` plus a slot index clamped to `1..5`, so no save content or user text reaches the path |
| Version check | Known families `1.9`, `2.0` and `2.1`, including their numeric patch versions |
| Payload hash mismatch | Warning only — the save still loads (`ok: true`, status `mismatch`) |
| Payload hash missing | Accepted silently (status `missing`, treated as usable) |
| Nested validation | Per-field validation and clamping, not recursive traversal |
| Damaged `owners` | Field dropped, load continues, map falls back to default quadrant ownership (no error surfaced) |
| Backup recovery | Unreadable primary → `.bak` read and copied back over the primary |
| Atomic write | Write `.tmp` → re-read verify → copy current save to `.bak` → rename `.tmp` into place |

Known gap, not yet addressed: there is no upper bound on save file size, so a pathological save would be read and parsed in full before any validation runs. Any future limit must be measured against real high-pressure saves rather than assumed.

当前已知缺口：存档读取没有体积上限，异常大的文件会在校验之前被完整读入。若要加限制，应先测量真实高压对局的存档大小，再决定阈值与读写一致规则。

### Projectile Coordinates / 炮弹坐标

Schema `2.1.0` writes projectile positions and trail points in battlefield space. Entries carry `position_space: battlefield` and restore relative to the current battlefield. Untagged legacy entries retain simulation-world coordinates. Builds supporting only the `2.0` schema family reject new `2.1.0` saves.

### Integrity Model / 完整性模型

- The hash is a corruption/consistency **checksum over the JSON text**, not an anti-tamper mechanism; collisions and deliberate edits are out of scope
- Mismatch and missing-hash both fail open by design so that hand-edited and legacy saves stay loadable

## Key Design Decisions / 关键设计决策

- `SaveGameCodec` does not mutate runtime objects — single responsibility
- `SaveStateApplier` bridges the gap between validated data and runtime mutation
- Each major system owns its own `restore_from_state(...)` instead of a centralized restore function
- The prepare/apply split allows validation before any mutation occurs

## Related Docs / 相关文档

- [ARCHITECTURE.md](ARCHITECTURE.md) — system layering and ownership rules
- [TESTING.md](TESTING.md) — `SaveFlowControllerTestRunner` and `RestorePlanTestRunner`
