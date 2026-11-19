# BallWar / 领土战争 (Marble Dominion Ricochet War)

A **Godot 4.7 + GDScript** 2D territory-control arcade prototype — four factions fight for grid dominance in a chaotic bullet arena.
一个基于 **Godot 4.7 + GDScript** 的 2D 四阵营领土争夺街机原型。

**Engine:** Godot 4.7 · **Language:** GDScript · **Tests:** 12 runners · GitHub Actions CI · **Platforms:** Windows / Android

4.7迁移使用4.7.1验证；导出模板必须匹配4.7.x，不能复用4.6模板。当前迁移/设置验证见 `docs/technical/AI_HANDOFF_CURRENT.md`。

## Gameplay Loop / 玩法循环

1. Four factions compete for territory on the central grid.
2. Control chambers decide firing rhythm and burst scale.
3. Turrets launch bullets into the battlefield.
4. Bullets convert cells and shift territory control.
5. Event roulette changes the match tempo.
6. A faction wins when mode-specific victory conditions are met.


## Screenshots / 截图

| 开始界面 | 游戏初始 | 游戏中场 | 事件画面 | 胜利结果 |
|:--:|:--:|:--:|:--:|:--:|
| ![](screenshots/%E5%BC%80%E5%A7%8B%E7%95%8C%E9%9D%A2.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E5%88%9D%E5%A7%8B.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E4%B8%AD%E5%9C%BA.png) | ![](screenshots/%E4%BA%8B%E4%BB%B6%E7%94%BB%E9%9D%A2.png) | ![](screenshots/%E4%B8%80%E6%96%B9%E8%83%9C%E5%88%A9%E7%BB%93%E6%9E%9C.png) |

## Demo Video / GIF

- 30s gameplay loop: TODO
- event roulette demo: TODO
- save/load recovery demo: TODO
- Android layout demo: TODO

## Download Latest Release / 下载最新版本

> **v2.1.11.1 (Latest Stable)** — [Windows zip](https://github.com/2002yy/BallWar/releases/tag/v2.1.11.1) · [Android APK](https://github.com/2002yy/BallWar/releases/tag/v2.1.11.1)  
> All releases: [github.com/2002yy/BallWar/releases](https://github.com/2002yy/BallWar/releases)

## Tech Highlights / 技术亮点

- **12 headless CI runners** — smoke, wiring, coordinator, integration, layout tests via GitHub Actions
- **Architecture layering** — `Main.gd` orchestration → coordinators, restore planners, save adapters ([docs/ARCHITECTURE.md](docs/ARCHITECTURE.md))
- **Save/load with hardening** — slot-based saves, backup recovery, version checks, input sanitization ([docs/SAVE_SYSTEM.md](docs/SAVE_SYSTEM.md))
- **Performance probes** — bullet pressure, frame time, trail cache metrics built into runtime ([docs/PERFORMANCE.md](docs/PERFORMANCE.md))
- **Android export pipeline** — ETC2/ASTC validation, debug APK, PowerShell scripts ([docs/ANDROID_EXPORT.md](docs/ANDROID_EXPORT.md))
- Four-faction territory control, chamber-driven firing rhythm, event roulette, multi-mode rules

## Architecture / 架构

System layering (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)):

- **`Main.gd`** — top-level lifecycle orchestration
- **`SaveFlowController`** — continue/load flow (`prepare_*` / `apply_*`)
- **`RestorePlan`** — active restore planning data through the continue path
- **`SaveGameCodec`** + **`SaveStateApplier`** — validate, normalize, then apply
- **`ControlChamber`**, **`Turret`**, **`Bullet`** — each owns `restore_from_state(...)`
- Runtime-heavy: `Battlefield`, `BulletPool`, pooled trail internals

## Testing / 测试

The Godot 4.7.1 CI runs **12 headless correctness runners**. The former 1083-check
count described the older 10-runner snapshot; current acceptance uses each
runner's exit status, assertion failures, and engine error logs.

| Runner | Responsibility |
|---|---|
| `LayoutSanityTestRunner.gd` | Responsive layout boundaries |
| `SmokeTestRunner.gd` | Core gameplay smoke checks |
| `SaveFlowControllerTestRunner.gd` | Save/load orchestration |
| `IntegrationTestRunner.gd` | Cross-system behavior |
| `StartMenuSceneTestRunner.gd` | Scene-driven main menu |
| `GameStateCoordinatorTestRunner.gd` | Game state transitions |
| `GameHUDSceneTestRunner.gd` | Scene-driven HUD |
| `EventRouletteSceneTestRunner.gd` | Event scene wiring |
| `RestorePlanTestRunner.gd` | Restore planning |
| `SettingsPanelSceneTestRunner.gd` | Settings scene wiring |
| `SettingsAndResultTestRunner.gd` | Persisted HUD settings and results |
| `EndToEndContinueMainTestRunner.gd` | Save/continue through Main |

Static menu, HUD, event, settings, and preview scenes are required resources;
obsolete code-generated fallback UIs have been retired. The active chamber
control buttons still use `GameHudView.gd`.
The manually maintained `.tscn` files are the only source of scene layout;
obsolete one-shot scene overwriting scripts were removed.

Full guide: [docs/TESTING.md](docs/TESTING.md)

## Development Setup / 开发环境

Open `project.godot` with **Godot 4.7** in the editor.

```powershell
# Headless check examples:
<godot_console> --headless --path . --script res://scripts/tests/SmokeTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/IntegrationTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/LayoutSanityTestRunner.gd
```

Release packaging: [docs/RELEASE_PROCESS.md](docs/RELEASE_PROCESS.md)

## Roadmap / 路线图

Current direction: visual & audio polish, mobile layout verification, performance baselines.  
当前方向：素材与音效接入、移动端布局验证、性能基线归档。

See [docs/ROADMAP.md](docs/ROADMAP.md)

## License / 许可

[MIT License](LICENSE)
