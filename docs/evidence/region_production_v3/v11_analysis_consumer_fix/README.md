# v11 分析消费者：真实失败、有限适配与防复发

最终full57的level-design-runtime真实失败：正式DemoApp已产生v11 RootBell Manifest，分析器仍只认识v8/9/10，错误文案甚至只写v8/9。原capture、report、receipt、log与Harness失败原件在 original_failure.zip，完整SHA见索引，未覆写为通过。

## 实际数据与最小边界

核对真实同seed旧/新map2 native RunManifest：areas、connections、nodes全同；v11增加root_bell_admission，限定替换单敌sentry为root_bell，加入pattern/escape并将落点y510改508。analyzer只消费拓扑/动作/静接缝及enemy.id/area等设计数据，不模拟敌人行为。schema_comparison_same_seed.json记录实际来源、全部变化。

显式支持常量固定为v8/v9/v10/v11-root-bell-v2，不自动采纳未来字符串。v11有限适配核对admission版本/0或1替换数、RootBell数量、非空身份和唯一lane、formal RunManifest根/stage_generator/generated_layout/enemy_layout版本及同seed/hash实际内容。混配、降级伪标、相关篡改和虚假active-combat scope拒绝；旧v8 sourceSHA专属美术投影不套到v11。

真实Godot JSON roundtrip的替换数可以是1.0，因此有限数值0/1均可，布尔、非整数、非有限值仍拒绝；最终源码对此实际存档数据的schema适配errors=[]。这是数据检查，不把declared physical_facts认证为物理或战斗通过。coherent伪造整套JSON需要原producer哈希/原生重放审查，本模块不提供真实性认证。

## 快测与真实入口

原24测试的全部方法AST原样保留。最终30测试通过，新增明确版本、混配、篡改、scope、缺失/空白身份、重复lane等反例。防复发快测读取真实generator VERSION与RootBell CONTENT_VERSION字面量，核对固定支持集合；实际mock缺当前版本的集合会触发AssertionError及分析REJECT，不是动态放行。

在R1源码f3a33552/d577e8db上已实际运行原 tools/run_level_design_tests.py：exit0且源前后相同，能力41/0、capture166/0、3条assembler策略2552/2552/3895tick，report REVIEW且原生provenance passed。完整新原件在 native_r1_success.zip，782项source projection按原Gitbase+2dirty源码完整重构。该范围明确敌人未实例化，不是RootBell战斗或Boss完成。

实际清理诊断原样保留：capability83对象/60资源、PagedAllocator/4RID；capture2对象/1资源，未签clean生命周期/设备或趣味。

## 独审返工与版本诚实

独立R1审查实际发现 None==None 导致缺失id/area/module误收；原R1源码保留在 rejected_r1_sources。修复非空string及恰好唯一region_connection后，原漏洞和新增blank/duplicate反例均拒绝。identity-only R2源码另存 r2_identity_source_snapshot；随后依据真实1.0字段做一条件类型修正，最终SHA见freeze.json，旧独审/旧native SHA不追改为新版。不同代理的最终复审/类型addendum另行保存。

最终源码对保留真实cap的API分析仍REVIEW3routes；五个实际JSON修改反例均REJECT。原CLI的producer守卫把所有tools/tests也纳入源清单，因此R2消费者变化后分析同一原cap会正确exit1/provenance_mismatch；这次真实拒绝保留，未篡改receipt或降低源守卫。R1实际原入口通过与最终R2数据适配通过明确分开，父任务在全部source/docs冻结后执行最终fresh gate，不能冒称原生曾在新Python SHA上启动。

本包只改两Python文件，无游戏runtime、driver、物理/资源/阈值或原断言修改，无新增图生/原host名额。最终冻结后不再写源，完整原件/源码/diff/单测/真实CLI结果与SHA见本目录。
