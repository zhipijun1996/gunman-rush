> 当前为V3-ENEMY-01真实实现阶段；下文先保留先期只读G0决策，最后“本租约真实实施覆盖”明确最新源、实际测试及未验边界。旧“本阶段只读”仅指先期审计，不描述当前实现。

# 平原 V3 敌人生态审计与单例制作合同（G0 proposed）

任务 PLAINS-PRODUCTION-V3-ENEMY；基线 ed0623000c61287282f89e6b0463937b0afe0aca；分支 feature/plains-production-v3。
本阶段只读源码、写 build；未启动 Godot、图生或修改 tracked。技能 enemy-creator / boss-creator（既有Boss审查）/ encounter-director / challenge-choreographer / animation-vfx / game-quality-gate。
这是实施决策，不是游戏、画面、趣味或独审通过。源指纹见 source_inventory.json。

## 真实生态与缺口

正式行为白名单为 charger/diver/sentry/fan_sentry/hopper；patrol 是历史灰盒。共享 3HP 不代表行为相同，但外观共享明显：aerial统一使用 actors.png 鸟类区域，地面只有 beetle/sentry 两种动作身份。

| 行为 | 实际承诺/玩家判断 | 正式编排与风险 |
| --- | --- | --- |
| charger | 锁朝向冲向巡逻边界；跳过或诱冲后还击 | 宽连接/节点/教程；身体始终存在，安全锚点只抑制攻击不抑制接触 |
| diver | 固定目标点俯冲→返回home | 渡船/铃窗/齿轮接近；与唯一接岸叠加会使跳跃和瞄准同负荷 |
| sentry | 预警后沿旧方向慢弹 | 宽连接/节点；可移出射线或利用实体遮挡 |
| fan_sentry | 与sentry共一状态机，仅三射线 | 后期渡船；增加空中方向压力，但不宜计作完全新机制 |
| hopper | 锁玩家x后抛物跃→回home | thorn安全格/节点；当前预警射线标记落点，主策略为等承诺后换格 |
| guard / moth | 开发候选：前盾/恢复弱点；错拍双射线 | Module Lab和Action Studio，均不在正式池；不能把已有候选改名作为新原创 |

当前真实玩家问题不是缺弹量，而是怪物大多迫使“避开正在运动的身体/弹道”。缺少“自己诱导一块短期危险空间，再利用它已锁定的空档改变落点”的普通敌交互；此缺口是专家假设，需真实输入录像证实。

既有宏观风险：connection枪线与竖向首跳接岸关系，奖励岸敌体占位，回程重复压力。新怪不能铺满全图；不得用更聪明测试驾驶掩盖不合理叠怪。原PR67有效路线、两图默认PulseLv1、一跳、无正式H/W/D/U1/U2授予不变。

## 三个机制方向比较与取舍

| 候选 | 真正的新决策 | AI/资产/集成成本估计 | 风险与结论 |
| --- | --- | --- | --- |
| 芦铃播种者 root_bell | 站位诱导固定地面芽印→选择走出/起跳→射击中断或承诺后换落点；未命中时仍可绕开 | 约100–125分钟：AI/真实伤害25，6态母版及正式动画30，安全单点集成15，专项20，正常速度音画/修正20；独审另由他人做 | 新的空间/承诺关系；保留宽平地和单压力，推荐只制1种 |
| 苔盾滚卫 shield_roll | 正面拒弹→诱冲→背击或恢复窗射击；反冲越背 | 约70–110分钟，但六武器伤害方向/爆心/激光需额外90分钟以上 | guard原型已有，原创增量弱；跨武器hit_direction与直伤sink审计大。不选 |
| 风囊鼓手 wind_puffer | 宣告局部推挤风区→选择借风/逆向反冲制动→在脉冲间落地 | 约180–300分钟；新风区与Motor接受受力、取消/吸附兼容；资产约30分钟 | 牵涉核心移动受力和资源回路，当前冻结边界不适合2h制作。不选 |

不选择换色、加HP、提速度、追加第四颗慢弹。Boss已有地波/投铃，root_bell不是缩小Boss：无抛物弹体，玩家脚底可见固定印记与真实受击中断组合构成新反制；若试玩只有“看到圈就跑”且与hopper没有可观察差别，G0退回而不靠新名字准入。

## 唯一候选 Enemy Sheet

名称芦铃播种者：旧灌溉铃被芦根抱住，收拢叶冠蓄鸣，沿地表发一束根脉，在已锁定的草面爆出一次短芽。体态低而扎根，绝不用既有甲虫/蛾图换色。

职责为中低压力的站位诱导者。AI不读取输入，仅观察真实PlayerMotor位置/接地。最初只放宽且稳定的支线平地，玩家可近岸观察，并有不击杀策略。正式构筑只要求基本移动/一跳/当前Pulse；射击反冲是可选修正而不是强制资源门槛。

状态：idle → grounded_target_lock/telegraph → single_pulse/attack → recovery → idle。未找到同层合法稳定地面就保持idle；不朝空中生成悬浮地印，不跨墙跨层遥击。朝向只看目标，不移动身体。

候选参数只写入新实际EnemyDefinition：telegraph 0.85s、attack 0.16s、recovery 1.20s、activation_range约240、pulse宽52高36；3HP复用patrol_health，不堆血。前摇时固定attack_goal，不持续追踪。范围/相位实际值以制作后的Definition为唯一真值，此文仅候选。

危险判定窄矩形自真实地表向上；玩家跃过36px芽顶或横移出52px扫掠均安全。判定读取真实碰撞查询并经FrameDamagePolicy.submit，使用source_id + _serial唯一event_id；没有特效决定伤害。进入attack才提交候选，重复overlap不重复伤害，既有批次和怪物无敌窗不改。

受击：订阅HealthState.changed里APPLIED且amount_applied<0的真实结果，telegraph内才打断至recovery并清地印；射击请求/碰撞/Damageable.damaged均不足（正式damage_sink早返回不发damaged）。若同tick伤害已进入攻击批次，遵守原eligibility/提交顺序，不能回溯撤销已接受伤害。死亡走EnemyActor唯一Health/defeated/drop；取消、actor epoch更换/失活立刻停止未提交脉冲。掉落完全复用既有敌人掉落表，无专属资源服务。

非击杀策略：从宽起岸诱导一次地印，横移一个身位等芽爆完，穿过原印记；或基础跳跃过芽，落在另一稳定格。击杀策略：预警时真实射击打断，或利用反冲让自己离印记而继续攻击。玩家不必保持敌存活，不依赖命中回能才能离开。

首次见面仅root_bell单独存在，无齿轮/船/额外diver；advanced允许隔离的下游charger但不能同时覆盖同一退路，必须在真实两同时压力上限内。拒绝标签：ferry、only_receiver、low_arch、thorn_cells、boss_seal、merchant/spawn_anchor、narrow_platform、vertical_first_landing。

## 正式消费者与实施owner

真实链：PlainsRegionCampaign/PlainsRegionGenerator._candidate输出manifest.enemies → PlainsRegionStage._ready → GeneratedDemoStage._spawn_enemies_from_plan → PlainsEncounterPlanner.definition_for_behavior → patrol_drone场景Actor/Presentation → DemoApp约330行bind_encounter/FrameDamagePolicy/contact → EnemyActor.physics_tick → EnemyAttackBehavior。

健康/保存：Damageable.damage_sink → FrameDamagePolicy.resolve_batch → HealthState.changed；PlainsRegionStage.capture_state约187行已有state/state_time/cooldown/serial/home/locked_direction/attack_goal/attack_origin/direction；DemoApp约338行恢复同字段。新AI只用这些现有状态量，不改保存schema/存储/核心Actor资源。禁止另存独立pending timer或marker随机流。

| Owner | 建议精确允许路径 | 职责 |
| --- | --- | --- |
| enemy worker | scripts/enemies/root_bell_behavior.gd(.uid)、root_bell_presentation.gd(.uid)、enemy_definition.gd、enemy_actor.gd；resources/enemies/plains_root_bell.tres；tests/root_bell_tests.gd、root_bell_runner.gd；tools/run_root_bell_tests.py；build/region_production_v3/enemy/** | 新行为、Definition验证/工厂绑定、独立表现、真实专项。旧行为不重写 |
| region owner（root协调） | scripts/generation/plains_region_generator.gd、plains_encounter_planner.gd、scripts/demo/generated_demo_stage.gd | 白名单与正式单例配置、已有budget替换而非加叠压、Presentation实例绑定 |
| art worker（由root指定） | assets/region_production_v3/enemies/root_bell/**；全局assets/manifest.json需统一owner | 1张新原创6–8态透明母版，裁切/来源/锚点清单；不得偷偷旧图换皮 |
| evidence/docs owner（root） | docs/quality/records/本轮任务.json、docs/evidence/region_production_v3/enemy/**、docs/handoff.md | 原Harness租约、审查和最终状态；portable目录须先纳allowed_paths |

如root把generator绑定交enemy owner，应在真实Harness租约写明精确路径并停对应并写。第一阶段这些路径均未修改。

## 美术、动画、声音具体请求

需要1张透明PNG新母版，建议2048×1024，8格512×512（2×4），每格完全分离、透明间距至少24px，不带地面背景/字/格线。统一右朝向，根脚锚点(256,440)；角色最大可见包络x160..352、y180..440，最终约40–48px宽、44–56px高。小图识别是芦叶冠/黄铜铃壳/四只短根足，低饱和苔绿、旧黄铜、暖米白，危险部位预告琥珀。新母版需art-director看黄金合屏后冻结；尺寸可由该worker实际调整，锚点随真实图登记。

八姿态：idle_a呼吸开叶、idle_b叶收轻鸣、telegraph蓄鸣(叶冠紧合铃芯露出)、commit根脉击地、recovery叶冠垂落、hurt铃壳偏摆、death_a断根倒铃、death_b叶片静落。若6态足以表达连续动作可合并idle和death末帧，但必须有实际过渡，不以两帧淡入冒充完整动作。脚锚不得随scale上浮；贴地危险是另一层程序地印，不把纹理碰撞当判定。

地印：以锁定点为中心的土黄根脉/虚线椭圆，边界准确包住52px危险宽；0.85s收束进度，攻击0.16s芽升后枯落，recovery立刻无伤害且不再保留危险色。地印不使用纯装饰绿圈假安全。警告线不能盖平台边、主角脚、弹道；镜像、角色hurt/death中断均验。

声音首例可复用既有许可Kenney库，但必须实听并使用已接受事件：telegraph→warning，pulse开始→bell或boss_impact（选其一且实际听）；真实中断→armour，真实HP命中/死亡沿原impact/enemy_defeat。无需新建音频服务或CUES；现有源许可assets/audio/kenney/sources.json。复用不等于已完成专属音色：听不出蓄鸣与落芽差别就标audio待返工，不能图生成后写“完整音效通过”。

## 首个正式落点与采集约束

先从正式manifest筛一段geometry.platforms[0]宽≥560、顶上净空≥180的region_connection；非creek发现、非低拱、非thorn、非营地/Boss接近，离每个端口/观察锚≥130。只替换一个已有lane守卫，保留id和已有drops抽样顺序，不增加RNG调用、不改RunRandomStream。选择以稳定node ID排序的第一个合格可选支线，若无合格地形就不生成并记录拒绝原因，不放宽安全阈值。前后同Seed同策略比较计数/首次顺序。

intro最多1个、advanced最多1个；不自动推广到所有junction。正式manifest必须有behavior_id=root_bell、pattern=ground_mark_interrupt、source module及escape说明。若新V3布局废弃旧connection形式，region owner按同安全合同选实际新节点，不能硬编码旧坐标。

## 可证伪验收矩阵（均为待执行）

| ID | 真实方法/预期 | 拒绝反例 |
| --- | --- | --- |
| E01 空间锁定 | 玩家站稳触发→移动≥1身位，attack_goal保持旧点；脉冲伤害仅旧点，原地不走正例真扣1HP | 目标跟脚移动、空中/墙后打点、只改动画状态 |
| E02 中断因果 | 普通PlayerProjectile经damage_sink/批次扣敌HP，HealthState.changed→取消telegraph；不出脉冲 | 空枪/墙击/重复event/旧epoch伪造中断或无HP下降也中断 |
| E03 两种非击杀 | 真Motor基础横移等脉冲穿越；真Motor一跳跨脉冲；入/出/停稳均连续、无注能 | 唯一落点覆盖、必须命中/必须杀、靠瞬移或关闭contact |
| E04 早死/移开/未激活 | 活体、提前真实射杀、对方goal离开、out-of-range inactive四态均同路线可通/返 | 死体成唯一钩点、死后仍芽伤新角色、inactive被当已解决/必需回能 |
| E05 生命周期 | telegraph/attack/recovery分别暂停、actor_epoch段回退、卸载/重进；核对状态时钟/serial/真实HP | 暂停清警告免费取消、恢复多发、旧request新目标、全场reset |
| E06 唯一接岸反例 | 隔离fixture故意把root_bell/地印放唯一窄接岸，正式placement validator必须拒绝；再在宽台真跳验 | 仅保护玩家中心而敌体封唯一脚位、camera外先伤 |
| E07 正式集成 | 正式新局spawn起步连续到首遇，记录manifest/enemy instance/行为状态、真实命中/伤害/逃离/回程 | Lab演示替代正式、helper通过、数组注册但实例还是旧Presentation |
| E08 动画声音 | 60fps正常速度带音轨连续录像；预警/脉冲/伤害/中断/恢复/死后按时间轴实听实看 | 无音轨、静姿拼片、过渡脚滑、地印不可见、inactive还鸣 |

实现阶段使用专用真实tests runner + 原harness gameplay/art，再交region总回归；全区10root×两图×四策略由root统一矩阵，不由此敌单片外推。现有tools/level_formal.py capture_one支持正常formal输入/kill_from_bank_v1策略；旧策略若不认识root_bell需显式版本化并在冻结旧内容复采，同字节策略收益与内容收益分开。

每次至少留源/命令/退出码/seed/manifest/构筑、输入请求与接受事件、controller资源、enemy state/clock/goal/serial、DamageResult.event_id/health变更、video frame/time。新专用验收必须拒绝删掉真实伤害/预警帧/回程或改enemy_id的证据；实际fixture失败与篡改验证器失败分开。

## Boss真实审查结论

正式map1 Bellstrider真实roll/ring/lob以及低血错拍第二声；map2 windkeeper_storm已有地波→上草台从上打背铃（持续左风）→亮草台追逐/落击，分别改变站位/瞄准决策。封门/登场和phase_transition禁接触，死亡优先/奖励唯一已有合同。没有证据表明必须重构Boss；本轮保留，重点在新V3竞技场入口、镜头和连续战斗重新采集。不得据源码把Boss趣味/画面签passed。

必须观测两场完整正常速度战斗，检查Boss警告提前可见、草台与射线、风中不强迫未授予D/H、phase切换取消、同帧玩家死亡、Boss死后门/保证奖一次。若新场景遮住弱点/平台假台，返工地形/表现owner，不借机改Boss核心。

## 声明与预算

建议实际worker上限125分钟，先一例；Host次数/图生额度沿root总预算。30分钟AI/正式挂接仍无可读独特行为则回G0，图片工具不可用明确blocked不以旧贴图冒完整原创。两轮连续无画面实质改善保留拒绝并停依赖。
作者只可自检design/technical事实；十一维当前全部unverified（design为proposed），独审必须不同真实只读worker，设备/用户手感不代签。


## 本租约真实实施覆盖

宿主实现代理 `/root/v3_enemy_ecology`，专用树 `/workspace/gunman-v3-enemy`，基线 `ebcf348312b2e128e51b8c5b684e402b3a565de0`。原Harness请求任务V3-ENEMY-01、request_hash=074e83d335708e941f88b4aa1efc174c11ae00933b7ae917af89eb48d39ec174，2026-10-15 18:10:47UTC到期。实际worker源/测试证明用独立source SHA清单，未制造新提交号。

已实现RootBellBehavior/RootBellPresentation、新EnemyDefinition、正式GeneratedDemoStage实例绑定、PlainsEncounterPlanner白名单、PlainsRootBellPlacement原预算单例替换和生成器受控调用。`PRODUCTION_ADMITTED=false`，此前正式所有seed没有偷偷接入新敌。只在显式候选验证中替换1个守卫，不增加RNG调用或修改Service/Save schema。

保存细节：原PlainsRegionStage.capture_state真实记录既有state/state_time/cooldown/serial/attack_goal/attack_origin/home；原PlainsRegionState真实JSON往返。新行为首次advance若发现恢复了旧telegraph/attack，则取消旧目标攻击并保留serial和至少一次recovery债。这是新actor epoch的待提交攻击取消，不是暂停重置世界；暂停依旧保留原时钟。完整正式DemoApp卸载/重载仍需晋级后从正式入口连续验证，本次snapshot fixture不外推全流程。

2026-10-15实际五次早期专项中，失败保持：不存在的测试set_active接口；射击真实反冲导致早死后固定65tick观察不足；JSON数值类型往返的字典直接等号；真实反冲使玩家95.3到root340距离244.7超出240感知，第二次warning没触发。修正测试driver为实际存在的active、有限实际步行、复用项目_same_data语义、真实走回感知圈。没有放宽AI范围/伤害/断言门槛。第5轮与第6轮129断言零失败；第6轮补accepted_jump/land事件和五个证据删改拒绝。后续校准/影片将有独立fresh报告，不能借早期129覆盖后改源。

20实际正式Manifest：10种root×intro/advanced，原560稳定宽支线严格候选仅advanced/v3-root-bell-7的一处合格。该稀少结果保留，不提高“生态丰富度”结论。400/440/560双方向Motor校准只说明局部基线单跳/地印/敌体关系，不能自动把正式门槛改为400，也不证明移动船、单向唯一岸或其他构筑安全。

原图：真实image_gen第1call，已实际view正式sentry与Courier母版；六态完全新原创芦根/黄铜铃。请求、参考SHA、原PNG及工具产物SHA在assets/region_production_v3/enemies/root_bell/source。请求至工具文件mtime的实测间隔75.974秒；API内部模型名、成本和usage不提供，明确not_exposed。未使用第2call。没有删背景、补画、像素重绘或旧敌换皮；代码只登记原图6格区域、测量脚锚、缩放与状态过渡，碰撞仍来自Definition。

G0/G1可供独立审查，G2美术/动画/声音、G3完整正式遭遇、G4独审、G5用户/设备保持未验。新原图静态看得到六种姿态，不等于连续动画/美术准入。整体父任务仍review候选。


## 封口实测与证据限制

最终唯一输出fresh：165断言/0失败，五个证据删改反例拒绝；四个纯输出policy反例拒绝；同一个实际成功目录第二次真实CLI返回1，原capture/report/runtime/import字节均未变，且未启动引擎。默认每次新目录，显式既存目录在引擎前拒绝，原生technical/movie各自started marker和capture也拒绝复用。

400/440/560各双方向共6个独立fixture均真实基础跳跨活体、每例至少1个实际pulse、0伤害/0射击，敌体接触包络垂直最小余量93.36px。不是同一实例出程+返程，也未校准容错/低顶/移动地形；正式门槛仍560。正式20Manifest原1个合格候选仍保留，不把局部校准偷换成全种子安全。

实际连续同一敌人影片623帧/10.383秒，1280×720/60fps、48kHz立体声，跳芽→走出固定印记→3枪真实命中（2次打断+唯一死亡）→从死体走过，玩家零损血。正常播放时间没有变速；实际软件渲染录制用了36秒，不宣称性能达标。音轨实际峰值约-3.74dB、非静音，warning5/bell2/armour2/shot3/enemy_defeat1；未实际听音，不签音频质量。作者实际看了完整尺寸warning帧和六帧合屏，但不签独立审美/连续动画准入。

影片属于v1原producer：归档movie_source_v1.zip按原receipt14份SHA逐一核验；其Python wrapper在归档前已改，后由精确逆补丁重建且SHA完全匹配，明确verified reconstruction，不伪称先已保留。新输出安全修复只动三个producer/测试文件，游戏/资产字节未改，差异另存producer_output_policy.patch。影片不冒称新wrapper fresh，最终165专项另有新源独立报告。

早期固定输出路径曾覆盖两次失败的完整帧JSON，没有原载体无法恢复；原失败日志全部保留，限制见limitations.json，不伪造旧轨迹。此缺口已明确上报协调者；新的唯一输出/既存拒绝和实际重复CLI反例防止再次覆盖。G0/G1当前fresh证明独立有效，旧失败完整重放能力不冒充通过。
