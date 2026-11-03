# 0.4.1起点钟门开发证据

当前为实施中的阶段原件，不是最终精确head验收。已推送SDK升级提交 `a0089f1cf061bb8397bbae151dfbca6026576525`；实际适配测试来自各自WIP/sourceSHA，原0.4与旧CI失败仍保原身份。未在此签生成风铃完整入口、0.4.1 Web、最终完整CI、main合入或发布。

[范围及授权](../../worklines/mapgen_041_windchime/scope.md) · [阶段结果](../../worklines/mapgen_041_windchime/results.md) · [上游要求与剩余消费者](../../worklines/mapgen_041_windchime/upstream_requirements.md)。

| 原件 | 可复核内容 |
| --- | --- |
| [custody.json](custody.json) | 精选65件原始/派生证据的路径、字节数、SHA256、原件位置；原字节复制，不改原source字段 |
| [原PR130最终失败](original-ci-41679005631/final-run-receipt.json) | head9ba7/run41679005631，126PASS/1FAIL/1在途/50未执行；同目录四job日志和serial原生失败capture |
| [原SDK主工具链验证](native-preliminary/sdk-verify-bundle-01.log) | Godot4.7.2实际执行0.4.1原verify_bundle，success/gears/failure完整结果核对PASS |
| [显式旧版核验](sdk-upgrade/old-040-verify.json)与[升级收据](sdk-upgrade/upgrade-040-to-041.json) | 原0.4.0 23叶/18GD先验；新0.4.1 24叶/19GD受锁安装；旧sdk-upgrade/summary保持当时ENGINE_PENDING原状态，不代替后续真实日志 |
| [Provider35原日志](native-preliminary/provider-native-02.log)与[capture](native-preliminary/windchime_provider.json) | 完整起点语义选择、usedPort准入与负例；首次body-path失败和import错误另存原件 |
| [完整模块夹具100原日志](native-preliminary/windchime-mechanism-native-01.log)与[capture](native-preliminary/windchime_mechanisms.json) | 真实源内容、双向物化、Router/弹丸/门/岸/恢复/取消；仅fixture，不签生成入口或邻居 |
| [gears69身份](native-gears/initial-69/receipt.json)与[后续73原日志](native-gears/restore-73/native.log) | 同次0.4.1/930007真实生成、完整危险/锯齿/双渡台，旧0.4恢复身份拒绝；各自capture分开保留 |
| [音频93原报告](native-preliminary/ambience-report.json) | 原wrapper、source_stable/退出清理；[测试修复说明](ambience-ci-audit/fixture-change.md)保留写成时native-pending，不改签为作者执行 |
| [CI工件41实现收据](ci-inputs/finish-summary.json)、[磁盘诊断后45](ci-disk/summary.json)、[独审41/4/54](review-ci/review.json) | 各自sourceSHA与原日志；实际4.43GB工件循环尚未签，不扩大独审SHA覆盖 |
| [边界只读独审](review-windchime/review.json) | 静态/原件检查，未独立运行Godot/Web；恢复加固及完整入口待验明确列出 |
| [实际0.4.1/930007库存](coverage/actual-041-930007-inventory.json) | 从本目录同次真实result按module/version/role/连接提取，不是运行注册表或40图/整图支持声明 |

所有必要原件先保全于 `/workspace/refactor-evidence/mapgen-041-integration`，上述精选小原件进入源码Git；大PCK、SDKZIP、moduleZIP与recovery tar不放本目录。原0.4 PCK另以SHA可核工件保全，不冒称0.4.1新包。未生成美术或音效，普通出发不变，不部署网站。
