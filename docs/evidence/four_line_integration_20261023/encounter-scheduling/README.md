# 当前采集的原预算调度修复

原CI8ca6的serial通道实际8通过、1超时、44未执行；[parallel原报告](ci-8ca6/parallel-report.json.gz)及[API身份](ci-8ca6/parallel-identity.json)已核89项fresh通过，因此整轮实际97通过、1超时、44未执行，仍失败。[原报告](ci-8ca6/report.json.gz)、[源与Artifact身份](ci-8ca6/identity.json)及[耗时审计](ci-8ca6/timeout-audit.md)保留。整个专项600.053秒截止；奖励14例、native及恢复三份、正式四例与独立重放已完成，最后bait到约573秒才启动，只获得约27秒，不能断言它自身240秒超时或死锁。Artifact须GitHub登录，2026-11-06过期。

实现163ad4f9a4d7341beb468c60ea2fd30cdeeec608只把六个独立当前采集有界双worker调度。原seed、参数、路径、真实独立重放、所有验证／反例、每producer240秒和整项600秒均保留；历史和奖励调度不变。旧16个非main函数与CASES同AST、原26个验证调用保留。[独审](independent-review.json)限定ACCEPT；[六项调度控制](candidate/scheduling-results.json)为小Python进程，不是真实Godot。

精确163ad的原Harness fresh专项在本地两核affinity下真实通过308.524秒：[报告](canonical-163ad/report.json.gz)、[完整原专项收据](canonical-163ad/receipt.json.gz)、[日志](canonical-163ad/plains-encounter-policy.log)。正式四例、独立repeat和非kill bait均真实完成，奖励14例、原验证及source_before==source_after成立。该本地条件不等于GitHub性能或完整CI通过。

另为核实紧邻时限风险，在精确8ca6执行原scene专项，两核affinity下整项227.090秒通过，原native180秒共享预算内实际130.160秒；[原报告](scene-8ca6-two-core/report.json.gz)、[原分片收据](scene-8ca6-two-core/positive-partitions.json)保留，没有改场景或预算。

当前游戏源／资源仍与a074公开Preview一致，后续只是工程验证变更。下一精确head的完整142合流、main合并与Release仍以实际Actions结果为准；本记录不预填成功。[无损归档索引](proof-index.json)逐项记录原始与存储SHA，不重签原来源。APT备选和纯链接Git存在性原型均未采纳。
