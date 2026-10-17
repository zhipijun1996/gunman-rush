# FOREST-DEPTH-02：五类行为与可选跨枝探索

当前基底是铃囊萤、棘籽哨、旧 charger 森林配方与织棘蛛。新版 v9 在地图2的一个共享庭院分支加入真实跨枝移动体与同一宝箱的异路回程；它提供可选运动表达，**不主张比普通强解更快、更省，或已经完成整区生态丰富度**。折枝獾、旧同轴停驻者、上层 Seed＋Lamp 和侧环 HR 均已淘汰，不能用新 ID 或技术通过给它们翻案。

全部动作仍使用实际 InputRouter、PlayerMotor、普通单武器、弹体与 FrameDamagePolicy，不改变玩家物理、H 射程、HP 或保护窗口。作者实现与自验不等于独立玩法评审、玩家认可或设备／听音验收。

## 参数及真实消费者

资源和脚本是唯一运行数值源。Stage 会用 placement 的 `patrol_radius` 覆盖实例巡幅，下表默认值不能代签每个放置。

| 类型／资源 | 判断与状态 | 实际运行值 |
| --- | --- | --- |
| 铃囊萤 `resources/enemies/forest_lantern.tres` | 保活作移动 H 目标或先枪杀；dwell→telegraph→travel→dwell | HP2，24×24，速度46，默认巡幅60，停驻1.15s，转向预告.5s；自主移动，无发射攻击，警戒距离不适用；身体伤1 |
| 棘籽哨 `resources/enemies/forest_seed_sentry.tres` | 读已锁定支持面，离开落区／借实体遮挡／先清；idle→telegraph→attack→recovery | HP3，30×36，警戒320，前摇.8s，attack .45s，恢复1.3s；种子220px/s、弧高70，落区64×30／.4s；落区伤1、身体伤1 |
| 旧 charger `resources/enemies/plains_charger.tres` | 宽枝上等承诺、射杀或换层；巡逻→telegraph→attack→recovery | HP3，28×32，巡速90，默认巡幅100，警戒180，前摇.45s，水平冲速360／.38s，恢复.7s，身体伤1 |
| 织棘蛛 `resources/enemies/forest_thread_spider.tres` | 抢行、等收线、换高度或枪杀；idle→telegraph→extend→hold→retract→recovery | HP2，26×28，警戒300，线长8..150／半径8，前摇.9s，展.15s、持.65s、收.25s，恢复1.6s后 CD .8s；线伤1、身体伤1 |
| 跨枝移动体 `resources/enemies/forest_crossbranch.tres` | 观察实际出发，借活体反向 R、普通双 R、先清或不取可选奖励；rest→telegraph→flight→settle | HP3，28×32，rest 1.8s，预告1s，settle .35s；g620，上行初速−540、回行−220，水平速度由真实当前位置与目标岸解算，实际碰撞积分；单段预算2.5s、受阻回稳内移100px/s；身体伤1。不是原 hopper 的 home.y 弧跳，也不使用空 transfer_points 接口 |

身体伤害由 `DemoApp._contact` 装配 `DemoContactEmitter`：amount1、重复接触间隔.7s。Policy 的普通怪物 iFrame .65s 独立于每个接触源；H 保护仅针对当前真实接触目标。籽哨落区来自真实 `ForestSeedProjectile`，蜘蛛线与身体独立提交 Policy，不能把绘制频率当扣血次数。

`DemoApp` 的 `protected_points` 来自 **`stage.anchors` 语义区域位置**，再加实际 spawn 与 exits；不是 `hook_anchors` 固定钩环，也不包含所有奖励。assembler 排除 boss／challenge_reward 等非观察 area。现籽哨／蜘蛛使用真实 protected_radius45 与当前地图并发上限1／2；蜘蛛还以线半径8扩张保护线段。因此线距 C 必须大于53，不能仅以中心 LOS 判可激活。cache80、camp90、完整 Player／敌身体／巡逻扫掠和 spawn150 是生成放置的另一层排除，不应混成 Policy 无敌区。

## 实际空间关系

`enemy_mix` 真正选择根盘 charger＋冠枝籽哨，或根盘籽哨＋冠枝蛛线；下方活萤另提供 R→E 可选返程。实例根盘 charger 为620／804、巡幅25；籽哨为620／802；冠枝籽哨1150／558或冠蛛1130／562。旧1050／380上方活萤已 DROP，现下侧1050／680、巡幅45只证明 R→E，不宣传它能穿 one-way 冠台成为上方旁路。map1 入孔蛛310／554、巡幅0、线320..368／540是低压时机教学，不算高级 H 战斗或整区密度。

地图2 v9 的 D 选择由实际 topology 流第五位决定，且只在 skeleton1 启用；root00 命中。原生成器将**同一个**奖励移到西侧宽枝，正式 placement 是 `hollow_route__crossbranch`，两岸由 `shore_rows` 记录，不由测试再次注入。N 支撑 x60..280／top468，奖枝 x−610..−320／top268，body 目标76／452与−350／252；间隔380、上差200。奖枝的低回岸、宽 root-catch 与两级真实恢复台阶保留，敌死后普通路线仍存在。回 W 后继续原北庭／洞／藤门，不把领奖岸到达当完整目的。

D 同时把原下根 idle 内蛛移到实际 C 出口 x1130、floor=C.y+18，线1085..1115／C.y；不增加敌数或修改 HP／频率。C1030±7完整接收仍在线外，左侧是观察区。该位置的身体／线可用普通跳、等待或枪杀处理；当前正式 H 片只证明一次实际接近跳过，不以一次无伤签全相位公平。旧 line1070..1100 因距 C40小于53而被保护拒激活，只属于冻结12原源，不追签为有效蛛线。

所有支撑分别按 body、H 钩头和弹体合同核查：one-way 可让身体从下上穿，不能据此说 H 头或子弹也能穿。唯一接岸不叠蜘蛛线、冲道和落区；遇到保护／恢复空间不足应删 placement 或重做共享关系，不以缩保护、加 HP／频率补数量。

## 六个差异问题

1. **玩家获得什么目标？** 下侧活萤是取奖后返高位门的可选资源路线；D 是另一方向的可选宝箱探索环。普通主路仍可不取 D，不把一次无目的上楼当返程价值。
2. **为什么不站桩清场？** 普通弹确实是合法解，命中会真实退款，不能按名义每枪20简单累计净成本。D 的强普通双 R 比 H 更快；保留的是活体接触、来侧踢离和反向 R 的不同运动，不宣称必须保活或射杀被全面支配。
3. **换高度是否真实？** charger 仍是水平承诺，不作为跨枝新品。D 在两块不同高度、不同水平位置的真实平台之间 `EnemyMotor.move_attack`，碰撞决定终点；不是每帧搬 StaticBody，也不传送玩家或 NPC。
4. **H＋R具体做了什么？** 真实头扫掠命中移动体后锁存来侧，body 接触通过 Policy 造成1伤；当前成功方向先向右上踢离，再由实际首个 free 状态射右下，反冲左上到奖岸。固定 hook_start 与动态目标 tip 不能混算；07不同方向虽真实锁左，也因物理受阻失败，未重试包装成成功。
5. **失误／死亡如何恢复？** 受阻保真实位置与重力，落实际静态支撑后以内移100走到完整身体支持，三足射线重查；原岸恢复后自然 settle/rest 再出发，非原岸可停止该迁移线。2.5s失败仍不悬空、不忽略 Player、不瞬移。死敌保普通双 R／低岸；并未穷尽所有误时和资源状态。
6. **保存／暂停是否改变动作？** Actor 拥有 HP、Stage 拥有位置；版本化 depth_state 保存实际 phase、velocity、shore、clock、预告承诺和恢复债务。先验证全部类型／有限数／几何／状态组合，再原子应用，不能借重载回岸或重置 HP。菜单冻结与取消不同：取消飞行保速度进入 cancelled_fall，实际落岸后恢复。当前实际保存覆盖 flight 和死体，不宣称已逐状态／逐资源穷尽。

## 当前实际证据与边界

- **基底局部**：退役后31逻辑case／45断言严格通过；不包含 D。原4蜘蛛＋3旧charger＋4 woven＋20消融／相位／死萤／低资源的结果保持原源范围。
- **下侧活萤**：八个局部控制含强双 R、另一真实相位、死锚、HP1接触致死后的动作恢复与空枪先落 R 恢复；不能叫空中无枪救援。[正式 map1 四控制](../evidence/forest_depth_v2/ecology/formal_expedition01/README.md)保自然领奖、回营与原13段门尾，仍只属原冻结源。
- **有目的普通跨联**：无侧环的 map2 `reward_crosslink02` 两完整组，450帧／15请求同 R 前缀，活萤70tick到 E、普通双 R87tick；共同 E→C 用真实满跳后1R共60tick。门719／736，HP4同、末精力100／95.5。E处85.5／65.5是 driver 读上帧，真实 post-Motor 为86／66；不是净全途消耗。它不代签所有新 v9 seed。
- **D 强反证**：旧04／06漏正式 outgoing contact，HP／同风险结论撤回，动作和多证据退款限定保留。补正式接触后的10组件真实伤、碰 Player、回稳后两岸循环；10 H完整1044帧，11正常先垂直清身体的强普通969帧，末 HP／钱包／claims／资源同。10原外层把独立组件误入共用前缀比较而FAIL，原报告不改签；11只补尚未执行的普通，外部reader离线接受三原件。普通不再是故意碰 rest NPC 的晚 coyote，75帧优势原样保留，不据局部到岸精力夸 H 效率。
- **正式 D 保存13**：唯一真实 App flight重载、menu暂停、取消后物理落岸再循环、三发普通弹 Policy3→2→1→0与死体重载；26检查、16畸形状态原子拒绝，strictPASS35.295s，2043源文件前后完全同。12真实 reload 被 Queen inactive 初始旋转角保存校验拒绝并保失败；root 仅在 band.configure 初始化真实角度，原守门未放宽，独立窄审接受13实际因果。此不是 D 所有 phase 保存穷尽。
- **正式 D 正常片14**：与13全部生产字节同，仅 child 在 C 前读取真实蛛位置起跳；完整18段／1152物理帧、1168视频帧／60fps＝19.467秒，strictPASS75.973s，2043源前后同。实际 W→N107、北营出返119／131、活H头请求197／body217／freeR232、奖岸281、cache321、返W534、C蛛jump1005／apex释放1028、门1152；wallet0→18，实际 region_health_purple，末HP5／E100／空枪2，全途玩家 committed damage为空。电影是自然当前前缀，不是旧107帧后直接插候选。原 AVI、MP4、16原尺寸关键图和全片2fps39样本供独立读性评审，不冒正常全速播放／听音或玩家认可；整体内容价值仍按独评限定。

14的实际返W后BFS选M，故未捡扩容后可用的北庭心，末HP5如实保留；当前main仅将建议growth行程改走既有N→S短接，不改物理世界，不把行程重排算新增随机内容，等待最终CI验证新行程。

[正式D保存与完整影片精选原件](../evidence/forest_depth_v2/ecology/formal_crossbranch13_14/README.md)含可直接观看MP4、12失败、13／14raw、完整库存和成员SHA。原始D12／13／14的全源快照、copy／source inventories与逐文件 SHA 仍在 `build/forest_depth/ecology/f2-crossbranch01/lifecycle-plan/` 和对应 `forest-v9-golden12/13/14` 冻结快照。13→14只变子 trace 的正常应敌驾驶；不能把13生命周期当14完整路线，或把14单条电影外推随机池全部表现。旧原80／v7影片是各自历史源，不能改签为 v9 新敌消费者。

## 淘汰历史与保留原件

折枝獾与旧 charger同构，生产行为／资源／scene／分派已删除；旧同轴 leaper 两失败、types-first未原生验版本及退役源码仍封存，不因新 D 跨枝行为而复活。入口蛛三相位只获有限低压教学；西庭高枝33空弹失败与后继同高三法、C地哨普通跳129优于杀188／等403均保留，后两放置 DROP，不用于敌数。

上层 Seed＋Lamp的完整 LOW607／HP5／E100／0R对 live603／HP5／E72.5是真实弱价值反证；额外动作只省4帧，不以影片技术成功救该组合。[上层退役档案](../evidence/forest_depth_v2/ecology/upper_retired05/README.md)保局部01–06、正式失败、五组最终原件与正常片。旧 map2 B 的 R→E→D→M→S→C无新增目的绕行也 DROP；[侧环退役档案](../evidence/forest_depth_v2/ecology/crown_reverse_retired01/README.md)保 sideHR93对 ordinary1R60的三控制。

[早期便携生态档案](../evidence/forest_depth_v2/ecology/README.md)保组合01／02遮线失败、03实H→R及退役原型。原37／60 stress不能重标当前31／45；31_01误删共用helper的Parse首败与02恢复原字节通过也不覆盖。全部旧证据保原 producer／scope／SHA，不删反例，不以“当前有五种怪”替代树根、庭院、树洞、冠枝和回程上真实观察—决定—执行—恢复的遭遇统计。
