---
name: gameplay-reviewer
description: 独立严格审查已实现内容，主动构造失败反例并决定 ACCEPT、REJECT 或 UNVERIFIED。
---

# gameplay-reviewer

## 触发与边界

独立严格审查已实现内容，主动构造失败反例并决定 ACCEPT、REJECT 或 UNVERIFIED。 从仓库根目录调用 `$gameplay-reviewer`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

先按 [通用审查方法](../../../docs/quality/review_method.md) 从契约推导空间×状态×时间×消费者矩阵，形成自己的发现后再对照用户反馈。审查源码、实际绘制路径和正式 GUI，不把用户现象抄成检查表。

输入冻结的 reviewed_commit/content_version、设计规格、真实消费者、运行方法、Seed/Manifest、原始证据与已知缺陷；记录实现者/审查者、独立性来源。主要发现缺陷，不修改被审查正式生产代码；修改后由实现者另提交再复审。
G0 比对授权和设计：玩家体验、实质差异、反冲互动、学习策略、失败恢复是否有意义？用户未确认的重大方向不能伪称确认。
G1 从真实入口操控，构造成功、失败、边界和最坏相位；验证碰撞、真实弹体、资源和恢复。禁止仅复述开发者报告或以 fixture 代替正式流程。
G2 看连续正常速度运行画面与声音，检查美术协调、比例材质光照、动作连续、枪口脚底、预警/判定与视听同步、镜头落点遮挡。单图无法证明动作。
G3 检查正式生成池/场景实例/保存/死亡/暂停/回退/重载，旧请求取消、唯一奖励、对象泄漏和性能。Lab 通过但正式消费者缺失必须退回。
G4 独立运行相关测试并对照 diff，主动找删除断言/放宽危险/改物理过关等降标。低质量敌人、同质 Boss 阶段、仅 Hash 不同地图都构造反例。保持失败证据、复现、严重度、修复提交与复审结果。
G5 设计价值、操作、动画、美术、特效声音、公平性、随机变化、正式集成、性能状态保存、玩家/设备十类审查分别给出客观失败或主观待审；不能把 AI 主观印象写成用户反馈。
最终 verdict：已证实违反必需标准→REJECT；缺运行/身份/设备/用户证据→UNVERIFIED；只有声明范围内所有必要标准证实成立才能 ACCEPT。设计审查 ACCEPT 不等于内容 G5 全通过。
当前宿主无法真正独立审查时，填写 self_review 和 independent_review=unverified；静态检查/模板演练不冒充独立技能执行。

## 设计要求

使用 [专用模板](../../../docs/templates/gameplay_review_report.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

涉及可变形状地形时，执行 [邻接与拼接契约](../../../docs/quality/terrain_tile_contract.md)：枚举局部邻接、不同分块的同图对照、薄结构与孔洞、真实 GPU 与正式合屏分开验收。不能用覆盖率代替美术品质。

## 自动验收

运行适用 harness、tools/quality.py check 和需要的真实场景反例；核对证据哈希、版本、测试保留及失败记录。tools/quality_drills.py 只验证结构化拒绝规则，不证明 AI 能自主评价游戏。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

逐项对照 [审查报告](../../../docs/templates/gameplay_review_report.md)，验证证据内容而非仅文件存在。审查者与实现者身份不能自报另一个名字伪造；用户对手感/趣味/美术认可及设备实测仍需原始来源。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
