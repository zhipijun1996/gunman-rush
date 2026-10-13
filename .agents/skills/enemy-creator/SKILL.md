---
name: enemy-creator
description: 设计或实现新敌人及实质行为改造；不用于单纯修正已有敌人拼写。
---

# enemy-creator

## 触发与边界

设计或实现新敌人及实质行为改造；不用于单纯修正已有敌人拼写。 从仓库根目录调用 `$enemy-creator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

A / G0 敌人策划：Enemy Design Sheet 写名称/背景/地区、战斗职责、独特操作压力、对射击反冲跳跃落点的影响、AI 状态机、移动/攻击、预警/判定/恢复时间、反制、受伤死亡奖励、旧敌人对照、地形/同伴组合。必须新增玩家操作或策略；换图/HP/速度不成立。
B / G1 灰盒：复用 [EnemyDefinition](../../../scripts/enemies/enemy_definition.gd)、[AI](../../../scripts/enemies/enemy_patrol_ai.gd)、[Motor](../../../scripts/enemies/enemy_motor.gd) 与既有 Health/[DamagePolicy](../../../scripts/damage/frame_damage_policy.gd)。让真实输入和弹体产生攻击/命中/死亡；含暂停、中断、无目标及失败反例，不旁路正式伤害。
C / G2 美术动作：用 art-director 区域母版和 animation-vfx 状态表，按需求完成待机/移动/预警/攻击/恢复/受伤/死亡；锚点、连续转向和动作过渡需正常速度录像，无统一帧数门槛。
D / G1–G3 遭遇：平地、多平台、落差、机关与其他敌人组合；写生成区域/机制标签、禁用组合、安全空间、同时压力预算。检查镜头外攻击、出口堵塞和落点公平性。
E / G2–G3 反馈：动画粒子、命中/落空、声音、死亡与掉落反馈对应已接受事件；死亡只结算一次，卸载取消旧请求。
F / G3–G5 集成：写正式场景/实例/生成池路径和许可证据；通过相关门槛后才入正式随机池。交可玩场景、设计卡、配置、正式运行录像及验收报告。

## 设计要求

使用 [专用模板](../../../docs/templates/enemy_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

运行 harness gameplay；素材改变加 art。核对 EnemyDefinition 与实际实例一致，真实弹体、暂停/回退/死亡/重复回调、组合场景反例。相关回归见 [核心测试](../../../tests/run_tests.gd) 和 [地区测试入口](../../../tools/run_plains_region_tests.py)。检查资产记录及任务完成条件。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

观察新的操作价值、预警可读性、可反制窗口、动画自然性、材质光照、声音和组合公平性。gameplay-reviewer 比较设计/实际，玩家确认趣味和表现，设备测量单列。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
