---
name: encounter-director
description: 联合编排路线上的平台、战斗、机关、奖励、观察和恢复，诊断空白、重复、高压与回程疲劳。
---

# encounter-director

## 触发与边界

路线“无聊/重复/一直被追/奖励不值得绕路”、战斗与平台/机关共同设计、地区节奏编排时调用 `$encounter-director`。不替代 enemy-creator/boss-creator 的敌人行为，不单独改变奖励账本；以现有对象和定义安排关系，新增行为交专业技能。

## 输入与依赖

实际区域 Manifest、route/edge/module ID、能力快照、行动轨迹和交互事件、学习前置、主路/支线/大师合同、敌人机关行为/相位、奖励语义、回程与低资源策略、设备、阈值来源和玩家反馈。单张地图总敌人数不满足路线输入要求。

## 阶段流程与交付物

1. G0 随 region-generator 列直接 Boss、普通探索、高奖励后返回的实际节点/边序列，必要时加能力重访、失败重试、低资源和不同单武器。明确每条路径为什么值得选，风险/时间/奖励/发现有什么区别。
2. 在每条路线放安全探索、展示、练习、组合、战斗压力、时序、奖励、安静恢复和高潮；使用八体验标签而非互斥房间类型，RoomIntent 解释具体玩家行为。新机制先展示再练习再组合，跨分支未学习机制不得直接强制考核。
3. 写 EncounterPlan：敌人/地形/机关的相互作用，允许击杀/躲避/绕路/利用反冲等策略，预告与危险扫掠，唯一落点保护，资源和奖励恢复条件。新敌人行为交 enemy-creator，Boss 空间交 boss-creator。
4. 用真实路线统计无有效互动距离；有可靠时戳才报无互动时长。分别记录高压连续段、观察/恢复间隔、重复动作/遭遇、奖励间隔、回程重复和高风险低回报。静态估计、输入轨迹和玩家评价分栏；有效互动要写明判断/动作依据，不能靠塞一个装饰机关刷密度。
5. G1–G3 先一段联合黄金样板再推广，保持碰撞/资源/奖励/生命周期合同；回放前后相邻段、低资源、不利相位和失败后返回。挑战编舞交 challenge-choreographer，镜头/地标交 scene-composer。
6. G4 同版本阈值、同 Seed/能力/策略比较前后，检查改善是否转移疲劳到别处；G5 用玩家反馈校准地区×类别×设备阈值，保留原基线。阈值未校准只报候选诊断，不评分“趣味95”。

## 完成与证据

[地区模板](../../../docs/templates/biome_design_profile.md) 中的 RoomIntent/EncounterPlan 和路线节奏表、[优化任务](../../../docs/templates/level_optimization.md)、build/ 下原始 Manifest/路径/事件/报告、docs/evidence/<task>/ 下前后对照/失败索引，以及既有十一维记录。每个发现必须含 route/edge/module 或帧位置、事实/推断、复现条件和具体修复层。

## 自动验收

使用 V2 validate/analyze/compare 和适用 harness docs/gameplay；涉及美术加 art。每个新增规则有正例和故意失败例：长空白、连续高压、相同动作换 ID、无意义分支、无恢复的资源链。重复诊断不能随坐标/贴图变化消失；真正加入新的行动依赖应能改变动作签名。真实 Godot 验证敌人/移动平台/资源关系，静态事件表不能代替。

## 人工审查与协作

gameplay-reviewer 按每条策略实际观察可学性、选择价值、失败原因、疲劳与惊喜；战斗不默认必须全杀。主路不能依赖随机高级道具或突然的精密大师链。PC/手柄/手机核查敌人与平台造成的同时操作负荷，缺设备写 awaiting-device。art-director 和 scene-composer 确认休息/发现/高潮的视听构图成立。

## 适用示例

“平原奖励绕路太空”：先报告路线与实际交互间距、奖励/回程状态，再提出缩短冗余地形、改变决策或添加有意义的组合中的最小改进；“森林树冠混合战斗”先做未来合同，未授予钩索不能用于正式主路证明。

## 设计要求与权威来源

先读 [AGENTS](../../../AGENTS.md)、[current_state](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[V2 真实合同/CLI](../../../docs/level_design_harness_v2.md)。实际参数来自 config/player_tuning.json、config/input_profile.json、运行 Definition 和正式消费者授予点；[动作入口](../../../docs/design/player_actions/README.md) 中规划/候选不是已授予能力。复用 RunManifest、RunRandomStream、PlayerMotor、PlatformingModuleDefinition 和现有 LEVEL FOUNDRY，不改物理、武器规则、资源、保存或随机流以让设计过关。

同 game-quality-gate 共用任务 ID、G0–G5 和 docs/quality/records/<task_id>.json，不重造门槛或质量类型。十一维 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance 分别记录 passed/failed/unverified/not_applicable（理由）。命令保存版本、退出码、日志；轨迹保存 Seed/Manifest、能力、相位、输入、失败位置和来源哈希。意图不冒充运行，单片不外推整图，AI 不代签用户/设备。

## 准入退出与返工

保留失败证据、发现 ID 和最差 Seed；设计失败回 G0、真实操作失败回 G1、表现失败回 G2、消费者失败回 G3，修复后重跑受影响检查并独立复审。依赖不足 blocked，缺主观/独立审查 review，缺设备 awaiting-device；不能删断言、放宽阈值、无限重抽或用静态结构掩盖失败。

正式准入依 [policy](../../../docs/quality/policy.json) 的所有适用门槛。黄金技术片明确 production_pool=false 和未完成视觉/创意项；Foundry 开发池晋级不等于正式地区准入。本技能文档不提供内容 PASS。

## 自主生产闭环与 Q1–Q8

每次关卡任务先执行 [统一质量维度的权威加载与来源账本](../../../docs/quality/level_quality_dimensions.md)：自动读动作入口、regions_v0.3、weapons_v0.8 全文及最新覆盖合同，核对 LOCKED/PROPOSED、实现消费者与正式授予三种状态。继承 S1–S6/16地区、H/W/D/U1/U2、S2单能力、S4替代、S5双移动+U1；不从旧八关或旧V2摘要重创规则。Q1–Q8 映射既有十一维，不增加质量编号。

本轮有界平原切片已获授权；按任务可写范围直接设计、实现、测试、审查、返工，不把历史“仅工具不改平原”当新审批要求。PlayerMotor/武器/资源/随机流/保存与未授权地区仍是边界。用户负责核心创意与审美偏好/最终体验认可；常规缺陷由团队主动发现修复。

本技能主责 Q3/Q5，并检查 Q1 的路线价值。每个联合遭遇先写“敌人如何改变起跳/瞄准/反冲/站位”，至少列一种非击杀策略；没有真实关联的并排摆放不能称机制耦合。与choreographer共同画安全落点、攻击扫掠、预告窗口和资源链。

建立alive/moving-away/dead/inactive对照：敌人离开或已死后，唯一钩点/回能/开路条件不能让必经无解；敌人占据唯一落点时须有可见预告与合法等待/替代/撤离。记录实际AI范围、伤害/资源事件和版本，旧无敌人assembler轨迹不外推正式遭遇；新增行为交enemy-creator/boss-creator，不另造奖励/伤害服务。

低互动诊断按统一标准填写留白的purpose/观察对象/恢复规则/下一拍/返回体验及反例。安全、叙事、眺望、观察可以是好设计，但需要实际画面/状态支持；不得事后改名消警，也不能用无效输入、装饰或堆机关刷密度。首次探索与回程分别体验，返工优先压缩无用距离、改善信息或改变决策。

输出逐路线Q发现和具体修改包，保留正常/最差Seed、原失败及修复重测；只把实测玩家原话写用户意见，AI对情绪/趣味的判断标专家假设。
