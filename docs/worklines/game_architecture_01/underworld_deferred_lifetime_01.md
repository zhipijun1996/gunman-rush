# UNDERWORLD-DEFERRED-LIFETIME-01：延迟表现安装生命周期缺陷

这是独立原缺陷修复，`small_fix`、`formal_impact=true`；不是保持行为不变的目录重构。[质量卡](../../quality/records/UNDERWORLD-DEFERRED-LIFETIME-01.json)记录原main2ce基线、595374候选基点与两个文件SHA。候选已应用为WIP，原wrapper有限原生已过，非作者独审限定接受，工作流in_progress。

原入口直接把Node传入延迟的typed `install_item`。节点在队列执行前释放时，参数转换先失败，函数内部validity检查来不及执行。候选沿现有入口保存节点及world的WeakRef，在下一延迟时机确认节点存活、当前world身份与归属，再调用原installer；同步setup、既有材质和当前存活节点的延迟顺序保留。不增加全局注册表，不改任何美术、声音、物理、碰撞、伤害、奖励、随机或存档。

[基线attempt01](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/baseline-01/report.json)出现3条UID/autoload导入错误，probe未执行，不能当复现结果。[attempt02](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/baseline-02/report.json)使用精确2ce生产源码及同一优化editor，实际App/TerrainStudy新增后同帧释放；新诊断probe完成且exit0，但原日志有**319条**相同deferred Object参数转换ERROR，因此结果是失败。source_clean_after=true；此319与另一次共享quality回归的317错误不是同一运行，不互相替代。

写集只限`game/presentation/world/underworld_plains/underworld_presentation.gd`与原`tests/underworld_plains/test_underworld_formal.gd`。候选保原formal检查并追加8项：真实formal late sprite仍延迟取得原材质、释放节点不进入typed installer、foreign/moved节点不安装、旧排队context不能污染新world、新world正常安装、world与子节点释放安全。实际原命令`python3 tools/run_underworld_formal_tests.py`、Harness150秒/原wrapper120秒预算不变，实际11.549秒内原formal96+新增8=104/0、原cache444/0，strict clean；[运行原件](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/native-01/report.json)保冻结source8及两任务结果，本任务只引用其中两文件和formal/cache范围。

归档author candidate.json包含另一个Bell phase_transition测试候选的元数据，原件不篡改；该测试及其独立patch明确属于CI-BOSS-CONSUMERS-01，不在本任务源码向量或通过范围。最终源码提交归属与独立诊断probe重跑未在此声明；原formal/cache有限通过不等于全量验收；full182、实际导出、GUI/设备及用户验收未签。

实现依赖为GAME-ARCH-CI-01；CI-BOSS-CONSUMERS-01只是发现该原缺陷的检查路径，并非代码依赖。[最终独审原件](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/review/underworld-deferred-lifecycle-independent-review.json)分别接受两个patch，本卡只采用生命周期两文件及104/cache444部分。全局formal、G4、full182、实际导出和GUI/设备仍未验。

提交及同probe补记：两文件已独立提交`a6714757ed59aa698027669ed2f11d8f346d4a93`，[Git blob核对](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/commit-binding/underworld-deferred-lifetime-01-commit-binding.json)与原候选SHA相同。原`71a613…`探针在该生产源加测试WIP下再次执行，5.615秒、exit0、ERROR0，见[修复后原件](../../evidence/game_architecture_02/underworld-deferred-lifetime-01/after-probe/report.json)；精确2ce同probe原319 ERROR保留。此为同字节诊断前后支持，不是原fullsuite，也不追改旧运行的WIP来源或签全量。
