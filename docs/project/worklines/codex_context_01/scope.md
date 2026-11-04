# CODEX-CONTEXT-01 当前交接

目标：轻量项目管理、新内容审查与现行设计读取。进度唯一见 [任务表](../../tasks.md)。

- 分支：`chore/lightweight-project-workflow`；负责人：本会话；[PR135](https://github.com/zhipijun1996/gunman-rush/pull/135) 面向 main。
- 基线：`5ce7db6b2af2e66efe9782ab581f026296aa593a`；实现：`bc1ec87857655377b1a494eb69397f85ebfe7228`。
- 写集：AGENTS、相关Skills、project规范／模板／交接、地区设计与读取元数据、Python工具及测试。游戏运行代码、素材、数值及CI流程未改。
- 结果：普通任务只维护表中一行和一份交接；新内容按需记录美术统一与玩家体验，省略不适用项，删除G1；显式执行器也支持普通任务无卡写入，scope完成不冒称内容品质通过；默认不增加独审审批。旧卡归档，当前7张内容卡共294行。
- 读取：地区任务读取现行圣经及相关对象；原附件只溯源。正常的仓库内设计确认无需上传附件，绑定与来源检查仍有效。
- 验证：实现提交的相关Python回归376项通过（含113项执行协议、41项当前来源保护、6项新增流程回归）；固定四项CI通过。文档、静态质量、默认当前卡扫描、编译与差异检查通过。变动的旧策略断言按已确认的新合同调整，来源／媒体伪造、越界和显式独审反例继续验证。
- 下一动作：审阅PR135的管理口径、读取与记录兼容；合并后更新本行交接并将此议题移出当前工作。源码尚未合并，本轮未发布。
- 未验：本任务未制作或验收游戏新内容，不代签画面、趣味、用户试玩或实体设备。

恢复先运行 `git status --short` 并核分支及SHA。验证入口：`python3 tools/check_docs.py`、`python3 tools/check_quality.py`、`python3 tools/quality.py check`、`python3 tests/test_lightweight_workflow.py`；执行协议回归为 `python3 tests/test_production_loop.py`，日常验证为 `python3 tools/ci.py`。其余专项从模块导航按实际影响选取，完整结果与精确来源见PR。
