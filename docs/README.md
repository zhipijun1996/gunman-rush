# 文档

文档按职责实际分为三个长期目录；临时产物写 ignored `build/`，必要原件留在 evidence。每个主题只有一份现行正文，改动直接整合，不追加修订说明。

| 目录 | 内容 | 从哪里开始 |
| --- | --- | --- |
| [project/](project/) | 当前状态、任务、交接、代码导航和开发／验证方法 | [当前状态](project/current_state.md) → [活跃任务](project/tasks.md) → [模块导航](project/module_map.md) |
| [bible/](bible/) | 玩法、世界、资源、生成与美术等长期约束 | [游戏设计](bible/game_design.md)、[地图生成](bible/procedural_generation.md)、[Visual Bible](bible/visual_bible.md) |
| [data/](data/) | 怪物、Boss、武器、能力、机关、声音和叙事对象的具体设计 | [对象索引](data/README.md) |
| [evidence/](evidence/) | 必要运行证据、许可、原始设计来源、归档任务和历史回放输入 | 仅由当前任务或具体复现入口按需读取 |

## 圣经索引

| 主题 | 唯一正文 |
| --- | --- |
| 整体体验、战斗原则 | [游戏设计](bible/game_design.md) |
| 输入、移动、资源 | [输入](bible/controls_contract.md)、[人物物理](bible/player_mechanics.md)、[攻击资源](bible/combat_and_recharge.md) |
| 伤害与回退 | [伤害合同](bible/damage_and_respawn.md) |
| 路线、能力锁与长期地区池 | [运行路线](bible/run_and_routes.md)、[地区框架](bible/regions.md) |
| 地图、模块与难度 | [生成](bible/procedural_generation.md)、[模块](bible/platforming_modules.md) |
| 地区体验 | [风铃平原](bible/regions/windchime_plains.md)、[荆棘森林](bible/regions/thorn_forest.md) |
| 构筑、家园与保存 | [奖励构筑](bible/rewards_and_builds.md)、[家园保存](bible/home_and_save.md) |
| 视觉与剧情 | [Visual Bible](bible/visual_bible.md)、[剧情](bible/story.md) |

## 阅读与维护

新会话按本次任务选相关圣经和对象，不通读目录。对象规范从开发者视角描述玩家会感知、判断和应对的内容；代码结构、字段对应和检查入口放模块导航。具体数值只在实际配置／Definition维护，正文保留简短配置链接。

先改受影响的设计／数据，再改实现和配置，同一任务同步。进度、验收和恢复信息只更新父任务工作线；任务结束删除中间稿，仅保留有明确复现、验收、来源或许可用途的原件。证据中的旧结果不代表当前源码已通过。
