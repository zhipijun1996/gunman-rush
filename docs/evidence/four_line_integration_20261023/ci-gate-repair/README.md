# CI 门禁修复与准确来源

用户质疑门禁效率后，先停止重复长 CI。原 [54573 的 run39959074418](https://github.com/zhipijun1996/gunman-rush/actions/runs/39959074418) 实际97通过、1失败、44未执行；Harness1771.956秒后才遇到2.655秒的 Python 缺件失败。其 [原报告](ci-54573/report.json.gz)、[失败日志](ci-54573/plains-encounter-policy.log)和[API归属](ci-54573/identity.json)保留，不能改签为通过。

两项问题均有实际修复：

- `9fb476593d70e18ccb5bdaba7644ddca1f91c4fa` 只补当前便携恢复工具单测实际读取的两个输入，合977249B；原24方法、setup、wrapper及原生验证未改。真实稀疏Git恢复两原件、无关历史不物化；[独审](inputs/independent-review.json)限定ACCEPT。canonical原输入23、production loop115、boundary24通过，原来源在 `canonical-9fb`。
- `17cd85f8692179f0c7f9ab53b3b3d88f4ca1f95b` 前置明确选中的无引擎原24单测；仅精确full142采用原物理双通道和原合流器，局部保持原检查。控制台摘要、完整计划保留；最终affected不提前绿。验收指针在同run可重跑，原失败诊断按attempt保留。原Harness／profiles／environment.yml／检查预算不改。[结构独审](gate-independent-review.json)与[实际采纳独审](adoption-17cd-review.json)限定ACCEPT。

精确17cd的canonical planner21/0、原 `python3 -S` boundary24/0、原sourceguards与[官方固定Actionlint校验](canonical-17cd/actionlint.json)通过；见 `canonical-17cd` 原件。候选另实跑75组最终gate状态，仅2种合法状态成功；既有11项lane反例保留并通过。Artifact重跑选择为本地实际YAML名称模型，3个旧错误反例拒绝；不是GitHub已经实际rerun。

原v1候选及实际故障发现保留在 `gate-v1`，最终仅采用 `gate-v2` 的workflow（SHA e4ed776b26bc92a3ed7757bc0439bd70c8cbdca1330293f5eeec56460421cd02）及原已审其余3实现。不能错误复制旧workflow。最终实际源码在Git17cd，旧候选不是当前部署。

[剩余44入口审计](sparse/sparse-final-audit.md)未发现另一项确定的历史文件缺件；它是有限只读消费者审计，不算44项执行通过。默认仍有少量旧版本检查，其本地耗时约一分钟，范围整理另列，不把“旧兼容延期”夸大为所有旧fixture均已退出。

本记录写入时，下一精确head的远端新流程、实际失败重跑、main合并和发布尚未完成；性能也未签。89个parallel检查在旧jobs2下实际span1398.77秒、duration合1963.35秒；新lane遵守原jobs1，还需计输入物化与prepare／collect成本，不承诺耗时减半。纯链接历史媒体的约1.864GB输入机会仍只是已审计的下一项改进，未实现。

[原件索引](proof-index.json)保存路径、原始／归档SHA。大JSON确定gzip无损压缩并核解压SHA；每份报告保留其真实commit或候选覆盖来源，不把计划、前置、部分通道及本地演练当作完整CI。最新可玩的a074开发包、游戏源及其生成56项Foundry仍沿用[原准确身份](../final-synchronization/preview-a074-delivered.md)。CI routing配置为工程元数据，没有批量修改游戏内容。
