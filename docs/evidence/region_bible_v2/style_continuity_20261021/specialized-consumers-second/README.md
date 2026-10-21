# V15专项消费者续包：entry、crossbranch与真实版本兼容

本目录只复制历史原件，不执行引擎/测试/源码重建，不改生产、工具、测试、素材或父目录索引。第一次专项失败仍见前一个[证据包](../specialized-consumers-first/README.md)。

[manifest.json](manifest.json)列原路径、文件大小和完整SHA256；[report.json](report.json)列准确来源与结论。4个轨迹ZIP及1个版本报告ZIP共含7份完整原JSON：原始72129886字节，压缩3411034字节，均逐成员CRC检查并完整回读SHA与原件匹配。没有删轨迹、改Manifest或抽掉原报告中的继承参考。

| 实际原运行 | 原始状态与范围 |
| --- | --- |
| [entry-third](entry-third/receipt.json) | 原生19段/1443帧，`bounded_jump_clearance_timeout/hollow__belly_entry`失败。 |
| [entry-fourth](entry-fourth/receipt.json) | 原生29段/2096帧、最低HP5、0failures；原wrapper因方向向量严格浮点相等而失败，receipt仍`passed:false`。对应独立[数值合同/离线实际轨迹复审](shot-roundoff-independent/report.json)保留原件，不倒签wrapper。 |
| [entry-fifth-unpinned](entry-fifth-unpinned/receipt.json) | 真正不传`--layout`的默认消费者，原生和wrapper均PASS：29段/2096帧、最低HP5，ecology1451→1647。只守原receipt/source指纹，不替换为后来修改的源码。 |
| [crossbranch-second](crossbranch-second/receipt.json) | 真实生成的正式`crossbranch_live_H` PASS：46段/3810帧、最低HP5，ecology2442→3204。不是历史candidate注入，也不代表全部策略比较或整区完成。 |
| [versions-v15-public-first](versions-v15-public-first/receipt.json) | 两个独立原生消费者data→actual App，原327断言/schema6/24cases全部通过；共有90秒native预算、24.204秒实际native、总31.419秒。是运行版本/历史保存兼容验证，**不是整区玩法或全发布**。原data.json、world.json和aggregate capture.json全在同一ZIP，两个原生receipt及data/world/import日志逐字复制。 |

[entry-failure-source-reconstruction/proof.json](entry-failure-source-reconstruction/proof.json)及8份原已保存源码保持：failed-first/second/third与current-fourth，各2文件。打包只核对它们与原proof的完整SHA，不重新运行逆patch。原reconstruct.py也以文本副本保留；`.gd/.py.source.txt`后缀避免证据成为运行脚本。这些有限文件不代表完整历史仓库，尤其不冒充第五次/版本消费者后来未归档的当前源码。

[prefix-freezes](prefix-freezes/freeze-source-proof.json)与[low-branch-freeze](prefix-freezes/low-branch-freeze.json)记录的是当时源候选/有限Python检查，不是实际Motor通过；后面的真实失败和成功各有原生原件，不能把冻结时间倒当运行证据。

来源限制：root已指出原生收据当时的55项单测源含一条坏负例；`source_guard:true`只能说明该次记录来源范围没有漂移，不等于那些单测通过。原before/verifier指纹保留，未用后来的55项修复源重签旧收据，也没有补造坏负例日志。root后来原45项11.611秒结果没有本包所需可携带原日志，**本包没有复制或声称包含该通过**；原7项harness/fixture仍属另一轮验证，也不在本包宣称通过。

所有原件仍留build，本包不签默认晋升、全森林/全策略、用户/设备/FUN或发布验收。
