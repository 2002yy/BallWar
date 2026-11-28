# DEV-SPEED P0

用于在隔离存档中检查战局。正式启动时只运行正常游戏。

## Windows 启动

先用 Godot 4.7.1 导入项目。然后从仓库根目录运行：

```powershell
.\tools\start_dev_speed.ps1 -Godot 'D:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe'
```

每次启动都会在本机 LOCALAPPDATA 下的 BallWar Dev Sessions 创建独立目录。终端会显示目录路径，也可通过 -OutputRoot 指定位置。游戏会核对启动标记和实际 user://，验证失败则在读取存档前退出。

| 操作 | 快捷键 |
|---|---|
| 显示或隐藏面板 | F8 或点击左下角「调试」 |
| 暂停与继续 | F9 |
| 暂停时前进一物理步 | F10，每次相当于 1/60 模拟秒 |
| 1×、2×、5×、10×、20× | 面板按钮，或面板开启时按 1、2、3、4、5 |

面板显示模拟时间、从开局起算的现实耗时、实际/目标倍速与 FPS。现实耗时包含暂停。暂停时实际倍速显示 0。返回菜单、结束战局或新开一局后，速度恢复为 1×。

## 同一模拟时钟

炮台、控制仓、炮弹、事件生效和胜负检查使用同一个 60 Hz 步长。倍率控制只调度每个现实秒执行的 tick 数。事件可在 UI 播放的同时按模拟 tick 生效。胜负读取战场格子数据，HUD 依旧按自身节奏刷新。现实时间只用于测量实际倍速。高倍速下，一帧最多执行的物理步数有上限，界面按实际推进速度显示。

## 复测

以下命令验证隔离、面板开关、20× 调度、暂停、精确一步、继续、重新开局和返回菜单：

```powershell
.\tools\start_dev_speed.ps1 -Godot 'D:\Godot\4.7.1\Godot_v4.7.1-stable_win64_console.exe' -CheckControls
```

Windows Git Bash 下可复用既有探针，只比较同 seed、同画质、同地图和同长度的轨迹：

```bash
export GODOT_BIN=/d/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe
BALLWAR_TEST_SPEED=1 bash scripts/tests/determinism_probe.sh speed1 85
BALLWAR_TEST_SPEED=20 bash scripts/tests/determinism_probe.sh speed20 85
bash scripts/tests/compare_traces.sh path/to/trace_speed1.tsv path/to/trace_speed20.tsv
```

探针在开局后立即记录 tick 0，再切换目标速度。报告末尾的无头耗时受固定帧参数限制，实测倍速以窗口数据为准。

## Windows 真实窗口

Godot 4.7.1，1120×720、限制 60 FPS、RTX 5060 Laptop，40×40 中画质基础局，种子 12345。在每档跑 22 模拟秒。

| 目标 | 现实耗时 | 实际 |
|---:|---:|---:|
| 1× | 21.930 s | 1.003× |
| 2× | 11.035 s | 1.994× |
| 5× | 4.406 s | 4.993× |
| 10× | 2.210 s | 9.953× |
| 20× | 1.112 s | 19.790× |

五档在 tick 0–1320 的模拟摘要一致。85 秒无头对照的五档在 tick 0–5100 一致，首次事件均在 tick 4142 生效。12 个既有 runner 无脚本错误并通过。普通用户目录无隔离启动标记时退出码为 5，测试偏好文件的哈希保持一致。

这些结果基于当前种子和配置。高密度、Android、存档继续和跨机器一致性各有独立验收范围。

## 后续

P1 将在同一物理边界判断目标并自动暂停，优先支持模拟时间、首次发射、弹量、事件、炮塔血量/摧毁、领土与战局结束。P2 的人为构造战况使用独立入口与隔离档，并沿用当前无头探针。
