# W10预案更正：取消无必要重建

先前“AvatarPresentation 必然进入 Foundry basis”的判断错误。实际 `FoundryCatalog.basis()` 只哈希明确列出的文件和指定目录，不遍历脚本的 preload / 类依赖。

- 对 Git `169ef171fee3f70911847fb2c2890351ee3468bb` 与当前 F1 `5182ace20c66b36aa9d6ec6fa38da9791adf2280` 分别展开实际203项输入，路径及内容SHA完全一致。
- 按原排序、`res://path:sha256` 与已记录引擎字符串重新算出的basis均为 `f3e060598385696137aa40910811fcbfed931853fe7f4c9992b11cf1af0263cb`，精确等于原stamp。
- `scripts/art/player_visual_adapter.gd` 是明确输入；`scripts/art/avatar_presentation.gd` 不在清单与递归目录中。前者被哈希不意味着递归哈希后者。
- 当前56份Foundry资源逐字节等于R169原Git blob；template分支的schema、记录引擎与4项配置hash也保持不变。
- 当前Scenery identity测试改动同样不在该203项清单中。

因此取消W10 prepared build/stamp，不执行原先预案，不放宽其中“新basis必须不同”的断言，不改原验收器、资源或W9证据。现存操作计划保留为已撤销预案，应以 `CANCELLED.json` 和本更正为准。尚未执行任何W10 Godot命令。

该结论只证明实际Foundry source-basis输入与现有artifact等值；F1确实改变了该清单外的UI运行代码，不能据此宣称全游戏源码相同或新增native/浏览器/设备验收。

机器报告：`source-equivalence-report.json`；完整输入：`basis_R169_inputs.json`、`basis_current_inputs.json`；重算脚本：`audit_basis_readonly.py`。
