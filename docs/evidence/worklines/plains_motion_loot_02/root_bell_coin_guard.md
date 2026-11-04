# 根铃物种固定金币 · 限定验收迁移

任务PLAINS-ROOT-BELL-COIN-GUARD-02，只修改两个测试/适配器，不改任何生产字节。来源为a5ff源CI40993924803的真实失败。用户已确认固定金币必掉；当前配置charger=2、root_bell=7，具体金额仍取唯一配置而非测试另造默认值。

原root-bell-spaces的40图对照中，plains-redesign-8/map2由v2冲锋守卫换成v3根铃，仍要求enemy_drops字典全等，已与本轮授权冲突。保原non_ecology_content_drift标签、nodes/connections/rewards逐字相等和原enemy budget，允许的唯一差异是actual.root_bell_admission.id的真实charger→root_bell改变：旧/新金额均核配置，复制原记录仅改amount/coin_total/configured_coin_total/behavior和唯一coin reward，完整期望字典再等于实际；RNG、流位置、概率补给及其余未知字段全保严格相等。预算必须整数，差额只等于这笔物种币差；同物种记录仍要求完整相等。

首版9负例本地通过，却被独审用“整条旧掉落+旧预算联合回退”及小数预算构造出漏放，不能用该技术marker签验收。原源码按当次source_before SHA精确复原，原报告/独审模型证据保留；修订先按真实物种判断，限定charger→root_bell并验证双侧预算TYPE_INT，再增加联合回退/双侧小数到12原生负例。

保原40图/10物理负例/2旧save/3版本replay、Godot60Hz、原native240秒/Harness360秒及原Python六负例；另增原生12掉落反例、Python拒绝缺新反例/伪拒绝共八变异。原生wrapper03真实通过且源前后一致；它是a5ff+这两个未提交guard路径的开发执行，冻结后须逐件比其输入SHA，不虚称原执行Git clean。精确新源独审/完整167仍分别待核，主任务保持review，用户/设备/听感均不在本process卡。

森林80在原600超时的证据单独保留：完成53皆通过，4CPU/4workers；串行多项检查普遍变慢，根因未定，不因本迁移改80/预算/采样/生产性能代码。随后按原计划对新源再跑完整门禁；若复现再profile。
