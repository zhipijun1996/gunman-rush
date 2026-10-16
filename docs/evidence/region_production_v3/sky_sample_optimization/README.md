# 父性能专项：sky 单采样有限修复

旧共享环境电影762 tick失败原件仍保留。本专项只改 sky softness .45→0 并加入零值单采样路径，ridge .75与正值原五tap不变。不是输入TTL修复、完整游戏或设备性能通过。

原29文件按原SHA/bytes无损归档为 `original_benchmark.zip`，索引 `original_artifact_index.json`；全ZIP CRC/逐文件SHA实际复验。内含三窗12PNG、ABBA原540稳态样本、12warm帧、219代码前快照、基准脚本与日志。源快照只有before，审查时对当前219项逐字节核对相同，不能冒称采集器输出了完整after快照。

GPU中位：钟庭85.08→74.25ms、营地68.32→58.46、树林84.09→75.02，仅当前llvmpipe固定镜头。画面平均绝对差≤.042/255、最大4/255；actual legacy175/0、default181/0。联合shell退出0，首个分进程exit未单独采集，不补造收据。独立像素审查另列，不代用户审美/设备。
