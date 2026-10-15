# 项目工作规则

## 开始与权威来源

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
- [.agents/skills/project-integration/SKILL.md](.agents/skills/project-integration/SKILL.md)：Git、结构与交付辅助。

关卡生产 V2 自动路由：

- “优化风铃平原/这里无聊、重复、不好看、不流畅” → region-generator 审计正式 Manifest 和玩家反馈 → 少量黄金改进 → 同条件路线对照 → 准入后扩展与回归。
- “制作荆棘森林/全新地区” → region-generator 明确合法基础构筑与地区身份 → 六层设计 → 黄金样板 → 模块库/拓扑/遭遇/美术 → 正式集成。未来地区不继承平原网格、Boss或基础数值。
- [.agents/skills/challenge-choreographer/SKILL.md](.agents/skills/challenge-choreographer/SKILL.md)：连续动作语法、入口出口、单武器、资源相位、观察恢复和替代解。
- [.agents/skills/encounter-director/SKILL.md](.agents/skills/encounter-director/SKILL.md)：敌人、平台、机关、奖励和实际路线节奏联合编排；不代替敌人/Boss制作。
- [.agents/skills/scene-composer/SKILL.md](.agents/skills/scene-composer/SKILL.md)：场景轮廓、焦点、深度、地标、模块接缝和合屏；art-director仍负责风格与资产质量。

统一入口 [Level Design Harness V2](docs/level_design_harness_v2.md)。`python3 tools/level_design.py route --request "优化风铃平原" --output build/level_design_v2/mission.json` 生成现有 harness 可读 mission，默认只规划；宿主按 Skill 实际执行，不把路由/模板测试写成模型自主制作成功。所有步骤共用现有任务类型、G0–G5与十一维；本轮体系授权不自动授权重做正式平原或开放未来地区。

自主生产续轮（LEVEL-AUTONOMY-01）：用户已授权范围可控的正式平原验证切片。简短优化/新地区需求自动读取 [地区V0.3](docs/design/player_actions/regions_v0.3.md)、[武器V0.8及最新覆盖](docs/design/player_actions/README.md)、[Q1–Q8](docs/quality/level_quality_dimensions.md)和带来源/适用范围的经验；继承已确认S1–S6/16地区/H/W/D/U1/U2，区分候选与真实授予。按 [实际执行协议](docs/quality/level_autonomy_execution.md) 使用原 `harness --mission --execute`，有效CLI或当前真实Codex宿主worker；自动处理租约/专业实施/真实检查/不同代理只读审查/有界返工。计划、mock、认证失败不得冒称真实执行。每次先黄金再推广；缺用户或真机证据保留review/awaiting-device，不按普通技术步骤反复请求许可。

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

## 武器与人物动作设计输入（2026-10-13）

新增武器、跨平台动作、H/W/D与地区能力锁先读 [设计入口](docs/design/player_actions/README.md) 与 [动作harness规划](docs/quality/player_action_plan.md)。同一时刻只有一种当前装备/使用武器；钩索等能力独立于武器。附件中LOCKED/PROPOSED状态保留，新规划不代表运行实现；旧未来计划冲突以此入口列出的最新用户要求为准。


## 平原整区重设计范围（2026-10-15，覆盖旧轮有限切片范围）

最新用户已授权全面重设计正式平原的布局、路线、模块组合、敌人与机关编排、构图和随机策略；仍保留核心物理、单武器/资源/能力成长、RNG服务、保存和两图流程。不要把上一轮“仅工具”或“只做最小切片”当成本轮上限。先验证代表性黄金，再按有意图的宏观骨架推广，并对整区实际路线/最差Seed/动态画面独审与返工。未知的新需求仍按其实际授权范围执行；本条不自动开放其他地区或授权合并/发布。

生产经验：portable证据目录必须在实施租约前纳入allowed_paths，超界须保留blocked后修订租约；每条连续链的出程与返程均需完整动作/边界/真实事件和资源因果，删事件、删返程或仅保留reached标记必须拒绝。策略升级时在冻结旧内容上用同字节策略复采，分清驾驶策略收益和内容收益。历史坐标专属测试在可重建的冻结源中保留原断言，新默认消费者必须另有实际强验，其他适用回归仍跑新默认。

## 视觉导演与试玩交付新授权（2026-10-15）

用户本轮授权在冻结核心玩法/生成/物理/资源规则下，重绘必要大空间资产、升级美术Skills/Harness并先制作一个正式黄金实景，准入后才验证第二空间。连续两轮没有实质画面改善或关键工具不可用须保存证据停止对应依赖，不无限扩预算。用户长期要求：以后每次大任务结束部署最新可试玩Web预览，提供HTTPS地址、准确build_id和源提交；无需合并main。该发布授权不等于商店发布、main合并或美术/趣味/实体设备验收。
