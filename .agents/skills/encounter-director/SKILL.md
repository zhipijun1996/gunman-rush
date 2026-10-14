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
