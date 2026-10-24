# 当前状态

## 2026-10-24 当前试玩反馈修复

main `cd4989a6`已合入四线；[当前公开试玩](https://zhipijun1996.github.io/gunman-rush/?build=72c47d59bc4f)实际包`72c47d59bc4f`已核完整PCK和真实标题→平原。旧自动Release的工坊音频生命周期失败保留，快速试玩不把该失败改为通过。

当前工作线`fix/main-playtest-feedback-20261024`处理[用户五项实际反馈](worklines/playtest_feedback_20261024/scope.md)：Web HiDPI像素放大、普通HUD固定边缘、所有怪物共享受击而死亡独立、原arms工坊3种Lv1选择、标题开始进入Home。运行实现/定向验证正在收口；此处不把原公开包写成本轮新源码，也不把软件GPU结果签为用户设备。

本轮共享引用候选为style-v11/creative-v14，仅DemoApp/HomeScene两项技术消费者更新，原34项/画风/Bible与旧v10/v13原件保留。下面四线集成段落是前轮实际来源；当前实现与新试玩是否完成以本轮交接/精确Git及实际部署记录为准。

## 四线集成与当前验证（2026-10-23）

人物b106976、怪物080ac505、UI ea2d6fd及美术02031d7已接入集成分支；黄金切片68bd037暂停，不在本轮合入范围。
正式默认新版Courier；家园“织时匠”保留服务id和位置，可在当前会话切换新／经典外观，刷新后默认新版。
家园、平原／Boss、森林／Boss已接入用户提供的五首原MP3；功能接入不等于听感、手感、审美或设备认可。

当前共享画风为style-v10，区域方向为creative-v13；原Bible、像素规范和历史版本保持原件。
当前性能修复源码为`421eacc19a838723aabe898af4565435958735b6`，第二阶段仅改UnderworldForeground；它不在36项style引用中，无需再改画风版本。
保留真实每帧渲染、保护与准入；诊断惰性生成的等价性按实际helper／shader／原GPU结果记录，不推断其他生命周期或玩法通过。

原森林80项结果：精确421eacc1原Harness fresh通过，80/80、source_stable=true；Harness总461.667秒，原检查451.045/600秒，实际CPU亲和[0,1]。
后续原35项结果：精确421eacc1的原35项fresh全部通过，Harness总644.359秒，jobs=1；使用本机原允许CPU集合，不能与双核80混为同一性能条件。
最终源码／CI身份与状态：运行源421eacc1；本次收口仅追加证据和文档，精确head、CI、main及发布状态以PR106／Actions为准。

a2f7远端run40011980788真实失败：106项通过，森林原600秒预算耗尽时68/80，35项未执行；parallel89仅证明该通道。
本地单例耗时和旧精确80收据保持各自源码，不签当前完整CI、GitHub耗时或品质认可；原断言、场景和预算不变。
最终Integration、main Release与新公开版本以[PR106](https://github.com/zhipijun1996/gunman-rush/pull/106)及其Actions实际收据为准；本地通过不代表已合main或已发布。

## 当前公开试玩

[四线开发Preview](https://zhipijun1996.github.io/gunman-rush-previews/previews/FOUR-LINE-INTEGRATION-01/a074a709ffa64c1382d73d2dab6dcff673222728/d38c8a407473/)
producer为`a074a709ffa64c1382d73d2dab6dcff673222728`，build为`d38c8a407473`，包含原工具生成并逐项核实的56项Foundry输出。
它不含本轮CPU修复，也不是main正式发布；[准确构建、公开验证与恢复证据](evidence/four_line_integration_20261023/final-synchronization/preview-a074-delivered.md)保留原身份。
主站本轮未复核；开发Preview不证明主站当前源码／内容。

## 范围与后续入口

当前任务为[FOUR-LINE-INTEGRATION-01质量记录](quality/records/FOUR-LINE-INTEGRATION-01.json)；作者卡的review／未验结论继续有效。
用户已授权普通合入PR106；先核PR/head状态，原142 CI完整通过才普通合main；若已合入则核原Release，不重复合并或重启已有检查。
审美、趣味、真人时长、完整浏览器旅程、五曲听感与实体设备仍按原证据边界，不能由AI代签G5。
用户已明确暂不考虑旧存档／旧特性兼容；当前保存、物理、能力、随机Manifest与资源引用守门保留，手动历史未跑不记通过。

[集成范围与来源](integration/four_lines_20261023.md) · [原始／失败／独审证据](evidence/four_line_integration_20261023/README.md) · [前景CPU证据](evidence/four_line_integration_20261023/foreground-cpu/README.md)
[生产入口](cloud_production.md) · [Harness](harness.md) · [任务](tasks.md) · [下一步交接](handoff.md)

历史正文完整原字节见[本页旧快照](archive/integration_closeout_20261023/current_state.before-second-cpu.source)及[旧交接快照](archive/integration_closeout_20261023/handoff.before-second-cpu.source)。
这些快照与各原证据保留旧源码／SHA及失败；旧“最新”、排期和下一命令不作为当前指令。
