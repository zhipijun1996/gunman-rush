# 当前随机生成实现与质量验证

本页描述 da76b0a 基线的实际消费者；生成规则权威仍为 [procedural_generation](procedural_generation.md)，最新正式范围见 [current_state](current_state.md)。本轮不改变算法。

| 实际模块 | 职责与版本 |
| --- | --- |
| [PlainsRegionGenerator](../scripts/generation/plains_region_generator.gd) | plains-region-v8，RNG plains-region-v4；最多 4 次候选，验证失败用 verified_fallback，记录 tuning hash、布局和预算 |
| [PlainsExplorationTopology](../scripts/generation/plains_exploration_topology.gd) | woven_layers / linked_rings / crossroads；网格删选保连通/环路与 Boss 邻接，保留教学/可选入口，失败有界保底 |
| [PlainsRouteRecipes](../scripts/generation/plains_route_recipes.gd) | 以 actions/pressure/decision 描述实际操作，历史使用次数和重复限制影响选择，初图过滤部分复合配方 |
| [PlainsRegionAssembler](../scripts/generation/plains_region_assembler.gd) | Manifest 实例化、模块对接和捷径状态，不能依外观重新抽图 |
| [RunRandomStream](../scripts/run/run_random_stream.gd) | sha256_counter_52_v1，命名流分离；拓扑/内容/奖励/机关相位等可复现 |
| [PlainsRegionCampaign](../scripts/run/plains_region_campaign.gd) | plains-two-maps-v1，两图独立 seed/实例前缀与 Boss 角色 |

当前已实现能力包络筛选、输入轨迹、预算与账本、三种拓扑家族及 Boss 快行/探索/深层奖励等专项验证。通用多武器升级树、区域结束授予大能力与后续能力锁尚未正式开放；未来用真实能力快照扩展，不把背景要求当现有消费者。

## 五层生产与七项独立验收

五层分别为：宏观拓扑（主支路/环路/捷径/层连接/单向回程/Boss接近/长度）；中观段落（教学/观察/平台/战斗/机关/恢复/奖励）；微观动作（已验模块及端口速度/资源/相位）；内容奖励（敌人/机关/商店/箱子/补给/线索与风险收益）；体验导演（学习顺序、高压长度、恢复、动作交替、选择价值、惊喜、重复、回程和地标情绪）。这是制作和评审分层，不声称已有独立的“体验导演”运行服务。

分别报告 A 拓扑、B 真实物理、C 能力资源、D 可复现、E 结构多样性、F 动作多样性、G 玩家探索趣味。A/D 通过不推导 B/F/G。未来逐任务补充下表观测，不改现有随机流以凑指标。

| 观测 | 来源和审查方式 | 不足以证明什么 |
| --- | --- | --- |
| 拓扑签名 | 去除坐标/贴图，比较连接、环路、分岔、回程和 Boss 路径 | 更多 hash 不代表更多选择 |
| 动作序列签名 | 真实输入轨迹的跳跃/射击反冲/落地/等相位/交互序列 | recipe 名称只是计划，需轨迹核对 |
| 机制组合签名 | 实际遭遇的敌人/机关/地形同时约束及玩家反制 | 数量不代表操作差异 |
| 风险收益签名 | 路程/回程成本、危险暴露、有限资源和领取收益 | 不制定新的经济数值 |
| 压力/恢复/重复/回程 | 连续高压段长度、安全恢复间隔、重复遭遇频次、返回输入时间 | 自动统计不等于玩家趣味认可 |

每个代表 Seed 至少覆盖快找 Boss、正常探索成长、绕路取高级奖励后返回；范围由本任务风险选择，注明实际 Seed 与能力。能力锁路径要有确定先授予能力的流程证据、旧存档/弱能力反例、无循环锁与可回程验证，不硬编码“默认已会”。不同枪的攻击/反冲/资源必须来自实际 Definition，不能假设共用轨迹。

已有入口：[地区套件](../tools/run_plains_region_tests.py)、[真实轨迹](../tests/plains_region_trace.gd)、[模块操作](../tests/plains_exploration_motion.gd)、[正式 GUI](../tools/verify_plains_region_browser.py)。新增断言先保留旧套件，不降低无损/危险扫掠门槛。
