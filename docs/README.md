# 文档

文档按职责实际分为三个长期目录；临时产物写 ignored `build/`，最小来源/许可随对应数据或素材，回归输入随tests/fixtures。每个主题只有一份现行正文，改动直接整合，不追加修订说明。

| 目录 | 内容 | 从哪里开始 |
| --- | --- | --- |
| [project/](project/) | 当前状态、任务、交接、代码导航和开发／验证方法 | [当前状态](project/current_state.md) → [活跃任务](project/tasks.md) → [模块导航](project/module_map.md) |
| [bible/](bible/) | 玩法、世界、资源、生成与美术等长期约束 | [游戏设计](bible/game_design.md)、[世界结构](bible/world_structure.md)、[Visual Bible](bible/visual_bible.md) |
| [data/](data/) | 怪物、Boss、武器、能力、机关、声音和叙事对象的具体设计 | [对象索引](data/README.md) |

## 圣经索引

| 主题 | 唯一正文 |
| --- | --- |
| 整体体验、战斗原则 | [游戏设计](bible/game_design.md) |
| 输入、移动、资源 | [输入](bible/controls_contract.md)、[人物物理](bible/player_mechanics.md)、[攻击资源](bible/combat_and_recharge.md) |
| 伤害与回退 | [伤害合同](bible/damage_and_respawn.md) |
| 固定世界推进、能力回访 | [运行路线](bible/world_progression.md)、[地区框架](bible/regions.md) |
| 房间、分区与难度 | [世界结构](bible/world_structure.md)、[房间制作](bible/room_authoring.md) |
| 地区体验 | [风铃平原](bible/regions/windchime_plains.md)、[荆棘森林](bible/regions/thorn_forest.md) |
| 构筑、家园与保存 | [奖励构筑](bible/rewards_and_builds.md)、[家园保存](bible/home_and_save.md) |
| 视觉与剧情 | [Visual Bible](bible/visual_bible.md)、[剧情](bible/story.md) |

## 按任务读取

| 本次工作 | 最小设计上下文 |
| --- | --- |
| 怪物／Boss | 所在地区圣经 → 战斗原则 → 对象规范；改画面时再读 Visual Bible |
| 地图／机关 | 地区圣经 → 生成与能力锁 → 实际使用的敌人、Boss、机关规范 |
| 武器／能力／道具 | 对象规范 → 涉及的输入、物理、资源或奖励合同 |
| 剧情 | 剧情圣经 → 目标地区与能力锁 → 相关叙事提案及已选 Boss |
| 工程修复 | 模块导航 → 受影响的合同与对象；无需加载整套设计 |

对象页描述玩家能感知的行为、反制和视听效果，链接实际参数；代码结构、字段和验证命令只放模块导航。按页内直接关联继续读取，不因目录相邻而全量加载。当前采用版本看 current_state 与实际选择器，设计正文不兼任进度表。

## 维护

先更新受影响的设计／对象规范，再同步代码与配置，同一任务交付。直接重写相关正文，删除重复和被替代内容；每条规则只在所属页定义，其余引用。调参数不再手写第二份数值表。未决取舍留在对应工作线，候选提案不自动升级为正式约束。

新地区有实际设计时才建立地区圣经；多个简单物种共用一页，招式复杂的 Boss 单页。对象至少交代身份与用途、行为与反制、可辨表现和参数来源，按内容需要组织，不设必填卡片。

临时审计、草稿和运行输出放 ignored `build/`，完成任务即清理；仅保留现行功能必需的最小来源/许可和测试输入，分别随对应数据/素材/测试；日志、报告、截图和录屏不入库。历史由 Git／PR 追溯，进度与交接只更新 project。
