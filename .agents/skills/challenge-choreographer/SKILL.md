---
name: challenge-choreographer
description: 设计基于真实能力的连续动作短语与挑战，明确空间、时序、资源、恢复、替代解法和真实验证。
---

# challenge-choreographer

## 触发与边界

用户要求“连续反冲挑战”“这里操作单调/衔接不流畅”“黄金普通/进阶/大师样板”时调用 `$challenge-choreographer`。负责动作编舞；level-module-creator 负责物理模块实现，region-generator 负责地区/路线集成；不发明未实现动作或改变武器。

## 输入与依赖

任务/源提交、主路/奖励/隐藏大师定位、经验标签、已学机制、单武器能力快照与合法备选构筑、真实资源/冷却、空间边界、上下游状态、敌人/机关、设备、玩家反馈、正式消费者。缺能力数据先采集授予点/运行状态，不能从最大跳高猜动作能力。

## 阶段流程与交付物

1. G0 填 [挑战设计卡](../../../docs/templates/challenge_sequence.md)，先写一次有价值的判断和失败可理解性，再选择 AtomicAction → ActionPhrase → ChallengeSequence → Encounter/Room → Route。原子动作逐个引用实际输入和 Runtime/Motor 消费者；未来动作标 future 且排除正式主路。
2. 为每个转移记录前置位置/速度、武器等级、空中次数、能量/冷却、观察信息、允许下一动作、稳定站位或恢复要求；主要序列及替代序列必须均遵守同一时刻单武器，钩索独立。射击命中/机关触发与反冲可在同动作耦合，但真实提交命中才允许资源恢复。
3. 把状态转移映射到空间/碰撞和机关时序，列安全观察区、目标落点、失败恢复、镜头提前展示、输入容错测量方法。禁止只写模块 ID 串；入口/出口的速度、资源、相位要能连续衔接。敌人不得无预告阻断唯一落点。
4. 按普通/进阶/大师模板做小样：普通主路短链流畅/容错；进阶支线更深资源决策和机制互动；大师隐藏可选、长链与精密控制且可学。难度用机制耦合、时序、恢复成本等向量描述，不单靠动作数/缩台/加障碍。
5. G1 委托 level-module-creator 用现有 Foundry/真实 PlayerMotor 建单片和连续 itinerary；至少测基线、低资源、错误入口、最坏相位及一次失败恢复。轨迹中的接受动作/拒绝动作和真实资源变化要能追溯，不中途重置身体或资源。
6. G2–G3 与 scene-composer/art-director 验实际镜头可见信息和目标设备操作，接正式相邻组合；G4 将正反例交 gameplay-reviewer；G5 单独收集玩家学习/流畅/公平反馈。

## 完成与证据

docs 下任务设计卡（使用挑战模板）；已有 Definition/Foundry 配置的最小修改；build/ 下运行 Manifest、能力快照、输入回放、轨迹和失败日志；docs/evidence/<task>/ 下精选复现索引；同一质量记录。ChallengeSequence 的动作关系和证据引用按 V2 schema，设计状态与物理状态分开。普通/进阶/大师卡均给实际可运行入口，不把空 JSON 当黄金样板。

## 自动验收

按 V2 文档调用 `python3 tools/level_design.py validate` 与 `analyze`（完整参数查 --help）；运行现有 `python3 tools/foundry.py build --profiles base --count 6` 和受影响能力 profile 的真实回放、`python3 tools/harness.py --profile gameplay`，文档至少 docs。不能拿 base 通过证明可选能力 profile 或正式整图通过。新增规则必须有通过例和故意失败例，尤其未授予能力、双武器拼接、连续资源不足和错版本证据；记录结果，不把命令清单当执行证据。

## 人工审查与协作

gameplay-reviewer 独立看正常速度轨迹/画面是否可读和公平；PC 键鼠、实体手柄、手机触屏分别评同时操作负荷、预判与误触。region-generator 检查主路线准入和学习前置；encounter-director 检查前后压力/恢复；art-director/scene-composer 检查落点/预告可见；animation-vfx 检查真实动作反馈。无设备/真人数据明确未验。

## 适用示例

“向下射击攻击敌人并反冲到平台”先证明敌人真实受击与位移是同一输入结果，再验落地/能量和下一短语；“jump→recoil→directional_correction→landing”是候选语法，只有引用实际消费者并回放后才有物理证据。

## 设计要求与权威来源

先读 [AGENTS](../../../AGENTS.md)、[current_state](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[V2 真实合同/CLI](../../../docs/level_design_harness_v2.md)。实际参数来自 config/player_tuning.json、config/input_profile.json、运行 Definition 和正式消费者授予点；[动作入口](../../../docs/design/player_actions/README.md) 中规划/候选不是已授予能力。复用 RunManifest、RunRandomStream、PlayerMotor、PlatformingModuleDefinition 和现有 LEVEL FOUNDRY，不改物理、武器规则、资源、保存或随机流以让设计过关。

同 game-quality-gate 共用任务 ID、G0–G5 和 docs/quality/records/<task_id>.json，不重造门槛或质量类型。十一维 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance 分别记录 passed/failed/unverified/not_applicable（理由）。命令保存版本、退出码、日志；轨迹保存 Seed/Manifest、能力、相位、输入、失败位置和来源哈希。意图不冒充运行，单片不外推整图，AI 不代签用户/设备。

## 准入退出与返工

保留失败证据、发现 ID 和最差 Seed；设计失败回 G0、真实操作失败回 G1、表现失败回 G2、消费者失败回 G3，修复后重跑受影响检查并独立复审。依赖不足 blocked，缺主观/独立审查 review，缺设备 awaiting-device；不能删断言、放宽阈值、无限重抽或用静态结构掩盖失败。

正式准入依 [policy](../../../docs/quality/policy.json) 的所有适用门槛。黄金技术片明确 production_pool=false 和未完成视觉/创意项；Foundry 开发池晋级不等于正式地区准入。本技能文档不提供内容 PASS。
