# RUN-GEAR-MERGE-05：最终版本、输入与观察守门

用户明确授权将[PR110](https://github.com/zhipijun1996/gunman-rush/pull/110)合main。此目录为合入前修订快照；恢复时先读PR实际状态，若已merged核main及自动构建，不重复合并。完整CI仍须同head两通道及affected全部成功，不以这里的局部结果替代。

## 原失败与修复

完整CI40324535594，head05200fc：serial55项全部成功；parallel73项成功后，`region-bible-tests`的精确style期望13／实际14失败，后15项未运行；整轮失败。[原身份](failed-ci-identity.json)、[失败phase报告](failed-ci-phase-report.json)、[原失败日志](failed-ci-bible.log)。

本地原32测试真实重现1失败：[版本旧断言](bible-version-before.log)。此前只修creative-v17时漏了style14绑定，现同步为精确14，并新增真实旧v13的拒绝。所有36引用／身体闭包／原G2与content阶段门／原历史拒绝均保留；旧v13原件和其他旧版本不改。

继续执行后，本机才暴露未物化v12历史文件（不是错误v13路径已执行）。原输入计划误报ready，原运行FileNotFound保[ae50](history/candidate-ae50.log)与[30bf](history/candidate-30bf.log)。现对已有`region-bible-tests.inputs`仅追加11份实际读取的冻结style文件，所有旧输入保留为原前缀，argv／30秒／regex不变。原工具显式物化v3、v12后[正例ready](inputs-positive.json)；真实隔离Git稀疏索引中v12仍缺且S，原CLI exit2／needs_materialization准确点名该literal input：[反例](sparse-negative.json)、[原调用收据](sparse-negative-receipt.json)。该隔离例仍有其他缺件，只证明worker前缺v12阻断，不冒称完整干净clone闭包。早先shared-clone与输出路径拒绝是基础设施失败，保留在history，不算该负例通过。

随后原尾部15项逐项验证，`forest-bible-reader-tests`原55测试的旧整文件SHA拒绝了已审定的持有统计API迁移：[原失败](reader-before.log)、[原phase](reader-before-report.json)。真实差异只有ecology1处、lift3处`app.build.item_ids()`改`app.build.inventory.item_ids()`；原字段表示持有，BuildState新语义仅已装备。未改变策略、物理或输入。修复保留原两SHA常量，先验精确1／3次数和旧API已撤出，再仅反向归一化这些观察字符串，所有其他字节仍须匹配原SHA；不是刷新指纹或给角色额外装备。

## 准确分源的执行

冻结测试／输入源`56f74fb0918d1cfbd1487a9734403975caf2e85f`，原Harness三个check fresh全部通过：32＋10＋55＝**97项／0失败**。[原报告](contracts/report.json)。不同只读作者在该同源另行执行原97项，exit0、200相关文件及HEAD前后稳定；实际临时副本正例接受、7个额外源变动／观察撤回反例全部拒绝：[独审](independent-review.md)、[机器审查](review.json)、[原执行及反例](reviewer/final56f/receipt.json)。审查未修改生产、测试或工具，不签完整CI／设备／玩家G5。

尾部其余**14项独立原Harness均fresh成功**，源80c3456：[汇总](tail14-summary.json)、[逐项原报告及日志](tail14/)。它们是在此前失败后补跑的独立消费者，不是原失败phase追签；与56f之间只改reader的Python源守门，游戏／资源／录片字节不变。整个尾部未执行美术生产。新fixture和guard的局部通过不等于最新同head完整144项已通过。

最终代码只修改两份Python测试与已有Harness输入清单；核心游戏仍为此前bb4bf46字节。本轮不改物理、装备事务、经济、艺术源或测试预算；设备、玩家与复杂道具效果边界保持。下一步推送当前小修，等待最新精确head完整CI，通过后普通merge，网页发布另核实际自动构建。
