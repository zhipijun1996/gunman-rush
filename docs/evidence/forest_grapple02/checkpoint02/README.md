# 纵向主干与正式路线：中间检查点 02

本包只整理已经终态的真实原件，不运行新验证，不代表完整地区准入。源码仍以 `6c61faadd511c48a267b975550da897e701fd09f` 加各次实际输入库存/工作区改动识别，不能只凭共同 HEAD 将不同运行当同源。原始目录名里的 `final` 是当时命名，不是最终验收。

## 实际结果分账

| 原运行 | 实际结果与边界 |
| --- | --- |
| targeted_harness01 | 原报告 `interrupted`，全仓源变化守门失败；终端打印 grapple-feel failed。不能将已执行的原生局部结果当整轮通过 |
| targeted_harness02 | grapple-feel、aim-save-compat 通过；forest-vertical-shortcut 外层完成标记失败。原报告 whole failed |
| targeted_harness03 | forest-vertical-shortcut 因非 fresh 输出目录提前拒绝；没有新原生通过，whole failed |
| targeted_harness04 | shortcut、air-chain、versions 通过；region 固定80首次在第8例 Seed02/图1/change_mind 失败，whole failed；不是六项或完整 profile 通过 |
| change_mind_fix01 | 同 Seed02/图1/change_mind 单例通过，source_stable=true。修复选择点合同不回填 Harness04，也不代表80全过 |
| air18_final01 | 请求18、实际18完整按预期通过、源稳定。7项目的打法加11项删除/普通策略对照，包含 recoil_hook_recoil。对照通过指实际观察到预期拒绝，不是18条成功主路；仍只是局部黄金 |
| matrix16_final01 | 请求16，只执行10：前9通过，第10 Seed00/图2/growth 真实候选H未命中并拒绝，余6未执行。完整16仍失败 |
| north_side_ring_fix01 | 修旧北庭环位后，同图2/growth 仍在 leg26/align 预算耗尽，whole failed；真实玩家末状态在 north_court 支撑上、HP5。NPC回程与新接收枝冲突的诊断/修复不能当这次通过 |
| canopy_rhr_trial | 与基线前905 tick 实际字段相同；第906 tick 真实第二R将1枪变0。基线916受1伤、试验无该伤并在959落稳；但试验 reader 拒绝 local_geometry/program 非当前 factory，outer failed，即使 native exit0。只是有据的开发假设，不是整合准入 |
| migrant_clearance01 | 接收枝让出迁徙NPC回程后，同图2/growth 仍 whole failed：leg28/candidate_return_clear_live_body 预算耗尽。作者记录 RHR冠叉978落稳、14次NPC往返及leg26活H/R到奖已发生；这些局部进展不能冒领完整返程。旧 upper_spiral 接收枝截住返程，后续 return_via/drop_through 修复在本包截止时未验 |

## 当前空间合同与未完成项

当前主干仍是七段纵向核心，冠叉按真实 seed/旧奖励分支有 HH、RH、RHR 候选，不是所有图都强制RHR。RHR针对同一实际落点/敌人相位的接近角和资源取舍，不能用H/R计数本身证明趣味；需保留原普通策略与受伤对照。接收枝裁切属于正式场地几何变化，旧18黄金、旧影片及试验pair不能直接签裁切后的正式出返。

当前16/80代表矩阵、完整 gameplay/art、冻结源 CI、Web/Windows/发布均未由本包完成。初见可读性、正常速度整片独审、真人手感、触屏/手柄实体设备与商业品质仍未验；父任务 QueenH/密度等缺口不由本包关闭。所有失败、源变化拒绝与外层reader拒绝保留。

## 归档与恢复阅读

[selected-originals.zip](selected-originals.zip) 收录上述原 report/receipt、raw、日志、原库存、Harness四轮报告及可匹配的源文本；[inventory.json](inventory.json) 绑定每个成员及整个ZIP，包内 `ARCHIVE-INVENTORY.json` 也给逐成员SHA256/大小。解包后按成员原路径阅读，不必依赖 ignored build 原件。

[source-custody.json](source-custody.json) 将每次源库存中可精确匹配的文本映射到去重的 `source_blobs/<SHA256>`。只有读取字节与该次记录SHA相同才保存，既包括当时仍相同的工作区文件，也包括先前已核的源blob；不匹配的旧源码没有编造。原 receipt 全输入库存、Harness diff 保留，但库存/差分不等于完整可独立重建的历史项目；本包不声称所有旧环境均可离线复跑。

[movie-index.json](movie-index.json) 保留旧图1/图2正常速影片原路径、大小和SHA，AVI不在包中；其相关原receipt/raw/log保留。影片未在本次完整播放或独审，且不是新裁切/返程修复的最终源录像。原大AVI仍在原build，不因本包生成而删除。无大音频/项目缓存复制。

[package.py](package.py) 是本次真实整理的producer，只读原件、按SHA收文本、压缩并逐成员读回校验，不运行游戏。源码作者、采集者和不同作者审查的身份仍以原件为准；此整理角色不独审自己写的机制，也不代签用户认可。
