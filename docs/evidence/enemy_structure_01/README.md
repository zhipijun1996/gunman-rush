# ENEMY-STRUCTURE-01 · 程序重构验证

最新：CI40844941490串行原80路线超时，完整CI未通过；性能候选正在按原标准复验，旧5b通过不改签新代码。详见[性能返工](../../worklines/enemy_structure_01/performance.md)。

运行源 `5b083938ea9f2722fe6c44896914f9d2d198e87b`；原14专项保 `4af16b8e49ecc6ea4ed6cbff957e06fe78fa9833` 来源。完整CI运行40844941490当前仍待结果，本页不签完整166通过或成品质量。

- 当前源：原生结构730断言／39独立case全部通过；原accepted-hit426、实际软件GL裁剪44及身体／弱点像素12全部通过，记录source稳定。
- 原14项：全部fresh、0复用、0失败；core5686，五受伤／留尸专项458／66／199／72／147，森林生态与Boss机制、实际App两场完整战斗、共享地形及原80路线均在原预算内通过。80路线547.301／600秒，整体846.481秒。详细[原收据](targeted14-4af/report.json)与逐项日志保原来源；[字节等价](source-equivalence.json)不改签fresh源。
- [限定源码与测试迁移独审](review/enemy_structure_review_acceptance.md)、[5b源复核](review/enemy_structure_5b_source_appendix.md)及[运行结果观察](review/enemy_structure_runtime_observation_5b.md)分别保范围；新runner作者未自称独立设计验收。

`gpu-and-hit-05`是原隔离fixture：状态冻结、接触粒子隐藏，用于RGB／弱点与裁剪验证。culling在三helper上使用同一probe纹理，不是三种怪的造型；所有PNG是实际Godot输出，未改像素，不是正常速度动画审核。用户旧美术拒绝继续有效。

失败原件：native01的外部Health配置共享（15断言）；旧motion中moth错用charger配方；native04切换后稀疏缺字体；首次CI40843714099旧165清单断言。分别由私有Health配置、真实候选fixture、恢复原输入及保165前缀追加新check修复。原失败不删除，旧motion失败后未产生新result，未把目录中旧708报告当fresh成功。native02／03等开发源与native05当前源均原样保存，不合并统计。

本轮无新图、素材替换、音频制作或验收skills采用；结构通过不代替美术／动作／声音／趣味／用户／设备认可。
