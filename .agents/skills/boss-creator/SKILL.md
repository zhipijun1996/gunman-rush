---
name: boss-creator
description: 制作新 Boss 或重构 Boss 核心机制/阶段；现有 Boss 可只作验证案例。
---

# boss-creator

## 机制价值先于扩产（FOREST-DEPTH-02）

使用[黄金玩法假设对照](../../../docs/quality/review_method.md#黄金推广前玩法假设对照)：先比较真正不同的玩家体验假设，再在同条件真实消费者上记录目的打法、最便宜退化打法与关键动作／对象消融。由不同作者在原黄金审查阶段作继续／修改／淘汰决定，整合只消费被接受的具体机制范围。不得用技术通过、阶段编号、Hash、动作计数或“G5尚待玩家”跳过此处的专家设计淘汰；仍不能把专家判断签成玩家认可。共享组件可保留，缺少新增判断的候选允许删除；失败只阻断其后继。

## 触发与边界

制作新 Boss 或重构 Boss 核心机制/阶段；现有 Boss 可只作验证案例。 从仓库根目录调用 `$boss-creator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取当前AGENTS及当前状态；按任务消费者读取相关设计与架构，保留目标、完整SHA、任务/内容版本、路径、已知失败和能力来源；缺证据写unverified。

## 阶段流程与交付物

G0：写叙事/地区联系、轮廓剪影、独特核心机制、射击反冲互动、竞技场、AI 状态图、阶段行为、预警/攻击判定/弱点/反击窗口、转换、演出镜头、动画特效音效音乐、死亡胜利奖励、公平失败。每阶段必须改变玩家决策并有学习过程；只加 HP/速度/弹幕退回设计。
G1：为每个阶段各做完整可玩样板。真实攻击、真实躲避、真实弱点命中，记录前摇/判定/恢复 tick、反冲位移空间和失败恢复；再从正式入口连续打完整场战斗，不能拼几段孤立录像。
G2：art-director 做区域黄金合屏和 Boss 母版；animation-vfx 做各阶段正常速度连续动作。视觉和判定、镜头/弱点可读性、音乐转段与攻击事件对齐。
G3：沿 [现有 Boss 契约](../../../docs/enemies_and_bosses.md) 和 [BossMotor](../../../game/bosses/encounter/boss_motor.gd) 接入封场、血量、阶段切换、死亡优先/唯一奖励、保存回家、暂停重载、epoch 和取消。正式池与接近区域一起验收。
G4：gameplay-reviewer 构造阶段切换同帧死亡、迟到弹体、多次奖励、不可避攻击、无意义等待、镜头遮挡反例。逐阶段和完整战斗分别出结论，失败可 REJECT。比较持续重复单一动作的强普通解，核其真实命中返还与目标限定接触保护覆盖的对象、阶段和时长，保留其他身体、危险区及弹体伤害，不把局部保护当全局无敌或忽略其合法收益。完整战斗失败须分清进攻、脱离与恢复各段因果；恢复段失败不证明前段抗重复打法成立，也不撤销整体失败。
G5：真实设备长战斗性能、控制方式、玩家学习/掌握与记忆点评价。牧风者、鸣铃巡游机作为既有契约案例，本轮规范验证不得擅自改其设计。
交付：Boss Design Sheet、竞技场与状态时序图、各阶段样板/连续战斗、资源配置、素材谱系、审查与证据。

## 设计要求

使用 [专用模板](../../../docs/templates/boss_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

运行 harness gameplay；素材改变加 art；参照 [boss_tests](../../../tests/boss_tests.gd)、[接近区域测试](../../../tests/boss_approach_lab_tests.gd)。记录真实输入/弹体和攻击窗口，不以直接调用结果函数替代战斗。完成记录要覆盖每阶段及完整战斗。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

逐阶段问：玩家是否必须改变决策、能否学习反制、等待是否有意义、反冲是否有用、动作自然吗？审查核心机制、失败公平性、场景合屏、声音/音乐和镜头；主观认可须用户证据。

## 准入退出与返工

按[共同契约](../../../docs/creative_direction/README.md)及原G0–G5准入退出；设计失败RETHINK、局部REWORK、不适候选DISCARD。保留失败原件，重跑受影响检查并独立复审，不降工程门槛。

## 完成与证据

按[共同契约](../../../docs/creative_direction/README.md)记录原十一维、版本/SHA、消费者、实机证据和未验范围；缺审查/用户/设备不宣称完成，旧证据保留原来源。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。

## Underworld第三轮实证回流

伤害资格与前摇/攻击/收招风险分开设计。当前正式连续合同可随时受击，不能用弱点窗口制造回合制；接触体与可打躯干按实际图形分别校准，必须有不躲受伤与真实正确躲过对照。 来源、真实失败、适用版本与待验见[第三轮经验](../../../docs/underworld_feedback_r3.md)；本条不代签最终用户手感或实体设备。

远程伤害必须传碰撞step的实际弹道方向；至少真实左右弹体各命中一次，检查accepted请求和唯一Motor位移，不用伪造hit信号替代。

战斗资格修改后同步实际Hud的状态行、命中词、阶段大字、盾标和方向箭头；continuous提示必须读真实accepts_combat_damage，旧窗口提示仅保留legacy。Encounter.objective改动不能代替Hud实机复审。
