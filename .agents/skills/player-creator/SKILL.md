---
name: player-creator
description: 主角整体设计、动作与操作表现的新增或成套改造；用真实输入、正式消费者、完整动作和品质门槛验收。
---

# player-creator

## 触发与边界

主角整体设计、动作与操作表现的新增或成套改造。任务涉及即自动路由，不要求用户点名；用户也可显式 `$player-creator`。game-quality-gate 创建一次任务记录，相关技能追加证据，不重复建流程；调用关系：weapon-creator、ability-creator、art-director、animation-vfx，最后 gameplay-reviewer。

## 输入与依赖

先读 [AGENTS](../../../AGENTS.md)、[当前状态](../../../docs/current_state.md)、[玩家机制](../../../docs/player_mechanics.md)、[控制](../../../docs/controls_contract.md)、[构筑](../../../docs/rewards_and_builds.md)、[能力组件](../../../docs/ability_components.md)。输入基线、任务 ID、玩家体验、现有能力/武器与正式授予情况、消费者和配置。未来计划不得伪称已存在实现；重大创意标 proposed/user_confirmed 及原始依据。

## 阶段流程与交付物

- G0：用 [设计卡](../../../docs/templates/player_design.md) 写核心玩家判断、与现有内容的差异、输入和资源合同、学会方法、失败恢复、视听/镜头与具体验收。先检查现有 PlayerMotor/Ability/Shoot/Modifier 接口，禁止重造移动或伤害管线。
- G1：实际 InputRouter→能力→唯一 PlayerMotor→真实弹体/碰撞/资源。走完整开始结束，测试成功/失败/边界、地面/空中/墙面/移动参照系及连招。注入输入允许作为测试驱动；改位置/直接结果调用只能是注明的初始化，不能作为可玩证明。
- G2：art-director 统一角色/装备母版，animation-vfx 实现整套动作与声音。左右朝向、不同瞄准角、连射/升级切换、跳跃反冲、受伤/死亡和落地的正常速度连续录像；相机、HUD、枪口、脚底不漂移。
- G3：正式装备/能力授予、保存/读档/重载/切换、资源/伤害/奖励、暂停和旧请求取消、对象性能；原型菜单通过不能代替正式消费者。升级撤销/重复加载/旧存档、能力不足的路径必须有反例。
- G4：运行适用 harness gameplay/art；独立审查比对设计、状态覆盖、连续画面及通用 [审查方法](../../../docs/quality/review_method.md)。修复后复审相同版本。
- G5：真实设备与用户分别确认手感、角色形象、动作、玩法价值；没有反馈保持未验，不能自行签最终认可。

阶段交付：角色形象/状态与动作矩阵、真实操作原型、区域黄金合屏、不同武器/能力组合、连续录像和交接。

## 设计要求

角色定位、剪影/比例、移动与战斗动作语言、武器握持/瞄准、受击/落地/死亡、相机与 UI 可读性。核心动作保持跳跃—射击—反冲—空中决策闭环。明确形象、叙事、能力、碰撞和表现各自的所有权。 视觉只订阅已接受事件，不能决定伤害/资源或搬动玩家。细节规范见 [动画标准](../../../docs/animation_vfx_standards.md) 与 [Visual Bible](../../../docs/visual_bible.md)。

## 自动验收

先填写质量记录，执行 `python3 tools/harness.py --profile gameplay --profile art` 和相关状态/输入/保存专项；新增客观不变量用参数化与正反测试验证，不删除旧断言。记录版本、环境、退出码、场景/能力/Seed、轨迹和性能；运行 `python3 tools/quality.py check`，内容宣称完成再 `--require-complete`。

## 人工审查

观察完整操作路径是否成立、玩家是否需要新判断、反馈与攻击一致、轮廓和姿态是否连贯、武器/能力组合是否破坏关卡、镜头是否给出动作所需信息。对比匹配条件的改前/改后录像；自动数字不替代玩家认可。

## 准入退出与返工

按相关 G0–G5 顺序；前置契约和输入明确后准入，交付物和可证伪证据满足后退出。玩法失败返 G0/G1、表现失败 G2、正式流程失效 G3；保留失败及修复版本，重新执行相关测试并独立复审。缺设计选择停该分支，其余不依赖工作继续；缺设备 awaiting-device，缺审查 review。

## 完成与证据

player 类型记录全部十一维，遵守 [总门槛](../../../docs/development_quality.md)、[policy](../../../docs/quality/policy.json) 和 [质量报告](../../../docs/templates/quality_gate_acceptance.md)。passed/failed/unverified/not_applicable 分开，N/A 有理由。技术原型/局部升级完成不能代替整套内容 done；截图不能证明动作流畅，AI 自评不能证明用户认可。

## 人物动作扩展（2026-10-13）

读取 [设计入口](../../../docs/design/player_actions/README.md)、[动作与harness规划](../../../docs/quality/player_action_plan.md)，使用 [动作覆盖卡](../../../docs/templates/player_action_coverage.md)。

先建立实际角色与正式场景inventory，填写动作覆盖卡；逐角色列身体、上身/武器、能力附件的叠加/覆盖与中断恢复。每个角色仅一个当前武器运行实例；敌人/Boss按自身动作盘点，不复制玩家武器能力矩阵。先黄金样板后扩产，禁止将Courier通过外推所有人物。
