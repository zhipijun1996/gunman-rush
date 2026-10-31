# P8 CI 工具独立审查

审查提交 `5589c284`，基线 `986bb75d`。结论：**暂不接受，两个守门问题待修正**。仅审冻结的 128 个文件，不签周边仍在进行的生产迁移，也未运行 Godot。

- **P8-SCOPE-R1** `tools/level_design.py:348`：Spatial experiment blanket game/world/ and experiments/ prefixes accept mapped DemoLifetime, RunProfile and graybox, whose original scripts/run or scripts/player paths were rejected. No blacklist catches these names. Preserve original protected-core boundary through exact migrated ownership projection. 复现：`p8-spatial-scope-independent-probe.json`。
- **P8-PARSER-R2** `tools/check_web_bundle.py:316`：Valid GDScript single-quoted revisions key yields zero mappings and empty contract, silently skipping raw+remap checks. Current actual registry uses supported double quotes, but unsupported equivalent declaration is not refused. Support a finite grammar or reject unrecognized/empty revision contract. 复现：`p8-recorded-revision-independent-probe.json`。

已独立确认：213 个检查和全部 profiles 不变，所有非 inputs 字段逐项相同；有效 1124 条迁移映射对应 120072 条原输入依赖全部保留；原 183 个 core 文件无遗漏；冻结 128 文件 SHA 一致。旧 Python 测试方法全部保留，715→728，旧方法的断言调用数无减少；这项语法检查不能代替语义审查。

有限 style_scenery 新 SHA 已独立证明只由精确路径替换造成。打包校验对当前实际双引号 Registry 能读取并校验 PCK 原字节及正常 remap，但不证明 ResourceLoader/Factory 行为。

测试改动说明：`p8-test-change-justification.json`。有效闭包复核：`p8-independent-effective-closure.json`。早期作者 121784 计数属于之前的迁移映射；最终历史路径保留后，本次独立计数为 120072。原失败日志不删；旧 Web 日志仅 49 项，作者待补冻结源 51 项对应日志。


## 修复复核

`d58b72b6` 已闭合上述两项问题，当前结论为**限定静态及 Python 验证接受**。独立运行旧/新空间授权函数，1124 个实际迁移路径中原296允许、828拒绝，结果零差异；双引号和单引号按相同有限合同解析。独立运行 Web-bundle Python 测试52/52通过，包含最终 PCK 原字节、remap、转换目标分别缺失的拒绝反例。日志 `p8-web-bundle-independent-52.log`。仍不签整体目录迁移、Godot 加载、实际导出 ResourceLoader 或渲染。
