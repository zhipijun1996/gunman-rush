# FOREST-DEPTH-02：森林四类生态与局部准入边界

当前保留**铃囊萤、棘籽哨、旧charger森林配方、织棘蛛**四种职责；新制作的独立行为只有织棘蛛。折枝獾因与真实旧charger同构已删除，不算新增生态。合法基础仍是H＋普通单武器／R，不改PlayerController、武器或物理；静态环、支持岸和死敌后的通路保底。

当前退役后真实局部消费者已通过：`ecology-retired31-02` 的31逻辑case、45断言/0失败、Python严格验收、干净原生退出和source guard。该结果不等于新宏观两图、完整出返、独立趣味或设备验收；新生成器仍是实验内容。采用enemy-creator、encounter-director、animation-vfx，作者的自验不能冒充gameplay-reviewer独审。

## 运行职责与唯一参数源

表中为实际Definition默认值；Stage会消费Manifest的`patrol_radius`覆盖巡幅，放置评审必须核该实例值，不能拿默认值代签实景范围。数值由资源/脚本消费，本文不是第二份运行配置。

| 类型／实际资源 | 玩家判断 | 主要运行值 | 状态与伤害 |
| --- | --- | --- | --- |
| 铃囊萤 `resources/enemies/forest_lantern.tres` | 要留作移动活锚，还是先枪杀换安全；何时接近与踢离 | HP2、身体24×24、速度46、默认巡幅60、停驻1.15s、转向预告.5s | dwell→telegraph→travel→dwell；无发射攻击，真实身体接触，正常H目标 |
| 棘籽哨 `resources/enemies/forest_seed_sentry.tres` | 离开刚锁定的支持面／退入实干遮挡；先清哨还是换接收枝 | HP3、身体30×36、警戒320、前摇.8s、attack.45s、恢复1.3s、种子220px/s、弧高70、落区64×30/.4s | idle→telegraph→attack→recovery；锁已落地玩家脚下42px射线的真实支持，实际伤害在旧落区，非飞行擦身 |
| 旧charger `resources/enemies/plains_charger.tres` | 宽枝上等承诺冲刺、射杀或换到另一层 | HP3、身体28×32、巡速90、默认巡幅100、前摇.45s、冲速360/.38s、恢复.7s | 既有idle/巡逻→telegraph→attack→recovery；同home.y水平冲刺，既有身体Policy |
| 织棘蛛 `resources/enemies/forest_thread_spider.tres` | 读一条局部线的时间与空间包络：抢先通过、等收线、换高路或枪杀 | HP2、身体26×28、警戒300、线长8..150、线半径8、前摇.9s、展.15s、持.65s、收.25s、恢复1.6s、之后CD.8s | idle→telegraph→extend→hold→retract→recovery；每周期每目标线伤1，身体仍独立走原接触Policy |

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

两图两seed的具体候选见本轮设计提案`build/forest_depth/ecology/two_maps_ecology_proposal.md`，尚不代签实际坐标可达。核心分配是：图1A宽根charger迫换层，再在E-K给蜘蛛/活萤；图1B换成E暴露-D实干遮种子，K外M宽枝charger，不机械重复A。图2共享J-D边与只共享J节点的seed，把敌压力分给不同实际出口，J/C/P保持安全观察；允许某seed没有某一种敌，不凑8只。

每个正式组合至少比较安全枪杀、活体绕行、已展开/移动相位、低资源等待/退回、死萤固定保底和正常回程。记录真实support、accepted H/R/弹体、Policy伤害与资源。若射杀同时最安全/快/省且其他路线没有目的地或发现收益，删placement而非仅改名字。

## 当前证据与历史保留

当前消费者为 `tests/forest_depth_enemy_runner.gd` / `tools/run_forest_depth_enemies.py`：4蜘蛛独立case＋3旧charger策略＋4woven策略＋20消融/相位/死萤/低资源，共31逻辑case、45断言。`ecology-retired31-02`实际1997文件copyguard一致，import8.187s/exit0、native3.423s/exit0，Python严格PASS及source_before==after。动作走真实InputRouter，杀怪由真实弹体/Policy；fixture初始搭建不冒充战役自然进入。

首31_01因退役误删蜘蛛仍复用helper，执行case前Parse失败，原件保留；02仅恢复该helper原字节，未改策略/断言/物理。两轮完整raw、producer、source及成员SHA在`build/forest_depth/ecology/retired31-native-evidence.tar.gz`（568301B，SHA256 `51ea4f649b832596f72d5ed2f3d0c0ea52e71411cb6a2178862c9f589f41288d`）。此包是本轮build交付证据，不是已提交的便携发布资产。

历史组合01/02被H线遮挡严格拒绝，03才证明实际H→R；旧原型和producer原件在[便携生态档案](../evidence/forest_depth_v2/ecology/README.md)，不删除旧失败。退役前stress01的37逻辑case/60断言仍只属于旧冻结源；`build/forest_depth/ecology/stress01-portable.tar.gz`保消融原件，`stress01-replay-overlay.tar.gz`保精确bee850基线的82路径差量、deletions及全部1996文件SHA，含已退役原型/UID可重放，不复制整份资产、不倒签当前31。

尚未由这些证据覆盖的是新宏观两图正式完整出返、组合保存回程、穷尽相位/低资源/武器矩阵、当前生态的独立机制评审、正常速度视听、玩家与设备认可；不把作者局部技术通过写成这些事项完成。
