# Queen18第三升降织网：独立局部机制审查

FOREST-DEPTH-02；审查者forest_ecology_review。只读Queen18-gap-angle冻结source/raw/log及其17/16历史，不改审查源，不占engine。没有实际正常速度电影，不签玩家趣味/音画/设备。此前我参与的是Guardian替代咨询；没有提出/选择Queen当前升降第三网，不把两者来源混为自产方案。

**局部决定：CONTINUE。** 第三带已真实改变旧侧枝驻留风险，并保留宽中枝的普通恢复；第三实体结作为可借又可反向射断的同一目标形成一次有后果的路线选择。该范围足以进入完整战斗/学习节奏取证。**不是Queen完整Boss接受，也没有接受某个最终学习HP数字。** Queen16最强安全无H619tick的旧REVISE不被本probe冲销；新内容尚未同条件自然全战比较。

## 原件与来源

- snapshot：`build/forest_depth/snapshots/queen18-gap-angle`。
- 原capture/native.log/receipt：其`build/forest_depth/queen/round18-gap-angle/`。capture SHA`c9c620a22fac9f8bad2312bdfbe46b22afffec16acaaa971cc89e09540deabf3`符合summary。
- outer import8.1838s/exit0、rising局部native2.5708s/exit0；21断言0失败，source_guard真。不是本审查者新跑。
- 比较17/18完整runtime source inventory，只变`tests/thorn_queen_sweep_runner.gd`。Queen Encounter/band/Definition/tres以及H实现/tres全相同。17的旧近结截获2fail原件保留，18改起钩位不改变捕获半径或H免伤。
- 本次新的`read-only-audit.py`与`raw-audit.json`只独立重算已有878帧，不冒充native或Godot验证。

## 真实压力与全身体

第三网由(200,570)到(888,585)，preview1.2s、grow.65s；成熟后45px/s上下180px往返。对每帧用记录age/growth重新计算两个实际端点，全878帧中所有已生成第三网数据与Definition一致，没有静态位置/阶段标签替代移动。

另用独立Python凸包＋分离轴检查：上一/本帧6px半厚条带的实际interval hull，Minkowski扩展Player12×18，再检查玩家前后中心线段。只在tick526/527相交；526原weave_sweep(field2)与Policy(player,source queen_growing_weave,id queen/weave/2/1/0)同tick真实HP5→4。玩家在(272.805,381.981)侧枝，不是初始出生在网内部。527仍短暂接触，随后真实跳离；没有第二扣血符合原cadence/Policy，但这不是新增iframe拒绝专项。

这证明该新网能压到Queen16旧静态条带没有迫使改变的侧枝驻留点；不证明所有低地/边缘/中枝永射反例已消除。压力探针故意等网、停射，不能拿878tick与任何效率策略比较。

源中_nonSolidReference collision_layer始终0、shape disabled，不推人、不挡弹/H；伤害交原Policy。_danger_polygon用于伤害与draw_colored_polygon是同一polygon，旋/升段包含上下帧strip的可见凸包。**仅源码确认判定与绘制共用，未看新像素/正常速度电影，不能签视觉可读性或精确人类容错。** 此处凸包就是声明的本帧攻击区域，不伪称连续旋转矩形的精确瞬时边界。

## 普通恢复与宽中枝

526受伤后正常jump23tick、向下普通枪R，于600附近回中枝(446.159,341.967)，HP保持4。到tick785第三age9.85达到preview+grow+完整8秒运动周期；观察序列确实经过最低→最高→返回最低，没有只看一段位置差假称完整往返。

中枝top360、宽300（x300..600），实测身体底约359.967；第三带最高中心线左端390、半厚6，全带最低危险y≥384，整个身体有至少约24px垂直净余量。不是用玩家中心离线距离代替全身安全。恢复利用普通跳/一次R，未要求第二能力，未凭空补HP。

这是合理安全恢复面；全战是否可常驻此面向所有巢位连射，仍是应保留的最强后继反例，不能为证明H强行删掉宽中枝。

## 第三结而非近目标截获

18先正常走到枝缝并下降到takeoff(615.160,352.759)，829排H；838真实capture记录actual_hook_target_contact：target_name QueenWeaveKnot2、position(720,260)、point(708,272)，随后hook_pull。846真实Policy target queen/weave_knot/2从2扣到1；旧结0/1未代替此结果。

853进入kick、860free，Player从接触约(691.883,297.303)到(667.883,273.303)，仍原每轴24来侧弹离。861反向普通枪aim(0.96893,-0.24733)使角色向左下反冲；862同Policy target queen/weave_knot/2从1到0，并同tick weave_severed field2。没有用“按了H/请求射击”冒充命中，也没有为了保锚取消H正常伤害。

878实际落中枝(505.668,341.925)，结死/网停、HP4。第三网停止age11.133不再推进，局部路线有“借同一结→剪同一结→回岸”的因果。它是可舍弃路线选择，不应未来改成必须按顺序清全部结的谜题锁。

## restore年龄相位：已证与未证

probe完成第三一整周期后取真实combat_snapshot，再same-instance restore；代码校验schema10、来源几何、分阶段/路径与field health/state，band以原age/growth/initial_angle/pulse/remaining damage interval恢复，rising方向由age确定，_refresh不重开preview。

原native断言valid snapshot和age精确恢复通过；逐帧年龄连续且端点满足年龄公式：784age9.833左端569.25，785age9.85左端570，786age9.866左端569.25，方向自然换回上行，无重长/年龄归零。基于原断言＋source＋连续raw，可接受该局部same-instance相位保留。

**限度：** capture未单列restore调用前/后完整saved JSON事件；因此不把这一片签成跨实例/fresh App重装/断电保存或全网络所有状态恢复通过。正式App restore由root另有真实消费者验证，不能用这里的字段存在替代。

## 允许继续与下一轮拒绝门

可以进入**合理学习HP下的真实完整三阶段战斗取证**，但24HP只是作者提出的候选，不在本接受范围；需由完整普通伤害/最快合理策略判断是否给学习和输出留有真实决策，而非加血迫玩家等到标签3。仍保留合法最快击杀，不限制射击，不人为满能/回血、延命或强制三个结都借。

至少下一轮保留：自然H借/反向剪、正常切而不借、保持网只普通换层、最强中枝边缘走射/旧619tick安全解的合理新内容驾驶；同初态资源/真实Body/接近相位，用完整自然战和正常速度电影审查。不能用“新网在旧驻点伤一次”直接宣布这些替代已失败。角色可用普通法安全赢不必删除；要看是否在相同风险/机会/恢复下严格支配H路径。

如果完整战仍可长期同一中枝/地面射击而不需读三网、第三阶段只在Boss即将死亡时生成、或目的法每轮都重复一个固定借结剪结脚本，则仍REVISE，必要时DROP此Boss身份而保留合格机关。新升降网不可借缩预告、改身体/无敌/射程或强迫损血制造必要性。

当前仅局部压力、普通恢复与第三同结借剪CONTINUE；**whole battle尚未验、完整三阶段尚未独立接受、学习HP未定、正式地图2/Boss准入未成立，正常影片/音频/玩家与设备未验。**
