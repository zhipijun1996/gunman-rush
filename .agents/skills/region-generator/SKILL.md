---
name: region-generator
description: 规划新地区或优化已有地区；统一拓扑、空间身份、动作挑战、遭遇节奏、构图、能力锁与体验验证。
---

# region-generator

## 当前生产入口：区域圣经先于制作

先读[区域创作入口](../../../docs/creative_direction/README.md)、[Bible注册表](../../../docs/creative_direction/bibles/registry.json)及目标地区完整原文。当前两份Bible由用户直接提供并选择，先完整荆棘森林（含美术），再优化风铃平原；不重新提出2–3个方向。缺Bible时自主编写proposed圣经，只写文档/G0，不制作地图/几何/资产/敌人/Boss；注册并独立审查前production拒绝。

所有地区任务绑定registry与原文的完整SHA、id/version/region、选择依据，原始全文随worker输入；本次BGM由用户后续提供，音效与事件驱动环境动画/VFX可做。发生漂移先停止相关后继，保留旧失败，列旧/新绑定、受影响设计/地形/生态/Boss/美术/动画/音频/消费者及需重验的证据，由独审确认后重绑；不得仅刷新下游SHA。原G0–G5、十一维、全量source snapshot与所有原适用检查继续有效。


重新编排已有空间时，核对连接是在旧推荐路线之前还是之后加入、由哪个正式消费者实际验证。图中存在的实验关系不能因一次新的最短路搜索自动升级为默认路线；逐条保留、验证或退休推荐关系，同时保留旧版本重建与原失败。不要按 `pending` 文本批量删除：同一旧标签下可能已有完整实测。先检查所选路线的动作类型、几何实例和对象绑定，再投入整区 Motor 回归；详见[森林反馈续轮](../../../docs/design/forest_feedback_expedition.md)。

所有后续region create/optimize及缺Bible的proposed先读[最新两条用户原话和实际共享母版](../../../docs/creative_direction/bibles/style-continuity-20261021-v3.json)。保留正式平原现用Underworld tileset家族的16px/32wu、47邻接/精确边界、光照/描边/材质语言；地区差异来自材料、结构、生态和色域，森林用树皮苔藓荆棘有机轮廓，不独立换项目画风。旧提案/失败实现不自动约束新区域，不等于整体抛弃正在使用的共享家族。worker绑定原话及实际参考完整SHA，漂移阻断并重验；新地区实际跨区黄金像素对照独审后扩产，hash不签视觉。仅用户明确选择新global style时版本化替代，无关物理/global动作/普通文档不新增美术门。

## 空间美术任务的协作入口

新连接局部反馈现有CLI为 `python3 tools/run_forest_bible_world_fixture.py --output build/<fresh> --fixture connection`；侧枝以 `--fixture backbranch --return short` 与 `--fixture backbranch --return long`分别留证。它只在首次Motor步前明确初始定位，保持资源/能力/physics，不签正式fullspawn。正式对照仍用 `run_forest_bible_world_motor.py`，`--route` 分别选择 `bible_connection_journey` 或 `bible_backbranch_journey`，保留完整旧预算；这些CLI的完整runtime/assets/tests/tools源清单由 `forest_bible_world_sources.inventory()`统一前后校验，任何增删改令本轮失败。

主要诉求为画面品质、景深或空间身份时，交 [visual-director](../visual-director/SKILL.md) 统筹像素闭环，本技能仍提供真实区域身份/Manifest/连接语义/支持面及正式消费者。若任务冻结玩法生成，仅开放表现分支，不重新抽Seed、移动平台、重排敌人或改能力资源迁就构图；大结构视觉可跨多个模块，但不能制造新的碰撞承诺。

先与scene-composer、art-director联合设计围合、大轮廓、负空间、路线和观看顺序，由同一真实源派生碰撞、体块、接口、根脚和景层。先核当前正式消费者；超出源尺度、端口或连接适用范围须拒绝并有界返工，不改变核心或正式随机流救候选。首样板独审未准入不启动扩产；区域节点不自动代表固定矩形美术房间，Seed/Hash差异不等于空间身份。森林DemoApp→实际生成器/Stage/Assembler已经存在，静态source_present不推断新Bible通过或production_pool准入。

提供跨纵横移动、回程、镜像、长通道及不同尺度节点的覆盖清单，保持玩法层/敌预告/船/奖励/HUD优先，根基/连接/植生挂点有来源。使用 `python3 tools/visual_director.py route --help` 生成共用原production_loop的任务，再按 `run --help` 真正执行；计划文件不算专业worker已执行。`capture --help`、`inspect --help`、`compare --help` 关联同Seed/路线/能力/相位的实机前后证据，详见 [视觉合同](../../../docs/quality/visual_director_contract.md)。

先一个正式静态/动态黄金内部准入，再在第二种空间以简短目标验证同族资产和方法；不复制黄金坐标当通用规则，也不把第二技术片签整区完成。连续两轮独审无实质画面改善或关键工具不可用停止该依赖，保留源/失败/调用耗时；客观覆盖、AI构图判断、用户审美/真机分记。新经验写来源、版本、消费者与适用范围，不将局部视觉经验改成全游戏能力或生成硬锁。

## 机制价值先于扩产（FOREST-DEPTH-02）

使用[黄金玩法假设对照](../../../docs/quality/review_method.md#黄金推广前玩法假设对照)：先比较真正不同的玩家体验假设，再在同条件真实消费者上记录目的打法、最便宜退化打法与关键动作／对象消融。由不同作者在原黄金审查阶段作继续／修改／淘汰决定，整合只消费被接受的具体机制范围。不得用技术通过、阶段编号、Hash、动作计数或“G5尚待玩家”跳过此处的专家设计淘汰；仍不能把专家判断签成玩家认可。共享组件可保留，缺少新增判断的候选允许删除；失败只阻断其后继。

## 触发与边界

修改随机区域拓扑、段落编排、模块池、内容奖励分布或体验节奏。 从仓库根目录调用 `$region-generator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取当前AGENTS及当前状态；按任务消费者读取相关设计与架构，保留目标、完整SHA、任务/内容版本、路径、已知失败和能力来源；缺证据写unverified。

## 阶段流程与交付物

输入最新 [生成实现](../../../docs/generation_current.md)、Manifest/RNG 版本、真实能力和已验模块。复用 PlainsRegionGenerator、PlainsExplorationTopology、PlainsRouteRecipes、PlainsRegionAssembler、RunRandomStream；不能重造不兼容框架。
G0 分五层设计：①主/支/环路、捷径、分岔汇合、上下连接、单向与回程、Boss 接近、长度；②教学/观察/平台/战斗/机关/休息/探索奖励段落；③已验微观模块的速度/资源/能力/相位接口；④敌人机关商店宝箱补给故事线索与风险收益；⑤学习顺序、连续高压、安全恢复、操作交替、路线价值、惊喜、重复、回程疲劳与情绪地标。第五层可用离线观察设计，不假称已存在运行导演服务。
G1 分开验 A拓扑、B真实物理、C能力资源、D种子复现。保留分流 RNG、Manifest、有界重试和已验保底；真实 Motor 不能被图连通替代。
G2–G3 接入正式两图探索和地图消费者，检查地形拼接/背景/地标/雾图可读性、生命周期、保存与回退。使用 level-module-creator 的已验端口；新素材/动作分别调用专业技能。
G4 验 E结构多样性、F玩法动作多样性；采集拓扑签名、动作序列、机制组合、风险收益、连续压力/恢复、重复遭遇及回程成本。写抽样依据和观察定义，不把 Seed/Hash/模块数量不同当作丰富度。保留最差种子反例和修复前后。
推荐路线与可玩世界分开审查：仅改变 Manifest.routes、求解器或测试驾驶的走法，不能算地形、拓扑或玩家发现顺序的随机变化。追到正式装配与运行消费者，列明跨 Seed 实际改变的实体、通路条件、敌人和奖励关系；驾驶按某顺序通过只证明该策略可行，不代表玩家必然按此顺序探索。始终共存的分支可以提供真实选择，但须与 Seed 引起的世界差异分别记录。
G5 验 G探索趣味：真实路线①尽快找 Boss ②正常探索成长 ③高级奖励绕路并返回，逐条记录选择、疲劳、公平与奖励合理性。设备性能和用户反馈分开。
交付：五层 Design Sheet、版本变更理由、种子集/Manifest、结构统计、真实操作/完整探索证据及独立报告；未实现能力解锁不得冒充当前已有能力。

## 设计要求

使用 [专用模板](../../../docs/templates/region_generation_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

新GDScript先在同一root引擎租约用 `bash tools/godot.sh --headless --path . --check-only --script <实际脚本.gd>` 做窄parse，再跑局部实际消费者，避免长fullspawn末端才暴露Variant/类型错误；parse通过只证明解析。新连接可先用 `python3 tools/run_forest_bible_world_fixture.py --fixture connection --output <fresh-build-dir>`（另一路用 `--fixture backbranch`） 做真实Motor局部反馈，必须记录 `initial_fixture_spawn_override=true`、`resource_or_health_override=false` 和首次Motor步前定位；资源、能力及physics不改，不做中途搬运。该结果只签局部连接，绝不冒充正式出发路线；随后仍跑原fullspawn、原案例与原预算的完整验证，失败保留，不以局部PASS冲销。

默认布局晋升前先盘点所有省略版本的正式入口、独立期望、特殊路线driver与Python reader；显式历史坐标/保存重建保留原版本，不用旧pin掩盖当前失败。实际选择的Seed必须包含待验边，特殊策略的started/finished及实际事件必须证明已执行；“native零失败但从未激活策略”不算通过。普通战斗pilot只能处理自己负责的遭遇，不能抢先杀掉生态对照正在观测的目标；保留其他正常前缀。按[实际默认消费者盘点](../../../docs/evidence/region_bible_v2/style_continuity_20261021/default-consumer-inventory/inventory.md)先做小范围真实消费者，再完整原回归，编译和单元测试不替代这一步。

运行 harness gameplay；直接定位 [15 套地区](../../../tools/run_plains_region_tests.py) 与 [共享生成消费者](../../../tools/run_generated_consumer_tests.py)，保留适用回归。结构统计、Motor 专项、完整体验三类证据不能混为一条 PASS。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

gameplay-reviewer 检查三种路线实际决策、学习与恢复节奏、地图/动作重复、回程成本和公平奖励。美感/趣味须玩家体验，不用自动随意打分。

## Level Design Harness V2：完整地区生产与优化

本节把旧五层设计升级为六层；旧运行入口和质量门槛继续有效。读取 [V2 总合同与真实命令](../../../docs/level_design_harness_v2.md)，使用 [地区模板](../../../docs/templates/biome_design_profile.md)、[优化模板](../../../docs/templates/level_optimization.md)、[验收模板](../../../docs/templates/level_experience_acceptance.md)。

所需输入增加：需求类型（optimize/create）、玩家原始反馈、目标设备、支持的合法基础构筑集合、区域身份与学习前置、源 Manifest/版本、代表及最差 Seed、实际路线和轨迹。权威能力来自正式消费者授予点、PlayerMotor、运行 Weapon/Ability Definition、config/player_tuning.json、config/input_profile.json、[动作最新要求](../../../docs/design/player_actions/README.md)；MovementCapabilityEnvelope 是规划输入，不能替代真实 Motor。读取最新资源/动作修订，不把 Studio 的十五装备、H/W/D 或 Foundry 开发 profile 当作正式平原能力。

| 层 | 本技能负责的集成结果 | 专业协作 |
| --- | --- | --- |
| 1 宏观拓扑 | 有语义的节点/边、路线选择理由、环路/捷径、授予与锁、回程 | region-generator |
| 2 身份与空间语法 | 行为目标、空间轮廓、机制生态、地标与奖励 | scene-composer |
| 3 动作编舞 | AtomicAction → ActionPhrase → ChallengeSequence → Encounter/Room → Route | challenge-choreographer、level-module-creator |
| 4 遭遇节奏 | 路线上的学习、压力、恢复、风险收益和回程 | encounter-director |
| 5 场景构图 | 功能可读性、前中背景、拼接与合屏 | scene-composer、art-director |
| 6 体验验证 | 各层证据、反例、对照与未验项 | gameplay-reviewer、game-quality-gate |

执行 A（优化已有地区）：冻结正式消费者和基线 → 收集反馈并复现 Seed/路线/模块 → 用 V2 analyze 取得基线，区分规则网格事实、重复动作和实际空白 → 按影响选择优先体验问题 → 少量黄金改进 → Motor/路线/构图验证 → 仅推广通过样板 → 同 Seed/能力/路线/版本依据 compare → 原有两图及保存/随机流回归 → 独立审查。不得为赶指标塞机关；反馈“无聊”须落到具体动作、决策或回程。

执行 B（新地区）：定位世界观与进入能力 → 明确区别于已有地区的机制和空间身份 → 比较语义约束图、非规则嵌入、多尺度分配与手工骨架变体 → 写地区/构图/挑战合同 → 完整场所黄金（空间、动作、生态与美术共同设计）→ 真实机制和连续动作/合屏 → 样板准入后提炼可复用场所与模块 → 多种非线性布局 → 遭遇奖励/能力锁 → 跨场所镜头与正式消费者集成 → 最差 Seed、回归和玩家评测。未实现区域先 fixture；继承 regions_v0.3 已确认 S1–S6/16地区框架，具体候选连边/机关不自行定稿，不能悄悄开放地区。

八种体验标签可并存：安全探索与环境叙事、基础教学、普通平台、多动作组合、战斗平台混合、高收益技巧、隐藏大师、Boss 空间。主路短动作链/低卡关与明确恢复；奖励支线允许更长、更复杂且收益匹配；大师仅隐藏可选且失败可学。难度记录已学机制、连续深度、机制耦合、路线复杂度、空中修正、时序、资源、恢复成本、战斗混合、能力深度；不改单独地区的重力/手感，不用动作数量单独定级。

能力锁逐条证明授予路径、无循环、锁前后探索变化、每个基础合法单武器构筑的替代路线、返回/撤离、换装不困死、低资源/冷却/相位下的恢复。动作/结构/机制/探索/视觉五签名分开；坐标、贴图、ID、Hash 变化不直接计新体验。

输出合同：同一任务目录保存地区设计卡、生成 Manifest、能力快照、路线清单、真实轨迹、LevelExperienceReport、对照报告和质量记录；意图/结果/运行状态/物理证据/主观评价独立标注来源。不复制 RunManifest/RNG，也不把设计 JSON 写成物理通过。

必须验证：V2 validate/analyze/compare/route（参数以总合同和 --help 为准）、每个新增检测的通过与故意失败例、harness docs/gameplay，涉及资产再 art；基线阈值按地区/体验类别/设备记录且版本化，黄金样板和玩家反馈后才校准。图可达和未互动距离只是诊断；无完整路线 Motor 证据则 traversal=unverified。人工看三种探索策略、正常速度音画、PC/手柄/手机操作；缺设备 awaiting-device，缺趣味/审美 review。

失败按所属层最小返工并保留反例；正式准入要求真实消费者覆盖、全支持基础构筑路径、原回归、独立审查及适用玩家/设备认可，不以 V2 诊断命令成功代替 G5。

适用示例：“优化风铃平原”执行 A、先找最长重复/空白路线；“制作荆棘森林”执行 B、先做不同空间身份的合同和技术切片；二者共享上述消费者与证据格式。

## 自主生产闭环与 Q1–Q8

每次关卡任务先执行 [统一质量维度的权威加载与来源账本](../../../docs/quality/level_quality_dimensions.md)：自动读动作入口、regions_v0.3、weapons_v0.8 全文及最新覆盖合同，核对 LOCKED/PROPOSED、实现消费者与正式授予三种状态。继承 S1–S6/16地区、H/W/D/U1/U2、S2单能力、S4替代、S5双移动+U1；不从旧八关或旧V2摘要重创规则。Q1–Q8 映射既有十一维，不增加质量编号。

依据当前任务的最新用户授权及可写范围直接设计、实现、测试、审查、返工；历史“仅工具”或“有限切片”不覆盖后来的整区授权，也不自动授权其他地区或核心规则变更。PlayerMotor/武器/资源/随机流/保存与未授权地区仍是边界。用户负责核心创意与审美偏好/最终体验认可；常规缺陷由团队主动发现修复。

本技能统筹 Q1/Q4/Q7，并合并其余维度证据。输入先列阶段/地区条款、合法单武器构筑、已学机制与实际开放范围，再决定局部拓扑、路线和身份；每个挑战只要求其必要子集，不能为展示全能力破坏 S2 或主路合同。森林制作和原型均从S2-H+基础动作出发，不重新征询已确认阶段框架；是否采用正式整区范围由最新用户授权及实际消费者决定。

本技能统筹 Q1/Q4/Q7，并合并其余维度证据。输入先列阶段/地区条款、合法单武器构筑、已学机制与实际开放范围，再决定局部拓扑、路线和身份；每个挑战只要求其必要子集，不能为展示全能力破坏 S2 或主路合同。森林按本次完整区域授权从S2-H与基础动作出发，原dry-run仅留历史。

优化先选一个有正式消费者证据的 Q 问题，提出最小修改与不改方案，写真实玩家行为差异和反例。将改动分成设计→实现→真实检查→独立审查→返工的依赖包；发现不成立可保留原设计，但不得只回传 TODO。新任务若授权正式切片，完成准许路径实现和回归后再报告主观待验。

正式两图区原验收仍保留至少10个root Seed ×两张地图×不同路线的覆盖矩阵及原断言，不能用局部艺术实验代签。当前开发按真实消费者和任务风险选择相关短反馈：首黄金整屏与活体路线先验，通过后再验证结构明显不同的同资产空间及预登记小Seed集，记录最差样本与有限外推边界。标清计划/实测、派生Seed和活敌范围，不重抽避失败；Q7五类差异仍需实际描述与来源，Hash或配方数不是空间丰富度。

把独立发现定位到对应Skill并附最小返工包、预算与恢复指纹；按统一标准保留可复用规则的来源/适用范围/反例。没有真实worker日志和消费者变化，不称自主生产完成。

## 平原整区重设计范围（2026-10-15，覆盖旧轮有限切片范围）

按当前授权确定可改空间、路线及敌人编排；冻结未授权核心规则。策略比较须同字节driver复采旧内容，出返程动作/资源因果完整；历史坐标断言在冻结源保留，新默认另有强验。

## 先保住设计承诺，再产生变体

生成结果中的路线合同不是愿望清单。在剪边、转单向、分配锁和空间之前确定教学短路、可选发现、汇合营地与回程；每个变换须保护这些实际step与进入条件。不能把删断后的8边绕路改名“短技巧路线”消除失败，也不能只保护第一边却宣称整条路线存在。变化优先放到学习后有意义的分流、重汇合、捷径与Boss接近；同时保留既有差异/动作覆盖等断言，不能用保护所有边制造重复地图。

对代表Seed和原corpus审核每条声明路线，再用同body真实输入验证最差Seed及替代路线。不同variant数字必须实际改变挑战组合或决策；未参与内容选择的随机字段不得计新体验。失败、候选与最终接入分开归档。[本轮实际返工](../../../docs/quality/plains_redesign_spatial.md)是有适用范围的例子，不是所有地区都采用相同轴向布局的规则。

反重复应按玩家实际动作家族/状态变化审查，不只recipe ID。稳定图1教学可以复用，图2应有明确深化；相邻不同ID若都要求相同短按释放，不自动算新体验。每条长绕路必须有可读发现、风险收益、恢复或回程价值。先验证真实黄金，再推广；将现有箱预算搬到新岸时，必须有真正可达支撑/取奖输入/回程，不能只修改坐标与标签。

探索顺序也是反重复输入：同一地区至少检查“先主路学会→再发现高奖”“先上层支线→回主路”“拿奖后异路返回”。直接deep策略避开主路，不能证明玩家正常探索不会连续复考同一个题。允许复用已学模块，但高奖深化应体现在入口状态、资源、时序、空间耦合或可选熟练解；若到相同满资源静止岸再做完全相同双铃，只增加前置台阶不足以证明新深度。先用真实帧/资源核对，再选已验证组合或做有证据的深化，不按ID数量做决定。

叶节点并非错误：有独特发现、恢复、景观或叙事也可以成立。但不能把700高度原路爬回、只有普通守卫掉落的尾枝，仅凭地图有环/后台打了探索tag就认作有意义。比较真实返程连接、现预算奖励与明确场景目的，避免每个角落塞币。参见[实际中期设计审视](../../../docs/evidence/plains_redesign/design_midreview/report.md)，其中候选设计与实跑证据分开，不能自动扩成所有地区的度数硬规则。

## V3真实缺陷修复：先审计生态的物理门，再设计空间家族

V3的20图RootBell为0，而原40图资格审计仅1例，不说明应增怪或提概率。新审计应保留正式Seed、每连接的原始拒绝原因、已有guard、邻接机关和真实资源；`tools/root_bell_geometry_audit.gd`与`tests/root_bell_spaces_runner.gd`从正式生成器取数，不重抽消反例。先区分宽度/双侧退路、教学保护、营地、动态危险与尚未驾驶的class。恢复桥紧岸与双齿轮宽岸来自现成空间，敌人数和非生态Manifest保持，新增class先用显式v3 pilot实跑，未准入不得修改v11。

联合空间合同由实际`PlainsRootBellEncounterV3.inspect`输出至`root_bell_admission.physical_facts.joint_space`：邻接动作→到岸判断→存活/射击替代→回程→视觉身份→真实solid与保留负空间。region、encounter、scene共享该对象；标签不是物理或视觉通过。`python3 tools/run_root_bell_ecology.py --seed plains-redesign-8 --output-dir build/production_repair/ecology/<new>`执行当前正式DemoApp，`--movie`生成实际正常速度影片。19case含明确独立的inactive反例，不能把整个轨迹称纯输入；17个移动/战斗案例只提交Router输入，另一个暂停案例走实际production pause回调；均不搬角色、不改资源、不关闭敌人。

默认内容变更采用新version与per-run pin；实际v10/v11地图hash、actor数量恢复和三版本RunManifest重建分开验证。旧v11资格和旧保存不能用新class的hash替换；仅状态兼容测试不是旧二进制执行或完整存档迁移。精确保留失败来源，先黄金再扩，不用统计改善代签玩家/设备/商业品质。

## 准入退出与返工

按[共同契约](../../../docs/creative_direction/README.md)及原G0–G5准入退出；设计失败RETHINK、局部REWORK、不适候选DISCARD。保留失败原件，重跑受影响检查并独立复审，不降工程门槛。

## 完成与证据

按[共同契约](../../../docs/creative_direction/README.md)记录原十一维、版本/SHA、消费者、实机证据和未验范围；缺审查/用户/设备不宣称完成，旧证据保留原来源。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。


历史本轮入口原字节与SHA见[迁移索引](../../../docs/archive/skill_history/bible-v2-input/manifest.json)；旧recipe、历史预算和失败只在复现相关来源时读取，不覆盖已选Bible。

专用生态驾驶器必须先核对当前真实manifest是否生成比较目标，再保留该目标到策略窗口；通用战斗不能提前消耗后续观察对象。保留活体后还须实际验证前置通行，身体接触与技能危险分别审查，等待技能冷却不等于移走敌人身体。测试输入路线可使用既有合法移动/跳跃/反冲，但不能写角色位置、重置敌人相位或伪造资源补偿；先复验已失败的小例，再扩矩阵。缺producer的旧候选命令明确历史/未准入，不编造内容凑通过。

默认晋升必须覆盖真实RunManifest→canonical_json→JSON.parse→from_snapshot往返；只验证内存Dictionary快照不足。JSON数值解码的整数/浮点差异须按有限、整值的字段合同处理，不能接受分数身份、bool冒充数字或绕过全量Manifest校验。跨区UI流程现有的真实序列化断言继续作为发布门槛，不以版本枚举同步替代保存验证。

新增Godot脚本/素材后，在冻结harness输入前先完成一次正式4.7.2 editor import，纳入真实新UID/import元数据再冻结。若检查内部首次import生成UID导致source drift，该轮仍失败并保留；明确核对唯一新增元数据后重新fresh，不把新文件排除守门或倒签原native通过为整轮通过。
