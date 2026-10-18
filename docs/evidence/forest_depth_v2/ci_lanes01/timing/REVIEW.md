# 原60分钟core风险盘点

**结论：存在具体、显著超时风险，不能据已有证据承诺60分钟完成。** 未运行native/浏览器、未改任何Git／预算／流程。当前pending36里18serial并非已执行；新7项只证明其定向成功，不是full profile。

0cf前49命令合2138.968s，wall2569.618s，差430.650s。df3f新7项commands=95.000s、wall=257.517s（含实际原Harness快照/准备等），不可拿94.999误当257.517的完整耗时。

原host matrix455.910 + scene264.498 + encounter442.294 =1162.702s，仅这三个历史剩余样本加前缀wall已3732.320s（62.205min）；尚未加其余serial、新7、art、后置上传和core前置安装。本次所有已测剩余样本相加的情景下：
`2569.618 + 1304.306 = 3873.924s = 64.565min`，而19项缺测及新增开销仍未加。

这是跨源/机器的实测情景，不是数学证明当前必超；但快慢波动和剩余缺测使盲推60分钟没有安全依据。不能用timeout上限/weight_seconds冒实测，不假设cache复用，也不因为jobs1就忽略各次快照的wall。旧0ed手动60矩阵case合360.584s与原host wrapper455.910s分开，后者才是这里引用的整命令时间。当前matrix已转bee冻结fixture，需restore/import/证据转移，455.910不能称其当前实测。

| pending检查 | 实测秒 | 身份/范围 |
|---|---:|---|
| environment | 未证 | unverified；缺当前/历史可用实测 |
| level-design-runtime | 未证 | unverified；缺当前/历史可用实测 |
| level-design-golden | 未证 | unverified；缺当前/历史可用实测 |
| level-formal-runtime | 未证 | unverified；缺当前/历史可用实测 |
| plains-autonomy-golden | 未证 | unverified；缺当前/历史可用实测 |
| plains-redesign-spatial | 未证 | unverified；缺当前/历史可用实测 |
| plains-experience-golden | 未证 | unverified；缺当前/历史可用实测 |
| plains-encounter-policy | 442.29381572000057 | historical full original600s wrapper；whole05 exact before/after source inventories; not enclosing Git label |
| plains-redesign-scene | 264.498 | historical full original900s wrapper；8103190 + recorded3 dirty test/owner files |
| terrain-family-tests | 未证 | unverified；缺当前/历史可用实测 |
| forest-h-slice | 未证 | unverified；缺当前/历史可用实测 |
| forest-ecology | 3.279 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-progression | 1.706 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-campaign | 7.887 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-debug | 8.247 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-traversal | 12.224 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-region-matrix | 455.91 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-formal-combat | 12.789 | historical original host command; not current runtime/wrapper timing；0ed19bb2f9b50b5fcc191ded67b077b81b1fadea |
| forest-depth-campaign-guardian | 12.916 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-campaign-queen | 12.767 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-ecology-expedition | 24.626 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-root-entry | 9.56 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-crossbranch-lifecycle | 10.973 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-queen-canopy | 11.6 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| forest-depth-campaign-canopy | 12.558 | actual current targeted command；df3f162ac7c49f0bcdfe56c3d4093a3f49d289aa |
| art-art | 未证 | unverified；缺当前/历史可用实测 |
| art-painterly_pack | 未证 | unverified；缺当前/历史可用实测 |
| art-plains_v3 | 未证 | unverified；缺当前/历史可用实测 |
| art-meadow_enemy_art | 未证 | unverified；缺当前/历史可用实测 |
| art-plains_ground_art | 未证 | unverified；缺当前/历史可用实测 |
| art-windkeeper_art | 未证 | unverified；缺当前/历史可用实测 |
| art-plains_spatial_art | 未证 | unverified；缺当前/历史可用实测 |
| art-plains_item_art | 未证 | unverified；缺当前/历史可用实测 |
| web-resource-contract-tests | 未证 | unverified；缺当前/历史可用实测 |
| runtime-raw-export-tests | 未证 | unverified；缺当前/历史可用实测 |
| asset-family-tests | 0.472 | historical Harness command；cda8c30ed375a97a53de27d8348a79f137199427 |

精确argv、预算、证据路径和来源见TIMINGS.json；raw-durations.json保留本次读到的Harness样本。仅core两个check-cache有可验证旧结果，不能填补以上pending；CDA完整CI在首serial level-design-runtime失败，后续未跑，不能用其51pass去补剩余serial。

## Canopy换版与旧消费者静态范围

- 已知真实失配是tools/run_forest_depth_campaign_boss.py旧line132；已由df3f读者迁移并在新7项真实通过，不能重新称未修。
- tests/forest_campaign_runner.gd:11/70–72、tests/forest_progression_debug_runner.gd:11/27–29明确要求实际Canopy scene/resource与v10，无旧S admission硬编码。它们尚未在这个CI被执行；不得因静态匹配签pass。
- tests/forest_ecology_runner.gd:201/237显式实例化thorn_guardian/thorn_queen旧独立fixture，验证旧基础敌/Boss，不读取current默认Queen；不是要改成Canopy的隐含缺陷。forest-progression只消费campaign/生命周期。
- forest-region-matrix与forest-formal-combat已由原profiles明确tools/run_forest_v1_regressions.py冻结bee原断言/原argv，不应因新Canopy改其断言；其结果仅v1。forest-traversal默认不带--region-matrix，只跑旧短H黄金，不假称新两图可达。
- 本次没有在其余旧plain/art消费者找到必须因Canopy必然失配的具体行；无运行不能保证其parser/资源退出/源指纹兼容。不能为推测失败改旧检查。

本报告仅帮调度决策：未建议或实施增加cap、减少check、拆分假fullapproval或变更已测结果。最终完整core仍需实际同源执行。
