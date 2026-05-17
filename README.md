# BallWar / 领土战争 (Marble Dominion Ricochet War)

A **Godot 4.6 + GDScript** 2D territory-control arcade prototype — four factions fight for grid dominance in a chaotic bullet arena.  
一个基于 **Godot 4.6 + GDScript** 的 2D 四阵营领土争夺街机原型，四个阵营在混乱的子弹战场中争夺网格领地。

**Engine:** Godot 4.6 · **Language:** GDScript · **Tests:** 10 runners · GitHub Actions CI · **Platforms:** Windows / Android

## Try It / 试玩下载

> **v2.1.11.1 (Latest Stable / 最新稳定版)** — [Windows zip](https://github.com/2002yy/BallWar/releases/tag/v2.1.11.1) · [Android APK](https://github.com/2002yy/BallWar/releases/tag/v2.1.11.1)  
> All releases / 所有版本: [github.com/2002yy/BallWar/releases](https://github.com/2002yy/BallWar/releases)

## Screenshots / 截图

| 开始界面 / Start Menu | 游戏初始 / Game Start |
|:--:|:--:|
| ![](screenshots/%E5%BC%80%E5%A7%8B%E7%95%8C%E9%9D%A2.png) | ![](screenshots/%E6%B8%B8%E6%88%8F%E5%88%9D%E5%A7%8B.png) |

| 游戏中场 / Mid Game | 事件画面 / Event Roulette |
|:--:|:--:|
| ![](screenshots/%E6%B8%B8%E6%88%8F%E4%B8%AD%E5%9C%BA.png) | ![](screenshots/%E4%BA%8B%E4%BB%B6%E7%94%BB%E9%9D%A2.png) |

| 一方胜利结果 / Victory Screen |
|:--:|
| ![](screenshots/%E4%B8%80%E6%96%B9%E8%83%9C%E5%88%A9%E7%BB%93%E6%9E%9C.png) |

## Tech Highlights / 技术亮点

**Engineering & test discipline / 工程与测试：**
- **10 headless CI runners** — smoke, scene wiring, coordinator, integration, layout tests run in parallel via GitHub Actions / 10 个测试脚本通过 GitHub Actions 并行运行
- **Architecture layering** — `Main.gd` orchestration extracted into dedicated coordinators, restore planners, and save adapters / Main.gd 编排职责拆分为专用协调器、恢复规划器和保存适配器
- **Save/load with hardening** — slot-based saves, backup recovery, version checks, and centralized input sanitization / 存档系统加固：多槽位存档、备份恢复、版本校验与集中式数据清洗
- **Performance probes** — bullet-pressure tracking, frame-time monitor, trail-cache dirtying metrics baked into the runtime / 子弹压力追踪、帧时间监控、弹道缓存脏标记
- **Android export pipeline** — ETC2/ASTC texture validation, debug APK packaging, PowerShell check/fix scripts / ETC2/ASTC 纹理压缩验证、debug APK 打包、检查/修复脚本

**Gameplay systems / 玩法系统：**
- **Chamber-driven firing rhythm** — control chamber accumulates marbles through multiplier gates; pending-count drives burst density and reload pacing / 控制仓弹球积累经过倍率门决定开火密度与节奏
- **Four-faction territory control** — simultaneous battle royale on a shared grid; bullets repaint cells and can hit enemy turrets directly / 四阵营同时争夺共享网格，子弹改写格子并可命中敌方炮台
- **Event roulette** — dynamic in-game events with faction-biased weighting, signal-bridge banner system / 动态事件系统，带阵营偏好的加权抽取和信号桥横幅
- **Multi-mode rules engine** — `basic`, `occupation`, `timed`, `wild` each with unique win conditions and event intervals / 四种模式各有独立的胜负条件和事件节奏

## 当前状态 / Current Status

- Current public line / 当前公开主线: `v2.1.x`
- Latest Stable release / 最新稳定版: `v2.1.11.1`
- Previous stable milestone / 前一稳定里程碑: `v2.1.11`
- Stable structural baseline / 稳定结构基线: `v2.1.4`

版本语义 / Version meaning:

- `v2.1.11.1` 是当前推荐下载版本，对应 GitHub Releases 的 **Latest Stable**。
- `v2.1.11` 是公开仓库收口的稳定里程碑。
- `v2.1.10` 是安全加固、性能优化和开始菜单 UI 改进的稳定里程碑。
- `v2.1.4` 是恢复链路、职责边界和结构收口最明确的结构基线。
- `v0.1.0-mvp` 只作为历史补录，保留项目起点，不作为推荐下载版本。

## Release 分层 / Release Layers

- **Latest Stable / 最新稳定版**: `v2.1.11.1`
  - Windows zip, Android debug APK, source archives / Windows 压缩包、Android 调试 APK、源码
- **Milestone Releases / 里程碑版本**: `v2.1.10`, `v2.1.9`, `v2.1.8`, `v2.1.4`, `v2.0.3`
  - important checkpoints for review and comparison / 重要检查点，不作为默认下载
- **Historical Releases / 历史版本**: `v1.9.x`, `v0.1.0-mvp`
  - reconstructed history, not the recommended download path / 重建的历史记录，非推荐下载路径

## 核心玩法 / Core Loop

- 四个阵营在中心网格战场上争夺领地
- 每个阵营拥有一个角落炮台和一个控制仓
- 控制球经过倍率口和发射口，决定待发射数量与释放节奏
- 子弹进入战场后会改写格子归属，也可能命中敌方炮台
- 支持 `basic`、`occupation`、`timed`、`wild` 等模式
- 事件转盘、设置面板、结算页、存档槽和继续游戏链路已接入主流程

## 运行方式 / Running

推荐使用 Godot 4.6 打开仓库根目录下的 `project.godot`。  
Open `project.godot` with Godot 4.6 in the editor.

For headless checks, replace `<godot_console>` with your local Godot console executable.  
Headless 检查（将 `<godot_console>` 替换为本地 Godot 控制台程序路径）:

```powershell
<godot_console> --headless --path . --script res://scripts/tests/SmokeTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/SaveFlowControllerTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/IntegrationTestRunner.gd
<godot_console> --headless --path . --script res://scripts/tests/LayoutSanityTestRunner.gd
```

Current verification recorded for / 当前已验证结果 (`v2.1.11.1`):

- Headless project load / Headless 项目加载: OK
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
Root directory keeps only the entry point and runtime-essential files; all stage notes, design docs, test matrices, handoff cards, and performance appendices live under `docs/`.

## 文档入口 / Documentation

| 文档 | 作用 |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | 精简版本历史主线 / release reading spine |
| [ROADMAP.md](ROADMAP.md) | 当前方向、已完成、下一步 |
| [docs/history/README.md](docs/history/README.md) | 历史阶段索引 / history index |
| [docs/technical/README_TEST_MATRIX.md](docs/technical/README_TEST_MATRIX.md) | 测试矩阵和推荐运行顺序 / test matrix |
| [docs/technical/TECHNICAL_GUIDE.md](docs/technical/TECHNICAL_GUIDE.md) | 工程边界、编辑器协作、导出与验证说明 / technical guide |
| [docs/technical/AI_HANDOFF_CURRENT.md](docs/technical/AI_HANDOFF_CURRENT.md) | AI / Codex 接管卡片 / AI handoff card |
| [assets/ASSET_SOURCES_AND_LICENSES.md](assets/ASSET_SOURCES_AND_LICENSES.md) | 资源来源、授权与可分发边界 / asset licenses |

## 版本脉络 / Version Spine

- `v2.1.11.1`: Latest Stable, UI hotfix — control chamber gate label clipping fix / 当前稳定版：控制仓门文字裁切热修复
- `v2.1.11`: encoding recovery, Android export fix, build pipeline stabilization, public repository hardening / 编码恢复、Android 导出修复、构建流水线稳定、公开仓库收口
- `v2.1.10`: save security hardening, hot-path performance optimization, StartMenu clarity / 存档安全加固、热路径性能优化、开始菜单改进
- `v2.1.9`: settings system, result panel, round statistics / 设置系统、结算面板、对局统计
- `v2.1.8`: decor-layer event model, chamber-state extraction, StartMenu polish / 装饰层事件化、控制仓状态外提、开始菜单打磨
- `v2.1.4`: restore interfaces, continue flow split, `Main.gd` orchestration cleanup / 恢复接口、继续流程拆分、Main.gd 编排清理
- `v2.0.3`: test infrastructure baseline / 测试基础设施基线
- `v1.9.x`: event, performance, save/restore, and UI history / 事件、性能、存档/恢复和 UI 历史
- `v0.1.0-mvp`: historical founding prototype / 创始原型

Detailed stage notes live in [docs/history/](docs/history/README.md).  
详细阶段记录见 [docs/history/](docs/history/README.md)。

## Android 导出 / Android Export

Android export requires ETC2/ASTC texture compression to be enabled in `project.godot`:  
Android 导出需要在 `project.godot` 中启用 ETC2/ASTC 纹理压缩：

```ini
[rendering]
textures/vram_compression/import_etc2_astc=true
```

Additional checklist and scripts / 更多检查和脚本:

- [docs/technical/README_ANDROID_EXPORT.md](docs/technical/README_ANDROID_EXPORT.md) — export troubleshooting / 导出排错
- `tools/check_android_export_config.ps1` — pre-flight check / 导出前检查
- `tools/fix_android_export_config.ps1` — auto-fix script / 自动修复脚本

The current public APK is a debug build. Treat it as a trial package, not a signed store/release package.  
当前公开 APK 为 debug 构建，仅作试玩用途。

## License / 许可

This repository is released under the [MIT License](LICENSE).  
本仓库使用 [MIT 许可证](LICENSE)。
