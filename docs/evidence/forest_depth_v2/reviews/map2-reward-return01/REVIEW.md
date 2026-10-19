# Map2 reward-return01：完整成功，但返Boss目的不成立

2026-10-17；`/root/forest_ecology_review`，gameplay-reviewer。只读，没有native、生产或测试修改。本审查未编写新的map2 expedition实现；先前建议过map1奖后R选择回营/继续守卫，并参与B/C出口宏观咨询，披露该关系，不以咨询自动签此map2移植。

## 决定：DROP当前map2 B路线晋级

四组实际strict PASS和R→E活借/双R局部物理都是真的；**不能据此接受当前map2“取奖后快速返Boss”设计**。Queen入口在C，不在E；当前路线让Player从R升324px到E，马上经lower_in下降244px回D，然后重新M→S→C。E没有新增目标、奖励或跨联。R本有直达D边，且同几何旧真实段更短。这是为展示H硬加的绕路，不是有意义的返回目的。

保留R→E局部工具、旧map1正确终点下的证明、四组成功原件；不改写成技术失败。不删既有R→D路救B，不继续为当前B录电影。旧上层强LOW反证及其永久DROP也不因本批通过翻案。新敌种多样性/密度、移除H后区域核心乐趣、玩家/设备/音频/新全片均未完成或未验。

## 原件与技术有限事实

权威冻结`snapshots/lower_map2_expedition01`，原根目录`build/forest_depth/ecology/expedition/lower_map2_expedition01/`：旧map1的`00-alive_lift/01-jump_two_R`，新map2的`map2_expedition/{00-alive_lift,01-jump_two_R}`。父receipt实际63.342秒/4组strict PASS。

独立离线使用冻结reader逐一读四原件，全收；全2035源哈希匹配inventory、source_before==after；每capture连续Motor1。新map2两法在自然R选择前450帧（含完整逐敌位置/health/state/time/depth）及全部真实请求、入口资源exact，见`audit.py/raw-audit.json`。非局部378warmup、不是地图1物理结果直接冒地图2。

从W实际出发，已真实pointer领奖/5帧modal暂停/重复交互幂等，R入口已有18金币、region_health_purple、HP4/E100/2枪。map2 camp_tick=-1、camp对象空，确实没有伪造一个额外camp目的地；**问题是E本身与最终目标之间的物理关系，不是camp标记。**

活借区间451→521=70tick，真Lamp H伤2→1/原kick/一R，E preMotor E85.5（同tickpost86）；最强普通满跳双R451→538=87tick，E pre65.5（post66）。两者HP4，后继最终E均100，不能说到Boss仍保20E收益。7combat是真独立账本但未在此路线中消费，不补虚构用途。新完整两法1272/1289差17tick，仅证明同一绕路内活借比双R更省，不证明这条绕路值得走。

伤害和自然恢复分清：两法前缀263冠蛛线伤5→4；后继根哨接触665/682伤4→3；729/746沿恢复路径经过现有camp_heart自然拾取3→4，最终HP4。不能说全程无伤，也不能指成脚本补血。拿奖后回D/M路经过心属于正常已有拾取，不能因此倒推“去E”本身获得额外目标。

## 新两法实际完整17腿

括号为alive完成tick / ordinary完成tick；不是仅列计划路线。

| leg | 实际动作 / 目标 | 完成tick |
|---:|---|---|
|0|arrival_reading，W观察|12 / 12|
|1|west_to_belly，普通跨缺口|82 / 82|
|2|west_to_belly，走到M|141 / 141|
|3|upper_out，M→E|234 / 234|
|4|reward_descent，E→外奖|336 / 336|
|5|reward_other_exit，奖→R|450 / 450|
|6|outer_lift_return，R→E|521 / 538|
|7|lower_in，E→D|636 / 653|
|8|inner_recovery，D→树腹左接收|798 / 815|
|9|inner_recovery，走M|851 / 868|
|10|belly_borer_access，低阶|927 / 944|
|11|belly_borer_access，中阶|951 / 968|
|12|belly_borer_access，S|975 / 992|
|13|S对齐观察|987 / 1004|
|14|borer_crossing，S→C|1135 / 1152|
|15|cavity_prep，C→prep|1208 / 1225|
|16|crown_approach，真环/gate|1272 / 1289|

E已在234到过，外奖336已领，到R450后没有在E发现新目标。E521/538再到D636/653，是上升后立即下降。用场地共享解释回访可以有价值，但本批没有新的景观发现/互动/跨联/敌清理目的，不能把固定函数复用当体验价值。

## 便宜替代：当前Manifest已有R→D，不能当作不存在

离线BFS按当前Manifest实际有向边，从R到gate_ready、避开已领cache，最短拓扑是：

`outer_to_inner(R→D) → inner_recovery(D→M) → belly_borer_access(M→S) → borer_crossing(S→C) → cavity_prep → crown_approach`。

新B多插入`outer_lift_return(R→E) → lower_in(E→D)`，取代原一条`outer_to_inner`。同一Hollow local_geometry逐数据相等的旧真实原件 `snapshots/cavity_v4_02/.../v4-leftloop-matrix/14-map2-high_return/capture.json`，同R450→D561，真实111tick；新B R450后到D636，区间185tick，多74tick。原更直接段已能落到同D，并非只一根纸上箭头。

边界必须诚实：旧直接段原raw在506真实用了固定`hollow__lower_window_ring`。它是**不借活萤的既有固定回路，不是已证明完全0H**。当前最短图本轮没有从同字节新源把整个R→gate完整重采，后继到达相位会变化，不能将74tick直接减总时长并宣称最终HP/速度一定支配。也不能拿另一growth总1280与本1272比快，growth到R533，前缀已差83tick。即便没有新整条native，E与D的无目的上/下绕行已由源和actual17腿成立，足以拒绝当前晋级，不需要再花engine证明“绕路更有趣”。

## 允许的后继与不允许的救法

若要保地图2奖后R活借，必须先有真正的E→C跨联、另一个真实E探索目标，或让R→E进入与R→D不同且有用的后继接收位。那是新空间内容：上窗/oneway/环头/全body/231射程/资源和失败返路都要fresh验证。不能只改route标签，把E写成Queen前哨，或因map1 E是守卫入口就复制同一个函数称两图目的相同。

当前不要求立即新造一套内容来救这个placement。可以保地图2上层/根路的安静观察恢复段，先把真实E→C假设作一段黄金，最强原D/M下路保留；若仍只为活H多绕一圈就DROP。既有map1两组物理成功属于正确源域，但不在本报告重新签其趣味或外推map2。

本结论不会以新的PASS数/Hash、17tick相对双R、电影或新增敌行改变。技术4PASS作为可靠证据保存；**当前map2 B设计DROP**，更深随机/生态/大部分核心因H而变的用户目标仍需真实内容关系证明。
