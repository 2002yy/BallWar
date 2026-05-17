# BallWar / 领土战争 (Marble Dominion Ricochet War)

A **Godot 4.6 + GDScript** 2D territory-control arcade prototype — four factions fight for grid dominance in a chaotic bullet arena.

四个阵营通过角落炮台发射子弹争夺中心网格地图，控制仓的弹球积累决定开火节奏。支持基础、占领、限时、狂野四种模式。

**Engine:** Godot 4.6 · **Language:** GDScript · **Tests:** 972 checks (6 runners) · **Platforms:** Windows / Android · **CI:** GitHub Actions [`.github/workflows/test.yml`](.github/workflows/test.yml)

## Try It / 试玩下载

> **v2.1.11 (Latest Stable)** — [Windows zip](https://github.com/2002yy/BallWar/releases/tag/v2.1.11) · [Android APK](https://github.com/2002yy/BallWar/releases/tag/v2.1.11)  
> All releases: [github.com/2002yy/BallWar/releases](https://github.com/2002yy/BallWar/releases)

## Screenshots

| 开始界面 | 游戏初始 |
|:--:|:--:|
| ![](screenshots/%E5%BC%80%E5%A7%8B%E7%95%8C%E9%9D%A2.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E5%88%9D%E5%A7%8B.png) |

| 游戏中场 | 事件画面 |
|:--:|:--:|
| ![](screenshots/%E6%B8%B8%E6%88%8F%E4%B8%AD%E5%9C%BA.png) | ![](screenshots/%E4%BA%8B%E4%BB%B6%E7%94%BB%E9%9D%A2.png) |

| 一方胜利结果 |
|:--:|
| ![](screenshots/%E4%B8%80%E6%96%B9%E8%83%9C%E5%88%A9%E7%BB%93%E6%9E%9C.png) |

## Tech Highlights / 技术亮点

**Engineering & test discipline:**
- **972 headless CI checks** — 10 GDScript test runners (smoke, scene wiring, coordinator, integration, layout) run in parallel via GitHub Actions
- **Architecture layering** — `Main.gd` orchestration extracted into dedicated coordinators, restore planners, and save adapters with single-responsibility boundaries
- **Save/load with security hardening** — encrypted slots, input sanitization via centralized codec, restore-plan seams isolated from scene runtime
- **Performance probes** — bullet-pressure tracking, frame-time monitor, trail-cache dirtying metrics baked into the runtime; separate benchmark suite for regression detection
- **Android export pipeline** — ETC2/ASTC texture validation, debug APK packaging, PowerShell check/fix scripts

**Gameplay systems:**
- **Chamber-driven firing rhythm** — control chamber accumulates marbles through multiplier gates; pending-count drives burst density and reload pacing
- **Four-faction territory control** — simultaneous battle royale on a shared grid; bullets repaint cells and can hit enemy turrets directly
- **Event roulette** — dynamic in-game events with faction-biased weighting, signal-bridge banner system, and save-state import/export
- **Multi-mode rules engine** — `basic`, `occupation`, `timed`, `wild` each with their own win conditions, event intervals, and scoring logic

## 当前状态 / Current Status

- Current public line: `v2.1.x`
- Latest Stable release: `v2.1.11`
- Previous stable milestone: `v2.1.10`
- Stable structural baseline: `v2.1.4`

版本语义 / Version meaning:

- `v2.1.11` 是当前推荐下载版本，对应 GitHub Releases 的 **Latest Stable**。
- `v2.1.10` 是安全加固、性能优化和开始菜单 UI 改进的稳定里程碑。
- `v2.1.4` 是恢复链路、职责边界和结构收口最明确的结构基线。
- `v0.1.0-mvp` 只作为历史补录，保留项目起点，不作为推荐下载版本。

## Release 分层 / Release Layers

- Latest Stable: `v2.1.11`
  - Windows zip, Android debug APK, source archives
- Milestone Releases: `v2.1.10`, `v2.1.9`, `v2.1.8`, `v2.1.4`, `v2.0.3`
  - important checkpoints for review and comparison
- Historical Releases: `v1.9.x`, `v0.1.0-mvp`
  - reconstructed history, not the recommended download path

## 核心玩法 / Core Loop

- 四个阵营在中心网格战场上争夺领地
- 每个阵营拥有一个角落炮台和一个控制仓
- 控制球经过倍率口和发射口，决定待发射数量与释放节奏
- 子弹进入战场后会改写格子归属，也可能命中敌方炮台
- 支持 `basic`、`occupation`、`timed`、`wild` 等模式
- 事件转盘、设置面板、结算页、存档槽和继续游戏链路已接入主流程

## 运行方式 / Running

推荐使用 Godot 4.6 打开仓库根目录下的 `project.godot`。  
For headless checks, replace `<godot_console>` with your local Godot console executable.

```powershell
<godot_console> --headless --path . --script res://scripts/tests/SmokeTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/SaveFlowControllerTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/IntegrationTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/LayoutSanityTestRunner.gd
```

Current verification recorded for `v2.1.11`:

- Headless project load: OK
- `SmokeTestRunner.gd`: PASS (218 checks)
- `SaveFlowControllerTestRunner.gd`: PASS (190 checks)
- `StartMenuSceneTestRunner.gd`: PASS (55 checks)
- `IntegrationTestRunner.gd`: PASS (133 checks)
- `LayoutSanityTestRunner.gd`: PASS (376 checks)

## 项目结构 / Project Structure

```text
BallWar/
├─ assets/                     # 图片、UI、素材资源与授权记录
├─ docs/
│  ├─ history/                 # 历史阶段记录 README_v*.md
│  ├─ technical/               # 测试矩阵、工程协作、导出说明、AI 交接
│  ├─ design/                  # 美术/UI/音效/素材规划文档
│  └─ performance/             # 性能基线与历史性能附录
├─ scenes/                     # Godot 场景
├─ screenshots/                # 仓库展示截图
├─ scripts/                    # 核心 GDScript 与测试脚本
├─ tools/                      # 导出/检查辅助脚本
├─ CHANGELOG.md                # 精简版本主线
├─ LICENSE
├─ README.md                   # 项目入口
├─ ROADMAP.md                  # 当前方向
├─ export_presets.cfg
└─ project.godot
```

根目录只保留外部入口和运行必需文件；阶段记录、设计文档、测试矩阵、技术交接和性能附录都在 `docs/` 下分层维护。

## 文档入口 / Documentation

| 文档 | 作用 |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | 精简版本历史主线 / release reading spine |
| [ROADMAP.md](ROADMAP.md) | 当前方向、已完成、下一步 |
| [docs/history/README.md](docs/history/README.md) | 历史阶段索引 |
| [docs/technical/README_TEST_MATRIX.md](docs/technical/README_TEST_MATRIX.md) | 测试矩阵和推荐运行顺序 |
| [docs/technical/TECHNICAL_GUIDE.md](docs/technical/TECHNICAL_GUIDE.md) | 工程边界、编辑器协作、导出与验证说明 |
| [docs/technical/AI_HANDOFF_CURRENT.md](docs/technical/AI_HANDOFF_CURRENT.md) | AI / Codex 接管卡片 |
| [assets/ASSET_SOURCES_AND_LICENSES.md](assets/ASSET_SOURCES_AND_LICENSES.md) | 资源来源、授权与可分发边界 |

## 版本脉络 / Version Spine

- `v2.1.11`: Latest Stable, encoding recovery, Android export fix, build pipeline stabilization, public repository hardening
- `v2.1.10`: save security hardening, hot-path performance optimization, StartMenu clarity
- `v2.1.9`: settings system, result panel, round statistics
- `v2.1.8`: decor-layer event model, chamber-state extraction, StartMenu polish
- `v2.1.4`: restore interfaces, continue flow split, `Main.gd` orchestration cleanup
- `v2.0.3`: test infrastructure baseline
- `v1.9.x`: event, performance, save/restore, and UI history
- `v0.1.0-mvp`: historical founding prototype

Detailed stage notes live in [docs/history/](docs/history/README.md).

## Android 导出 / Android Export

Android export requires ETC2/ASTC texture compression to be enabled:

```ini
[rendering]
textures/vram_compression/import_etc2_astc=true
```

Additional checklist and scripts:

- [docs/technical/README_ANDROID_EXPORT.md](docs/technical/README_ANDROID_EXPORT.md)
- `tools/check_android_export_config.ps1`
- `tools/fix_android_export_config.ps1`

The current public APK is a debug build. Treat it as a trial package, not a signed store/release package.

## License

This repository is released under the [MIT License](LICENSE).
