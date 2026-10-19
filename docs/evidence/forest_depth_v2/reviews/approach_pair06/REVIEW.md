# Approach06 — A2组合有限继续 / level不入池

2026-10-17；审查者`/root/forest_ecology_review`，gameplay-reviewer。实现者`/root/forest_ecology`。只读冻结source、十个actual capture/native及原wrapper receipt；无engine、不改生产。自算`audit.py/raw-audit.json`。

**A2配置局部CONTINUE到一次真实C前缀验证；level当前放置/驾驶REVISE、不放该pair。** 不改level台/敌/相位来救本轮。level失败只证明本phase/接近驾驶没有完成，不能宣称所有H物理不可能。整体wrapper是exit1/9PASS＋1FAIL，不是10PASS；原01–05全部驾驶/内容失败与04两个普通成功保留，不倒签。

## 身份与范围

冻结`snapshots/approach_pair06/build/forest_depth/ecology/approach_pair06/`，十个case分00 A2和02 level。独立哈希当前冻结source与receipt一致，source_before==after；逐路径比较05与06仅`tests/forest_depth_enemy_runner.gd`和`tools/run_forest_depth_enemies.py`不同，生产同字节。实际生成/Assembler地形、语义protected points、原Definition/Policy/InputRouter被消费；不是场景实体伪造的gate奖励。

378tick局部预热、HP5/E100起步，不是真实完整C prefix。05/06不engage aim，因此未实际消费.2 slowfocus；不能用这些physics tick差签用户瞄准体验/真实反应时间。没有当前正常GL、完整前后生态/保存/玩家/设备/音频认可。

## A2实际结果

| 策略 | 决策tick | HP/E终态 | 证实范围 |
|---|---:|---|---|
| ordinary_early满跳 |128|4/100|Lamp身体伤1，gate真实开/1400支持12|
| ordinary_low短跳 |128|4/100|Seed身体伤1，gate真实开/1400支持12|
| clear_under |269|5/100|三真弹杀Seed，地走从Lamp下穿，gate开|
| wait_phase |270|5/100|保Seed、0普通枪，等待后按原clear起跳时刻通过|
| live_jump |120|5/85.5|跳起后真借Lamp→kick→一R→固定gate环，完整开gate/同岸12|

只差8tick，不称live最快上限，也不称所有未试普通路径会伤。未试的中间起跳位置/早收跳/相位和更直接gate接近仍可能给出便宜普通无伤解。**这不妨碍已证的有限取舍存在**：在当前局部时刻，可以快速普通承伤保能、等到更安全相位而省枪、清掉实体风险，或用一枪/部分末精力借活锚保住生命。H无需最快；它已提供另一条实际穿过两层身体压力的轨迹，而非仅多操作一次同路。

### H真实链成立，区分钩头取得目标与身体到达

401 queued grapple；`contacts`411是hook_contact信号/钩头取得Lamp，观察帧412进入pull，不是此刻身体已到。Policy事件416的`event_id=hook/.../1/1`使Lamp2→1，观察417实际contact_kick、424 kick、431 free；没有给目标赋值或用普通子弹冒H伤。H保护属于原Traversal，不额外给免伤。

431 request/accepted左枪，432观察帧stamina100→80、air shots2→1，普通R burst431→440真实x1242.739→1396.740，位移154.000px，440结束后再钩固定环。445钩头gate contact，447身体contact_kick，454观察进入原kick，随后由Assembler真实开vine，498到1400支持12终态，HP5/E85.5。不得将目标signal、damage、contact、kick混为同一帧，也不能把154px普通枪反冲叫H位移。

## Seed有身体作用，但独立投种机制价值未证明

ordinary_low真实417被Seed body伤，ordinary_early高路避Seed却436碰Lamp：两者构成低/高路径的身体压力差异。不能再写Seed完全没有作用。但这些例没有Seed种子弹/旧支持枝落区击中或改变Player路径的证据，不能宣传“上层锁枝种子机制已深化”。当前已证明的是双层身体关系＋可借上层Lamp。

clear三枪把Seed变成0HP是真的，收益却不等于必须清场：wait_phase保Seed、0枪同样无伤，269vs270相近。wait是改变时机/路径的控制，不是严格同输入消融；不能据此断定任何场景清Seed均无价值，也不能将三枪当为了安全必须付的操作税。永久清除可能对回访有价值，**本批没有回访**。到真实prefix时只保它为普通可选清路，不把清敌case数充作第三种同等独特策略。

A2有限继续理由主要是：保活Lamp已经产生真实伤害保护/位移/反冲接收与生命—精力取舍，同时普通快解和慢稳解都存在；不是Seed投种与两敌数量本身。若真实C到达时更便宜普通无伤很容易且借点没有后继位置/资源价值，仍应REVISE/DROP该放置，不缩路/加频率救它。

## Level失败与配置隔离

level四普通/清/等实际通过：普通125/128各HP4，清269与等268均HP5，E100。live401在(1129.667,165.335)同朝向发射，412实际miss；原缓存ShapeCast命中`hollow__cavity_right_step`，point(1266.231,200)。0Lamp contact、0kick、0R，436碰Lamp身体伤1，固定gate未开，三断言失败。真实平台位置与A2不同，不能按相同平移敌行/同relative C关系自动继承A2。

当前被动readiness只能在请求那一刻证明目标优先；之后cast/windup、玩家与Lamp运动会改变截获，不能把“预检通过”当未来body路径保证。已有真实miss足以拒绝此driver，不能改reader把它当成功。也不推断其他起跳点/时间全不可行；本轮预算停止，不继续调相位/挪台/强迫别法。

**可以把level上层明确设为安静过渡段**：C后给宽台恢复、读gate/Queen入口、保留H移动与观察空间，不必每个上层seed都塞一对怪。A2在其特有低C/relay关系才给这对placement做真实prefix；level不放该尚未成立pair，不按root seed字面特判，应该绑定清楚的物理variant/placement条件。仍不签A2所有相位/所有seed已有生态准入。

## 地面Seed是否现在替换charger

**建议保持A2已成功组合，先做一次真实prefix，不立即换charger。** 低普通碰Seed、高普通碰Lamp、借Lamp保生命而花一R，双高度身体路权已经不是完全无作用的固定摆件；足够作为一个有限遭遇，不必要求每个placement都发挥所用敌人的全部招式。明确此处Seed只承担地面占位，投种未贡献，不把旧类型或新数量包装成创新。

现成charger的.45预告/360水平承诺会提出不同问题：让地面威胁主动推进、玩家上借Lamp去放弃原地面射角。这方向可有价值，但不是把同HP3单位无风险换皮；冲刺可能追到C观察/起跳一侧，必须重核接收岸、预告、完整路径和普通绕行，06不能继承。此时换它会重开另一轮候选，而不是解决已经观察到的阻塞。没有实现/验证，不能签其优于Seed或PASS。

若一次真实prefix发现Seed从未对想走的路线产生可观察意义，或普通零代价路线稳定消去整个组合价值，再删该放置或仅替换一次charger验证新假设；当前不先通过更动态敌人来掩盖已有取舍已经足够/不足的事实。

## 下一最小步骤与边界

只把A2既有相同敌/参数/位置送入真实从地图入口到C的prefix，不注入378相位/满HP/E；随后比较正常普通与live的实际到gate健康、枪/精力/接收位置，必要时保wait可读但不硬等到旧固定帧。无需再做level调参，也不增怪/弹量/HP制造密度。完整新像素与恢复/暂停跨界另验。

本报告签有限CONTINUE，不签默认pool、正式全区密度、Seed独立投种价值、普通上限/全资源支配、影片或玩家好玩。05 REVISE属于旧失败，06 A2真实成功只升级这个新增局部范围；level失败和wrapper整体FAIL继续保留。
