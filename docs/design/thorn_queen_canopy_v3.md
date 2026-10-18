# 棘冠女王 Canopy v3：越身、留剪、换岸

FOREST-DEPTH-02 的新 Boss 内容设计记录，合同 `forest-queen-canopy-v3`，Resource `thorn_queen_canopy_v3`／definition_version=1，战斗快照 canopy_schema=1。本稿依据当前真实实现及黄金01／02，不是作者自评验收。采用 boss-creator Skill 的机制、阶段、完整消费者与证据分界。

**当前结论：允许有限产品整合，整体品质与 H 核心仍 REVISE。** 黄金[完整原件与独审](../evidence/forest_depth_v2/queen_canopy_v3/README.md)及[两部正常速度影片](../evidence/forest_depth_v2/queen_canopy_movies/README.md)分别绑定冻结源。 不同作者在 build 字面路径 `build/forest_depth/independent/final-experience-v7/Queen-canopy-v3-02-REVIEW.md` 允许继续正式 App、保存和正常整战片；没有签真人趣味、设备、音频或最终三阶段品质。旧[迁巢织场设计](thorn_queen_v2.md)保留历史原 scope，不以新黄金覆盖旧版本失败。当前工作区的整合代码也不能自动继承黄金的消费者结论。

## 身份与地区联系

女王是穿梭两道实体树肋的织冠者：身体持续横扫，结把路线变成玩家可保留、可剪断的网络；推进伤害会把最近真正站稳的岸变成持续危险。记忆点是“先决定下一次在哪里站，再决定借结、剪网还是换岸”，而非等树心开窗。

她与图1 Guardian 的差异是内容因果：守卫是身体扑越与独立实体铃的 H 夺取返撞、打断；女王没有铃返撞、扑落反击或轮流亮侧资格。她始终可伤，身体不属于 grapple_target；可钩对象是固定 A/B/low_recovery 与真实2HP结。H 不是阶段按钮，也不自动打断或剪光网络。表现当前为冠形多边身体、暖色路径箭头、带血点的结和生长织带；最终剪影、美术、动作声音与音乐转段仍待实际合屏与正常影片判断。

## 权威源与参数范围

数值唯一运行来源是 [Canopy Definition](../../scripts/bosses/thorn_queen_canopy_definition.gd)、[实际 Resource](../../resources/bosses/thorn_queen_canopy.tres)与[Encounter](../../scripts/bosses/thorn_queen_canopy_encounter.gd)。下表是当前读取值的设计说明，不是另一套默认配置。Definition 继承旧 Weave 类型以复用 Knot/Band；旧 perches、旧三网旋转／升降、seed 弹、heart_open、弱侧点积、旧迁巢速度等字段并未成为本 Boss 的行为，不能按继承字段名虚构攻击。

| 当前消费参数 | 值与作用 |
|---|---|
| Queen／结 Health | 24／2；Queen碰撞48×54，结24×24 |
| 阶段门槛 | HP≤16进P2，HP≤12进P3；两者分别为24×2/3、24×1/2 |
| 身体运动 | speed360世界单位/秒；每段路径预告0.65秒；首入介绍1.6秒、重复介绍0.5秒 |
| 织带 | warning1.2秒，随后grow0.65秒；radius6，即完整宽12；每次伤害1，同源请求间隔0.7秒 |
| 接触／Policy | 身体接触伤害1，源间隔0.7秒；共用monster iFrame0.65秒，非额外全场免伤 |
| 连接 | entry_gap48，overlap24，Player半高18；实际连接详下，不复用旧地板入口假设 |
| Player基础 | 24×36，普通地速260，重力2600，落速上限800，普通跳初速−666、hold0.13／minhold0.1；来自config/player_tuning.json |
| H实际 Traversal资源 | range231，windup0.065，头飞速1650，拉速1150，stop30，头半径12；接触停顿0.10，kick每轴240持续0.10，即名义24px；接触grace0.15、伤结1；miss hold0.015、回收速4200 |
| 普通枪与R | 弹速1200、生命2秒、伤害1、冷却0.25；空中枪容量2，反冲burst1100×0.14秒；真实命中返资源，因此不把强普通策略假设为全战最多两枪 |

不改 Player、无敌、基础资源或碰撞体来适配此 Boss。H 成功身体接触与kick按原规则重置 H 使用资格；不会凭 H 次数回满空枪。普通命中返能／空枪需按实际提交账本与命中时的既有语义结算，不能拿结束资源倒推净消耗。

## 场地、入口、支持与固定锚

以下全是**arena local**，y向下，世界位置统一加geometry.origin。arena为(400,0,560,600)，不是从x0起的960宽房；黄金出生S=(450,342)，Queen初位(550,440)，奖励落点(550,582)。所有下列平台均solid，不是one-way。

| 支持／遮挡 | Rect(x,y,w,h) | 意义 |
|---|---|---|
| floor | (400,600,560,36) | 永久恢复地面；low站中心y582 |
| central_rib／S | (400,360,100,240) | S站中心y342；24宽全脚中心x412..488 |
| right_rib | (650,260,50,340) | 隔开左右腔，真实挡身体／钩头／弹体 |
| right_bank | (720,560,240,76) | right站中心y542，全脚中心x732..948 |
| canopy | (400,20,560,40) | 上界实体遮挡 |

固定锚 A=(640,300)、B=(800,250)、low_recovery=(575,490)。A/B提供树肋两侧的转换目标，低环保恢复可能，不规定每阶段钩几次。H仍要满足231距离、实体视线与全身体可达，瞄到目标不是身体已经抵达；停距30也不等于身体贴结中心。

当前 [Factory](../../scripts/generation/forest_boss_arena_factory.gd) 的 `queen_canopy_from_prep` 将local prep=(352,342)平移到真实prep，连接台为(328,360,96,24)，从外接近岸走入S，和central_rib重叠24px。它不是旧air-motion floor820→S的方案，不应拿此前入口草稿当本场已验证。Definition 的 `player_spawn`／`entrance_position` 是几何数据，黄金从S起跑不证明正式App自然接近、封场和奖励链已经通过。

### 身体四段闭环

所有阶段共用下列实际完整路径，段间先停下预告0.65秒；每段内按360移动到各顶点，只有走完最后一段回初点才计一次cycle：

1. (550,440)→(550,310)→(426,310)→(600,200)→(740,200)→(740,410)。扫S附近并越肋。
2. (740,410)→(740,510)→(930,510)→(930,110)。扫右岸再升上冠。
3. (930,110)→(426,110)→(550,110)。上冠跨回左侧。
4. (550,110)→(550,550)→(530,550)→(620,550)→(550,440)。扫低层而非留下永久地板炮台。

BossMotor真实move_and_collide地形，不穿实体；对绑定Player加入实例碰撞例外以免单向推挤破坏路线，但独立全身体接触Emitter仍按Policy伤人。碰撞例外不是接触无敌。身体接触在intro关闭，migration_preview与flight均可伤；预告停住时也不能随意贴身。

## 状态机与三阶段判断

激活→intro→migration_preview→flight（逐leg）→下一section的migration_preview；第四section后循环。终态／取消由既有Encounter生命周期接管。P2/P3是叠加网络状态，不是替换身体运动状态。生命跨门槛时依序启动阶段，**不取消已承诺路径、不瞬移、不回血、不提供无敌阶段切换**。active且未死时始终core_open，任意方向正常有效伤害可命中，没有计时开放弱点。

| 阶段 | 新判断、预告与实际应对 |
|---|---|
| P1：24→大于16 | 看整段已锁路径与实体肋，选择普通跳/R换侧，或H固定环借体越身后再射；R枪向与希望位移相反。通过移动制造射角，不等心门。 |
| P2：≤16且大于12 | 一次生成高结(730,150)，网(700,230)→(760,230)。1.2秒明确全线预告后0.65秒逐段生长，成熟持续。可以保结作借点并绕开线、H伤1HP后反枪剪剩1HP、或两弹直接剪掉。清网也永久失去此结，不会按循环重生。 |
| P3：≤12 | 一次锁定最近实际全脚支持岸，生成对应结与网；不是预测正在空中的未来落点。可以离开被锁旧岸而保网、提前剪、或先站想诱导的岸再推进HP门槛。旧高网同时保留，身体原路径继续。 |

P3每次physics只在真实grounded、脚底距对应support顶<1且左右全脚都在support内时更新last_receiver；初始值S。进入P3锁一次，不逐帧追踪。事件另记sampled_player的当时坐标，**空中坐标不是锁定依据**。可选岸：

| id | 用于判定的支持Rect | 结 | 完整预告线起→终 |
|---|---|---|---|
| S | (400,360,100,240) | (480,220) | (412,340)→(488,340) |
| low | (500,600,150,36)，是永久floor的子区域 | (575,450) | (512,580)→(638,580) |
| right | (720,560,240,76) | (850,410) | (732,540)→(948,540) |

织带是可见**非实体危险**：不推人、不挡枪/H，不把刚好站在生长范围中的身体夹进solid。有效范围是从start向tip生长的12px宽带，使用真实Player半身12×18与相邻帧身体路径扫掠，经Policy处理。Canopy的field_id是canopy_high／canopy_receiver，不匹配旧数字旋转／升降索引，因此这两网不会按旧Weave的旋转或上下运动参数运行。1.2秒预告没有危险；生长开始便有已长成部分的伤害，不必等1.85秒全长。已有持续网在后续预告、阶段转换仍危险。

预告绘制为完整细线，生长部分与危险多边形同源；身体路径为整段箭头。目的应对是看线换岸／剪结／改H和反枪方向，不是看到字幕再按指定按钮。当前只有实现与原生轨迹，未看该版正常影片，不能断言提示清楚或陌生玩家理解无负担。

## H+R的真实联合动作与自由选择

02目的打法在receiver kick tick425，Player约(516.741,182.325)，结(480,220)仅剩1HP；瞄左下(−0.698169,+0.715933)射出真实圆弹，427经Policy把结1→0剪网；同时R把身体推右上，离开旧S。它将“伤结、瞄准剩血、剪网、反向位移”连成一件动作，非H回调自动清场。高结仍保1HP至战斗结束，不假称其保留收益已被证明。

keep不是停在原岸：02观察231锁S，238开始两次真实水平R撤离，314右岸全脚12帧；保两结各2HP和两网持续，继续对Boss输出。cut可在预告内两普通弹剪结，合法、应保留。lure可主动暂停Boss输出，先用正常行动站到right，再恢复输出触P3锁right；攻击和时钟从未暂停，不存在合成HP锁。三者是自由策略，不是三段必须依次完成的流程。

## 受伤、恢复、容错与战斗结果

身体与成熟网各有真实1伤，按monster iFrame竞争；命中不等于每帧连续扣血。H只对实际目标及既有规则保护的接触有效，借结不会免疫整个Queen或整条网。网非实体、宽floor和低环保留失误后转向的空间，**不代表任意姿态保证无伤恢复**。本稿没有有限误差扫描、最差相位或低资源普遍容错证据；不能将一次顺利站稳12帧叫宽容已验。

01目的错误在receiver kick后仍向Boss右上射，R反推左下回旧S，真实网伤发生466/508/550/592，结没有被剪掉；最终HP1不是优秀风险控制。02换成上述反枪剪结而不改任何内容/Player参数，消掉这些网伤，但548仍一次Queen身体接触，最终HP4。普通keep也358身体伤1；lure224/357两次身体伤。01盲keep317/360/403/446/488五次网伤后死亡，不能用它证明所有普通keep不可行。

| 冻结轮次／实际策略 | 断言／结果 | 击杀tick／恢复全脚12tick | 结束Player HP／E |
|---|---|---|---|
| 01 H目的 | 15/0，但四次网伤 | 617／628 | 1／80 |
| 01 ordinary_cut | 15/0，零H，两网预告内真剪 | 626／637 | 5／100 |
| 01 ordinary_keep | 15项2fail，原exit1；488死亡时Queen6HP | 未击杀 | 0／80 |
| 02 H目的 | 17/0，反枪真剪receiver | 614／625 | 4／80 |
| 02 ordinary_keep | 18/0，换岸保两网 | 500／511 | 4／65.5 |
| 02 ordinary_lure | 19/0，先移right再锁right | 876／887 | 3／100 |

这些为各case物理tick，不是所有策略同一绝对时刻。02只改既有runner的理解与输入，2083源域中内容和基础参数未改；01 cut没有02复采，必须保01身份。keep比H早114tick且同HP，结束E65.5和80在不同时间，**不能称H净省14.5**。cut比H慢12tick但无伤E满，是强合法安全策略。lure证明可控制锁岸，尚未证明值得诱导的收益；慢且多伤应如实保留。

## 保存、失败、胜利与产品边界

当前实现记录身体位置／mode／clock／section／leg／cycles、阶段、最近岸／锁岸／sampled_player、结HP、网age/growth/severed/pulse/下次伤害余时、intro与attack_epoch。validator检查几何版本、有限类型、路径线段位置、合法阶段／field存在关系等，恢复后取消旧epoch并从原字段继续。pause/cancel_pending暂停网的现有时钟而非清网或重开预告；剪断状态永久保留到本场结束。**这是实现契约，01／02未实际验证保存／重载／畸形输入和所有生命周期相位。** 不以静态validator存在签安全。

Queen生命归零后既有Encounter终态与正式Stage接管封场、清理、一次奖励及同帧Player死亡优先；reward_stand_position消费(550,582)。新正式App连续入口、全战、胜败清场、菜单、保存、epoch取消和奖励账本未由此黄金或本稿验收。黄金用了真实Player/Policy/Seal搭建，但仍不是DemoApp消费者，更不是浏览器/设备输入。

## 证据、反例与下一结论

原件字面路径：`build/forest_depth/queen/canopy-v3-01/RESULT.md`、`build/forest_depth/queen/canopy-v3-02/RESULT.md`；独审路径见开头。它们是当前存在的build材料，不伪造将来portable链接。运行源入口为[场景](../../scenes/bosses/thorn_queen_canopy.tscn)、[表现](../../scripts/bosses/thorn_queen_canopy_presentation.gd)、[原生runner](../../tests/thorn_queen_canopy_runner.gd)、[真实fixture](../../tests/support/forest_queen_canopy_fixture.gd)、[wrapper](../../tools/run_thorn_queen_canopy.py)。旧[整体REVISE](../evidence/forest_depth_v2/reviews/final-experience-v7/REVIEW.md)不因局部继续而撤销。

已保留的内容差异是身体持续压力、可留可剪的持久路线、真实历史支持岸锁定与反枪换岸。H尚未证明创造普通jump/R之外的新有效输出窗口，既不最快也不最安全，保高结后继收益亦未明。不能为显H重要而禁掉强普通cut、收紧旧岸或锁HP；也不能机械因H非最快就否定不同运动表达。下一结论应来自正式完整消费者与正常影片的实际可读性、反枪余量、弱结反馈和策略学习，而非更多断言／H计数。没有作者自签fun、商业品质、G5或发布完成。

电影之后的可读性修正：新Canopy Presentation按真实结Health显示16px的`2/2`或`1/2`深底标记，以补原2px亮点在实际影片不明显的问题。不改shared Knot／碰撞／血量／damage；旧电影不会追签此新像素，正式App／GUI增量另验。

## 正式App03实际补证

[完整原件](../evidence/forest_depth_v2/canopy_app03/README.md)实际46/0，正常路线与封场后完整24HP击杀，MENU真暂停、真实phase2活结保存、新Stage/Boss恢复、旧token拒绝、9个坏快照原子拒绝、GOLD/D/边界/Home闭合。704个观测帧；679击杀，704稳岸12，战斗HP4→4（此前路线已受伤），不能把它写成该场战斗受伤证明。保存时Boss15、活结1、年龄0.516667；HP4／E80／上限5保持，玩家依法从空中回S检查点，空枪按原返回规则重置2。GOLD上限5→7且HP4／金币0不变。01／02原失败及后续只读读取器修复分别保留；没有重写旧失败，也不签headless像素或真人趣味。
