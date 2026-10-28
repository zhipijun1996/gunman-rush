---
name: enemy-creator
description: 设计或实现新敌人、实质行为改造，以及按统一标准核对或补齐已有怪物完成度；不用于单纯修正拼写。
---

# enemy-creator

## 每物种完成标准

新怪与旧怪完成度核对先用[怪物完成标准](../../../docs/quality/enemy_completion_standard.md)的E01–E12及扩展Enemy Design Sheet，共用原G0–G5／十一维。逐项分开记录实现事实与实际验收；共享命中模板、若干姿态或Lab通过不代表整怪完成。先统一身体、完整动作及进入／退出／中断，再验正式遭遇与生命周期。缺实现不得记不适用，不以平均完成率抵消缺项。旧怪纯表现补齐引用原机制，不强制新增AI；新物种仍需独特玩家判断。

## 机制价值先于扩产（FOREST-DEPTH-02）

使用[黄金玩法假设对照](../../../docs/quality/review_method.md#黄金推广前玩法假设对照)：先比较真正不同的玩家体验假设，再在同条件真实消费者上记录目的打法、最便宜退化打法与关键动作／对象消融。由不同作者在原黄金审查阶段作继续／修改／淘汰决定，整合只消费被接受的具体机制范围。不得用技术通过、阶段编号、Hash、动作计数或“G5尚待玩家”跳过此处的专家设计淘汰；仍不能把专家判断签成玩家认可。共享组件可保留，缺少新增判断的候选允许删除；失败只阻断其后继。

## 触发与边界

设计或实现新敌人、实质行为改造，以及核对或补齐已有怪物完成度；不用于单纯修正拼写。 从仓库根目录调用 `$enemy-creator`。使用 [总门槛](../../../docs/development_quality.md)；重要内容由 game-quality-gate 建立一次任务，专业技能补充同一记录，不重复执行共用阶段。

## 输入与依赖

读取当前AGENTS及当前状态；按任务消费者读取相关设计与架构，保留目标、完整SHA、任务/内容版本、路径、已知失败和能力来源；缺证据写unverified。

## 阶段流程与交付物

A / G0 敌人策划：Enemy Design Sheet 写名称/背景/地区、战斗职责、独特操作压力、对射击反冲跳跃落点的影响、AI 状态机、移动/攻击、预警/判定/恢复时间、反制、受伤死亡奖励、旧敌人对照、地形/同伴组合。必须新增玩家操作或策略；换图/HP/速度不成立。
B / G1 灰盒：复用 [EnemyDefinition](../../../scripts/enemies/enemy_definition.gd)、[AI](../../../scripts/enemies/enemy_patrol_ai.gd)、[Motor](../../../scripts/enemies/enemy_motor.gd) 与既有 Health/[DamagePolicy](../../../scripts/damage/frame_damage_policy.gd)。让真实输入和弹体产生攻击/命中/死亡；含暂停、中断、无目标及失败反例，不旁路正式伤害。
C / G2 美术动作：用 art-director 区域母版和 animation-vfx 状态表，按需求完成待机/移动/预警/攻击/恢复/受伤/死亡；锚点、连续转向和动作过渡需正常速度录像，无统一帧数门槛。
D / G1–G3 遭遇：平地、多平台、落差、机关与其他敌人组合；写生成区域/机制标签、禁用组合、安全空间、同时压力预算。检查镜头外攻击、出口堵塞和落点公平性。
从实际接敌函数逐项核距离、视线、目标保护区、并发上限与落地等前提：敌人允许生成，不等于它能在拟定观察岸发动攻击。站位无攻击时先记录哪项真实谓词拒绝；不要先移动敌人、加射程或削弱安全保护。普通弹、钩头与身体各按实际形状扫掠，中心射线可通不代签可射杀。
E / G2–G3 反馈：动画粒子、命中/落空、声音、死亡与掉落反馈对应已接受事件；死亡只结算一次，卸载取消旧请求。
F / G3–G5 集成：写正式场景/实例/生成池路径和许可证据；通过相关门槛后才入正式随机池。交可玩场景、设计卡、配置、正式运行录像及验收报告。

## 设计要求

使用 [专用模板](../../../docs/templates/enemy_design.md) 写场景/前置、方法、可观察结果和失败条件。复用真实配置/Definition/架构，禁止重复数值默认值、无消费者框架或为通过测试改基础物理。占位仅限明确标注的原型，不能冒充最终内容。

## 自动验收

日常Development按 `tools/production_plan.py` 选择相关专项与正式消费者，不每次强制完整gameplay＋art；Integration覆盖受影响完整系统，未知full。最终仍执行原完整适用profile（gameplay，素材改变加art）与Release门槛，局部结果不能升签整套。核对 EnemyDefinition 与实际实例一致，真实弹体、暂停/回退/死亡/重复回调、组合场景反例。相关回归见 [核心测试](../../../tests/run_tests.gd) 和 [地区测试入口](../../../tools/run_plains_region_tests.py)。检查资产记录及任务完成条件。 记录实际命令、环境、退出码、日志和版本；计划命令不算执行。执行 [质量检查](../../../tools/quality.py)；静态检查、运行测试、实际宿主调用分别记证据。

交付按[生产入口](../../../docs/cloud_production.md#按验证需要选择最轻交付)：只需观察用真实MP4，必须操作用Web，两者都需则两份。

## 人工审查

采用 [通用审查方法](../../../docs/quality/review_method.md) 的不变量与对照/变形测试，覆盖实际绘制与正式消费者；用户反馈是回归样本，不是发现问题的唯一列表。

观察新的操作价值、预警可读性、可反制窗口、动画自然性、材质光照、声音和组合公平性。gameplay-reviewer 比较设计/实际，玩家确认趣味和表现，设备测量单列。

## V3实证：从生态缺口到有限正式遭遇

先盘点地区身份、已授予能力、现有敌人的行为差异、实际空间/安全点与奖励压力；不要默认沿用旧怪，也不要先决定新增数量。
至少比较多个机制方向：分别写玩家新增判断、与地形/反冲的关系、制作与动画成本、可读性风险、可复用范围，再选最小有价值候选。
风险、收益、预告和主路压力来自该地区设计身份、当前Definition和真实消费者；本轮具体银行宽度不是跨地区全局规则。

候选必须真实进入正式DemoApp/地区消费者验证，独立Lab通过只提供局部证据：

1. 从正常入口用真实InputRouter接近，记录其他敌人、机关、镜头及资源，不搬角色、不停敌、不旁路伤害。
2. 活体非击杀通过/撤回与击杀策略分别跑；需要打断时由实际弹体造成HP变化，射击请求不等于命中。
3. 已死、失活、位置改变/还原后仍有合法通路；唯一钩点、回能或落点不能依赖敌人继续存活。
4. 完成相邻机关、完整出程与返程，核对连续资源、相位、失败恢复；单独跨过敌身不等于整条连接通过。

准入以可证伪的物理/机制class约束及有界替换预算表达，不写Seed白名单或靠无限重抽避错；新几何类另做真实证据。
修改默认内容须独立内容version、每run选择pin和旧Manifest hash状态恢复；保持存档/RNG schema与已生成实例行为。
测试可显式用现有loader pin历史内容构造真实snapshot，但必须说明不是冻结旧二进制，保留hash/version/actor数量等全部原断言。

本轮实际CLI：`python3 tools/run_root_bell_formal.py --default --output-dir build/root_bell/<new_run>`；需要实际电影加`--movie`。
该15案例入口是standalone；已注册的`root-bell-tests`负责原专项，不把新formal入口冒称已注册Harness check。
原生证据、旧电影、当前源码和离线新验收器各自绑定SHA；`--revalidate-frozen`只复核旧证据，不冒称fresh Godot。
[实际父集成与失败反例](../../../docs/evidence/region_production_v3/enemy_parent_integration/README.md)保留原27+9拒绝、旧失败和不同source闭包。
资源必须从实际accepted shot/projectile first hit，到独立grant与accepted recovery按event_id/epoch/tick一一绑定，合法clamp也要验证。
删去grant与recovery再连贯重放剩余资源曲线仍须拒绝；数据自洽不等于真实资源因果，更不替代原生来源。

[独立有限试玩审查](../../../docs/evidence/region_production_v3/ecology_admission/README.md)将有条件接受与后续default复验分开。
条件未补齐不得改写原REJECT；有限runtime候选可保持review交试玩，但不代签G5、用户、设备、商业品质或整区生态完成。
玩法失败退回空间/AI时序与反制设计；视觉失败交art-director/animation-vfx；验收器误收交实际证据消费者修复并保留原连贯反例。

## 准入退出与返工

按[共同契约](../../../docs/creative_direction/README.md)及原G0–G5准入退出；设计失败RETHINK、局部REWORK、不适候选DISCARD。保留失败原件，重跑受影响检查并独立复审，不降工程门槛。

## 完成与证据

按[共同契约](../../../docs/creative_direction/README.md)记录原十一维、版本/SHA、消费者、实机证据和未验范围；缺审查/用户/设备不宣称完成，旧证据保留原来源。

## 共同创作契约

[预制作→制作→验收及版本总谱](../../../docs/creative_direction/README.md)是共同执行依据。总谱SHA变更须RETHINK并复验；交付写贡献、协作、新行为/视觉、主题冲突和实机验证。REWORK局部修复，DISCARD隔离候选；ACCEPT只限真实已验范围，审美不绕过工程红灯。

历史复现按需读取[原始Skill与迁移索引](../../../docs/archive/skill_history/README.md)，不默认加载旧轮授权、PR实录或失败数字。

## Underworld第三轮地面受伤反例

无重力的地面敌人被受伤力推出窄台会永久悬空；只给该受伤通道检查真实下一脚步支撑，保留宽地面击退、空中敌人、普通AI及旧技能合同。双侧边缘/宽地面/空中对照、失败及修复范围见[第三轮经验](../../../docs/underworld_feedback_r3.md)。

普通受伤力不能抢占钩索/主动技能的既有运动所有者；真实producer显式传技能语义，接受事件保留hurt音画，原技能继续负责force/stagger。必须保留原移动目标和技能时钟断言，不能以新受伤需求为由删除。
