# 精确4df候选的历史锁证据绑定失败

run41728429398的prepare与两个通道的实际大工件恢复成功。parallel实际7PASS/第8项quality FAIL/余85项未开始，0reuse；serial继续执行，未取消，本目录不是serial或整轮最终验收。完整原日志、phase与API摘要收据以原source/run身份保全。

parallel原Git守门已通过：源码前后36220项一致、Git状态/差异为空、工具链相同。严格恢复164.318秒，其中已核4824个Git对象/4,387,487,368字节缓存114.263秒，network_fetch:false。先前422候选初始化Gitdiff超时未重现。

失败是两张0.4.0历史卡的lock证据仍指当前可变config/mapgen_candidate.json，期望旧SHA09c2c...，当前合法升级0.4.1后发生漂移。修复为[旧锁原字节及原卡保全迁移](../historical-lock-040/README.md)，不刷新旧SHA、不更改历史来源/认可，也不改SDK运行文件。新head仍须完整179+affected，旧失败不追改。

ZIP原件保持API digest；.gz为原字节无损存储，raw SHA及长度见[custody](custody.json)。大输入tar留同run远端工件，未放源码Git。
