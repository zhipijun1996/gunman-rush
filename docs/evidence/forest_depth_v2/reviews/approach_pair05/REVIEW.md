# Approach pair05 — 原普通、清敌与失败活锚因果审查

2026-10-17；`/root/forest_ecology_review`，gameplay-reviewer。只读，无engine、不改受审生产或driver。读实际生成器/Assembler/平台与protected点、EnemyActor/InputRouter/Traversal、AirFocus源码；读冻结05 clear/live原capture/native及04两普通原成功。独立提取见`audit.py/raw-audit.json`。

**当前 REVISE：05尚无活锚完整成功，不值得按三解生态组合集成。** 允许一次有限、基于真实terrain的接近点修正；不是已经证明所有H物理不可能，也不以H必须最快/唯一为门槛。普通与clear保留为真实局部结果，不能把三个live断言失败改成成功。旧approach-weaver DROP与01–03驾驶失败身份保留。

## 真实输入和范围

Seed(1230,C.y)和Lantern(1250,C.y−90)是局部另实例，使用实际地图2生成/Assembler平台、真实gate环与closed vine、语义保护点和正常Policy。05本例C.y=372；真实return relay x1100..1260/top290，不能忽略。全部Definition默认，没有给H目标强赋值。

378tick是特选局部预热，非自然完整C prefix；起始HP5、E100、2枪为该局部状态，不能从此签正式到C健康/精力。source记录04→05只改driver/reader，生产不变，04普通可按这个范围比较，不叫05重采全部普通。配置启用airfocus .2、2秒，实际AirFocus依赖router.aim_engaged；05用显式action方向而未engage aim，**本批没有实际比较.2慢瞄准**。不要把物理tick差叫玩家现实反应窗口，也不据no-aim驾驶签鼠标/手柄舒适度。

## 已发生的四个结果

| 原记录 | 完成 | 决策tick | 末HP/E | 真正发生的事 |
|---|---|---:|---|---|
| 04普通满跳 |是|127|4/100|gate环contact454；444伤1来自Lamp身体|
| 04普通宽绕 |是|149|4/100|gate环contact477；同444 Lamp身体伤1|
| 05 clear |是，7/0|270|5/100|真弹3杀Seed；598真gate contact，gate打开、1400支持稳定|
| 05 live |否，8断言3失败|96（失败局部长度）|4/100|Lamp 0contact、0kick、0R；gate没开，417撞Seed伤1|

96不是一次成功高效活锚路线，也不能与127当速度收益。失败driver在1400附近支持稳定后就停，但未开gate，真实断言拒绝。没有影片，G2/正式prefix/密度/玩家/音频/设备均未验。

## Live失败首先是错误接近点/terrain处理，不是“多加一次H即可有价值”

392请求前Player(1090.666,371.925)，H发射参考origin(1090.666,365.925)，Lamp(1278.369,282)。请求向右上，queued=true；393实际cast、397fly、401miss、402retract、404free。没有实际hook_target被认成Lamp，没有真实contact，因此不能领取H保护/回能/踢离收益。

请求时的直线在x≈1215.745/y310穿过**实际**return relay下边，不仅是扩展12px的保守矩形。该relay是one-way支撑，但H头仍从全边界碰撞，不得按Player能从下面跳上去推论H能穿它。相同request附近4px发射时序偏移不改变“整段穿过宽relay”的阻挡风险；原raw已确认miss，未伪造新物理成功。

05新增`approach_terrain_head_clear()`只守到gate环的那次请求；第一次向Lamp仍仅看距离<210，没有terrain/head检查。当前失败因此优先归到driver接近/可达性遗漏。继续正常走后经过Seed身体受伤也符合失败路径，不是成功活H后的公平风险。不能删除relay、减capture radius、允许H穿oneway或给免伤来救。

最小修正是先选一个**实际可见/terrain清楚的合法起跳或岸位置**去接Lamp，再用原kick/first-free R接gate；若从该位置仍因Body/实际近目标被截而失败，继续如实归因，不从中心距离推成功。一次修正后仍无新增收益，应停止这个placement，而不是持续造更长choreo。

## 当前clear无伤的原因尚未隔离

04普通两法唯一伤害来自Lamp身体，Seed没有打伤Player。05 clear杀的是Seed，但多花143tick才完成，清枪/重站岸让Lamp相位发生明显变化：clear562起跳、591发gateH、598contact，不能把HP5直接解释成“清Seed带来安全”。Seed HP3→0的真弹因果成立，清场是否值得仍未成立。

有两个最便宜反证应优先面对，以下只是待证假设，不冒签已经成功：

1. **同相位普通等待消融**：保Seed，在安全C/岸等到与clear相同的起跳相位，再用同普通满跳/真gate H。若同样无伤，clear的HP收益主要是Lamp相位变化，而非三弹清场；等待可成为可读选择，但三弹不能自动算新生态收益。
2. **低通路/先清后地走**：clear后可尝试沿地面从高处Lamp下方走过，再从已过Seed的一侧正常钩gate，避免再做满跳撞向Lamp。普通保Seed也应面对正常短跳只跨Seed/低于Lamp身体的通路，而不仅比较两种满跳。真实净空、Body、H头、相位需原Motor验证；不预言短跳必胜。

这些反证不要求普通最快不受伤，也不要求三个策略互相支配。要核的是保活H是否得到明确的接收位/射角/健康/资源/后继相位收益，清敌是否真替想走的路线扫掉风险，而不是“完成更多动作”本身。若普通可以不用认识这对敌人完成同一目标，且另外两法都无目的收益，DROP该放置；不增加HP/弹数/频率/关旁路来保数量。

## 限定后续决定

现在可说“实际上层同一岸有了两敌可用对象、普通承受一次Lamp风险、clear局部无伤”；尚不可说“上层已产生三种有意义生态解法”。先有限修driver取得一次真Lamp contact/kick/R/开gate完整结果，同时检查最强普通/相位消融；无需把旧默认31重采，也不需上完整战役来掩盖局部未成立。

若真live成功后仍只节约无关动作或三弹清场纯为等相位，按无收益操作税修改/淘汰；若获得可读的风险/资源/接收位置取舍，则可有限CONTINUE到真实C prefix，之后再谈整图。当前REVISE限定于pair05，原地域F02与默认pool不因本批通过数改变。
