# CI-BOSS-CONSUMERS-01：当前Boss测试消费者迁移

测试专属process任务，不修改生产规则。原已审五文件以4e91为候选基点；现工具链merge595374上的八测试脚本及两份test-only fixture仍为WIP，第8非作者独审限定接受；[质量卡](../../quality/records/CI-BOSS-CONSUMERS-01.json)列逐文件实际SHA。此为内容版本变化后的测试迁移，不称原断言等价或P9行为修复；current15有限原生已通过，全局验收仍unverified。

| 变化 | 保留与明确迁移 |
| --- | --- |
| 当前Bell死亡/领奖 | 旧单loot与通用mini爆炸改为真实四个5/5/1/1物理币、已绑定具象死亡、impact/final各一次及无重复通用层；真实App拾取、钱包和重复拒绝，不伪造发币 |
| 共享campaign fixture | 依据Bell/Pressure各自Definition与真实owner时钟有界等待，不直接推进clock；原seven second_map消费者保留，cohesion新复用使整个helper八消费者 |
| V3八来源伤害 | 保原八站位/单发/45帧；固定两底部来源预先声明壳甲负例，真实point/ray/armour恰一次、Health提交零、弹体消费；六上铃仍精确伤害1与一次真实提交 |
| V4 Pressure phase3 | 只等真实intro结束并检查可收伤害；原cap*2/3、await3frames和phase3断言逐字保留。HP20本已≤.34×60=20.4，先前阈值猜测被否定，未改伤害阈值 |

[五文件应用核对](../../evidence/game_architecture_02/ci-boss-consumers-01/review-and-candidates/current-boss-five-final-independent-review.json)由候选作者完成，不能冒充独立审查；真正独立依据为归档的structure V2/V3/V4收据，原native-pending限制原文保留。五个当前源码快照使用`.gd.source`归档，避免历史脚本污染全局类扫描。

[ed95原基线](../../evidence/game_architecture_02/ci-boss-consumers-01/baseline-02/report.json)真实19/5；baseline01仅旧UID/autoload导入失败，没执行测试。拒绝V1手动visual._process、V2 expansion2919/2及V3 region29/2候选、各旧源码和日志原字节保留。V3 expansion2959/0、早先cohesion28/0与campaign3721/0只是其各自直接预检，不转签最终完整套件。

[actual01 ledger](../../evidence/game_architecture_02/ci-boss-consumers-01/wrappers/actual-01/ledger.json)因稀疏缺gdignore而重复ShotEnergyDefinition类，parse失败、断言未达；[actual02 ledger](../../evidence/game_architecture_02/ci-boss-consumers-01/wrappers/actual-02/ledger.json)前9套通过，第10 Energy540/1并报Bellstrider requires BellstriderDefinition而停止。两者完整原日志分开归档，不把导入失败当玩法断言失败，也不把已停止的current15签通过。

第6项Energy已限定修复：沿既有Windkeeper场景与实例副本装配精确历史16HP HealthDefinition，不复制旧Boss算法、不修改当前40HP资源；原540检查、循环与90秒预算保留。实际[540/0报告](../../evidence/game_architecture_02/ci-boss-consumers-01/energy/native-01/report.json)耗时10.701秒、exit0、源码不变；它验证历史闭甲拒伤/不返能，不替代当前Bell专项。

第7项Pressure已显式分类：default保留原两函数的真实App/Camera/Home/Underworld生命周期与原renderer投影检查，实际[444/0报告](../../evidence/game_architecture_02/ci-boss-consumers-01/pressure/native-01/report.json)6.684秒、原90秒预算、clean exit。旧D077 Boss混合组合完整原run保留在`--legacy-d077-boss`手动诊断，明确deferred，既有27条legacy itineraries不包含此组合；default15只是分类后的槽位数，不能称旧15完整断言通过。历史renderer手动投影检查不等于自然调度或GUI验收。

共享消费者[actual01](../../evidence/game_architecture_02/ci-boss-consumers-01/shared/actual-01/report.json)中root-bell-current42.937秒、wood15.820秒通过，但quality-review-engine1044/1及317条Underworld deferred参数错误失败；[actual02](../../evidence/game_architecture_02/ci-boss-consumers-01/shared/actual-02/report.json)中root-bell-spaces50.208秒、terrain15.306秒通过，全部保原命令与预算。失败日志完整归档。第8项quality接触fixture已应用并纳入八脚本向量：保原六模式，当前Bell phase_transition按solid copper接触为true，追加具体Bell类型与dead负例，原inactive检查前恢复neck。原wrapper实际1046/0、14.714秒、原240秒预算且strict clean，见[原件](../../evidence/game_architecture_02/ci-boss-consumers-01/native-01/report.json)。至此五共享消费者各有真实通过运行；前四运行在独立Underworld生产修复前，不能称同一最终源全量。旧1044/1及317错误保留。Underworld生产生命周期修复独立属于UNDERWORLD-DEFERRED-LIFETIME-01，不在本tests-only源码向量。完整current15 actual03已通过，见下方收口范围。

原注册槽位、命令与预算保持；Pressure默认覆盖范围上述显式分类；style27另批inputs变化不能据此声称profiles全文件原字节。默认current15与显式27条legacy itineraries分开，当前套件即使通过也不代表全部历史路径通过。full182、实际导出、GUI/设备仍未验，工作流in_progress。


本阶段最终原wrapper [actual03 ledger](../../evidence/game_architecture_02/ci-boss-consumers-01/wrappers/actual-03/ledger.json)完整通过：15个current槽位加import，总224.151秒/原1500秒；baseline75.042/120，regionBoss31/0、13.026/90。16个原生日志和完整stdout各存一份（本批约160KB），不重复复制缓存或其他运行目录。27条legacy未运行逐项保留；Pressure444的分类范围不能签旧D077完整合同。

八脚本与两test-only fixture仍是595374基点上的WIP；当前HEAD a6714757只独立提交Underworld生命周期修复。实际当前十文件SHA与各阶段原生前已有冻结收据相同；[源码比较收据](../../evidence/game_architecture_02/ci-boss-consumers-01/wrappers/actual-03/post-run-source-comparison.json)明确为运行后核对，不是伪造新的run前snapshot。第8quality1046/0及其独审沿各自真实来源；旧actual01/02、19/5、2919/2、29/2、Energy540/1与shared1044/1、317错误全部保留。

当前15有限技术通过，任务仍in_progress。全局formal、G4、full182、实际导出、GUI和设备未验；最终测试提交身份由root提交后绑定。

提交归属补记：八测试与两test-only fixtures现已独立提交`49a298b40890ccf4d9d2326d051f12a0ffe63c27`，[十个Git blob逐字核对](../../evidence/game_architecture_02/ci-boss-consumers-01/commit-binding/ci-boss-consumers-01-commit-binding.json)均与原WIP冻结SHA一致。前文WIP是运行时事实，未追改原run字段。[最终八源核对](../../evidence/game_architecture_02/ci-boss-consumers-01/commit-binding/current-boss-eight-native-final-binding.json)由部分候选作者完成，仅核应用/运行证据；独立实施批准仍来自structure、ci和items原收据。current15有限通过，不签full182、旧D077、27legacy、全局formal或导出/设备。
