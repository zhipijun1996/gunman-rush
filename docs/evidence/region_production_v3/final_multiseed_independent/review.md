# 原80路线矩阵：独立来源接受，9失败与设计缺口保留

**结论：ACCEPT矩阵来源、完整记录和有界观察；路线设计/策略缺口保持REVIEW。** 审查者`/root/v3_ecology_admission`。本包固定审查原`kill_from_bank_v1`，不由后来v2尝试改变旧71/9；无新Godot或host调用。

## 独立实际核对

[可重跑检查程序](check_actual_matrix.py)与[实际结果](audit_results.json)直接读取原ZIP/capture/receipt/log，未构造新成功fixture。检查全部80例而非只看摘要：10个root×两图×fast/growth/deep/return，组合唯一且完整；每例原始SHA、accepted terminal/exit0、source_before=after=source_files、连续tick，以及全局events与每帧accepted_events完整多重集合逐项相等。真正失败策略依然是被正确捕获的失败，不因capture accepted变成路线通过。

全部初始与末尾能力均为单PulseLv1、单跳、实际授予jump/shot_recoil；未把implemented但未授予的H/W/D当通路依据。记录数据证明该有限配置和实际驾驶方式，不外推全部单武器构筑。

从6个真实Git commit逐blob重新计算每份声明source projection，全部798项精确相同。**这是798项运行脚本/JSON等投影，不是1072项正常电影/全部美术纹理闭包**。字典独立compact JSON digest与原摘要的不同空白序列化digest不混用；实际逐字段和Git内容相等。[实际读过遭遇源码绑定](reviewed_encounter_source_binding.json)从实际原Git重建并核对冻结投影；当前driver已进入独立v2返工，当前字节与冻结字节分别记录，不追认新driver或后续metadata/export修改。

原先磁盘OSError28原日志仍在原ZIP，恢复是26完整已验回执复用+54新原生，不能称80个新进程。全部80日志/回执来源完整，记录退出错误不等于生命周期通过。手动40audit缺before不由本审查补签严格G1，需其后真正fresh wrapper。

## 成功与失败实际分布

71个到驾驶目标：fast20、growth20、deep15、return16。9个均在map2可选高收益探索策略。目标不是Boss通关或完整campaign；这不是真人成功率，更不是趣味分。71例也有伤害：最低HP分别5有31例、4有27例、3有9例、2有2例、1有2例，达到目标不代表普通玩家节奏/公平已通过。

20张不同实际Manifest中**Root Bell为0**，因此80矩阵不能充作新敌人的地图覆盖；Root自己的默认15case/正常电影独立保留。

| root后缀 | map/策略 | 失败tick | 地点/原因 | 终态事实 |
| --- | --- | --- | --- | --- |
| /01 | 2/deep | 2612 | deep_region_top，bank unsafe/no damage progress | x2697.627,y-910.075，HP5，diverHP3/idle/serial0 |
| /03 | 2/deep、return | 各931 | deep_high_ferry，unsafe recoil bank | x-130,y-1100.026，HP5，能量66，diver未开始攻击 |
| /05 | 2/deep、return | 各951 | 同上 | x-130,y-910.026，HP5，能量90.5，diver未开始攻击 |
| /08 | 2/deep、return | 各1014 | 同上 | x-130,y-1100.026，HP5，能量100，diver未开始攻击 |
| /09 | 2/deep、return | 各960 | 同上 | x-130,y-910.026，HP5，能量95，diver未开始攻击 |

每个失败的last frame、aborted edge、邻近AI终态、目标策略记录与模块Manifest都在audit_results.json，不靠重复一句泛泛“地图有问题”。

## 优先问题与可证伪返工

**P1 / 自动驾驶有限搜索不足候选。** `kill_from_bank`只试±16/32/48/64；`plains_ferry_two`首静态岸local[0,950,180,40]，对应deep_high offset x=-150，入口角色x=-130距左缘仅20。实际Pulse地面反冲84.7，完整身体半宽还需支撑；面对右上diver，+64候选可能仍无足够向左反冲余量，更往岸内的+80/+96可能有合法站位。这是静态几何和实际原失败定位支持的有限策略盲点，不是已经证实新的动作链能过，也不能删除安全guard直接射击。

返工交驾驶器而非Motor：保持原v1和全部安全规则，独立opt-in候选扩大有限支持搜索；用相同Seed/原source、正式输入与资源、邻敌/相位/出返验证，并比较HP。无真实改善就保留失败并撤回候选。父任务正在另包尝试；本报告不预签其成功。

**P1 / 旧ferry联合遭遇风险。** 当前生成可在同一摆渡放diver与fan_sentry，前者威胁穿越/落点，后者限制站位；首岸先观察、可读预告、反冲瞄准余量和上船窗口需一起设计。生成中的不与slab/patrol_box交叠只证明局部几何，不能证明实际联合逃生。8例保守驾驶在敌未激活、满血时停下，不证明无解；也不能反过来把所有问题都当误报。

**P2 / 诊断语义失真。** /01的`kill_bank_enter`与abort同为tick2612，未发生900tick久战；目标仍HP3/idle/serial0，只有一条进入银行记录。代码最初用归一化aim投影retreat.x检查，开枪前又用完整水平±84.7检查，可能立即break而走到笼统“no damage progress within budget”。应区分“选位失败/反冲支撑拒绝/实际开火未命中/真正超时”，保留真实帧和判断原因；不能凭笼统文本断言玩家已战斗很久。

## 两个额外非击杀尝试并未修复9失败

实际bait seed01在更早的area_1_0→area_2_0被area_2_0攻击命中，HP4、tick2074失败，尚未证明原region_top可过。seed03推进更远，但deep_high tick1111确有`ferry_air_intercept_contact`伤害，最后又被area_2_0攻击命中，HP3、tick3293失败。它支持“原kill策略不是唯一进路”的线索，却没有给出无伤/公平完成证据。两者完整伤害event_id/source/帧与路线列于audit_results.json，不能清空后宣称修复。

最终需用专业遭遇审查检查观察岸、diver俯冲扫掠、fan射线、移动甲板等待、奖励与返程；只改driver或只增怪都不能代替联合设计。当前证据不够判地图无解，也不够判所有问题都是策略误报。

本次只作历史固定版本的轨迹/源码审查，没有新像素影片、音频、真机或主观趣味认可；旧9失败和完整退出错误继续保留。
