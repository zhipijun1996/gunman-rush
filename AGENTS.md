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

流程权威：[development_quality](docs/development_quality.md)、[policy](docs/quality/policy.json)、[使用说明](docs/quality/README.md)。当前状态兼任 project_status；[generation_current](docs/generation_current.md) 解释当前生成实现，[visual_bible](docs/visual_bible.md) / [动画规范](docs/animation_vfx_standards.md) 统一表现要求。旧规则冲突以最新明确修订为准，不能复制同义规范。

流程：确认需求和依赖 → feature/fix/docs/chore 分支 → 小范围实现 → harness 计划与验证 → 修复 → 更新任务和交接 → 提交推送 → PR。默认不合并 PR；用户明确授权合并的范围直接执行。已授权项目内可逆实现、文档、验证、分支、提交推送与任务管理。不强推、不覆盖用户改动、不提交密钥。不自行购买服务或发布商店。无用户明确要求不启用子代理。

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
