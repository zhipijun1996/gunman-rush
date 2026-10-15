# PLAINS-REDESIGN-01：动作与联合遭遇只读审计

源基线 `30f6a825712fbb30e607791c996de142c6757a79`，分支 `feature/plains-designed-exploration`。本报告只作专家设计与源码/保留轨迹审计；未运行新黄金样板，不宣称物理、趣味、视觉、设备通过。采用 challenge-choreographer / encounter-director / level-module-creator。允许改造整区平原；不以旧切片限制缩小本轮目标。Motor、武器、资源、成长、RNG、保存保持用户边界。

## 1. 实际能力与参数来源

正式能力来源：DemoApp → PlainsRegionStage → Player/Controller；`tools/level_capability_snapshot.gd`从真实对象读取 granted_actions。保留的 `build/level_formal/action_after_80/seed_02/map_2/deep/capture.json`初始能力为 `jump,shot_recoil`，当前装备 `pulse_gun` tier1，H/W/D均无。ActionStudio里实现15武器与H/W/D不构成正式授予；随机道具可能改变数值，主路与高奖线应基线空构筑先证通过。

已读动作README、regions_v0.3、weapons_v0.8及action_budget/weapon_feel/all_weapons最新覆盖。S1是基础跳跃+R，探索核心是反作用力位移/平台/地图；S2单新能力、S4替代、S5双移动+U1保持未来合同，不在平原偷授H。

唯一参数源：`config/player_tuning.json`，ground_speed260、gravity2600、jump第一段-666、hold0.13、min_hold0.1、release0、max_jumps1、空中未命中2发、cooldown0.25、shot_burst1100×0.14=154世界单位、ground乘0.55=84.7，身体24×36、半身12×18。普通枪ShootAbility的单发实际走RecoilAbility.execute→Motor.start_shot_burst，因此WeaponDefinition默认burst_duration0.065/recoil_scale0.72并不是普通枪反冲预算，不能据此缩短关卡。

`MovementCapabilityEnvelope`只作60Hz、无障碍、单跳估算；该算法当前输出held150.31高/186.33远/0.7167秒，tap62.27高/82.33远/0.3167秒；没有碰撞/移动落点/串联/实武器语义，严禁拿supports()当可通关证明。原154反冲预算在碰撞时会裁剪，上冲后apex hold0.075与blend0.14来自`WeaponMotionDefinition`，不得复制为另一个运行默认。

正式射击精力：`resources/player/plains_shot_energy.tres`100容量/100开局；`ShotEnergyDefinition`20消耗、有效伤害20回收、地面30每秒、射后0.35秒延迟。地面落地重置空中发数/普通跳使用数，不补满精力。井钟/风铃是真机关，不是Enemy DamageResult，不应声称敲钟回能。一次击中3HP敌人不等于击杀：普通弹伤1，每次真伤害返还20与一份空中射击资格；死亡/无效命中不再返还。主路按所有敌已死或未激活、无命中回能仍可走，低精力在合法岸上等待恢复；从0到一发20至少0.6667秒地面（若射击延迟已清），射后0回到20至少1.0167秒。镜头/慢时改变观测与真实时间，统计不可用tick/60冒充真实墙钟秒。

## 2. 审计结论：动作关系不足，难度证据混淆

`PlainsRouteRecipes`已有16类，但大半仍是到点→跳→落地。`bell_pit`真实双效果可用；`controlled_ferry`写shoot_start/park/restart，但正式interactive_motion只开一次后carrier，没有验证刹停/重开。`thorn_gap`已获技术黄金：held gap→真落地→7tick tap/release→落地；这是两种输入时值关系，但无敌人且不应被无限复制成地区身份。

`PlainsRoomGrammar.phrase`把每个模块夹在SAFE之间，available只计预算；此类隔段全复位既不能证明连续动作编舞，也不应强制保留每个重复安全模块。它服务旧branch生成，正式两张connected_region的路线编排应以PlainsRegionGenerator._horizontal/深层loop及PlainsRouteRecipes为真实消费者；仅编辑grammar JSON不算改正式地区。

现有正式enemy ecology：charger(0.45 telegraph/0.38 attack/0.7 recovery/360速)、diver(0.6/0.35/0.9/200速)、hopper(0.45/0.7/0.7，弧线90高)、sentry(0.65/0.1/1.0，240速默认投弹)、fan_sentry(0.65/0.1/1.0，210速/1.4寿命/330感知)。通用感知180、protected_radius45、敌碰撞28×32、HP3。生成实例会把patrol_half_width覆为记录patrol_radius（35等）而不是Definition100；diver窗口还覆dive_depth115。攻击locked_direction在telegraph开始锁定，_can_engage可因距离/视线/protected_points退出预告；可用“引出锁线→换层/穿过恢复”策略。敌人无地面重力，不可凭想象设计自然坠坑。

每地图随机关按window模式最多intro2/advanced3，之后长连接随机sentry/charger、各junction随机charger/sentry/diver/hopper，并把tutorial charger压在主线上；总上限26/36。位置判断只排patrol_box与slab/saw，不排玩家完整落点/起跳/对向回程，enemy.escape文字不是运行保证。_can_engage保护anchors不保护敌人巡逻身体接触；所谓安全观察台必须同时验敌接触包络，不靠45范围标签。

保留实际报告统计：baseline_80_v2=16达目标/58death/6policy_failed；action_after_80=18/56/6。这个自动驾驶只沿既定geometry driver去目标，不判断敌AI，不瞄敌、不选择击杀或诱导策略。sample baseline/map1/return在area_2_0同一敌接触1805、1848、1891、1934、1977tick反复扣血；另一sample map2 fast两发shot，5次damage全target=player，含gear窗口/area guards。它是坏策略的反例，保留为自动试玩覆盖漏洞；不能得出“关卡普遍不可玩”或“2条改善后地区趣味通过”。同时不能反过来把所有death推给driver：碰撞卡住、落点敌堵死、观察区接触伤害、必经低能无解必须逐例验证。

## 3. 黄金A：主路短“井铃借势—远岸诱导”

复用`plains_windchime_well`完整几何，不新造系统：bounds640×420，左岸x0..280/floor300，右岸380..640，坑危险x280..380/y390..420；bell(330,350)，gate(490,30,24,270)。开局观察x140..230；实际takeoff265（旧driver）/277（单模块combo），跳14tick后朝铃释放，同一次实体碰撞开gate并反向上冲。`tests/shot_latch_module_driver.gd`现有combo断言：latch.is_open且10tick后y比发前高>100，exact1 shot与真落点；因此选它作首个真正射击“双重作用”黄金。不要把铃后敌人也说成同一弹受击，弹体会在铃处提交并消耗。

主路一拍决策：看见井铃与远岸diver→选择先地面开门再宽容单跳，或跳后朝下开门顺势升高；接近远岸时在安全接收范围落定，再看diver预告，等其锁向旧站位离开、穿恢复窗口。diver候选home(530,177)、radius35、depth115，直接取当前生成well窗口语义，保留右岸x380..470为另一落点。若HP/相位测试发现diver可扫尽接收区，将home向出口侧移动或移出本井，调整遭遇位置；不能让玩家在空中必须打死3HP敌才能落地。

双策略：安全主路先开门→常规跨100井口→看预告/停；熟练玩家空中开门+上推→修正落岸→避开俯冲，不强迫同一解。敌alive/moving-away/dead/inactive均用这条地形通过；尸体不承担钩点/回能/开门作用。低精力必须岸上等20，空中失射应落回左岸或右岸合法点，而非必须命中恢复。错误朝向/铃射偏保留为应失败输入例；主路可返回安全岸重试，不偷偷开铃。

镜头：在takeoff前同屏显示bell、门与380..470接收带，diver预告要早于承诺；拍摄native1280×720与mobile实际视口，不能只凭bounds640判定。画面允许短安静间隔供察觉门已开/落点已变。回程门持久开启，同body右岸395→左岸250，无再开门/无敌复活；若初次由右岸进入且门闭，走真实access_bodies返回铃，射击原点守卫已有必失败例。

## 4. 黄金B：高奖连续“反冲登阶—新视线—控渡—撤离”

先复用`plains_recoil_step`，floors(0,1160,260,40)/(260,970,260,40)，190高度差，入口(20,1142)/出口(500,952)。旧driver move170→jump→18tick射DOWN→9tick后jump_release→move400→真落地。此动作依赖反冲升高，不依赖敌人；这是和A“开门+升高”不同的关系：选择射击时机获取新视线/稳定高台，后续再对远程钟。保持上岸宽260避免缩台伪造难度。

可选联合攻击版：在下岸home(230,1142)安排charger、radius35，并把观测/起跳x170移至经Motor验证的x180..195候选。玩家从charger左侧接近→诱出方向锁定→跳高→朝下/右下击其身体并反向升高到右高台；同一shot真实DamageResult与Motor上冲应记录shot_id/packet_id对应。charger仅在lower岸巡视/冲刺，不能覆盖upper接收面。它只有3HP，普通一枪不全杀：允许留存后绕过，或岸上保持距离三枪击杀后用同样空中反冲登阶。射偏/敌已走开/已死时仍能用空射154位移过190阶；伤害返还只是提升容错，绝不写最低完成所需回能。此新攻击版坐标是候选，先G1测真实projectile muzzle/body轨迹与collider遮挡，不宣称已证。

然后使用`plains_remote_sequence`或缩减为一次高位remote_bell，避免两道钟重复主路A。原remote_sequence全宽900基础floor300，高位oneway x440..600/y210，baffle x360..384/y140..250；第一铃(100,220)，第二铃(520,170)，gate780。真正关系是“先取得高位视线→再可打远程铃→开放前方出口”，不是机械jump次数。高奖线先在upper真实地面恢复/观察，才衔接远程钟；若串联预算过长，删第一铃/第一gate转为single remote方案，保留单个视线依赖和探索发现，不堆两个同式开关。

第三拍复用`plains_bell_ferry_control`：banks x0..200与600..800/floor300，ferry中心start(240,312)→finish(560,312)，120×24，travel2.5/dwell1.2秒，period7.4；ring(130,220)开/停运动。选择完整搭乘的安全策略，或从岸上先停车→乘上→可见铃重启→落接收岸。现有carrier只选fresh<0.25泊位再上船，不能拿它证明任何相位都自然能追船、停车后都能再开。高奖支路应该记录park/restart真实is_open/motion_running/motion_clock而不是只看门open。

可选sentry放岸边支撑台，home例如(650,282)与下层往返空间经过扫掠准入；玩家上船前在岸上引出locked aim，移到另一层/离开原线后乘船，或先3真命中击杀再骑船。不要额外放diver+fan crossfire占唯一120宽平台；稳定泊位的压力不等于平台途中强制同时双摇杆瞄准/跃迁。sentry生存与dead/inactive版本都保留，不杀策略必须穿恢复窗口。压力不是“敌数量2”，而是敌的锁线与渡船是否互相影响承诺时机。

高奖线收益复用现有tier high/region_top预算与领取账本，路线目标为到连续上层缓存→异路oneway下撤→短路回到已探索junction；不能随机刷道具才可继续，也不新增奖励总量。需要展示缓存与回落出口，让玩家清楚绕路价值。连续性定义为同body/同session不重置，从step后实际ground energy进入remote/ferry；允许一次安全观察恢复，这是战术落点，不是每模块夹一整屏SAFE。

高奖线保留三种选择：commit整链、登阶后安全返下岸、获得奖励后下撤不重爬。错误时机应可从合法站位撤回；真正精密大师线可选，不能把基础主路一并拖长。若现有生成axis/布局不容step→remote→ferry，则先只证step→remote二拍；“少量新模块”最多一个共享紧凑观测/接收平台，不新造玩家动作或额外能力。

## 5. 黄金C：安全观察/恢复不是加机关

在fork/营地或B高位落点设置一段160..260宽的真实支持地面：purpose=看见两支目标/观察下一机关相位、恢复射击精力；观察对象=铃连线/渡船往返/敌锁线；恢复=原30每秒、射后0.35延迟；下一拍=可选承诺；回程=已开门和掉落不会reset。宽度是设计候选，按24×36身体/两端接触扫掠留margin后准入。

敌body与projectile包络不能扫进观察位置；_can_engage的45保护点只限制新攻击，旧弹/巡逻身体仍需真实碰撞证明。营地不要把安全留白重新命名却仍放charger在站位上；观察区可以无输入，无敌无机关也有效。反例：没有看见任何下个目标/无真实恢复且只是长绿桥，应缩短。无互动距离和真实墙钟时长分开，只报目的是否实现，不给AI趣味95。

## 6. 可实现函数包与验证入口（推荐优先级）

P0：在既有`tests/level_formal_trace.gd`新增显式不同策略helper（仅测试，保留旧baseline）：`observe_enemy(enemy_id, safe_point, max_ticks)`读取真实attack.state/locked_direction/health；`cross_on_recovery(...)`等待实际telegraph→attack→recovery后执行原跳；`aim_damage_and_recoil(enemy_id, expected_landing, ...)`通过router给shoot_release，不调用try_fire、不改坐标；`shoot_until_terminal_from_safe_bank(...)`每次等0.25并验证真实DamageResult，允许敌走离后重新瞄准；bounded无解返回diagnostic。候选函数不能用`_can_engage`预测替代实际state与扫掠。

P1：先把A同弹开门/反冲与敌phase联测。复用ShotLatchModuleDriver.traverse(combo=true)、PlainsRegionTrace.bell_well(forward/reverse)与`tests/plains_exploration_module_runner.gd`双向8phase入口；正式敌消费者用DemoApp/PlainsRegionStage/GeneratedDemoStage._spawn_enemies_from_plan/actor.bind_encounter，不能只在assembler挂空EnemyMotor。实际输入路径`router.request_action→Controller→ShootAbility→Projectile/DamagePolicy→ShotEnergyPolicy→Motor`全保留。

P2：联测B的step→remote同body真实出口资源，然后ferry与回撤；已有BranchModuleDriver.recoil_rises、plains_cohesion_motion.remote_sequence、plains_interactive_motion、plains_exploration_motion.carrier是基础。需要补`traverse_ferry_toggle`真实start/park/restart，候选低能等待必须在银行，不靠ferry下无支撑回能。仅selector插入Recipe/定义不够，实际PlainsRegionGenerator装配、镜像/height/reverse状态要接上。

P3：推广路线角色：快路3..5个有判断的短拍之间合乎目的观察；探索线连到medium缓存与营地；high/top连续line异路下撤；区域完全回程无需重演每个长挑战。本建议没有证明理想拍数，以真实路线节奏/镜头/player反馈校准。正式两图都保持连通与不同目标价值，不能只做离线黄金。

测试入口：`tools/run_plains_region_tests.py`15 suites（module八phase两方向；pressure/lifecycle/campaign/boss等），`tools/run_generated_consumer_tests.py`真实共享对象；`tools/run_plains_action_golden_tests.py`原held→tap往返/0与100energy/删bank负例；`tools/foundry.py build --profiles base --count 6`与`tools/level_design.py golden`只development技术；`tools/level_formal.py --maps 1 2 --strategies fast growth deep return`Live DemoApp有完整敌人/攻击/接触/奖励/镜头，此脚本exit0只保证capture integrity，不保证route_reached或无伤。当前run_level_formal_tests也只签完整捕获，必须另外断言路线成功及适用安全门槛。

ActualInputTrace字段实际散在level_formal_trace/level_design_trace/Foundry replay，仓库未发现这个同名类。不能新增一个空同名容器冒充动作证据。复用frames/input_requests/accepted_events/collisions/runtime；关联DamageResult source/target、shot accepted shot_id、packet、精力与air_shots变化、health、enemy.attack_state/serial/clock、镜头screen_center/zoom/viewport。请求不是接受，InputTrace中的action不能当真实攻击成功；掉血失败若driver仍继续move_to可能在原地消耗整命。

## 7. 黄金矩阵与保留反例

每黄金至少：forward/reverse×initialenergy100/0×所有动态相位0,.125,.25,.375,.5,.625,.75,.875；双锯还要独立phase组合，不能只两锯同phase八次。A用closed/open/已敲铃回程，B渡船start/stop near/stop midchannel/restart，不重置clock。相位fixture是一次初始设置，continuous itinerary中不调相位/身体/资源。

enemy四态 alive/moving-away/dead/inactive × kill/bait-and-cross两策略：主路/G高奖均不把杀敌回能或永生目标作为必要条件；dead必须沿合法攻击杀死然后接续同body实跑（另可保留清晰标注的边界fixture）；inactive不是disable证明正式成功，而是主路对目标不参与的稳健测试，随后同正式alive消费者回放。每态采enemy+player全身和危险相对扫掠，身体碰撞、墙顶/门/oneway/移动platform携带不可用点射线代替。

合法入口停稳/接260跑速/射冷却0.25未清/残余recoil>0分别测。port默认maxnormal330/maxrecoil0/maxcooldown0，因此刚结束射击未落稳不能假装端口满足。降低站位margin或删除port断言去通关均不准。串联100→A消20→落地按实际时间恢复→B消20→下一拍资源不足是真失败；低energy0应先岸上等而不是由driver“每模块满补”。

必失败负例：删真实receiver collider（原golden已有29/4保留）；铃射偏±角与墙遮挡；无铃命中不能开门；hit target已死不回能；未授H请求不构成替代；在空中精力<20拒射且不补；两次shot间隔<0.25被拒；各模块可过但串联无安全恢复且资源不足必须REJECT；ferry最坏相位/不可见唯一落点必须REJECT；unique landing被活敌全覆盖必须REJECT。负例失败应是预期合同失败，禁止把断言改成宽松“附近即可”。

同条件对照保持既有10seed×2map×4strategy80原策略、源Hash/Manifest与捕获原件；新增kill/bait策略另列，不用新策略分数覆盖旧死亡。按fail tick关联碰撞/target=player事件/敌位置/accepted输入，分类：driver无敌策略、driver坐标镜像/泊位bug、地形/敌联动死路、资源不足、不可见预告、用户控制负荷。真实“内容不可过”需要至少一种合法有界策略穷尽或构造必经无解反例；“driver失败”需要同Seed同能力同相位的合法替代策略真过证明。仍有未归因必须unverified。

特别保留：原formal map1 return同敌每43tick接触反复扣血样本；map2 baseline仅2shot且全伤害target=player样本；新版18/56/6不能降标改成全部passed。独立正常速镜头与键鼠/实体手柄/手机双拇指证据另门，headless不签输入学习、公平、趣味、审美或设备。

## 8. 收束后的实施合同（给root）

主路最终首选well→low_arch→短观察岸，两短语足够：well takeoff265、jump14tick、向真实bell坐标射、真落430；arch正向275/反向365起跳，7tick释放，然后真落地。两者floor同为300/bodycentre282，不改Motor。前者是射击开路+上推耦合，后者是释放时值服从顶棚，连续真实落地分隔，两种动作关系成立。gear可作为第二图变体，采用先实际读wheel离开起跳侧再跳的现有twin_gears关系，不把每条路都叠全。

高奖至少step→remote两短语完整连续；ferry为观察后自选第三拍，在两拍没证之前不强行拖成四段。每个Phrase必须标起止accepted event tick、入口正常/反冲速度、精力与cooldown、shot命中/机关提交、落地支持；总体同body/session没有重置。

Driver最终功能块按真实状态循环实现（不按预录固定tick“假装会打怪”）：

1. `nearby_threats(path_aabb)`从formal_stage.enemies和enemy_manifest取得health、world collision、attack state/home/goal与活动弹体；限定策略消费者读取，不写AI。`safe_stop_before_crossing()`必须选择有全身支持且不在body/patrol/saw/projectile扫掠内的bank候选，不能刚好停在敌人身上再等能量。
2. `kill_from_bank(enemy_id, bank_interval)`：站在可见、可回撤合法岸，router shoot_release使用KeyboardMouseAdapter.world_direction(canvas×enemy真实位置)，至少0.25冷却/20energy才发。每次以shot_accepted确认，再等待damage_committed target为该敌的真实receipt；一次只1HP，最多6次有界miss重瞄，死亡时停止。地面反冲84.7要求bank留真实背侧空间，逐frame纠正轴，不覆盖身体坐标。敌不可见先换合法支撑视线，不穿墙自动射。低精力只合法ground等。若阵型不能安全三枪，返回unverified/改选bypass，不注入资源。
3. `bait_then_bypass(enemy_id, takeoff, receiver)`：选在180感知内、45保护anchor之外且不在charger home±真实radius/body扫掠内的bait；看到telegraph真实state后保存attack_serial/locked_direction，移回避开锁线的实际safe bank，等同serial attack/recovery，再调用existing jump/low_arch/carrier。diver/hopper必须按真实attack_goal/attack_origin与返回位置判定接收区是否清空；sentry要保留已发projectile，即使其state recovery也不能直接认为安全。不能仅“等0.7s”就强行commit；bounded超时返回具体原因。
4. `make_enemy_state_by_inputs()`：alive为自然起始；moving-away通过上一步合法bait使敌在attack/recovery离开接收/目标；dead通过kill_from_bank同body三次真实伤害；inactive通过真实移动到activation_range外或进入遮挡bank让_can_engage退出，记录actor仍processing/health>0，不是set_physics_process(false)。然后沿可达连接再次进入挑战，不能直接teleport到测试入口。若某态从路线入口无法合法制造，保留explicit fixture单独标边界测试，并不签正式通关。
5. `follow_semantic_edge(...)`解析当前Manifest的模块/port坐标，避免well/arch/gear helper漏镜像，收到segment_returned立即记录失败/停止本条原轨迹，不在重生后仍朝旧x行走消耗生命。保留同driver的baseline盲走模式与kill/bypass新模式；禁止自动绕过正在测的edge，除非策略明确是选择另一正式连接且把路线差异报告。

同新driver必须copy到`30f6a82`baseline隔离worktree和V10项目；冻结相同input策略代码Hash，再跑同seed/map/初始能力/phase，且相同目标与奖励选择。分别报告olddriver baseline→olddriver V10的内容差异、newdriver baseline→newdriver V10的内容差异、old→new同版本的策略差异。不能把策略提高通关率偷记为新地形改善。当前baseline80/beforemovie执行中禁止改其source/hash；此审计没有写生产或tests。

原V9 187/0与删bank29/4测试：继续在冻结V9工程实际跑，不能编辑旧断言以适应新V10布局。V10另建golden入口/新Manifest版本断言、同级全身/双向/0energy/连续性与敌四态；保留原V9 failure和历史版本reject。版本迁移会使旧正式布局hash失效，需明确拒绝旧Manifest，不能把文件只改version然后重演成V10。

建议实施路径分工：动作/模块实施者可写`resources/generation/modules/{受影响平原}.tres`、`scripts/generation/plains_route_recipes.gd`及必要catalog/shot_latch配置；区域编排者专写`scripts/generation/plains_region_generator.gd`/formal装配与合法EncounterPlan定位，勿多人并写generator；Driver/黄金验证者专写`tests/level_formal_trace.gd`、新的V10 golden runner与验证工具，不改Motor/武器/资源；场景/镜头实施者写正式scenery/局部镜头cue，以前两者Manifest为输入；独立审查只读全部源和轨迹，保存build证据。各自报告可写各自build/plains_redesign子目录，生产diff归root整合，用户体验/真机仍不得代签。
