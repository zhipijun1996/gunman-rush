---
name: animation-vfx
description: 角色敌人 Boss 机关动作、动画过渡、射击反馈或游戏视听特效工作。
---

# animation-vfx

## 触发与边界

角色敌人 Boss 机关动作、动画过渡、射击反馈或游戏视听特效工作。 从仓库根目录调用 `$animation-vfx`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取 [AGENTS](../../../AGENTS.md)、[实际状态](../../../docs/current_state.md)、[handoff](../../../docs/handoff.md)、[架构](../../../docs/architecture.md)、[验收](../../../docs/acceptance_tests.md) 和相关最新设计。输入用户目标、基线完整 SHA、任务 ID、内容版本、受影响路径、正式消费者、已知失败与前置能力。缺信息先记录 unverified，独立可逆工作继续；重大创意不可伪称用户确认。

## 阶段流程与交付物

G0：读 [动画特效规范](../../../docs/animation_vfx_standards.md)，列状态动作、关键姿态、转换/中断规则、脚底/武器/枪口锚点、视觉碰撞边界、预警/判定/恢复时间轴、瞄准/反冲/空中/落地/受伤/死亡、特效起止、声音事件和生命周期/性能预算。
G1：用真实玩家控制和已接受玩法事件驱动表现。核心链：瞄准→松手开火→弹体出现→反冲爆发→空中动作→命中或落空→落地恢复。禁止特效回调决定伤害、资源或直接搬动角色。
G2：制作实际运行连续样板；验证左右/上下瞄准、连续开火、转向、落地、受伤中断、死亡、暂停恢复、慢时和重载。与 art-director 共用母版/比例/材质，不统一规定动画帧数。
G3：正式 Player/Enemy/Boss/机关实例接入，声音与实际事件同步；取消旧 epoch，清理节点/粒子/音频/回调；检查峰值并发、对象回收及目标设备预算。场景卸载后不得有残留效果打到新角色。
G4：录制正常速度连续画面，必要时逐帧分析枪口漂移、脚滑、突变、预警与判定错位、不可见弹体、遮挡落点、镜头跳变、反馈延迟；将帧号/tick/事件对应写入报告。
G5：用户评价动作连续性、反馈准确、操作流畅和视听可读性；目标设备实际测量单列。单张截图、若干姿势或节点成功创建不算完成。
交付：状态/锚点/时间轴卡、运行资源和正式绑定、带音轨连续录像、事件追踪、性能/生命周期测量及返工记录。

## 设计要求

使用 [专用模板](../../../docs/templates/animation_vfx_specification.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

运行 harness art 与相关 gameplay；记录正式输入至视觉/声音事件的实际序列、暂停/慢时/重入反例，对象释放与帧时测量。没有音轨的录像不能证明声音，构建成功不能证明延迟预算。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

gameplay-reviewer 检查正常速度动作再逐帧定位；最终依据连续性、可读性、同步和用户手感，不靠总帧数。AI 自评不能签玩家认可。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
