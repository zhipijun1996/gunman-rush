---
name: region-generator
description: 修改随机区域拓扑、段落编排、模块池、内容奖励分布或体验节奏。
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

运行 harness gameplay；直接定位 [15 套地区](../../../tools/run_plains_region_tests.py) 与 [43 套历史](../../../tools/run_plains_ten_tests.py)，保留适用回归。结构统计、Motor 专项、完整体验三类证据不能混为一条 PASS。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

## 人工审查

gameplay-reviewer 检查三种路线实际决策、学习与恢复节奏、地图/动作重复、回程成本和公平奖励。美感/趣味须玩家体验，不用自动随意打分。

## 准入退出与返工

按 [policy](../../../docs/quality/policy.json) 的相关 G0–G5 执行。进入一阶段前上一相关阶段通过、输入与消费者明确；退出须专用模板的可证伪判据及对应证据成立。设计失败退 G0，操作/公平失败退 G1，表现失败退 G2，接入/状态失败退 G3；修复后重跑受影响门槛并复审。保留失败原件，不删除测试/降标。依赖阻塞写 blocked，缺审查写 review，缺真机写 awaiting-device。

## 完成与证据

使用 [质量报告](../../../docs/templates/quality_gate_acceptance.md) 和 docs/quality/records/<task_id>.json，逐项记录 design/technical/formal_integration/visual/animation/audio_vfx/gameplay/performance/independent_review/device/player_acceptance。只允许 passed/failed/unverified/not_applicable（有理由）；证据需路径、SHA256、提交/内容版本、观察和来源。技术通过不能宣称完整内容完成；所有适用条件具备才可 done。本技能文档本身不提供任何内容的 PASS 或用户认可。
