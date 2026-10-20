# W1 正式消费者严格执行原件

运行源2cd7fa05356c1b8e537b624329cbb4ee0b65ef66。原generated driver 33/33、actual exit0、718.627s；原core 5680/0、actual exit0、46.592s。全部原suite和内部上限、script/shader/ObjectDB/resource扫描保留。HomeUI故意失败负例actual exit1，其余28检查先通过。

聚合外层诊断最初额外要求HEAD前后一致，但执行时仅追加7个docs文件，故外层orchestration exit1原回执保留；它不是原driver退出码。补充回执逐Git tree核实所有游戏/资源/测试/工具完全相同，strict_pass按实际driver及严格日志判断。不能把原外层exit1改写为0。

W2后来只修Python静态checker和其反例，不冒签为本W1全部source完全相同；完整新HEAD CI另验。files.json列精选原字节。
