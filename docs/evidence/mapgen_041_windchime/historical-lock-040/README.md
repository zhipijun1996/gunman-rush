# 0.4.0 历史锁证据的字节保全迁移

最终候选4df的完整CI在quality检查明确失败：两张历史质量卡的lock证据指向已升级0.4.1的可变运行配置。该失败保留为run41728429398，不追改为通过。

从PR130/head9ba的Git blob提取原0.4.0锁，逐字节SHA256为09c2c213e1d0311a0d8417595201c262d3ab32dca23616b779e30d2ca5dffb62，与两张原卡期望一致。此目录仅开发证据，不进入PCK。当前运行配置仍config/mapgen_candidate.json的原版0.4.1，全部19SDK/module/request/bindings与实际已验Web源相同。

两张原卡字节以.original.json保留；现行索引只把evidence[id=lock].path迁到本目录的固定旧版原件。原sha256、source_commit、content_version、reviewed_commit、production_snapshot、所有门槛/失败与审阅结论均不变。不是把旧卡SHA刷新成新版，也不继承0.4.0的认可给0.4.1。逐项来源与变更在[migration.json](migration.json)。

独立审阅仅认证存储路径迁移、原字节和来源身份；最终修复head仍必须完整179+affected通过。保留正在执行的旧serial结果，不取消、不以本地quality通过代签新head。

[独立审阅](independent-review.md)限定ACCEPT：34项核验、原quality及6个负例通过，不签完整CI或旧失败转绿。为保留原serial，修复另建后继分支/集成PR，从4df接续，不更新仍在运行的PR131分支。
