# 平原场景原预算调度修复

CI f50真实98通过、1失败、43未执行，整轮失败：[serial身份](ci-f50/identity.json)、[parallel身份](ci-f50/parallel-identity.json)及原压缩报告保留。遭遇专项已通过500.292秒；场景positive两组负载不均，shard0在180.100秒被截止，shard1在158.291秒完成，没有证据证明已完成路线断言失败。[只读定位](ci-f50/scene-timeout-audit.md)保留未完成边界，不将超时改记通过。官方HTTPS镜像本次实际Get已核：[原记录](ci-f50/official-mirror-actual.json)。

实现1dab6cea2ca4a430d0ea901b313d9cbec5963032仅修改两个测试文件的分派／汇总：四组[0,1]、[2,7]、[3,6]、[4,5]共享原180秒，原8条路线主体、输入、10种子corpus、94断言和900秒wrapper不变。legacy与corpus各执行一次，结果恢复0..7顺序；每组身份、唯一完整路线与清理、非零退出／缺标记／超时和source guard均保留或加强。原main／errors与其他函数AST相同，GD逆三谓词逐字还原。[11项小进程控制](candidate/fault-controls.json)仅验证调度拒绝，不是Godot证据。

精确1dab6的[原Harness fresh专项](canonical/report.json.gz)在本地两核affinity下完整通过229.189秒：native八路线129.262秒／180，94断言零失败；10个真实场景反例和15项证据篡改拒绝，原source-before/after一致。[原收据](canonical/receipt.json.gz)、[分片](canonical/positive-partitions.json)及[限定独审](adoption-1dab6-review.json)保留来源。本地结果不等于Cloud时长或完整CI通过。

[逐件恢复SHA](proof-index.json)用于原件追溯。当前游戏源与a074开发Preview相同，不重新标记其producer；下一精确head完整142合流、main合并与Release仍待实际结果。G5审美／手感／趣味及实体设备未由AI代签。
