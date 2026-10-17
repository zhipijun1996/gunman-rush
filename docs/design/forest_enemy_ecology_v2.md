# FOREST-DEPTH-02：森林四类生态与局部准入边界

当前保留**铃囊萤、棘籽哨、旧charger森林配方、织棘蛛**四种职责；新制作的独立行为只有织棘蛛。折枝獾因与真实旧charger同构已删除，不算新增生态。合法基础仍是H＋普通单武器／R，不改PlayerController、武器或物理；静态环、支持岸和死敌后的通路保底。

当前退役后真实局部消费者已通过：`ecology-retired31-02` 的31逻辑case、45断言/0失败、Python严格验收、干净原生退出和source guard。该结果不等于新宏观两图、完整出返、独立趣味或设备验收；公开生成器注册器当前默认已选v2，旧v1仍可精确回放；默认选择不等于所有局部候选或整区丰富度准入。采用enemy-creator、encounter-director、animation-vfx，作者的自验不能冒充gameplay-reviewer独审。

## 运行职责与唯一参数源

表中为实际Definition默认值；Stage会消费Manifest的`patrol_radius`覆盖巡幅，放置评审必须核该实例值，不能拿默认值代签实景范围。数值由资源/脚本消费，本文不是第二份运行配置。

| 类型／实际资源 | 玩家判断 | 主要运行值 | 状态与伤害 |
| --- | --- | --- | --- |
| 铃囊萤 `resources/enemies/forest_lantern.tres` | 要留作移动活锚，还是先枪杀换安全；何时接近与踢离 | HP2、身体24×24、速度46、默认巡幅60、停驻1.15s、转向预告.5s | dwell→telegraph→travel→dwell；无发射攻击；身体接触伤1，正常H目标；自主移动不以警戒距离启动 |
| 棘籽哨 `resources/enemies/forest_seed_sentry.tres` | 离开刚锁定的支持面／退入实干遮挡；先清哨还是换接收枝 | HP3、身体30×36、警戒320、前摇.8s、attack.45s、恢复1.3s、种子220px/s、弧高70、落区64×30/.4s | idle→telegraph→attack→recovery；锁已落地玩家脚下42px射线的真实支持，旧落区伤1，身体接触伤1；非飞行擦身 |
| 旧charger `resources/enemies/plains_charger.tres` | 宽枝上等承诺冲刺、射杀或换到另一层 | HP3、身体28×32、巡速90、默认巡幅100、警戒180、前摇.45s、冲速360/.38s、恢复.7s | 既有idle/巡逻→telegraph→attack→recovery；同home.y水平冲刺，身体接触伤1 |
| 织棘蛛 `resources/enemies/forest_thread_spider.tres` | 读一条局部线的时间与空间包络：抢先通过、等收线、换高路或枪杀 | HP2、身体26×28、警戒300、线长8..150、线半径8、前摇.9s、展.15s、持.65s、收.25s、恢复1.6s、之后CD.8s | idle→telegraph→extend→hold→retract→recovery；每周期每目标线伤1，身体接触伤1仍独立走原Policy |

实际身体伤害由`DemoApp._contact`装配`DemoContactEmitter`：请求amount=1、重复接触间隔0.7s；`FrameDamagePolicy.monster_iframe=0.65s`是独立的普通怪物伤害保护，并非每只敌另有0.65s配额。H保护只针对正在接触的真实钩目标。籽哨落区伤1来自`ForestSeedProjectile`，蜘蛛线伤1来自Definition，每周期事件去重；身体、落区与线都提交同一Policy，不能把展示频率直接当实际扣血频率。

籽哨、charger与蜘蛛的攻击准入读取`EnemyAttackBehavior._can_engage`：目标须在各自警戒距离内、有真实地形射线，并离实际`protected_points`至少45px；DemoApp读取Stage.anchors，再附出生与出口；森林Stage.anchors实际由assembler的semantic areas生成（排除boss与challenge_reward，再含world_entry），不是hook_anchors环坐标。森林exit_positions当前清空。不能把环附近误判为45px保护区，也不能忽略prep／gate_ready语义点。正式连接区域map1攻击并发额度1、map2为2，但通用计数只数其他敌的`telegraph/attack`，不把蜘蛛`extend/hold/retract`全算入，因此不宣称所有场上线同时最多1/2条。籽哨落区还会取消覆盖保护点的落区；蜘蛛开始与持线期间检查线距保护点至少线半径8＋保护45=53px。铃囊萤是自主停驻／巡游，无主动攻击射程；其警戒字段不构成移动启动条件。

**charger不会自行换层。** 实际目标是`home.x ± patrol_half_width`、y固定home.y；“换层”指玩家受横枝占位压力后换路线，不能把Manifest里的点列表当敌人有跳台/迁枝能力。

## 织棘蛛的实际行为合同

`ForestEnemyDefinition extends EnemyDefinition`只加入蜘蛛所需线参数；原base Definition未扩散新默认值。`ForestThreadSpiderBehavior.configure_line(world_start,world_end)`接收固定世界端点，不追玩家、不是实体墙、不改变H钩线最近碰撞或PC输入。未配置、非有限点、长度超限拒绝；开始前实际地形射线必须通，线与保护点安全距离必须成立。前摇与hold期间再次核遮挡/保护；死亡、失活、旧actor epoch取消线与旧token。

hold使用玩家真实碰撞形状投影的扫掠判定，防快H穿线漏伤，提交正常DamageRequest/FrameDamagePolicy，事件`<source>:thread:<serial>`当轮只一次。H只保护实际所钩目标的接触，**不保护另一只蜘蛛的线**。表现读取状态：整线/端点先橙后红，线宽对应Definition；表现不判伤害。死亡不会留线、门锁或凭空奖励。

`depth_snapshot()`保存端点、configured、当轮命中状态；Stage已有保存消费者另存HP/位置/home/state/time/CD/serial/direction，再恢复depth_state并用新scope取消旧请求。这是现有代码接入事实；本31case不包含正式跨图保存回程，不能从字段存在推导持久化已全验。

## 六个差异问题的当前回答

1. **新增的判断是什么？** 蜘蛛让“已展开的固定短线”成为等待/抢先/换高路的时机选择；它不是另一色投射物。萤提供可舍弃的移动锚，哨锁旧支持面，charger占真实地面。四者职责不同，不要求同屏全出现。
2. **H改变什么，而普通走跳是否仍合法？** 萤H接触后第一次free水平R可真实抵达上枝，代价为正常精力与空弹；固定环、等线、普通跳和fresh直接走仍合法。蜘蛛不是H开关，不能按玩家H才突发放线或强制活锚存活。
3. **能否站桩射死？** 可以。安全观察岸射杀是合法成本选择，不能加无敌、强制伤害或封旁路。当前fresh直接走111tick无伤，比活H＋R127tick还快；这条便宜反例保留，不能宣传此位置必须H。
4. **地形真的影响结果吗？** 蜘蛛线必须不穿实干；哨先需要当前直视才锁定，随后种子弧线可被真实实体截断。把哨完整藏在墙后可能根本不发动，不能当隔墙压力。charger完整巡逻/冲刺要有真实双端支持；旧组合01/02曾因平台遮H线严格失败，不以示意图替代。
5. **反制、失败和恢复是否有余量？** 线预告整段可见，至少一条线外替代边和安全等待岸；已hold时等收线、fixedH与liveH都能无伤。敌体不放唯一接收岸，失手落相邻恢复层，营地/奖励交互/Boss prep不承受旧弹/线。固定H也可能撞活萤，静态环存在不等于各相位无伤。
6. **死敌、低资源和相位改变后是否仍有路？** 真实弹体杀萤后固定环路线125tick无伤；正常射空＋走回消耗后起始精力38.5，实际H反馈后R44.5→24.5、空弹2→1，95tick无伤。左右各达到巡逻半径75%以上的travel样本都通过，但不是穷尽最差相位/镜像/所有武器/正式回程。不得把局部成功扩大成完整随机池准入。

## 共享几何与实际取舍

`ForestEcologyGeometry.woven_crown()`是B组合唯一数据factory，runner实际消费platforms、hook_anchors、enemies、观察/目标/退出合同。原golden默认整体包含2600px根地板、主枝、固定环、蜘蛛线和移动萤；正式嵌入不能裁地板、镜像或更换端点后沿用原证明。新巨木macro不得直接复制三套完整箱体；新接缝是新内容，要独立实跑。

同入口同驾驶的真实线消融只在测试Policy抑制指定蜘蛛thread请求；AI、身体伤害、物理、资源、观察等待和其余Policy全部保留。当前31版结果：

| 入口相位／策略 | line-on | line-off | 当前可支持结论 |
| --- | --- | --- | --- |
| fresh直接走 | 111tick／HP5 | 111／HP5 | 可以抢在危险前便宜穿过，不强迫H |
| fresh活H＋R | 127／HP5 | 127／HP5 | 动作与上枝价值真实，但此时无蜘蛛线因果差异 |
| hold直接走 | 111／HP4 | 111／HP5 | 单次实际线伤；off仅抑制1个thread请求 |
| hold等线 | 150／HP5 | 150／HP5 | 等待是合法安全替代 |
| hold固定H | 125／HP5 | 125／HP5 | 无活锚依赖的替代 |
| hold活H＋R | 92／HP5 | 92／HP5 | 该相位可用更快上路线，但正常资源有成本 |

fresh固定H161tick损1血来自萤身体，on/off相同；不能误算新蜘蛛伤害。蜘蛛当前只证明**已展开时的条件压力**，不证明全区域放置值得保留。若正式位置各相位都没有可观察区别，移位置或删该placement；不加频率/HP、封旁路来补价值。

A地面组合的同实际旧charger对照中，新獾击杀/固定H与旧敌同构，未证明其有限换层有价值，因此删除新獾行为、scene/resource、dispatcher、参数和绘制；森林地面职责复用真实旧charger，不再把新ID算生态创新。

## 生成与组合准入

Stage显式识别`forest_lantern/forest_seed_sentry/forest_thread_spider/charger`，未知behavior失败，不回退成哨。普通Actor、Motor、Definition、正常弹体、DamagePolicy和生命周期复用正式组件；不把planned行当实敌。

每行需绑定真实enemy_id、Definition、support、观察岸、进出边与邻近失败恢复面；蜘蛛另需线端点/alternative_edge，萤需完整实际巡幅清隙与固定fallback。以默认charger巡幅100为例，完整228px以上名义身体支持仅是几何起点，仍需Motor扫掠核安全；实例巡幅改变必须重新算。一个唯一接收岸最多一个主动危险，禁止线＋charger冲道＋籽哨落区三叠，禁止相邻双蛛交替封唯一路。

当前共享树实际消费已记录的`enemy_mix`，不再只写标签：mix0在根盘放旧charger（620/804，巡逻半径25），树冠放棘籽哨（1150/558）；mix1把根盘改为锁支持枝的棘籽哨（620/802），树冠改织棘蛛（1130/562，线1045/558→1105/558）。两者共享1050/680、巡逻半径45的下方活萤（原1050/380上方放置已因实际收益不足退役）；另一骨架另有400/806的内根蜘蛛，线370/802→420/802。Manifest保留实际recipe、分组、替代策略和被安全过滤拒绝的放置理由。原A3/B4只是最小空间批次，既不是敌数上限，也不代表整区密度完成。当前v6的C岸为x930..1200、top=C.y+18（水平出口C.y282，下降出口372）；此前水平冻结源绑定右口→既有prep支持→外宝箱的1160/282籽哨，因三策略实际普通满跳首过更便宜且无独立生态关系，已从当前生成器删除。C宝箱/恢复空间保留；不缩保护、不增频率救该摆法。当前生态合同为compact-authored-ecology-v5，历史C比较属于v2冻结源；上层pair退役记录见下节。

当前仅保留map1侧枝入孔蛛：`borer_entry_perch` x270..350/top568，蜘蛛310/554、巡幅0、线320..368/y540。它是M升到S之前读时机的低压教学，完整三法结果见后文；并非高级H组合或地区密度验收。map2同高西哨与其前身高枝哨均已淘汰：前身33次实弹无命中且预算失败，不能据此断言具体遮挡物；同高三法虽然严格通过，主动引怪后退等与先清怪没有取得新的目标、射界、保活或回访关系，普通gap更直接。独立审查建议DROP，当前已删敌放置，支撑由地图作者同步删除。完整spawn/camp/cache安全过滤不变，真实遭遇以当前Manifest与逐帧动作统计，不能按spawn数验收丰富度。

新配方真实B seed `forest-depth-hollow-02` 的fast/growth正式路线均完成、敌全部存活；未处理战斗的驾驶分别由HP5降到2/3。fast含根籽身体152、内蛛身体203和冠蛛真线481帧损伤，growth含根籽身体258和冠蛛身体514。它证明实际消费者和危险存在，不证明强制损血或难度合理。逐敌状态、距离、损伤类别与原件路径在`build/forest_depth/ecology/seed-recipes01/actual_B_mix1_route_ledger.json`。主路、奖励回程和不同seed还需有目的的击杀/绕过/等相位对照；地图2西庭受spawn保护、392接岸唯一，不能往接岸硬塞敌以补数量，应先联合拓扑扩共享观察岸。

每个正式组合至少比较安全枪杀、活体绕行、已展开/移动相位、低资源等待/退回、死萤固定保底和正常回程。记录真实support、accepted H/R/弹体、Policy伤害与资源。若射杀同时最安全/快/省且其他路线没有目的地或发现收益，删placement而非仅改名字。

## 图2上层候选：完整前缀反证后淘汰

上层Seed＋Lamp与`crown_live_approach`已从当前v5生成器、可选route和专用driver/reader中退役。最终实际arrival→C完整481帧、26条Router请求及482入口资源／敌状态完全同源：活H→R在603帧真实开藤门站稳，HP5，驱动末快照E72（同tick post-Motor为72.5）；普通满跳608帧／HP4／E100；**普通低跳607帧／HP5／E100／0R**。后者是必须保留的强反证：4帧优势不能支撑额外活体H、枪和精力成本。普通仍有前缀两次腔体H及末固定gate环H，不叫全区零H。

五条正式消费者（含旧map1两条）整组严格通过、完整H影片615帧真实60fps通过，与内容DROP并不冲突。独评接受真实技术链，淘汰当前upper活锚收益；未消费的战斗packet7、不造成独立压力的种子落区、局部378预热下的普通受伤均不能挽救实际低跳反证。当前不为凑数保留静态Seed，也不抬HP／频率／地块去救摆法。

[退役原件、完整producer与成员SHA](../evidence/forest_depth_v2/ecology/upper_retired05/README.md)同时保留局部01–06、正式01/02/03和普通读验失败、最后五条整组与正常影片；后继reader修正不倒签旧receipt。地图2下层B已真走完17段／四组技术通过，但尾路E→D→M→S→C绕回原路径，无新的E目的，因此其全局返程主张也淘汰，不拍电影。v7同一完整领奖／R／活萤至E前缀的三法已严格完成：侧H反向R到C用93tick，普通真apex向下1R只用60tick，HP与用枪相同；双R预算法亦只需实际1R。侧环及专属驱动因此DROP，未以方向变化掩盖33tick劣势；[冻结三控制与源档案](../evidence/forest_depth_v2/ecology/crown_reverse_retired01/README.md)保留全部原件。当前只保留无H的E→C普通跳反冲跨联，使下层领奖后的R→E真正通往高位出口，保原D恢复路；最新无侧环源`reward_crosslink02`两完整组已实际严格通过：同450帧／15请求自然领奖至R前缀，alive到E521／C582／gate719，双R到E538／C599／gate736。两者E→C均是真满跳apex后一发向下枪，60tick，完整C支持12帧且不再下D；E处driver精力85.5／65.5、C处72／52，都是读取上个Motor帧，post-Motor各多0.5。最终HP均4，精力100／95.5；前缀263帧蜘蛛伤1保持，后续无新增损伤或人为心回血。这一版本才具备真实取奖后返高位门的目的；同源正常完整影片实际735帧／60fps＝12.25秒、719物理帧且严格通过；独评对root02／map2／level0这一可选有目的返程有限CONTINUE，原existing expedition检查追加地图2两法。独评采样24张实际帧，不冒称亲自正常速度播放／听音，不用严格技术成功替代玩家体验。上层C至Boss可诚实保为观察恢复段，不用spawn数冒充遭遇丰富。

## 当前宏观下方活锚：八个真实控制与保底

旧上方活萤在相同实际端口仅省2tick（活H83、继续既有固定环85），同时多耗14.5精力，因此删除该放置，不以动作多冒充价值。当前下方萤在R至E之间，真实high_return前缀到R时HP4、精力100、空弹2；HP4来自前缀真实身体伤害，未补血。所有控制以相同R支持和敌相位为入口，HP1专项另以旧已证R前缀的冻结源、仅观察/专项consumer覆盖采证，不混新C/cache路线。

| 真实策略 | 含本策略准备的R→E总tick | E端精力／HP | 判断 |
| --- | --- | --- | --- |
| 活萤H接触→首个free输入向下R | 70 | 85.5／4 | 实际H伤萤2→1，独立combat包7；不冒充枪击精力返还 |
| 正常满跳＋至多2向下R | 87 | 65.5／4 | 无H合法强对照；下方H省17tick/20精力，不是通路锁 |
| 原R-D-M-E固定返回 | 407 | 89／4 | 实际受1伤后拾既有心回血1，不能说全程无伤 |
| 普通枪杀萤后固定返回 | 448 | 89／3 | 实际2伤/自然回血1；不是死萤唯一或最便宜解 |
| 普通枪杀萤→同R实站→满跳2R | 140（杀后运动87） | 65.5／4 | 真弹体339/355击杀，死锚仍可廉价直返E |
| 等到真实左向travel再H＋R | 218（等待148、运动70） | 85.5／4 | 有限另一相位样本，不能称穷尽最差相位 |
| 满跳两次真实空射→空弹0→落R恢复→H＋R | 148 | 57.5／4 | 实际空弹362帧、落地恢复400帧，再H；无命中返还或资源注入 |
| 普通一弹至1HP→同R实站→H致死→R | 107（准备37、运动70） | 85.5／4 | 339帧普通Policy到1HP；379帧H致死；393首free、394实际R；死锚未吞恢复 |

活锚给“保一发空弹与20精力”的可选择回程；普通2R保底真实成立。因此不能强迫留活萤，也不应把死后长固定路线448tick当作它的必要性证明。当前未证明所有相位、所有构筑或新C宝箱路线都具相同前缀；新生成路由改变后必须重新绑定实际Manifest，不能改Manifest造R入口。

首次4控冷import＋native整体50.604s、后增3控39.283s、HP1专项34.244s，均严格原生退出和source guard通过；没有为补后三控重采前四。原件为各自HEAD＋dirty冻结源，不是当前主源整区通过。compact档案位于`build/forest_depth/ecology/formal-choice01/lower-lift-four-controls.tar.gz`与`lower-lift-three-additional-controls.tar.gz`，各有成员SHA收据；HP1另包`HP1-lethal-contact-originals.tar.gz`（359137B，SHA256 `e8876e4d88534c4317a48ac4c69e40e9eeaaddb10ba4f5564bcb44ed834d0427`）。后三控333648B、SHA256 `1605536e87908cd9f1d4623f07e3352bfb8d989a263d2ea809360c62ae047cde`。

## 已淘汰C哨：保留真实比较，不计当前密度

历史C候选在cache_route=0且skeleton=0时，宝箱目的为C→右口1300/282→既有prep支持1300/558→外宝箱1300/672；C哨不再是无目的右端摆设。该已淘汰候选的实际source以`ecology_cavity_choice03`冻结，三策略共用精确逐帧前缀、敌相位和C入口297帧/HP5/E77.5，均完成宝箱及gate整条实际路线，严格原生退出/source guard通过，总38.936s。

| C后合法策略 | C至cache耗时 | cache端HP／精力 | 实际结论 |
| --- | --- | --- | --- |
| 支持银行普通3枪杀哨 | 188tick | 5／100 | 真实弹体Policy三次致死，后继支持/领奖完整 |
| 旧支持面真锁定→退C等完→普通跳 | 403 | 5／100 | 545帧1118.99/300真实未取消落区，保活敌，不靠注入相位 |
| 直接正常满跳过活哨 | 129 | 5／100 | 0H/0枪，当前首过最便宜；不人为短跳削弱它 |

原normal首消费者右走不跳，320帧在1133.98/281.93受哨身体伤1；不能称种子落区强制伤害。新三策略显示“要不要跳过身体”的基本判断成立，但未证明该处有比旧地面敌更深的独立收益；等待不是必须，H不是此处准入条件。精力在后续真实地面/走行恢复到100，不能拿入孔出口剩余精力直接宣称整个后继仍省同样数值。

这条实际borer路线有5个活敌配置，却只有入孔蛛和C哨真正接近：根charger全程idle、最近206.5；旧冠哨全程idle、最近约150；下方萤未被钩且最近约206以上。入孔蛛29帧预告、83展线时玩家已在low岸、92持线时玩家已升层，fresh合法抢先通过。**历史5个行不等于5场遭遇**；根/外回/冠枝仍应在各自实际路线计数，图2庭院在这份历史C源未验证；入孔hold后来的实证见下节，地区密度未因此完成。

首C枪杀驾驶曾因1030银行仅约3.3px反冲余量而允许7px对齐容差，在324帧被原严格footprint守门拒绝；原失败保留。修正只把驾驶银行按实际平台左边界＋PC半宽＋真实weapon_motion反冲＋7px对齐，原不安全时不发枪、敌/平台/预算均不变。`build/forest_depth/ecology/combination-points02/cavity-first-unsafe-bank.tar.gz`保失败；`C-three-controls-originals.tar.gz`保最终三策略/源/日志/逐敌ledger（392940B，SHA256 `b42d90a047b211fec5ee0945676fb62c13d84d4804a498626f9306b63d24aaa5`），成员收据并列。当前CLI已删除三个专属C策略和派生驱动函数；只可用该冻结producer重放，不把退役候选显示为当前可用测试。作者自验仍不是独立趣味或玩家认可。

## 入孔相位教学与西庭放置淘汰

`ecology_entry_west02`冻结源（字面layout仍v3，但已含当时的map2高位cavity_prep实现，必须按完整source SHA而非版本标签识别）中，入孔三策略完成真实全路线并严格退出：同M13帧/HP5/E100，先用真实支持银行普通2弹杀蛛，S193帧（180t）/HP5；观察真实hold→retract后升层，S209（196t）/HP5；真hold时跨线，S170（157t）/HP4，存在唯一thread Policy伤1。它证明当前摆法的错相位压力与合法等/清解，仍只是低压教学候选；旧fresh131帧属于较早接缝源，本批没有严格同源fresh第四法，不能拿旧131帧替代。独立审查允许仅以条件时机教学保留这一处，不扩大为H核心或整体密度成功。

首次入孔清杀驾驶误把M600作银行，而真实belly_entry右边界是680，完整反冲脚印越界；校验始终拒枪，1813帧原预算失败。修正仅按真实support.end−PC半宽−唯一weapon_motion反冲−7推银行576.3，未改变平台/敌/预算。原失败与最终收据保留，不把首败抹掉。

西庭原高枝枪杀首例实际33发普通弹均未伤到哨，E100耗至0，原预算1813帧严格拒绝，wait/jump未跑。没有实际impact/collider收据前不把疑似枝角/北庭遮挡当已证根因；W出生点处不攻击本来符合protected_radius45，不能改保护迎合设计。

同高西庭的最终冻结源`ecology_west_level01`中，三法共同W13帧/HP5/E100/空弹2：出保护岸射杀到M228（215t），真落区出现后退等到M460（447t），原普通gap到M141（128t）；三者全路线HP5，M处E100。射杀真实3弹命中36/65/94，等待真实落区306，普通gap零H零枪。未观察战斗钱包，因此只比较已测HP／精力／时间，不宣称全资源支配。此处DROP不修改这三次严格技术成功或旧失败原件。便携原件位于`build/forest_depth/ecology/current-readiness/west-level-three-controls-originals.tar.gz`与`entry02-pass-west02-failure-originals.tar.gz`，独立位置评审位于`build/forest_depth/independent/entry-west-position-review/REVIEW.md`。

## 跨枝停驻者淘汰历史

旧hopper只做同home.y弧跳并回home，没有configure_transfer_points消费者。曾实现不同的实体两岸停驻候选，根680/804↔奖枝622/722通过真实EnemyMotor逐physics跳落，上下完整身体支持实际成立，没有传送／关闭one_way。该动作事实不等于战斗价值：同入口8tick普通跳零R、21tick上岸／35回程、HP5/E100；活H真接触再R却需209／228、到岸HP5/E83。当前82px目的／活H收益DROP，不改HP／频率／Player挽救。

原两次wrapper皆未通过：01因新fixture未命名CollisionShape2D导致正式drop合同拒绝，native10/1；02修组件名后原生43/0／7case与strictclean，但Python位移判据仍拒离岸首帧的.07418额外恢复量，整wrapperFAIL。没有把疑似safe_margin变成随意容差。此布局中的实体迁岸尚未证明可取代无伤站桩三弹或改变后继目标；“诱离岸后换高射击”仅未验假设。

当前已完整退役新增行为／展示／scene／resource与两个UID、Actor单分派、Definition六参数／验证、runner附加7case及CLI leaper；默认原31 runner、Actor和蜘蛛Definition与既有冻结源逐字恢复，旧31校验函数AST亦相同。候选types-first及22个malformed反例是在退役前静态完善、未运行，不拿原43倒签。正式Stage使用support_ids数组而非局部ecology_support_id，也没有configure_shores消费，因此从未集成随机池。真实失败、冻结完整运行overlay、未验新源精选档及退役字节证明均在[跨枝候选档案](../evidence/forest_depth_v2/ecology/leaper_rejected02/README.md)，不留死生产接口待“以后也许用”。

## 自然领奖后的正式活锚返程

地图作者将真实可选`outer_lift_return`（R→E）追加在旧routes计算之后，旧默认BFS不变；map1/skeleton1公开`ecology_expedition`：原high_return完整领奖返营→camp_outer_back→可选活锚边→原E至gate尾。消费者`--scenario expedition`不再截第一次出生R或局部E结束；保原cache指针／modal／重复交互幂等、camp支持，再走第二次R、E十二完整支持与真实gate。

真实seed forest-depth-hollow-02／skeleton1／mix1／cache0的四组均完成13legs：alive758帧；普通真apex后最多双R775；观察一轮右移后再借左移1123；两次真实空弹落R恢复再借活体836。原alive01和新controls03到R539之前，25条Router请求规范字节、538帧位置／HP／精力／空枪／敌状态／钱包／items／claims完全同hash。后继蜘蛛身体伤1保留，四组末HP4/E100，并非全程无伤。

共同R处HP5/E100/空枪2。alive70tick到E、HP5/E85.5、1R／战斗7；普通双R87tick、HP5/E65.5、2R／战斗0。这里E值是原lift_exit完成驱动前快照，同tick post-Motor帧为86.0／66.0，差额仍20，不能混报时序。活体提供真实少17tick／20精力／1枪的可选返程，不宣称永久省精力：后继正常步行使各末精力均100。后续左相需实际等365tick，运动仍70tick；低枪579空中枪0、617落R自然恢复，再70tick到E/E57.5。不同setup的成本单列，不叫资源／相位完全相同。

自然指针奖励选region_health_purple（ADD生命上限1.5、不改位移／精力、不自动回血），coin18／notes0；领奖时HP4仍4，随后营地实际心回血至5。共享资源reader核真实H对象、HP2→1、首free573／R574、20精力与1空枪实扣、独立战斗packet7，不能把H当普通弹精力退款。新reader亦拒绝旧8份局部capture充当完整路线。

[正式出返原件与比较](../evidence/forest_depth_v2/ecology/formal_expedition01/README.md)保存alive01、controls02因main新增未消费factory方法而拒同源并截停import的失败、controls03冻结alive production仅叠phase producer的真实三例。原90s导入／每case240s、route18000／edge1800未改。全链有限技术通过不替代当前退役后新源回归、整区生态密度、独立价值／正常视听／玩家设备认可。

## 当前证据与历史保留

当前消费者为 `tests/forest_depth_enemy_runner.gd` / `tools/run_forest_depth_enemies.py`：4蜘蛛独立case＋3旧charger策略＋4woven策略＋20消融/相位/死萤/低资源，共31逻辑case、45断言。`ecology-retired31-02`实际1997文件copyguard一致，import8.187s/exit0、native3.423s/exit0，Python严格PASS及source_before==after。动作走真实InputRouter，杀怪由真实弹体/Policy；fixture初始搭建不冒充战役自然进入。

首31_01因退役误删蜘蛛仍复用helper，执行case前Parse失败，原件保留；02仅恢复该helper原字节，未改策略/断言/物理。两轮完整raw、producer、source及成员SHA在`build/forest_depth/ecology/retired31-native-evidence.tar.gz`（568301B，SHA256 `51ea4f649b832596f72d5ed2f3d0c0ea52e71411cb6a2178862c9f589f41288d`）。此包是本轮build交付证据，不是已提交的便携发布资产。

历史组合01/02被H线遮挡严格拒绝，03才证明实际H→R；旧原型和producer原件在[便携生态档案](../evidence/forest_depth_v2/ecology/README.md)，不删除旧失败。退役前stress01的37逻辑case/60断言仍只属于旧冻结源；`build/forest_depth/ecology/stress01-portable.tar.gz`保消融原件，`stress01-replay-overlay.tar.gz`保精确bee850基线的82路径差量、deletions及全部1996文件SHA，含已退役原型/UID可重放，不复制整份资产、不倒签当前31。

已有13段自然领奖／回营／第二R活锚／E／藤门四控制，是冻结map1特定源的完整出返证据，不能抹为“未正式出返”。尚未覆盖的是超出root02／map2／level0这一有限完整返程的多相位与全地区内容价值、穷尽相位／低资源／武器矩阵、整区生态独立准入及正常速度视听／玩家／设备认可；不以map1四控制代签图2丰富度。
