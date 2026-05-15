# Project Principles / 工程原则

## 原则 1：每次重构都要降低耦合、提高安全性、保持向后兼容

这个项目从 `v1.7` 到 `v2.1.x` 的一条稳定趋势，是把高风险的大函数和深层状态写回，逐步拆成更明确的边界与入口。  
When refactoring, prefer smaller responsibilities, clearer seams, and compatibility-friendly transitions.

实践准则：

- 新接口比旧接口更安全，但不要无理由打断已有调用链
- 优先把隐式全局依赖改成显式参数或更清楚的职责边界
- 让新增结构降低未来维护成本，而不是只是换个文件名继续堆逻辑

## 原则 2：新代码出问题，优先检查新边界与新接线

历史上很多回归并不是老系统突然失效，而是新引入的测试脚手架、协调层或恢复路径接线不完整。  
When regressions appear after a change, inspect the new seam first.

实践准则：

- 先查新加文件、新增测试、新增 helper、新增入口
- 再查新旧系统之间的参数、类型、时序、所有权边界
- 不要因为老代码“看起来可疑”就先动已稳定主路径

## 原则 3：可见 UI 优先 `.tscn`，脚本负责逻辑与连接

对人类需要频繁调整的可见界面，优先交给可编辑场景。  
Visible UI that benefits from editor tuning should stay scene-first.

实践准则：

- 新增或迁移 UI 时，优先建立 `.tscn`
- 脚本优先负责 `@onready` 绑定、信号连接、数据刷新和轻量协调
- 不要把大块可见 UI 节点树重新塞回 `_ready()` 动态创建
- 可编辑入口和协作边界要同步写进 `TECHNICAL_GUIDE.md`

## 原则 4：验证结论以真实证据为准，不靠猜测补救

逻辑正确性、性能表现和编辑器可加载性必须分开看。  
Validation should be evidence-driven, not speculation-driven.

实践准则：

- correctness baseline 以 `README_TEST_MATRIX.md` 为准
- performance probe 不等于 correctness proof
- 若 Codex 运行环境崩溃，但没有明确 parse/script 错误，且桌面本地不复现，不要继续靠猜测改生产代码
- 手工验证、headless 验证和静态检查都要如实分开记录

## 原则 5：常驻文档要少，但职责必须清晰

版本历史可以长，常驻真相文档必须短而明确。  
Detailed historical notes are fine; live operational docs should stay few and clear.

实践准则：

- 历史阶段记录保留在 `README_v*.md`
- 当前真相优先收敛到：
  - `README.md`
  - `ROADMAP.md`
  - `README_TEST_MATRIX.md`
  - `TECHNICAL_GUIDE.md`
  - `AI_HANDOFF_CURRENT.md`
  - `CHANGELOG.md`
- 临时过程稿不要长期堆在根目录
