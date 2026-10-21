# V15专项消费者：原始成功、失败与后续只读复审

本目录是历史原件的可携带副本，不是新一轮运行、整区准入、默认晋升或发布验收。打包未调用引擎或测试，未修改生产/工具/测试/素材；所有build原件保留。

[manifest.json](manifest.json)逐项记录原路径、复制路径、字节数和完整SHA256；[report.json](report.json)列每次真实状态、帧数、最低HP及来源范围。8个`capture.zip`各含未经修改的完整原始`capture.json`：总原始116732750字节、ZIP4318205字节；均已重新读出全部字节，核对原件SHA与ZIP成员CRC。它们不是抽帧或删字段摘要，包含原Manifest、继承参考、全部轨迹与事件；没有额外复制独立参考Manifest。

| 原运行目录的简名 | 真实结果与本目录范围 |
| --- | --- |
| [support-fast-first](support-fast-first/receipt.json) | 原普通fast单消费者PASS，map1 hollow00，28段/最低HP5；不是完整16/80矩阵。 |
| [formal-first](formal-first/receipt.json) | 原生26段后`edge_tick_budget/26/ecology_start`失败，wrapper也失败。 |
| [formal-second](formal-second/receipt.json) | 原生28段、2293帧、0failures，但原wrapper的recipe版本检查失败。原receipt仍`passed:false`；后来只读修正reader并重放完整原capture，独审限定接受，不冒称重新运行wrapper成功。 |
| [lift-first](lift-first/receipt.json) | 原生29段0failures，但seed/recipe前缀不适用该lift对比，wrapper失败；不能作有效lift证据。 |
| [lift-second](lift-second/receipt.json) | 合格hollow02/map2的真实alive_lift专项PASS，22段/1836帧，**最低HP4**；不是无伤，也不是完整F07策略比较或整区准入。 |
| [entry-first](entry-first/receipt.json) | 目标被前段通用Grove提前击杀，随后entry_wait在第21段align耗尽预算；原生失败。 |
| [entry-second](entry-second/receipt.json) | 第19段落在错误`hollow__belly_entry`支撑，原生失败；尚未完成entry_wait实验。 |
| [crossbranch-first](crossbranch-first/receipt.json) | `candidate_actual_two_R_failed_destination`原生失败，不签crossbranch机制或路线。 |

每个运行子目录保留原始receipt、import.log、native.log和完整capture ZIP。原wrapper未另存完整外层stderr的情况，不以新编的错误日志补造；失败/通过仍以原receipt及原生capture/log交叉读取。

[ownership-independent/review.md](ownership-independent/review.md)与[report.json](ownership-independent/report.json)保留独立源级所有权/比较前置检查和完整实际ecology capture的离线复审，连同原审计代码、测试日志、attempt history及当时真实归档的`reviewed-source`副本（GDScript以`.gd.source.txt`后缀保存完全相同字节，避免证据目录成为新的运行脚本）。[entry-reservation-freeze](entry-reservation-freeze/freeze-and-review.json)保留目标预留修复冻结；[recipe-reader-freeze](recipe-reader-freeze/freeze-and-offline-replay.json)保留v15 recipe reader修复后的离线重放声明。

源的因果范围必须分开：各原receipt的`source_before/source_after`等SHA清单是各次实际执行当时的来源权威；后续reviewed-source只是该次独审真正归档的五文件快照，不代表完整1374文件运行源码包，也不倒签前面失败执行。未归档的历史源码没有从当前生产重建，更没有因当前源后来改变而重签旧通过。源冻结/哈希/离线reader接受都不等于新原生成功、设备或玩家认可。
