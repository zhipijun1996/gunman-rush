---
name: game-quality-gate
description: 重要游戏内容总流程、质量门槛与完成声明；普通修复按风险轻量验收。
---

# game-quality-gate

## 触发与边界

重要游戏内容总流程、质量门槛与完成声明；普通修复按风险轻量验收。 从仓库根目录调用 `$game-quality-gate`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

识别 enemy/boss/level_module/region/art/animation/mechanic/ui_feedback/process/small_fix，填写同一个任务记录。重要内容必须启用相关专业技能，不能把整项 Boss 工作拆成若干 small_fix 逃避验收。
- 主角→player-creator，武器及升级→weapon-creator，新能力→ability-creator，新敌人→enemy-creator，新 Boss→boss-creator，新挑战→level-module-creator，随机区域→region-generator，新美术→art-director，动作/特效→animation-vfx，独立审查→gameplay-reviewer；Git 整理可用 project-integration。
- 输入用户目标、最新分支/PR/提交、正式消费者、已有契约/能力/未验项目。先 fetch 并比较 ancestry 和累积内容，不能默认 main 最新。
- G0：明确体验、趣味来源、差异、核心操作、反冲关系、学习/策略、视听/UI、失败恢复与可证伪验收。重大创意标 proposed，取得真实用户依据后才能写 user_confirmed。
- G1：真实输入、PlayerMotor、弹体、碰撞、资源与开始结束流程，保留成功/失败/边界反例。禁止传送、改位置、直接结算冒充实际操作。
- G2：专业技能提供正式画面合屏、连续正常速度录像、过渡与事件同步；原画、导入与静态姿态不能代替。
- G3：列出真正消费者和调用路径，验证入口、实例、池、奖励/保存、暂停/死亡/回退/重载、epoch 取消、对象和性能。
- G4：实际执行相关 harness 与反例，交给独立审查者。没有独立执行条件就 unverified；保留 REJECT 和复审链。
- G5：分别记录功能、GUI、美术、动作、趣味、设备和玩家认可。用户未认可的主观维度不能最终通过。
- process 只做 G0/G4、design/technical；small_fix 另按 formal_impact 检查 GUI。文案修复不用走 Boss/素材/设备全流程，范围扩大立即重新分类。

## 设计要求

使用 [专用模板](../../../docs/templates/iteration.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 消费者覆盖闭环

执行 [审查方法的覆盖闭环](../../../docs/quality/review_method.md)：先从正式实例和分支盘点消费者，再逐项对应实际输出证据。未修改、不同物理语义和已有辅助测试都不是豁免依据。新任务的 consumer_coverage 将运行 inventory 与观察一一对应；缺项、错场景、仅 helper 通过不能宣称正式通过。最终声明不得超出记录的 scope；缺画面写 unverified，用户拒绝保留失败链。

## 自动验收

大任务按 [生产循环](../../../docs/quality/production_loop.md) 拆依赖包，先黄金样板后扩展；允许有界反复调用专业 Skills 与独立审查，遇创意/玩家验收或无进展必须保留现场。

先运行 tools/quality.py init，再按范围运行 harness；tools/quality.py check --require-complete 用于最终声明。检查文档、证据 SHA/版本、状态一致性、实际退出码、正式路径和测试没有降标。脚本只检查证据结构，不会评出“好玩”。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

逐条比较设计与实际体验，识别换皮/数值堆叠/素材拼贴和遗漏消费者。用户确认仅记录可溯源原话，不能用 AI 自评替代。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
