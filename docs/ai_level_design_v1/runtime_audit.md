# 运行链路审计与四层模型接入建议

审计日期：2026-10-23。基线为 `main@e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，另核对当前开发集成头 `integration/four-lines-20261023@a074a709ffa64c1382d73d2dab6dcff673222728`。本文为源码只读审计；没有新跑 Godot，不把库内已有回执签成 fresh，也不签玩家趣味、设备或美术认可。文件行号以下均指 main 基线；开发差异另列。

## 实际入口与数据

| 系统 | 真实生产与消费链 | 已有约束与限制 |
| --- | --- | --- |
| 风铃平原 | `project.godot:6` → `scenes/demo/demo.tscn` → `scripts/demo/demo_app.gd:402` / `:406` → `PlainsRegionGenerator` → `PlainsExplorationTopology` / `PlainsRouteRecipes` → `scripts/demo/plains_region_stage.gd` → `scripts/generation/plains_region_assembler.gd:10` | 正式两图的平原主链；不是旧 RoomGrammar/SetDressing。Generator 有 v10 基线及 RootBell v11/v12 内容分支，实际模式由 DemoApp 固定。`plains_region_generator.gd:24` 最多四次候选并有验证保底；失败不靠无限换 seed。 |
| 荆棘森林 | `demo_app.gd:405` 构建真实能力快照，`:406` 调 `ThornForestRegionGenerator`；`:447` 选 `ThornForestRegionStage`，其装配器为 `thorn_forest_region_assembler.gd:12` | `thorn_forest_region_generator.gd:20` 当前默认仍 v15；v16/v17/v18 都有明确开发入口，v18 不是默认森林或商业准入。历史 v1 和版本化布局保留以重建存档。 |
| LEVEL FOUNDRY | `scripts/ui/demo_menu.gd:217` → `demo_app.gd:1150` → `FoundryLab` → `FoundryCatalog.batch()` → `FoundryWorld.build()` → 原 `PlatformingModule` | 明确开发工坊。`tools/foundry.py:22` 构建/验证；`--promote` 仅更新 `resources/foundry`，不是向正式地图池晋级。 |

`PlatformingModuleDefinition` 已覆盖大量 Module 所需字段：原始平台/单双向面、刺面、锯轮、摆渡、锚点、主支路、多入出口、压力与基础能力筛选。`platforming_module_definition.gd:35` 的 `is_valid()` 只验证结构、安全站位和索引，不执行真实动作；`:139` 的 `supports()` 明确只是能力包络筛选。不能改名为“物理验证器”。

`PlatformingModulePort` 已有身体中心位置、方向、最大普通/反冲速度、冷却与跳跃/空射要求；`platforming_module.gd:116` 在实际 Motor 上检查落地、位置误差、速度、burst、真实剩余资源。现有实际端口是**稳定站立接缝**：必须 `is_on_floor()`，不是任意空中接缝。四层侧车契约可以表达空中入口，但旧消费者不能声称已经支持；须拒绝适配或另经现有森林动作链消费。定义中的多端口数组保留备选，canonical `entry_port` / `exit_port` 仍是实际遍历合同，不能把数组存在当所有组合均验。

森林内容使用不同的 Dictionary 结构：具名 `platforms[{id,rect,one_way}]`、`hook_anchors`、`dangers`、`danger_surfaces`、`routes`、`steps`、`action_program`、`ports`。`forest_exploration_modules.gd:8` 为有限库，`:53–64` 所有结果统一写 `requires=[grapple]`、候选/未验状态。它不是 `PlatformingModuleDefinition` 的子类型。`forest_exploration_place_embedding.gd:6` 负责平移、稳定 ID 映射、挂点与路线接入，最终由森林现有装配器实例化；不能丢掉挂点、宿主、上下刺向和返回路线后强转成通用矩形模块。

## 生成方法真实能力与缺口

平原不是毫无意图的几何随机：`plains_region_generator.gd:49` 起先提交拓扑，命名流分离 topology/content/reward/phases；保护语义路线后裁边，身份影响配方与地貌。`plains_route_recipes.gd:4–21` 有 17 条配方，包含操作、压力和判断，`:23` 起按身份、教学、历史使用次数挑选。缺口是有限手工骨架与有限配方，仍共享列轴；`actions/decision` 是设计声明，不是实际行为观测。同一个 twin_gears 资源可在多配方中出现，不能按配方名字计新玩法。

森林 `thorn_forest_region_v2_v18.gd:29` 从 v15 `_candidate` 出发安装 `ForestExplorationNetwork`；`:36` 验确定性重建及源一致。`forest_exploration_network.gd:18` 真实嵌入双窗/7/Z/倒木等场所，迁移 Boss 并写主路、奖励、回程；`:91` 的自身合同明确“场所链而非充分网状”、真人时长未验、production_pool=false。root seed 改变 Z/倒木顺序与两图反排，但不能由拓扑 hash 推出探索价值。有限代码工厂的目录项不等于实现、源动作脚本不等于通关。

Foundry 使用 6 个有限模板（`config/platforming_foundry.json`），每个 2 个模块 ID 列表变体及 4 个初相位（`foundry_catalog.gd:6`、`:89`）。拼装依入口/出口对齐和 `_compatible_geometry`；`:158` itinerary 再拼短语，≤6 个短语且总模块≤24，运行扁平化为 nodes。主库当前 36 accepted 短语 + 18 itinerary，`design_status=awaiting_playtest` / `production_pool=false`；这不是 54 个新机制，phase/profile/顺序变化需另算变体。当前生成器没有自动发明交互关系、质量多样性档案或模型训练；`tools/foundry.py:137` 的 next 是有限 AI revision jobs 队列，明确要下一代理会话执行。

## 可复用验证、评价与自动化

1. **低成本规则**：Definition.is_valid/supports、各 Generator.validate、manifest hash/重建、接口/资源/拓扑检查可继续用，不复制 Python 物理。
2. **真实 Motor**：`tools/foundry_validate.gd:34` 创世界只初始 spawn；`:65` 真实 Router→Controller tick，24×36 身体 swept AABB 和移动锯相对扫掠；`:103` 连续逐模块穿越且检查实际入口/出口。输入由旧 `tests/branch_module_driver.gd` / `plains_interactive_motion.gd` 的反馈策略产生，是一个有界可行策略，不是人类操作成功率或最优解搜索。
3. **确定性回放**：`foundry_validate.gd:128` 重建同世界，以记录的 axis/actions 重放，最大位置偏差≤0.05；还有 JSON 落盘重放。`:188` 起 itinerary 单独连续 trace/replay，不能以单片通过替代串联。运行工坊用 `foundry_route_player.gd:18` 向同 Controller 提交输入，position 只核对不搬角色；`:76` 使用较宽 2.0 的运行偏差阈值，应保留其用途区别。
4. **整图与正式上下文**：`tests/plains_region_trace.gd:8` 复用正式地形及铃机关装配，仍是 fixture，不包括完整敌人/Boss；fixture 快走不能签正式 App 战斗。`tools/level_design.py:148` 分析会核对应 invocation/log/source 并拒绝漂移；`level_design_analysis.py:197` 只能返回 REVIEW 或 REJECT，subjective_quality 始终未验。森林现有 `run_forest_exploration_motor.py` 和 `run_forest_places_feedback.py` 绑定真实 App、完整身体/挂点/奖励/回程，需按候选对应版本选择，不能用 v16 reader 给 v18 签名。
5. **设计契约**：`tools/level_design_contracts.py:301–382` 已有 Build、Action、Phrase、Challenge、entry/exit 状态区间、拓扑/场景/节奏；`:385` 严格版本和引用检查。它是 intent schema，`evidence_boundary` 明确未验，不能重用为 runtime manifest。四层模型应引用这组设计合同与既有来源，而非新造第二套控制/装配系统。
6. **反馈与租约**：`tools/production_loop.py:238` 汇入反馈历史，`:550` 宿主任务、`:726` 有界运行、`:1426` 独审身份、`:1275` 检查点、`:1055` 原质量门槛。模型调用/独审与玩法验收应复用这些生命周期；不能另加一个自洽但无正式宿主的“自主”空循环。
7. **CI 与缓存**：`tools/harness.py:232` 输入 digest、`:465` 缓存复核日志/完成标记/产物原字节与来源；`tools/production_plan.py:70` 已有按改动路径和依赖闭包选 development/integration 检查，未知共享范围保守 full。接新专项时注册其真实依赖/影响规则；不要声称只跑一个新单测便是最小充分 CI，也不能改旧 budgets/断言。

## 重复、兼容性与最小改法

- 平原 Resource、森林 Dictionary、Foundry manifest、map-edit JSON 是不同层次；统一应先有**有损拒绝的侧车适配器**。来源绑定 Resource/factory/manifest；几何与原 action_program 保留原数据，不在统一 schema 复制物理数值默认。
- 单向面/危险宿主/相位/角色资源不能由 tag 推断；缺字段写 unknown。特别是森林 `requires=[grapple]` 不能解释成每条普通路线必需 H，Foundry profile 也不等于最低能力锁。
- canonical/hash、pair/rect、route/port 构造在旧版本有重复，但部分是历史复现合同。当前不作跨版本大规模去重；新 adapter 可共享规范化代码，不重签旧 manifest 或删除历史源。
- `FoundryCatalog.basis()` (`foundry_catalog.gd:38–76`) 保守散列整个 generation/player/combat/input 子树及部分资源，新增 generation 脚本也会令旧开发池失效。已在项目历史中造成真实 Web 阻塞。新设计 schema/分析尽量独立于 runtime 子树，需动时按原 build 真验重建，禁止改 basis 或 export stamp 放行。
- 初版宜新增工具/版本化侧车与报告，输出仍映射现有 Resource 或森林 factory 接口；候选默认开发/隔离，正式入口与有效库原字节保留。评价分技术、AI设计、真人三栏；优质/普通/疑似差候选是选样假设，必须允许证据推翻。

## 最新开发分支差异不能忽略

`git diff main a074a70 -- scripts/generation tools/foundry.py tools/foundry_validate.gd tools/level_design.py tools/level_design_contracts.py tools/level_design_analysis.py tools/harness.py tools/production_loop.py`：生成子树只改平原 manifest 一行 `shot_energy_version`，上述工具原字节不变，森林生成/装配原字节不变。

但底层玩法与 UI 已实质改变：`config/player_tuning.json:12` 空射容量从 2 改 1；`scripts/combat/shot_energy_policy.gd:19–57` 加入射击不消耗时间能量分支；`scripts/player/player_controller.gd` 和相关 Definition 消费新合同；平原 manifest `plains_region_generator.gd:442` 改 `time-energy-v2`。`config/foundry_capabilities.json` 名称与说明同步一发，并保留显式四发历史开发包；Foundry batch/54 replay 和 export basis 已换版本。`project.godot` 新 typography autoload/font，demo/menu/表现也变化。

因此在 main 上验证所得是 main 的双发/射击精力规则，不得当最新开发分支的一发/时间能量结论。至少单列两种来源与未验范围；若目标是最新体验，须在准确开发源真实重验。不能只手改标签或 max_air_shots 作完整迁移。

## Macro Module 是否必要：可选体验编排层

**第三层有价值，但不是每张地图必须经过的中间层。** 它的存在理由是可独立复用、可独立验证的跨模块体验约束，不是“更大”或“包含多个矩形”。Map 应允许直接消费 Cell / Module / Macro Module；Module 本身可以有多入口、支路和小回环。

现成正例是 Foundry itinerary：`foundry_catalog.gd:158–180` 保留 phrase boundaries，再扁平 nodes 交原 World；`foundry_validate.gd:188–220` 给完整连续路线另跑真实 Motor 与回放，因为单短语分别通过不能推出串联后的速度/冷却/资源/相位可行。这支持 Macro **合同**，不要求 Macro 专用运行节点。另一正例是 `ForestExplorationNetwork.install`：多个场所之间的普通推进、奖励领取、失败去旧营地、远岸去 Boss 的去向不同，局部成立不能推出总回程和奖励关系成立。

反例：`forest_exploration_places.gd:45` 的 seven_bough_reveal 已自带多端口/主路/奖励/回程，却仍可作为一个复杂 Module；仅因面积大升级无收益。纯顺序 ID 列表、同几何换名字/坐标/相位、多个彼此独立的挑战恰好放一起，也不自动成为新 Macro 玩法。Foundry phrase 与 itinerary 不应硬按固定名词一一改层，须按本轮采用的动作挑战边界映射。

推荐升级判据：有具体跨边界状态/资源/时机，或教学→组合→回收、分叉→收益→回程等统一设计目标；其完成条件无法由子项各自通过推出；并且有自己的外部接口、版本与实际连续证据。无这些条件，保留普通 Module 或 Map 的直接编排，省去空壳和重复准入。每个 Macro 的 novelty 也必须依据行为关系/可观测决策，而非 children 数量。

## 本次核验方法

实际只读命令包括 `git show <sha>:<path>`、`git grep -n ... <sha> -- <paths>`、`git diff --name-only/--numstat main <dev-sha>`，以及 Python 标准库解析 `platforming_foundry.json` / `batch.json`、枚举资源。记录中的 72 Resource、6 template、36 accepted、18 itinerary / 18 connection proof、零 rejected 是库文件当下内容；没有本轮 fresh Godot 日志，不能把零 rejected 推断为候选搜索历史从未失败或设计优秀。
