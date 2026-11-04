# 项目结构与文档索引

新会话从 AGENTS → 当前状态／父任务 → 模块导航 → 相关圣经和对象数据进入。分类按内容职责，沿用现有文件，不为分类批量搬目录。

## 四类文档

| 类别 | 当前入口与位置 | 维护方式 |
| --- | --- | --- |
| 项目管理 | [当前状态](current_state.md)、[任务](tasks.md)、[管理规范](project_management.md)、[协作交接](cloud_production.md)、`worklines/<议题>/` | 只保留当前状态、依赖、负责人、验证与下一动作；完成的多轮记录退出活跃视图 |
| 设计圣经 | [游戏设计](game_design.md)、下方圣经索引 | 长期方向和约束；相关任务按需读取，直接维护完整正文 |
| 具体数据 | [怪物／Boss 数据索引](enemies_and_bosses.md)、下方对象数据索引 | 定义对象行为、状态、技能、表现及参数字段；与真实 Godot 消费者同步 |
| 临时与追溯 | `build/`、工作线中的中途审计／实验报告；必要归档在 `docs/archive/`、`docs/evidence/`、`creative_direction/archive/` | 临时输出任务结束删除；仅为验收、恢复、来源、许可或复现所需的原件归档，历史不进入默认上下文 |

README／模块导航和工具链、测试、架构手册是项目管理的支撑入口；专业 Skill／模板是执行方法，不另立设计规则。冻结来源和候选实验不作为当前圣经。文件名含 latest、版本或日期不自动取得权威。

## 设计圣经索引

| 约束范围 | 唯一主题入口 |
| --- | --- |
| 整体玩法与战斗原则 | [游戏设计](game_design.md)；具体伤害／死亡语义见 [伤害合同](damage_and_respawn.md) |
| 输入、移动和资源合同 | [输入](controls_contract.md)、[物理](player_mechanics.md)、[资源](combat_and_recharge.md) 各管自己的主题 |
| 地图生成、模块与难度 | [生成](procedural_generation.md) → [模块](platforming_modules.md)、[压力维度](difficulty_profiles.md)；当前版本由 config／Provider 选择 |
| 路线、能力锁与流程 | [运行路线](run_and_routes.md)、[能力组件](ability_components.md)；长期地区目录为 `world_regions.json` |
| 构筑与永久成长 | [奖励构筑](rewards_and_builds.md)、[家园保存](home_and_save.md) |
| 全局美术 | [Visual Bible](visual_bible.md)；[制作基础](art_foundation_v1.md) 解释生产方法，不另选画风 |
| 区域方向 | [Bible 注册表](creative_direction/bibles/registry.json) 的 `current_bible` 选择 [平原](creative_direction/bibles/1-windchime_plains_region_bible_v2.md)／[森林](creative_direction/bibles/2-thorn_forest_region_bible_v2.md) 原始方向；`direction_path` 和 `shared_style_authority` 是同一方向的结构化绑定 |
| 剧情 | [剧情入口](design/story/README.md) → [循环规则](design/story/loop_rules.md) → [故事圣经](design/story/story_bible.md)；简版只解释同一规则，人物／日程／结局细案为提案 |

## 具体数据索引

| 对象 | 当前数据文档 | 机器参数与实现入口 |
| --- | --- | --- |
| 普通怪／Boss | [对象索引与缺口](enemies_and_bosses.md)；[冲锋怪完整样例](design/enemies/plains_charger.md) | `resources/enemies/`、`resources/bosses/`；EnemyBehaviorRegistry／BossFactory 确定实际注册身份 |
| 武器与技能 | [全武器](quality/all_weapons_spec.md)、[动作预算](quality/action_budget_spec.md)、[操控手感](quality/weapon_feel_spec.md) | WeaponCatalog、`resources/weapons/`、`game/combat/weapons/`；三页分别管攻击生命周期、运动预算、分支操控，不各立参数默认值 |
| H/W/D 与恢复 | [动作入口](design/player_actions/README.md)、[空中恢复](quality/air_action_refill.md) | `resources/player/traversal.tres`、`game/player/actions/`；正式授予见运行路线 |
| 道具 | [覆盖矩阵](worklines/item_v5_01/consumer_coverage.md)、[道具配置说明](item_authoring.md) | ItemCatalogV5、`config/item_v5_*.json`；逐件解释仍需整理，P17 规则未决 |
| 机关、危险和世界对象 | [世界组件](world_components.md)、目标地区具体机制文档 | `game/world/objects/`、`game/world/levels/content/` 与实际 Resource；按 [模块导航](module_map.md) 找消费者 |

数据规范记录身份、用途、状态转换、触发与反制、伤害／奖励、表现、生命周期、参数来源和验证入口。运行值只维护于 Resource／配置及其 Definition 字段；文档写字段含义和单位，不复制一套默认数值。仍存在的代码常量如攻控初始冷却／并发上限须明确真实来源，后续参数化时归并到唯一配置。

工作线中的 `spec.md` 如已被当前消费者选定，属于具体数据而非进度。例如鸣铃巡游机和牧风者的当前规范由方向文件 `boss.current_overrides` 精确绑定；搬动／改写时核对应注册引用与证据身份，不另抄一份竞争规范。

## 来源、候选与临时文件

- `design/player_actions/*_v*.md` 与 sources 是原始设计来源，当前输入／资源行为从上方合同读取。机器上下文区分原始方向与当前规则。
- 森林默认 `forest-bible-world-v15`；v16–v18 是显式候选，待选择采用范围，不按文件日期自动晋升。
- 根层 plains／underworld 的 delivery、report、validation 及旧 SVG／TileMap 指南是专项报告或特定消费者资料。只有任务／真实消费者需要时读取，不覆盖当前圣经。
- 中途审计、抓图、计划和调试输出优先写 ignored build；交付时结论归入当前正文或任务结果，删除中间稿。必要原件保留来源／SHA／用途，旧通过不签当前实现。
- P17 与剧情细案继续保持未决。完整16地区是设计池，不是当前已开放范围。

## 实际目录

| 路径 | 职责 |
| --- | --- |
| `game/` | 正式功能、专属场景和局部资源；入口 `game/application/demo.tscn` |
| `experiments/` | 可启动开发入口、练习政策和有限样板 |
| `config/`、`resources/` | 参数、目录、authoring 与 Godot Resource |
| `scripts/`、`scenes/bosses/` | 仍被消费的 Definition 身份、版本布局及 Boss 场景 |
| `assets/` | 当前图声、原图、来源和许可 |
| `tests/`、`tools/` | 真实回归、创作／构建／验证／交付工具 |
| `.agents/skills/` | 按专业加载的操作方法 |
| `.github/workflows/` | 固定四项日常 CI 与独立手动交付 |
| `docs/` | 上述四类文档；架构和具体代码入口见 [模块导航](module_map.md) |
| `build/`、`preview/`、`.godot/` | 临时产物、预览和缓存 |

每项状态和参数有一个所有者。移动／删除核对 preload／load、动态拼接、class_name、UID、导出和历史版本消费者；目录名旧不等于文件已失效。
