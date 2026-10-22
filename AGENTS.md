# 项目工作规则

## 2026-10-21 最新选择：快速部署试玩网页

用户明确要求“这个流程是否太复杂，之后快速部署试玩网页即可”。单纯更新试玩默认走轻流程：同一运行源已有已验证Web包时，复用原包，通过现有`deploy-prepared-playtest.yml`发布，核对公开版本/完整PCK并做基本入口冒烟；不重复完整CI、Windows导出、全路线或长录像。缺包或运行源变化时只重建Web并执行受影响的必要检查；完整CI仍用于开发回归/合入/正式交付，不和每次试玩部署捆绑。复用须记录实际source commit/build id；试玩、整区完成、用户和设备认可分开。不得为提效伪造通过、忽略实际加载错误或默认合main。操作入口见[project-integration](.agents/skills/project-integration/SKILL.md)。

## 2026-10-20 最新选择：区域圣经 V2

后续制作或优化地区先有该区完整圣经，按原文生成和优化；当前用户已提供并选择[风铃平原](docs/creative_direction/bibles/1-windchime_plains_region_bible_v2.md)和[荆棘森林](docs/creative_direction/bibles/2-thorn_forest_region_bible_v2.md)，先完整森林含美术，再优化平原。[原始指令](docs/creative_direction/bibles/user-request.json)保留原quote与附件完整SHA。音效与背景动画/VFX可做，BGM由用户后续引入；Bible音乐章节保留设计意图，不生成/替换BGM。用户选择方向不签新内容的艺术、玩法或设备验收。

[注册表](docs/creative_direction/bibles/registry.json)绑定原文字节、id/version/region、选择证据；新/优化生产与手写mission均须完整绑定，漂移前后及恢复时拒绝。缺Bible自主做document-only proposed/G0预制作，不要求先问用户；注册和独审前不给生产写集。发生漂移须版本化影响分析、独审与重绑，不以刷新SHA恢复旧通过。旧提案或失败实现不自动约束新区域，但不能抛弃正式平原仍在使用的Underworld tileset家族/整体像素风格；原始素材、许可、冻结版本、旧保存重建及所有旧检查保留。核心玩法、物理、资源、能力授予、RNG和保存合同继续有效。

最新用户补充原话：“森林的tile set得和风铃平原的整体风格一致，只是体现不同的区域特色。你这个都直接扔掉了”“同时后续区域不要出类似的问题”。[完整补充与实际共享参考](docs/creative_direction/bibles/style-continuity-20261022-v4.json)绑定当前正式平原16px/32wu、47邻接核心+精确边界适配、PNG/atlas/TileSet/shader与许可完整SHA。所有后续region create/optimize及缺Bible的proposed输入先读该共用母版；区域差异来自材料、生态、结构与色域，森林用树皮苔藓荆棘有机结构，不能独立换画风。正式跨区黄金实际对照与独审后才扩产；仅用户明确选新global style时版本化替代并重验。SHA/metadata不签视觉认可，无关物理、global动作或普通文档不新增美术门槛。

## 开始与权威来源

森林荆棘按[用户最新平台覆生要求与原参考图](docs/creative_direction/bibles/thorn-covered-platforms-20261021.json)制作：真实根枝/平台承载缠绕藤体与刺面，不能用独立刺砖、矩形框或跨空假根代替。新区域同样按真实宿主/危险方向审查装饰与伤害关系；最近平台的字符串标注不等于已贴附。原区域Bible与共享画风继续有效，参考图仅借生长关系，不移用其项目画风或素材。

先读 [当前状态](docs/current_state.md)、[交接](docs/handoff.md)，检查 Git 工作区，再选择 [任务](docs/tasks.md)。用户最新指令优先；当前状态列出的最新修订覆盖同主题旧段落。历史记录和开发 fixture 不代表正式规则。

| 范围 | 权威来源 |
| --- | --- |
| 产品、世界、路线 | docs/game_design.md、docs/world_and_story.md、docs/run_and_routes.md |
| 输入、物理、资源 | docs/controls_contract.md、docs/player_mechanics.md、docs/combat_and_recharge.md |
| 伤害、构筑、保存 | docs/damage_and_respawn.md、docs/rewards_and_builds.md、docs/home_and_save.md |
| 生成、对象、敌人 | docs/procedural_generation.md、docs/world_components.md、docs/enemies_and_bosses.md |
| 美术与体验 | docs/art_quality_target.md、docs/visual_and_gamefeel.md、docs/content_pipeline.md |
| 架构与导航 | docs/architecture.md、docs/module_map.md、docs/project_structure.md |

参数唯一来源为 config/player_tuning.json、config/input_profile.json 及实际使用的 Definition Resource。禁止重复默认值。docs/design_contract.json 是设计检查契约，不是运行配置；world_regions.json 是候选白名单，不代表地区已开放。

## 迭代与 skills

无需用户逐次指定：先按目标/内容类型匹配描述，自动读取并在任务中记录采用的 Skill、职责和证据。可用 `$skill-name` 显式调用；复杂任务组合，共用同一个 G0–G5/证据记录：

- [.agents/skills/game-quality-gate/SKILL.md](.agents/skills/game-quality-gate/SKILL.md)：重要游戏内容总流程、质量门槛与完成声明；普通修复按风险轻量验收。
- [.agents/skills/enemy-creator/SKILL.md](.agents/skills/enemy-creator/SKILL.md)：设计或实现新敌人及实质行为改造；不用于单纯修正已有敌人拼写。
- [.agents/skills/boss-creator/SKILL.md](.agents/skills/boss-creator/SKILL.md)：制作新 Boss 或重构 Boss 核心机制/阶段；现有 Boss 可只作验证案例。
- [.agents/skills/level-module-creator/SKILL.md](.agents/skills/level-module-creator/SKILL.md)：新增平台跳跃挑战、模块端口/时序/连接改动及模块准入。
- [.agents/skills/region-generator/SKILL.md](.agents/skills/region-generator/SKILL.md)：修改随机区域拓扑、段落编排、模块池、内容奖励分布或体验节奏。
- [.agents/skills/art-director/SKILL.md](.agents/skills/art-director/SKILL.md)：新增资产、地区视觉母版或风格精修，以及合屏与来源质量审查。
- [.agents/skills/animation-vfx/SKILL.md](.agents/skills/animation-vfx/SKILL.md)：角色敌人 Boss 机关动作、动画过渡、射击反馈或游戏视听特效工作。
- [.agents/skills/gameplay-reviewer/SKILL.md](.agents/skills/gameplay-reviewer/SKILL.md)：独立严格审查已实现内容，主动构造失败反例并决定 ACCEPT、REJECT 或 UNVERIFIED。
- [.agents/skills/player-creator/SKILL.md](.agents/skills/player-creator/SKILL.md)：主角整体设计、动作与操作表现的新增或成套改造。
- [.agents/skills/weapon-creator/SKILL.md](.agents/skills/weapon-creator/SKILL.md)：新增或替换武器、武器升级分支及整套攻击动作/特效。
- [.agents/skills/ability-creator/SKILL.md](.agents/skills/ability-creator/SKILL.md)：新增移动/战斗能力、二段跳、贴墙/蹬墙跳或能力解锁与能力锁。
- [.agents/skills/story-writer/SKILL.md](.agents/skills/story-writer/SKILL.md)：剧情、NPC、区域碎片和多轮结局；统一循环规则、角色知识与简明写法。
- [.agents/skills/project-integration/SKILL.md](.agents/skills/project-integration/SKILL.md)：Git、结构与交付辅助。

当前创作统一从 [区域创作总谱](docs/creative_direction/README.md) 开始，前置 [.agents/skills/region-creative-director/SKILL.md](.agents/skills/region-creative-director/SKILL.md) 负责Bible缺口、未选方向的比较/取舍与RETHINK；[.agents/skills/visual-director/SKILL.md](.agents/skills/visual-director/SKILL.md) 负责完整游戏画面，不取代区域创作决策。

- [.agents/skills/challenge-choreographer/SKILL.md](.agents/skills/challenge-choreographer/SKILL.md)：连续动作与入口/出口/资源/恢复。
- [.agents/skills/encounter-director/SKILL.md](.agents/skills/encounter-director/SKILL.md)：敌人/地形/机关/奖励/返回的共同节奏。
- [.agents/skills/scene-composer/SKILL.md](.agents/skills/scene-composer/SKILL.md)：围合/层深/焦点/根基和实际合屏。

`python3 tools/level_design.py route --request "制作荆棘森林" --output build/creative_system/start.json` 自动绑定已选Bible与总谱；无Bible只写proposed预制作。`--direction`仅绑定同一Bible的明确版本，不重新选方向。route是计划，实际宿主按原harness租约执行。未来地区按S1–S6/16区/H/W/D/U1/U2最新权威和实际授予分开，不照搬平原，不用G0/G1技术片称整区。每专业交付贡献/协作/新体验/主题冲突/实机验证，不能最后拼贴。

流程权威：[development_quality](docs/development_quality.md)、[policy](docs/quality/policy.json)、[使用说明](docs/quality/README.md)。当前状态兼任 project_status；[generation_current](docs/generation_current.md) 解释当前生成实现，[visual_bible](docs/visual_bible.md) / [动画规范](docs/animation_vfx_standards.md) 统一表现要求。旧规则冲突以最新明确修订为准，不能复制同义规范。

流程：确认需求和依赖 → feature/fix/docs/chore 分支 → 小范围实现 → harness 计划与验证 → 修复 → 更新任务和交接 → 提交推送 → PR。默认不合并 PR；用户明确授权合并的范围直接执行。已授权项目内可逆实现、文档、验证、分支、提交推送与任务管理。不强推、不覆盖用户改动、不提交密钥。不自行购买服务或发布商店。用户已于2026-10-14授权自主启用subagent，无需逐次请求授权。可按任务需要委派实现、验证或只读独立审查；明确职责和允许修改路径，避免并行写同一文件。审查者不能修改自己正在审查的生产代码，也不能代签用户或真机认可。

## 实现底线

- Godot 4.7.2 Standard、类型化 GDScript、snake_case 文件、PascalCase 类型。安装/版本检查使用仓库工具链。
- PlayerMotor 唯一调用 move_and_slide，每物理帧最多一次。输入提交意图，不能搬角色；表现订阅已接受事件，不能决定玩法结果。
- 组件组合、局部类型化服务；只为真实消费者增加接口，不造空框架或万能事件总线。
- 固定/生成地图共用对象契约。碰撞、端口、相位与素材尺寸分离；移动平台通过碰撞携带。主路不依赖未授予能力、强制损血或凭空补资源。
- 随机流分离，版本化 Manifest 可复现，有界失败与已验证保底。几何连通不等于真实 Motor 可通关。
- 段回退保留敌人/机关相位/奖励/商店实例，不全场 reset。零血结束本局回家；同帧死亡优先于 Boss 奖励。
- Run/Stage/Actor epoch 分层，取消旧弹体与回调。伤害、交易、二选一、奖励确定性且幂等。
- Run/Meta、金币/音符分离，不自动兑换；Modifier 从唯一基础重算且可撤销。未实现地区/能力明确显示开发边界。
- 暂停/面板/切换取消输入与旧射击；家园复用正式控制。资源消耗遵守当前修订，不复用旧慢时预算重置射击精力。

## 验证与结束

使用 [harness](docs/harness.md)：每轮至少 docs，玩法改动 gameplay，素材改动 art 和 gameplay，构建/缓存改动 web；未知范围 full。计划不算执行。命令失败、超时、缺少完成标记都失败，不删断言或降标准。

技术回归、浏览器真实 GUI、用户真机/手感/趣味性分开记录。未执行写未验证；设备任务保持 awaiting-device，不能靠 headless 标 done。美术先看合屏黄金样板，再批量；原图来源与许可保留，技术通过不等于用户视觉认可。

新任务和本轮修改内容必须有任务 ID 与质量记录。十一维分别写 passed/failed/unverified/not_applicable（理由）；内容 done 必须具备相关门槛、独立审查、用户与设备证据，纯流程/小修按适用性轻量执行。未进行独立审查不得造 PASS，AI 自评不能签用户认可。禁止以静图冒充动画、Hash 冒充丰富度、几何连通冒充真实操作、fixture 冒充正式消费者。

结束前更新 docs/handoff.md：分支/提交、已完成、失败/阻塞、下一任务和命令。证据包含版本、退出码、日志、Seed/Manifest（适用时）；临时产物写 build/，精选证据写 docs/evidence/。历史规则快照见 [归档](docs/archive/agents_before_harness.md)，仅供溯源。

## 当前授权与历史读取

本轮用户授权系统审计、可逆瘦身、三阶段架构升级、风铃平原代表正式空间艺术样板和未来地区有限真实演练。保留核心物理/合法能力/武器资源/RNG/保存与已验证玩法；不得因旧窗口“只平原”而拒绝本轮森林演练，也不得因此正式开放森林。

武器/能力工作先读 [当前动作设计入口](docs/design/player_actions/README.md)，按任务取具体权威章节和实际消费者，不要求每个无关专业重复全文读取所有历史附件。G0建立一次带SHA的权威索引，下游引用适用段落与当前总谱；发生冲突/涉及新能力时读取完整相关原文核实。历史授权与全部旧规则逐字保存在 [基线原件](docs/archive/creative_system_baseline/manifest.json)，Skill原件见 [Skill归档](docs/archive/skill_history/README.md)，按需恢复，旧冻结Manifest不无区别约束当前内容版本。

图像方向每方向连续两轮无实质改善停止并保留失败；工程阻塞独立限预算，不冲销完整CI。已授权每次大任务结束交付准确版本可玩Web预览，但仍须通过当前发布门槛；不能通过时提供本地已验证构建及阻塞原因，不以旧包冒充。发布不等于main合并/商店发布/玩家或真机认可。
