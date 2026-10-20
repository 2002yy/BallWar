# BallWar Interview Notes

## 一句话介绍

BallWar 是一个 Godot 4.6 四阵营领土争夺原型，重点展示玩法循环、事件系统、存档恢复、性能探针和 headless 自动化测试。

## 技术亮点

- Godot 4.6 + GDScript
- Main orchestration split into controllers and planners
- Save/load hardening with backup recovery and version checks
- Bullet pressure and frame-time performance probes
- 10 headless CI runners, 1083 checks
- Windows / Android release pipeline

## 面试重点

这不是只会做玩法 demo，而是把游戏原型按工程项目维护：架构拆分、测试、CI、导出、性能边界和文档都覆盖。
