# CI-CURRENT-01 验证收据

基线为 PR124 合入后的 main `bd86237456c7ce12a352b040857b208bdede7f66`。测试运行在仅补齐 VisualFixture 可空 boss 字段的工作树上，不宣称当时 Git clean；生产代码未改。原始日志和 Harness 报告在 [证据归档](verification.zip)，来源与完整 SHA 在 [receipt.json](receipt.json)。

| 验证 | 实际结果 |
| --- | --- |
| 原失败重现 | 新 main 原测试访问缺少的 boss 字段，原 runner 严格报 SCRIPT ERROR；before.log 保留 |
| 修复后原单项 | 27 断言/0 失败，原60秒预算与断言不变 |
| 原故意失败模式 | 28断言/1个故意失败、进程退出1；无 SCRIPT ERROR，negative-02.log |
| 原 generated-consumers Harness | 全26套通过，总161.372秒；使用原检查/预算，未删或跳过任何套件 |

第一次本地负例诊断脚本误填预期断言数量，negative.log 原件保留；后继按正例实测数量验证，没有修改游戏或原runner使诊断通过。

只读独审确认真实装配均由 GeneratedDemoStage/PlainsRegionStage 安装该 visual，宿主继承 DemoStage 的 nullable boss 字段；未发现需要保留“没有该字段”的实际运行宿主。本批选择补齐测试契约，无需在生产逻辑中宽泛吞掉装配错误。此审查不签新 Pressure Boss 全部奖励显示相位。

PR124原CI与森林超时失败仍保留，完整169项并未在本轮通过。当前/历史/实验的分类和已核重复执行见 [CI清单](../../worklines/ci_current_01/ci_inventory.md)。本批尚未修改workflow、profile或部署网页。

最终只读独审由结构审计工作线完成，结论 ACCEPT 限于这两行 fixture 修复。审查者核对当前测试源码、归档及7个成员SHA、原失败/正例/负例、26套顺序/预算/成功标记与严格日志；确认生产代码和原runner/profile无改动。审查者未自行运行引擎，不代签完整169、森林超时、Pressure奖励门控、GUI或设备体验。
