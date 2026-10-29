# CI性能返工（进行中）

原5b完整CI40844941490：并行通道通过；串行75项在forest-depth-region原600秒超时，前17项passed、此项timeout、后57未执行。52条已完成路线均passed，不写成80完成。原请求80／60Hz／逐case240秒／总600秒不改，原proof ZIP与job log保留。CI带准备后的Foundry差异，不称clean5b；原日志未打印有效CPU，不按ubuntu标签推断2核。

本地原4af全部80在547.301秒通过；与旧d91约540相近，不支持把CI慢化全归因新结构。逐条配对CI52条中位耗时为本地的1.649倍。重route24.5MB／3810帧离线parse0.593秒、带profiler校验1.102秒，不能把40余秒都归Python校验。

候选只缓存森林身体的静态影响权重，动态角度／原rotated／原求和顺序保留；提前裁剪仍更新最后身体pose，归零绘制transform后返回，不暂停AI／clock／HP／警告。只读快照的新建字典直接freeze，可选行为容器仍隔离，不做跨帧缓存。

原生数学对照756case／218484vertex字节一致，纯math0.154倍不冒充路线收益。相同本地两CPU affinity重路线39.344→32.735秒（约16.8%），3810帧选定玩法字段及completed_legs一致；不是相同CI硬件。长期差分并入原新结构check，原39case保留＋1cachecase／767数学case／221663vertex，原90＋180秒预算保留。当前候选native733／40case通过，GL44及GL12通过，原15＋4张PNG字节不变；完整80与后继CI仍待实跑。

## 3bc本地完整原80与下一轮调度修正

冻结提交`3bc1759b17a0d06be94ef43f85f2116631437aef`的原forest-depth-region完整80条实际通过；原检查505.552／600秒，Harness总524.939秒、0复用。原报告见`build/verification/harness/20261029T102028.518369Z/report.json`。本地收益不追签CI40844941490，也未证明后继CI已解决。

后继工具修正只读取实际CPU数、affinity和可见cgroup祖先配额，未指定workers时从原1／2／4档选择不超过有效容量的档；显式值继续优先，所有读数不可用回退原4。逐case记录native、JSON读取解析、validate三段wall时间，未进入段为null。原corpus、schedule、80请求／前16顺序、60Hz、import90／native240／总600、全部验证与失败退出不动；非corpus仍串行。本机可见CPU5、affinity5、quota4，因此选4；不推断GitHub实际核数。

原14项scheduler测试原文完整保留，追加13项CPU／真实小进程时序反例；实际27／27通过（1.870秒，无Godot）。独立审查ACCEPT仅限源码与纯Python，另实跑27／27（1.777秒）；[原报告](../../evidence/enemy_structure_01/cpu-scheduler-01/enemy_structure_cpu_scheduler_review.md)。后继完整CI以新原收据为准。
