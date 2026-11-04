# 平原连续黄金：PLAINS-REDESIGN-GOLDEN-01

当前为 development technical_slice / review，content_complete=false、production_pool=false。实施者 `/root/plains_golden_worker`，分支 `feature/plains-designed-exploration`，内容版本 `plains-redesign-golden-v1`，基线 `30f6a825712fbb30e607791c996de142c6757a79`。采用 challenge-choreographer、level-module-creator、encounter-director。依据整区重设计规格与完整动作审计先做黄金，再交原 production_loop 独立审查。

运行入口：`python3 tools/run_plains_redesign_golden_tests.py`；直接 Godot 入口为 `bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/plains_redesign_golden_runner.gd -- --output=<从未存在的JSON路径>`。去掉 headless 可观察技术 fixture；该入口自动回放真实 Router 请求，不提供设备实操验收。`--delete-far-bank` 删除真实接收岸 collider，必须失败；`--smoke` 仅单相位定位，wrapper 不接纳 smoke 为完整证明。

## 设计目的、备选与能力

普通黄金让玩家观察井底铃与门的关联，起跳后向下开枪：同一枚弹体负责开门，同时其反方向推力抬高身体，落到井对岸；下一拍看到低顶与地面齿轮，改用短按七帧释放，再真落地。两者的差异是射击方向与高度耦合、跳跃时值与顶棚耦合；不是更换两个模块名称。

保持现状方案为原 bridge→arch held→tap，仍有价值但没有同弹机关/反冲依赖。替代方案先站岸敲钟再普通跨井，可以返回但不会证明空中同弹耦合。选择现有 well→arch，不改 PlayerMotor、武器、资源、RNG、保存、正式配方或模块池。高奖先实跑 step→remote_sequence 两拍，再加入可选 ferry 第三拍；比强制四段更容易隔离资源和视线问题。大师黄金本切片没有制作，不以长度命名难度。

当前单武器来自真实 `player.tscn` Controller 的 `pulse_gun` Lv1；每帧记录实际装备、max_jumps、max_air_shots、H/W状态、精力与冷却。基础一跳/两空中发、收费与地面恢复读实际 PlayerTuning、plains_shot_energy.tres、ShotEnergyPolicy，不复制运行默认值。没有授予 H/W/D/U1/U2，也不使用敌命中恢复。低精力 fixture 仅在初始边界以合法 stamina transaction 实耗到0，帧0先记录真实0；之后只能真实地面自然恢复。

## 短语、空间与衔接

| 短语 | 真实输入与消费者 | 支撑/判断/目标 | 接续与拒绝 |
| --- | --- | --- | --- |
| main/well | Router jump；14 ticks 后真实指针基底瞄准铃，shoot_release；上升反冲后 jump_release，方向修正到对岸 | 原 well banks x0..280 与380..640，floor300；正向 takeoff265、receiver430。真实下弹→ShotLatch健康事务→gate collider关闭，反冲与弹体共用 shot_id | 先真落地到端口620、停稳并清实际cooldown，再走40到 arch入口660。删接收岸必须落空失败 |
| main/arch | 原 low_arch input-only driver，正向275/反向365 起跳，7 ticks 后释放 | arch offset640；原顶棚 y160..178、地面锯 radius18；通过原完整身体/危险扫掠 | 出口1260，三条脚底碰撞射线全支持；不用额外射击。不改变顶棚或锯 |
| high/step | 原 recoil_rises：跑到170，jump→18 ticks→真实向下枪→上升→落高台 | step offset(0,-860)，floor300→110、身体中心282→92，190高差；空射也有反冲 | 真实落端口(500,92)，停稳，自然恢复后走40到 remote入口(540,92)，无传送/补能 |
| high/remote | 原 remote_sequence Driver；先真敲铃1，过门1，从420跳到上层520/192，再射高位铃2 | remote offset(520,-190)；原 baffle x360..384/y140..250 与上层 one-way440..600/y210；第二次射击必须从实测高台，不用地面射替代 | 真 drop_through 下撤，落远端(1400,92)。归程可沿已开门经过，不要求重新敲两钟 |
| high/ferry（可选第三拍） | 真实安全岸瞄铃，开船→再射停车→等30ticks→再射重启；原 carrier 真跳上船/随碰撞携带/跳下 | ferry offset(1420,-190)，原120×24移动落点、travel2.5/dwell1.2；记录motion_running、clock、position；停车不resetphase | 同一身体/资源从remote接续；归程同样真实park/restart，岸上自然等资源/泊位。8真实初相位分别跑，不重置运动时钟 |

两个链各有两条 legs（去/返）。从正向入口与反向入口分别开始，第一次可面对closed gate，返程沿同session已开门返回。进入与退出均调用原 authored port_accepts，并要求精确位置、完整支持、normal/recoil速度0和cooldown0。各短语的 start/end 是实测状态，不将刚射完或空中的状态伪称端口满足。接口compatible_predecessors/successors限定上述落地同高连续连接；未测试的镜像/随机邻接/额外速度入口不作兼容声明。

主路相位字段仍逐案记录，但 well与arch没有移动机关：arch锯 travel=0，不能称其为动态相位覆盖。高奖第三拍的 ferry 是真实动态相位消费者。8相位为0,.125,.25,.375,.5,.625,.75,.875；进入后只由自然世界时钟推进。每个case独立fixture初始化一次，每个case内部两legs与所有短语连续且只spawn一次。

## 安全、恢复、输入与未验内容

原 `random_stage_tests.tick` 的完整24×36身体静态危险扫掠、相对圆锯扫掠、30px连续性阈值原样执行，PlayerMotor继续唯一move_and_slide。逐帧另存原生slide collision point/normal/collider、hazard position/radius、三点脚底support、资源、Router move_axis；事件分开记录请求、accepted_jump、accepted_shot、projectile_impact、latch_health_commit、latch_committed、accepted_landing与拒射。

主路同弹绑定为 `shot/session/shot_id` 的真实精力consume，与 `motor_id:session:shot_id` 的 ShotLatch健康damage receipt；不是wrapper调sink或try_fire假命中。井铃不属enemy，检查无hit/回能receipt。反冲后10帧实测上移>100，再实际落岸。七帧arch释放必须由真实跳跃事件和请求差值验证。

观察/恢复 purpose=落地后看下一低顶/上层视线/船往返；recovery_rule=原地面恢复，下一拍才承诺。只有获得完整身体支持才能等待，空中低精力不能等待回能。return_experience=已开门不重做开门链，高奖高差用真实下撤；具体视觉可见性、留白感受仍未验。失败反例是删除原well接收岸而保留其Definition元数据；身体会落空，原驱动bounded失败，停止本leg，不重生后继续旧目标。

本fixture无敌人，绝不通过disable敌人证明通关。敌 alive/moving-away/dead/inactive、kill/bait策略、正式AI/projectile扫掠以及奖励账本/不同单武器均待下游真实正式消费者验证。唯一落点上敌人/盲落点、错误入口速度和未授予替代动作不在本轮成功范围。镜头、构图、音画、玩家学习/公平/趣味、手机双拇指与实体手柄、性能未验；PC意图路径不等于真实设备输入认可。

## 实际执行与保留失败

实际证据存于 `build/plains_redesign/golden/`，每次使用unique run目录，禁止覆盖。原首次租约未授权 `docs/evidence/plains_redesign/golden/`，因此该调用以真实blocked结束，未自行扩大路径。后续新租约 `plains-redesign-golden-portable` 已明确增允该目录；本轮复跑相同用例并归档完整原件，消除portable证据阻塞，独审仍待原controller执行。详见本任务质量record的currentSnapshot与证据路径/SHA。

- worker_1/smoke_1：typed conditional Array错误，原始失败保留；smoke_2：观察器属性weapon_id错误，原始失败保留。修正新runner的类型与只读观察字段，未改基础Motor/旧driver/断言。
- smoke_3：两拍main与两拍high实际280/0；两拍通过后smoke_4扩optional ferry第三拍322/0；smoke_5真park/restart346/0；smoke_6加energy/cooldown对照363/0。smoke只定位，不代替完整矩阵。
- 完整wrapper run_9voq9kbj：64cases、95488实际物理ticks、288真实shots，2768/0；删岸真实10/1 exit1，身体落至y1381.031，必须rejected。
- 完整wrapper run_z3niuwig：64cases相同矩阵，加2个资源guard为2785/0。实测energy拒射与cooldown拒射，未命中铃不得开gate。日志/原件保留。
- 原bridge→arch黄金wrapper实际重跑 `build/level_autonomy/action_golden/run_i_c3sq5z/receipt.json`，原187/0与删岸29/4持续成立；未修改旧187断言或任何旧driver。

自动验证只签此技术消费者；原 controller 仍将自行执行docs/quality/新check后发独审lease。没有以此替代完整地区G3/G4或G5。

## Authority ledger与当前快照

| 来源/章节 | SHA256 | 规则状态 | 实际消费者 | 正式授予与证据范围 |
| --- | --- | --- | --- | --- |
| `docs/design/player_actions/README.md` / 最新覆盖/单武器 | `26b46fcf4be3440f0d4c6563d59af7dc5595f65ea3cb1e6f5a612eae1fb92618` | LOCKED；实现候选不等于最终认可 | PlayerController/ShootAbility/WeaponRuntime | 当前正式S1仅基础枪/一跳 |
| `docs/design/player_actions/regions_v0.3.md` / 0.1/2.1/3/S1/4.3 | `1c0e78298942fce4e0b133f4b5a52e37cf302c6af57e268747fdf7e6deb636f4` | 阶段/能力边界LOCKED；具体机关蓝图PROPOSED | PlainsRegionStage/Generator；本fixture无成长写入 | 无H/W/D/U1/U2授予 |
| `docs/design/player_actions/weapons_v0.8.md` / 0/1.1/3.2/6/7.2 | `0d2b908637a85270e46ede7cbb17fb8d5d8f353d901a3bda79665291c450e852` | 单武器/真实位移LOCKED；Lv3具体技能PROPOSED | Pulse WeaponDefinition/PlayerMotor/ShotEnergyPolicy | 实测pulse_gun Lv1 |
| `docs/quality/action_budget_spec.md` / 基准D/反冲收束 | `6e1b9fe47f6cf61d680ae2c842cdb7e4b6954383a3f5fc848f1353d253eaabab` | 最新用户覆盖 | 实际PlayerMotor/RecoilAbility | 沿原Definition未改预算 |
| `docs/quality/weapon_feel_spec.md` / Lv1位移与瞬闪区别 | `6c3c89a82ccbe9d118ca2452f4ee57a68ec24424ee2fb9203d68f708169c0723` | 最新用户覆盖 | Pulse recoil，未混用shuriken瞬闪 | 仅pulse构筑证明 |
| `docs/quality/air_action_refill.md` / enemy真实提交/已授能力 | `fe6bc80021a09b82ec27bebfe866efe6f1b96423cb9102c7d9af9ad904772f86` | 最新用户覆盖 | PlayerController on_weapon_damage | 无敌与未授H/D，机制命中不回能 |
| `resources/player/plains_shot_energy.tres` / 实际20收费/30恢复/.35delay | `c4f5570999639b349a5568db095cccad18a38be67d88dc3456a6ec2acf291770` | 实际配置，数值为现行候选 | ShotEnergyPolicy | 本fixture enable_shot_energy沿正式consumer |
| `config/player_tuning.json` / 实际默认物理/次数/冷却 | `e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058` | 当前配置 | PlayerTuning/唯一PlayerMotor | 每帧能力/资源采样 |
| `config/plains_shot_latches.json` / well/remote/ferry定义 | `2b542b870b9b4e94db9e7ae207b8ffcf3deb4c3d7013bab411f324d0f9a40b31` | 当前配置 | PlainsShotLatchPlanner→GeneratedShotLatchEncounter→ShotLatch | 真实机关fixture，不称正式路线已接入 |

上次最终源完整矩阵 `build/plains_redesign/golden/run_gd33wjdk/receipt.json`：native 3105/0，64cases、95488ticks与2个真实资源guard；positive 35.981秒，negative 1.47秒。source_before==source_after，新增逐帧hazard position/radius与原authored出口port断言。receipt SHA256 `aea7175b3d692a232179331874c5e88c165e3ba34ff8294170d8cf32ebd3058a`。可携带原件应在新允许目录中gzip保存完整JSON，不裁掉失败或用摘要冒充逐帧证据。

## 第1轮便携原件（历史，已被独审REJECT）

新真实implement request_hash=`7513636102516afbcb4243a18ba7b5496efdc8ea24edde88dcc09d3d582fbaec`；原blocked调用保留在 `docs/evidence/plains_redesign/golden/history/blocked_lease/`，不是重标为成功。新调用只有证据打包/归属更新，没有增加或改变tests/cases。

第1轮复跑原件来自 `build/plains_redesign/golden/run_odr6ne1_/`。实际positive3105/0、64cases/95488ticks/288shots加2资源guard；positive35.143秒、真实坏岸negative1.471秒/10断言1失败/exit1。当前完整逐帧JSON分别以 `docs/evidence/plains_redesign/golden/current/positive.json.gz` 和 `deleted_bank_negative.json.gz` 无损保留；gzip解压后逐member字节与SHA256都等于原始文件，不重写JSON。`archive_index.json` 包含每member的原始路径/大小/SHA、压缩文件SHA和读回验证；`current/receipt.json` 是未改写的原wrapper receipt，含实际命令/退出/日志哈希/前后source。

`current/summary.json` 从原始frames/events派生，列每case方向、初始真实0/100、实际phase、samebody/session、支持/碰撞/危险结果、逐短语入口出口与真实acceptedshot/资源/latch/landing事件。它便于审查，不能替代完整逐帧原件。`current/source_snapshot.json` 保留实际历史source_commit与逐文件dirty SHA，source_before==source_after；用现有wrapper来源库存，排除quality records，不把未提交工作树假称HEAD内容。主路无移动相位的范围与高奖真实ferry8phase范围仍分开声明。

保留首次observer错误smoke1/2完整JSON和错误日志，以及原187/0、原负例29/4的原件/日志/receipt；失败仍是失败。质量记录只推进G0/G1技术范围，workflow=review/contentfalse；正式敌/地图、美术/音画/玩家/实体设备与独审未签。原controller将自行执行docs/quality/newcheck，再交不同代理独审。

## 第2轮：GOLDEN-R1事件完整性返工

独审 `/root/plains_actions_audit` 实际REJECT保留于 `docs/evidence/plains_redesign/golden/round2/previous_review/review.md`：旧validator把high的events全部删除并把shots改0仍接受；删除high第二leg的phrases仍接受。原始完整native动作轨迹实际存在，问题是新wrapper对未来不完整证据失守；不撤改或重标原REJECT/反例。

本轮仅修新wrapper，没有改runner、玩法、Motor或旧driver/原187断言。两legs都要求精确方向与模块/phrase顺序、数量，start/end绑定实际同tick的完整状态（只有在tick之间改变的phrase标签单独处理），时间区间连续覆盖最终帧。每次jump/shot绑定同tick的真实Router请求与Motor前一帧位置，landing绑定真实grounded/support帧；每发shot绑定当前session/shot_id的实际消耗receipt与原生recoil。

High上行step必须真实空中向下射击、上反冲并落到高180以上接收台；下行必须真实跳落低台。Closed remote必须第一弹实际sequence_step/seen source-ID→jump→上层支持landing→第二弹health receipt/gate commit→下撤landing完整顺序；已经打开的return不新增射击，只在全程原生open/disabled gate帧与更早真实health receipt成立时允许。Ferry每leg逐发shot/真实projectile impact对应open_count/motion_running转换；停车至少30帧真实clock/position不变，重启从原clock继续，两个jump/landing中第一个确实落在移动落点身体支持范围。

原64case矩阵与真实删岸复跑 `build/plains_redesign/golden/run_0u1mbkkt/`，native仍3105/0，95488ticks/288shots；positive32.127秒，删岸10/1、exit1、1.473秒。另11个证据破坏回归全部拒绝：high events清空且shotcount0、第二leg phrase清空、step landing缺失、remote health/commit缺失、ferry toggle commit缺失、step收费receipt/Router input缺失、返回方向错误、虚假frame boundary、high session/shot receipt错误。原独审4例脚本实际复跑也全部拒绝。回归只临时替换内存证据引用并逐次恢复，不修改任何native原件，不以总计数代替动作因果。

本轮完整原件/日志/实际receipt/11例结果/compact case journal/source snapshot在 `docs/evidence/plains_redesign/golden/round2/current/`；`round2/archive_index.json`逐一记录21个实际原件成员的复制/压缩SHA和解压字节复验。原第1轮便携目录未改写，实际独审REJECT、原反例脚本/JSON/日志/物理probe与原来源库存全部照原件收录。G0/G1仅技术范围待重新独审，review/contentfalse；不签G2-G5/玩家/设备或整区完成。
