# 怪物与 Boss 数据索引

本页定位当前对象规范、机器资源和缺口；共用战斗原则唯一见 [游戏设计](game_design.md)，画风见 [Visual Bible](visual_bible.md)，地图／版本事实见 [当前状态](current_state.md)。注册不等于正式准入或内容完成。

## 普通怪

当前 [EnemyBehaviorRegistry](../game/enemies/enemy_behavior_registry.gd) 注册14种基础行为和2个显式开发候选。Factory 创建实例配置，Actor 持有生命，Behavior／Strategy 决定动作，Motor 执行运动；资源参数唯一从 `resources/enemies/` 及 Definition 读取。

| 对象／范围 | 当前数据规范 | 资源与缺口 |
| --- | --- | --- |
| plains_charger／charger | [冲锋怪完整样例](design/enemies/plains_charger.md) | [当前资源](../resources/enemies/plains_charger.tres)；描述定位、行为／反制与视听效果，附数值入口；实现和检查见模块导航，实际内容认可另验 |
| patrol、diver、hopper、sentry、fan_sentry、root_bell | 尚缺各自完整现行规范；目前说明散在 `plains_enemy_behaviors.md`、`plains_interactive_platforms.md` 和任务制作记录 | 对应 patrol_drone／plains_* `.tres`；接续功能时按样例整理已有内容，不先创建空卡 |
| forest_lantern、forest_seed_sentry、forest_bark_beetle、forest_swing_pod、forest_thread_spider、forest_crossbranch、forest_bible_weaver | [森林对象入口](design/forest_enemy_ecology_v2.md) 提供真实资源和当前行为入口 | 各自 forest_* `.tres`；共享索引尚未代替逐物种完整行为／表现规范 |
| candidate_lure_guard、candidate_crosswind_moth | 实际候选配方在 EnemyFactory.CANDIDATE_RECIPES，身份在 Registry.CANDIDATES | 开发 Lab／Studio 候选，未选入正式内容；采用时补完整规范 |

完整度和逐专业制作方法见 [完成标准](quality/enemy_completion_standard.md) 与 [enemy-creator](../.agents/skills/enemy-creator/SKILL.md)。数据规范不记录逐轮审计进度，当前验收／阻塞放 ENEMY-ALL-02 工作线及原质量记录。

## Boss

[BossFactory](../game/bosses/encounter/boss_factory.gd) 注册9个当前可构建身份。具体数据规范按对象／版本唯一选择；参数从该条目的 `.tres` 和引用的健康资源读取。

| 身份 | 数据规范／设计状态 | 运行关联 |
| --- | --- | --- |
| bellstrider：鸣铃巡游机 | [当前规范](worklines/bellstrider_rework_01/spec.md)，属于对象数据；当前正文仍需去掉任务起始说明 | [bellstrider.tres](../resources/bosses/bellstrider.tres) → `game/bosses/bellstrider/`；当前方向 boss.current_overrides 绑定此规范 |
| windkeeper_storm：牧风者主动追压版 | [当前规范](worklines/windkeeper_pressure_01/spec.md)，属于对象数据 | [windkeeper_storm.tres](../resources/bosses/windkeeper_storm.tres) → `windkeeper_pressure.tscn`／`game/bosses/windkeeper/`；当前方向绑定本规范，不混用旧 windkeeper 窗口版 |
| rootbell_guardian_v2 | [根铃守卫 V2](design/rootbell_guardian_v2.md) | [资源](../resources/bosses/rootbell_guardian_v2.tres) → 同名场景；需把正文中的实现／审查过程移回工作线并核当前消费者 |
| thorn_queen_v2 | [迁巢织场女王](design/thorn_queen_v2.md)，独立版本 | [资源](../resources/bosses/thorn_queen_v2.tres) → 同名场景；不与 Canopy 内容合写成一个对象 |
| thorn_queen_canopy | [Canopy v3](design/thorn_queen_canopy_v3.md) | [资源](../resources/bosses/thorn_queen_canopy.tres) → 同名场景；需要整理最终行为与表现正文，保留实际未验范围 |
| clockwork_guardian、windkeeper、thorn_guardian、thorn_queen | 尚缺完整独立现行规范，已有旧消费者与场景说明 | Factory.RECORDS 给实际 `.tres`／场景；先判断是否仍有正式／版本消费者，再补规范或退休，不按文件数量补空文档 |

无 Factory 选择的孤立资源、旧 revision 和历史 Boss 只按明确消费者读取。地区原始 Bible 提供方向，后续已选对象规范定义具体招式；修改绑定规范时同步对应方向来源，原验收 SHA 不改签。

## 需要继续整理

1. 优先整理真实默认地图使用的普通怪，补齐完整状态／退出／反制／表现及资源字段来源；森林共享说明不能代签每种对象。
2. 把已选 Boss 规范中的任务基线、时间线与审查过程移回现有工作线结果，长文只留最终行为。迁移前核注册绑定及必要证据原件，保持一个规范入口。
3. 武器分支、道具与机关同样按实际消费者逐个整理；完整主题入口见 [文档索引](project_structure.md)。P17 先解决规则选择，再改数据与实现。

这些是文档缺口，不是新的数十条全局任务。后续选中对象时在同一个父议题内完成文档与实现同步。
