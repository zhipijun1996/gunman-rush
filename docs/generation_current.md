# 最新正式生成候选：平原内容v10（2026-10-15）

本段覆盖下面v9及旧八小关的当前性描述。最新用户已授权整区布局/动作/遭遇/构图重设计，独立分支feature/plains-designed-exploration，未合并/发布，最终整区质量仍review。正式链为 `DemoApp → PlainsRegionStage → PlainsRegionGenerator → PlainsExplorationTopology/PlainsRouteRecipes → PlainsRegionAssembler`；RunManifest/RunRandomStream/Definition、真实PlayerMotor与奖励保存服务继续复用。RoomGrammar/SetDressing不是当前正式地区主链。

v10使用三种手工宏观骨架的受约束变体、按身份变化的共享列距和层高，生成前保护完整主路、上层、溪谷和东外环，之后才做裁枝/能力门。当前依然正交共享列轴，不是任意形状嵌入；随机内容使stream positions变化，派生算法v4和各流隔离不改。旧v9 Manifest当前会明确拒绝，历史复现用冻结旧源；MetaSave合同未变。

动作与探索：正式初始单PulseLv1/基础跳与反冲，未来H/W/D和Studio能力不能用于主路证明。主路线短动作段留恢复/观察；溪谷以既有船、实际中箱、侧岛、下落/重启与营地回返构成发现；高奖变体按主路学习顺序避免直接重复，仍是可恢复的段落，不以模块数称大师难度。外环purpose真实消费现有ferry_dock；实际循环的方向/敌态/策略限制见测试原件，连通≠物理可达≠全方向公平。

构图消费实际area identity和实体支撑：风车侧焦点、钟拱上层、溪谷深度、开放小屋前庭，前景/镜头/HUD避让与真实触屏控件几何分别检验。已有水粉资产复用，种子装饰差异不当审美完成；未制作完整新资产系列。

[设计规格](quality/plains_redesign_design.md)、[空间卡](quality/plains_redesign_spatial.md)、[体验卡](quality/plains_redesign_experience.md)、[构图卡](quality/plains_redesign_scene.md)、[共同质量准绳](quality/level_quality_dimensions.md)。所有中间黄金/电影按自己的源码清单绑定；最终fresh回归与同条件80/电影尚需实际结果。

---

# 当前随机生成实现与质量验证

本页按 2026-10-14 `main@fa9b9502` 的实际消费者审计更新；生成规则权威仍为 [procedural_generation](procedural_generation.md)，最新正式范围见 [current_state](current_state.md)。本轮 V2 只扩展离线生产、证据与检查，不改变正式生成算法。

| 实际模块 | 职责与版本 |
| --- | --- |
| [PlainsRegionGenerator](../scripts/generation/plains_region_generator.gd) | plains-region-v8，RNG plains-region-v4；最多 4 次候选，验证失败用 verified_fallback，记录 tuning hash、布局和预算 |
| [PlainsExplorationTopology](../scripts/generation/plains_exploration_topology.gd) | woven_layers / linked_rings / crossroads；网格删选保连通/环路与 Boss 邻接，保留教学/可选入口，失败有界保底 |
| [PlainsRouteRecipes](../scripts/generation/plains_route_recipes.gd) | 以 actions/pressure/decision 描述实际操作，历史使用次数和重复限制影响选择，初图过滤部分复合配方 |
| [PlainsRegionAssembler](../scripts/generation/plains_region_assembler.gd) | Manifest 实例化、模块对接和捷径状态，不能依外观重新抽图 |
| [RunRandomStream](../scripts/run/run_random_stream.gd) | sha256_counter_52_v1，命名流分离；拓扑/内容/奖励/机关相位等可复现 |
| [PlainsRegionCampaign](../scripts/run/plains_region_campaign.gd) | plains-two-maps-v1，两图独立 seed/实例前缀与 Boss 角色 |

当前已实现能力包络筛选、输入轨迹、预算与账本、三种拓扑家族及 Boss 快行/探索/深层奖励等专项验证。ActionStudio 已有15种装备与H/W/D实现；正式平原仍基础单武器/一跳，正式成长、区域结束授予与后续能力锁尚未开放。V2旁路 CapabilitySnapshot 读取实际装备、授予、精力、共鸣和冷却，绑定原 RunManifest；不改保存合同，也不把Studio目录当正式解锁列表。

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

## LEVEL FOUNDRY 与 V2

LEVEL FOUNDRY 已合入 main，正式菜单开发入口可进入；`tools/foundry.py build` 验证短语与完整连续路线，`--promote` 只安装开发池，不代表正式地区准入。`tools/foundry.py experience` 新鲜执行并整理普通/进阶/大师三类设计卡对应的技术切片；主观难度和美术仍待校准。旧 config 的 hook `implemented:false` 表示工坊profile未接入，不表示游戏没有钩索。

[关卡生产体系](level_design_harness_v2.md)复用此链路，提供正式 Manifest + 实际 Motor 路线采集、分层诊断、同条件对比及未来地区设计 fixture。[审计报告](quality/level_design_v2_audit.md)区分已证代码约束与体验假设。旧 `PlainsRoomGrammar` / `PlainsSetDressing` 不属于正式两图对应主链，不能用其样板外推正式内容。

能力包络仍只做无碰撞筛选；现有地区trace只支持默认能力，V2遇请求/实际不匹配明确拒绝。trace只装配地形和射击机关，未实例化完整敌人/Boss战；新报告保留该范围，不能把自动三种策略说成全部玩家体验。
