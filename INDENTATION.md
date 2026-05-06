# GDScript 缩进审计 / Indentation Audit

日期: 2026-05-06

## 正式规则

1. 新增 `.gd` 文件统一使用 `TAB`
2. 新增 `scripts/tests/*.gd` 统一使用 `TAB`
3. 新增 `scripts/tools/*.gd` 统一使用 `TAB`
4. 修改旧文件时，保持该文件原有缩进风格
5. 不在功能修改里夹带全文件格式化
6. 如果要统一全项目缩进，必须单独开一次“格式化版本”

重点：
- 旧文件原本是 `SPACE`，继续用 `SPACE`
- 旧文件原本是 `TAB`，继续用 `TAB`
- 不要在同一个文件里混用

## 为什么不在 `.editorconfig` 里强制 tab

当前项目是历史混合风格，不是全仓统一 `TAB`。

如果在 `.editorconfig` 里写：

```ini
[*.gd]
indent_style = tab
```

那么编辑旧的 `SPACE` 文件时，很容易把新行写成 `TAB`，导致：
- `Could not preload resource script`
- `Parse Error`
- `Cannot resolve class`

因此当前策略是：
- `.editorconfig` 只保留保守的编码/尾空格/换行规则
- 缩进风格依赖本文件历史风格
- 真正的检查交给审计工具

## 当前 `.editorconfig` 期望

```ini
root = true

[*.gd]
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = true

[*.md]
indent_style = space
indent_size = 2
charset = utf-8
insert_final_newline = true
trim_trailing_whitespace = false
```

## 审计工具

路径：
- `scripts/tools/audit_gd_indentation.py`

用途：
1. 扫描所有 `.gd` 文件
2. 统计 leading tab 行数
3. 统计 leading space 行数
4. 统计 mixed 行数
5. 输出 suspicious files

运行方式：

```powershell
python scripts/tools/audit_gd_indentation.py
```

也可以指定子目录：

```powershell
python scripts/tools/audit_gd_indentation.py scripts
```

## 结果解释

输出示例：

```text
scripts/Main.gd                 SPACE  tab=0    space=520 mixed=0
scripts/TestFixtures.gd         TAB    tab=183  space=0   mixed=0
scripts/Turret.gd               MIXED  tab=12   space=220 mixed=0
```

注意：
- `mixed=0` 不代表整个项目统一
- 它只代表“单行前导缩进里没有同时 tab+space”
- 真正要看的是：每个文件内部主要风格是否一致

## 重构时怎么用

在做中大型重构前后，至少做一次：

```powershell
python scripts/tools/audit_gd_indentation.py
```

建议在这些场景必跑：
- 新增多个 `.gd` 文件后
- 批量修改 `Main.gd` / `ControlChamber.gd` / `Turret.gd` 后
- Agent 大量补测试后

## 现阶段结论

- 这个项目允许“仓库级混合”，不允许“单文件混合”
- 新增重构文件统一 `TAB`
- 旧文件保留原风格
- 缩进治理靠审计，不靠全仓强推格式化
