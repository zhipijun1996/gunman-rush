# GAME-ARCH-ENGINE-01：固定上游回补工具链

独立small_fix，formal_impact=true，依赖GAME-ARCH-CI-01；工作流in_progress。只管理构建、推广、严格安装与后续工具链整合，不把旧官方退出失败混称为游戏等价重构完成。[质量卡](../../quality/records/GAME-ARCH-ENGINE-01.json)记录精确来源及范围。

原始基线2ce；当前整合基点为4e91，工具链尚为WIP。完整当前文件SHA见[整合身份观察](../../evidence/game_architecture_02/engine-toolchain-01/active-main/integration-source-receipt.json)，不能仅用HEAD声称工具源码已提交。构建recipe为184970c7，原十lane run41180438395；promoter为f91a69d0；strict installer独审为62eceec4，Android builder CLI修复为63afcb1b。全SHA在质量卡，不混用这些不同来源的接受结论。

官方4.7.2源加明确PR117991与PR120976形成Standard custom distribution，不是官方原包。原A/B同源正式191项断言虽通过，仍因57 ObjectDB/25资源退出失败；[原ABC结论](../../evidence/game_architecture_02/engine-toolchain-01/history/abc-conclusion.json)及原失败日志保留。诊断C只签当时063d6ccb游戏源与诊断二进制，不能转签优化产物或full182。

[完整产物独审](../../evidence/game_architecture_02/engine-toolchain-01/build/engine-184-complete-artifacts-independent-review.json)核十lane、editor四成员及18模板成员与来源/命令/实际字节。public release429822541，tag toolchain-godot-4.7.2-gunman-sd1，draft=false、prerelease=true；[八公共URL校验](../../evidence/game_architecture_02/engine-toolchain-01/publication/engine-184-public-download-verification.json)均HTTP200且SHA符合。发布源码184与promoter f91不同，[实际推广run41188433036](../../evidence/game_architecture_02/engine-toolchain-01/publication/engine-promotion-41188433036-run.json)与job日志已逐字归档，head为f91、conclusion为success。

当前config.godot逐字段等于公共锁84522f721203e0f58d9be63ceecf2bd51e844e3a57676d0456fbf6bdf9b34604，非Godot配置保持基点原值。实际[安装报告](../../evidence/game_architecture_02/engine-toolchain-01/active-main/setup-report.json)通过，原26 downloader/build/identity与原91 Harness单元通过。这些仅构建/锁/安装/单位范围；原单位日志中的预期失败fixture并未被删。

优化editor的生命周期28、原upstream序列、PREDELETE及4负例有独立来源证据；28契约是经审查修正的新测试契约，不冒称原26全部等价。[既有独立绑定](../../evidence/game_architecture_02/audio-lab-material-01/review/audio-lab-material-native-independent-binding.json)复用原件，不重复归档音频/native大日志。旧本地上传401、ce26实际415、7c false-prerelease静态拒绝必须保留；ce26/7c原件已归档；401为事后转录的真实exec观察，明确不是原始文件或复跑日志。

未复制381MB包、1.5GB源或二进制到repo；只归档小报告、原日志和公开元数据。没有运行新的引擎或发布动作。full182、完整正式native、实际Web/Windows/Android导出及运行、GUI/设备/玩家验收仍未完成；旧局部通过和本卡技术passed均不代表这些范围通过。

当前整合已有[限定独立接受](../../evidence/game_architecture_02/engine-toolchain-01/active-main/active-toolchain-main-integration-independent-review.json)：实际merge parent为63afcb1b，包含已审installer62ec及AndroidCLI后续；本次只是4e91上的未提交工具WIP。独审核当前源码、实际安装字节、公共锁与原26/91日志，未再次运行引擎，不签最终提交、full182或各平台验收。
