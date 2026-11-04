# 项目结构

正式入口为`project.godot`和`game/application/demo.tscn`。 [模块导航](module_map.md) 提供具体代码、设计和检查； [架构](architecture.md) 描述状态所有权。

| 路径 | 职责 |
| --- | --- |
| `game/` | 按功能组织正式实现、专属场景与局部资源 |
| `experiments/` | 可启动开发入口、练习配置与有限切片 |
| `config/` | 当前参数、authoring、目录与选定版本 |
| `assets/` | 当前图声字体、原图、来源和许可 |
| `scripts/` | 仍在使用的Definition身份、森林布局及显式版本实现 |
| `scenes/bosses/` | BossFactory仍直接消费的场景 |
| `resources/` | 当前武器／Boss／玩家等定义与开发fixture |
| `tests/`、`tools/` | 真实行为回归、内容检查、Harness、构建与交付 |
| `.github/workflows/` | 四项日常 CI 与独立手动交付 |
| `docs/` | 当前设计、导航与任务索引 |
| `docs/worklines/` | 每个任务自己的范围、结果和当前交接 |
| `docs/quality/`、`docs/evidence/` | 必要质量记录、来源及原始运行证据 |
| `docs/archive/` | 退出活跃视图的任务索引及必要冻结输入，按需读取 |
| `build/`、`preview/`、`.godot/` | 生成物、临时预览与引擎缓存 |

## 放置与修改

每项状态和参数有一个所有者。新代码放所属功能，调用实际服务／工厂；同义逻辑抽取时连真实消费者一起迁移。专属场景和资源靠近功能，原图声及许可保持在资产目录。

移动／删除核对`preload/load/extends/ext_resource`、class_name、动态拼接、注册表、UID、启动入口、导出allowlist、Manifest版本与测试输入。保存源文件和进入正式PCK分别判断。

当前设计直接修改完整正文，历史版本由Git保存。冻结证据只保留当前校验、复现或许可确实需要的输入，不作为另一份可编辑规则。临时输出写build；跨会话恢复使用任务自己的工作线。

## 文档分类与权威

“当前规则”“候选设计”和“实际实现”分别陈述。当前规则先查本表的主题入口，再沿链接找具体合同；运行版本从注册表／配置读取，实现范围从真实消费者与当前状态核实。文件名含版本、latest、delivery 或日期，不自动获得优先级。

| 分类 | 文件／目录 | 职责和读取时机 |
| --- | --- | --- |
| 项目管理与导航 | `AGENTS.md`、`README.md`、`current_state.md`、`tasks.md`、`project_management.md`、`cloud_production.md`、`roadmap.md` | 项目入口、事实状态、工作选择、协作与交接；不定义动作或美术细则 |
| 工程与验证手册 | `architecture.md`、`module_map.md`、`project_structure.md`、`environment.md`、`harness.md`、`ci-test-inventory.md`、`acceptance_tests.md` | 代码职责、工具链和真实检查方法；CI 以 `tools/ci.py` 为准 |
| 全局玩法设计 | `game_design.md`、`player_mechanics.md`、`controls_contract.md`、`combat_and_recharge.md`、`damage_and_respawn.md` | 当前动作、输入、资源与伤害合同；数值由实际 Definition／Resource 提供 |
| 流程、成长与世界设计 | `run_and_routes.md`、`rewards_and_builds.md`、`home_and_save.md`、`level_design.md`、`procedural_generation.md`、`world_and_story.md`、`docs/world_regions.json` | 正式流程、权益、保存、地图版本与长期世界方向；16 地区目录不等于已开放 |
| 全局视觉圣经 | [Visual Bible](visual_bible.md) | 统一风格、采样、空间与合屏原则；`art_foundation_v1.md` 为制作方法，不另选风格 |
| 地区设计圣经 | [地区注册表](creative_direction/bibles/registry.json) 的 `current_bible` | 当前仅平原／森林两份已选原始方向；完整原文、用户选定凭证和 SHA 不随历史猜测改签 |
| 地区专业方向与技术绑定 | `creative_direction/windchime_plains.json`、`creative_direction/thorn_forest.json` 与注册表 `shared_style_authority` | 解析当前 creative-v37／style-v34 及真实消费者引用；它们是同一圣经的结构化投影，不是第二份自由编辑的设计稿 |
| 剧情设计圣经 | [剧情入口](design/story/README.md) → `loop_rules.md` → `story_bible.md` | V0.3 最后一天循环；简版 `story_overview.md` 解释同一套规则，人物、日程和结局细案仍是提案 |
| 专题设计合同 | `quality/all_weapons_spec.md`、`quality/action_budget_spec.md`、`quality/weapon_feel_spec.md`、`quality/air_action_refill.md`、`design/enemies/`、`worklines/*/spec.md` | quality／worklines 目录也有玩法设计，不能一律当管理材料。按模块导航读取与当前消费者匹配的规范 |
| 创作与质量方法 | `.agents/skills/*/SKILL.md`、`development_quality.md`、`content_pipeline.md`、`level_design_harness_v2.md`、`quality/production_loop.md`、`quality/README.md`、`templates/` | 专业方法、阶段和证据协议；相关任务按需加载，不是全仓强制前置或自动 CI |
| 当前议题与恢复 | `worklines/<任务>/scope.md`、`results.md`、相关质量卡 | 只保留该议题的范围、精确来源、验证、阻塞与下一动作；不抄进全局入口 |
| 原始设计来源／候选 | `design/player_actions/*_v*.md`、`sources/`、`design/forest_*v16/v17/v18*` | 附件方向和显式版本提案；原始版本可能包含已被当前动作合同替代的描述，不能整体当当前运行规则 |
| 追溯与运行证据 | `archive/tasks.md`、`evidence/`、`creative_direction/archive/`、`quality/records/`、`quality/asset_records/` | 任务追溯、许可、原始输入及已执行结果；哈希与旧通过只属于原来源，不签当前实现 |
| 专项交付报告／特定消费者指南 | 根层 `plains_*`、`underworld_*`、`enemy_feedback_01*`、`*_delivery.md`、`*_report.md`、`*_validation.md`、`latest_art_integration.md`、`terrain_art.md`、`tile_map_production_plan.md` | 从归档任务或真实消费者按需进入。旧 SVG、64 单位、八房间、旧母版等规格只描述对应版本，不覆盖当前圣经或正式流程 |

## 主题边界与未决项

- 森林默认为 `forest-bible-world-v15`。v16–v18 是显式候选，不因文档较新自动晋升；FOREST-VARIETY-04 先确认采用范围和实际体验。
- Boss 具体行为使用当前方向中 `boss.current_overrides` 绑定的 [钟庭巨像规范](worklines/bellstrider_rework_01/spec.md) 和 [牧风者规范](worklines/windkeeper_pressure_01/spec.md)。原地区 Bible 提供区域意图，当前规范分别明确 40HP／60HP 及招式；选定方向不代表用户已验收实战。
- `weapons_v0.8.md` 的射击精力／旧激光、`regions_v0.3.md` 的旧 H／D 描述属于原始设计来源。当前输入、弹药、AirFocus 和已授予能力恢复从本表的当前动作合同加载；机器上下文将它们分成原始方向和当前规则。
- P17 的满速蓄力与 40/55/70% 候选仍未定案，沿 ITEM-V5-01 决定；剧情细案与完整 16 地区也仍是设计范围，不推定已实现。

历史冻结输入只由对应回放工具读取；当前规则直接维护完整正文，不维护“最新补充覆盖旧规则”链。冲突不能靠把所有文件称为圣经解决：先确定主题、消费者和选定版本，再修正文或明确提案状态。
