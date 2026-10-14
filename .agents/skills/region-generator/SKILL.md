---
name: region-generator
description: 规划新地区或优化已有地区；统一拓扑、空间身份、动作挑战、遭遇节奏、构图、能力锁与体验验证。
---

# region-generator

## 触发与边界

修改随机区域拓扑、段落编排、模块池、内容奖励分布或体验节奏。 从仓库根目录调用 `$region-generator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

输入最新 [生成实现](../../../docs/generation_current.md)、Manifest/RNG 版本、真实能力和已验模块。复用 PlainsRegionGenerator、PlainsExplorationTopology、PlainsRouteRecipes、PlainsRegionAssembler、RunRandomStream；不能重造不兼容框架。
G0 分五层设计：①主/支/环路、捷径、分岔汇合、上下连接、单向与回程、Boss 接近、长度；②教学/观察/平台/战斗/机关/休息/探索奖励段落；③已验微观模块的速度/资源/能力/相位接口；④敌人机关商店宝箱补给故事线索与风险收益；⑤学习顺序、连续高压、安全恢复、操作交替、路线价值、惊喜、重复、回程疲劳与情绪地标。第五层可用离线观察设计，不假称已存在运行导演服务。
G1 分开验 A拓扑、B真实物理、C能力资源、D种子复现。保留分流 RNG、Manifest、有界重试和已验保底；真实 Motor 不能被图连通替代。
G2–G3 接入正式两图探索和地图消费者，检查地形拼接/背景/地标/雾图可读性、生命周期、保存与回退。使用 level-module-creator 的已验端口；新素材/动作分别调用专业技能。
G4 验 E结构多样性、F玩法动作多样性；采集拓扑签名、动作序列、机制组合、风险收益、连续压力/恢复、重复遭遇及回程成本。写抽样依据和观察定义，不把 Seed/Hash/模块数量不同当作丰富度。保留最差种子反例和修复前后。
G5 验 G探索趣味：真实路线①尽快找 Boss ②正常探索成长 ③高级奖励绕路并返回，逐条记录选择、疲劳、公平与奖励合理性。设备性能和用户反馈分开。
交付：五层 Design Sheet、版本变更理由、种子集/Manifest、结构统计、真实操作/完整探索证据及独立报告；未实现能力解锁不得冒充当前已有能力。

## 设计要求

使用 [专用模板](../../../docs/templates/region_generation_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

运行 harness gameplay；直接定位 [15 套地区](../../../tools/run_plains_region_tests.py) 与 [共享生成消费者](../../../tools/run_generated_consumer_tests.py)，保留适用回归。结构统计、Motor 专项、完整体验三类证据不能混为一条 PASS。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

gameplay-reviewer 检查三种路线实际决策、学习与恢复节奏、地图/动作重复、回程成本和公平奖励。美感/趣味须玩家体验，不用自动随意打分。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。

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

执行 A（优化已有地区）：冻结正式消费者和基线 → 收集反馈并复现 Seed/路线/模块 → 用 V2 analyze 取得基线，区分规则网格事实、重复动作和实际空白 → 按严重度选择最小问题 → 少量黄金改进 → Motor/路线/构图验证 → 仅推广通过样板 → 同 Seed/能力/路线/版本依据 compare → 原有两图及保存/随机流回归 → 独立审查。不得为赶指标塞机关；反馈“无聊”须落到具体动作、决策或回程。

执行 B（新地区）：定位世界观与进入能力 → 明确区别于已有地区的机制和空间身份 → 比较语义约束图、非规则嵌入、多尺度分配与手工骨架变体 → 写地区/构图/挑战合同 → 黄金技术切片 → 真实机制和连续动作 → 可复用模块库 → 多种非线性布局 → 遭遇奖励/能力锁 → 美术系列/合屏 → 正式消费者集成 → 最差 Seed、回归和玩家评测。未实现区域先 fixture；继承 regions_v0.3 已确认 S1–S6/16地区框架，具体候选连边/机关不自行定稿，不能悄悄开放地区。

八种体验标签可并存：安全探索与环境叙事、基础教学、普通平台、多动作组合、战斗平台混合、高收益技巧、隐藏大师、Boss 空间。主路短动作链/低卡关与明确恢复；奖励支线允许更长、更复杂且收益匹配；大师仅隐藏可选且失败可学。难度记录已学机制、连续深度、机制耦合、路线复杂度、空中修正、时序、资源、恢复成本、战斗混合、能力深度；不改单独地区的重力/手感，不用动作数量单独定级。

能力锁逐条证明授予路径、无循环、锁前后探索变化、每个基础合法单武器构筑的替代路线、返回/撤离、换装不困死、低资源/冷却/相位下的恢复。动作/结构/机制/探索/视觉五签名分开；坐标、贴图、ID、Hash 变化不直接计新体验。

输出合同：同一任务目录保存地区设计卡、生成 Manifest、能力快照、路线清单、真实轨迹、LevelExperienceReport、对照报告和质量记录；意图/结果/运行状态/物理证据/主观评价独立标注来源。不复制 RunManifest/RNG，也不把设计 JSON 写成物理通过。

必须验证：V2 validate/analyze/compare/route（参数以总合同和 --help 为准）、每个新增检测的通过与故意失败例、harness docs/gameplay，涉及资产再 art；基线阈值按地区/体验类别/设备记录且版本化，黄金样板和玩家反馈后才校准。图可达和未互动距离只是诊断；无完整路线 Motor 证据则 traversal=unverified。人工看三种探索策略、正常速度音画、PC/手柄/手机操作；缺设备 awaiting-device，缺趣味/审美 review。

失败按所属层最小返工并保留反例；正式准入要求真实消费者覆盖、全支持基础构筑路径、原回归、独立审查及适用玩家/设备认可，不以 V2 诊断命令成功代替 G5。

适用示例：“优化风铃平原”执行 A、先找最长重复/空白路线；“制作荆棘森林”执行 B、先做不同空间身份的合同和技术切片；二者共享上述消费者与证据格式。

## 自主生产闭环与 Q1–Q8

每次关卡任务先执行 [统一质量维度的权威加载与来源账本](../../../docs/quality/level_quality_dimensions.md)：自动读动作入口、regions_v0.3、weapons_v0.8 全文及最新覆盖合同，核对 LOCKED/PROPOSED、实现消费者与正式授予三种状态。继承 S1–S6/16地区、H/W/D/U1/U2、S2单能力、S4替代、S5双移动+U1；不从旧八关或旧V2摘要重创规则。Q1–Q8 映射既有十一维，不增加质量编号。

本轮有界平原切片已获授权；按任务可写范围直接设计、实现、测试、审查、返工，不把历史“仅工具不改平原”当新审批要求。PlayerMotor/武器/资源/随机流/保存与未授权地区仍是边界。用户负责核心创意与审美偏好/最终体验认可；常规缺陷由团队主动发现修复。

本技能统筹 Q1/Q4/Q7，并合并其余维度证据。输入先列阶段/地区条款、合法单武器构筑、已学机制与实际开放范围，再决定局部拓扑、路线和身份；每个挑战只要求其必要子集，不能为展示全能力破坏 S2 或主路合同。森林 dry-run 必须从 S2-H+基础动作出发，不重新征询已确认阶段框架。

优化先选一个有正式消费者证据的 Q 问题，提出最小修改与不改方案，写真实玩家行为差异和反例。将改动分成设计→实现→真实检查→独立审查→返工的依赖包；发现不成立可保留原设计，但不得只回传 TODO。新任务若授权正式切片，完成准许路径实现和回归后再报告主观待验。

本轮冻结至少10个不同root Seed ×两张正式地图×不同路线的覆盖矩阵，标计划/实测、派生 Seed 与敌人范围；保留最差 Seed，不随机重抽规避失败。既有capture无敌人只作辅助，必须补正式敌人及画面；同条件before/after和至少一正式优化切片由原质量记录验收。Q7五类差异各有描述与来源，不能用Hash或总体配方数证明路线丰富。

把独立发现定位到对应Skill并附最小返工包、预算与恢复指纹；按统一标准保留可复用规则的来源/适用范围/反例。没有真实worker日志和消费者变化，不称自主生产完成。
