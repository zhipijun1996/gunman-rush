# 逐怪程序入口索引

源码快照：`596a2eee230eb1b9d23dc2ff878c1ff3259cf293`。这是当前程序入口导航，运行登记仍以[EnemyBehaviorRegistry](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/enemy_behavior_registry.gd)、[EnemyFactory](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/enemy_factory.gd)和[BossFactory](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/bosses/boss_factory.gd)为唯一来源；表格不参与运行。

[同源原生结构结果](../../evidence/enemy_structure_01/native-09/runtime.json)包含40个结构case／733断言，全部通过。表中profile是这些fixture实际装配的分支；它不能替代正式关卡的连续玩法、美术、声音或用户验收。原[资料／素材盘点](../enemy_asset_audit_01/README.md)仍按原快照保留。

## 14种普通怪

普通创建统一调用`EnemyFactory.create_for_behavior()`；返回未入树Motor，Definition与外部HealthDefinition按实例隔离。Stage负责放置、Manifest和场地。表中运动策略运行在原共享攻击协调器内，森林专有行为独立保留。

| 怪物／行为ID | Definition | 攻击策略或专有行为 | 原生实际profile |
| --- | --- | --- | --- |
| 巡逻怪 `patrol` | [patrol_drone](../../../resources/enemies/patrol_drone.tres) | 无攻击Behavior | scene、underworld |
| 冲锋怪 `charger` | [plains_charger](../../../resources/enemies/plains_charger.tres) | [charger_attack_strategy](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/charger_attack_strategy.gd) | scene、underworld |
| 俯冲怪 `diver` | [plains_diver](../../../resources/enemies/plains_diver.tres) | [diver_attack_strategy](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/diver_attack_strategy.gd) | scene、underworld |
| 跳扑怪 `hopper` | [plains_hopper](../../../resources/enemies/plains_hopper.tres) | [hopper_attack_strategy](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/hopper_attack_strategy.gd) | scene、underworld |
| 炮哨 `sentry` | [plains_sentry](../../../resources/enemies/plains_sentry.tres) | [sentry_attack_strategy](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/sentry_attack_strategy.gd) | scene、underworld |
| 扇射哨 `fan_sentry` | [plains_fan_sentry](../../../resources/enemies/plains_fan_sentry.tres) | [fan_sentry_attack_strategy](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/fan_sentry_attack_strategy.gd) | scene、underworld |
| 根铃 `root_bell` | [plains_root_bell](../../../resources/enemies/plains_root_bell.tres) | [root_bell_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/root_bell_behavior.gd) | scene、underworld、root_bell |
| 铃囊萤 `forest_lantern` | [forest_lantern](../../../resources/enemies/forest_lantern.tres) | [forest_lantern_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_lantern_behavior.gd) | forest |
| 棘籽哨 `forest_seed_sentry` | [forest_seed_sentry](../../../resources/enemies/forest_seed_sentry.tres) | [forest_seed_sentry_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_seed_sentry_behavior.gd) | forest |
| 树皮甲虫 `forest_bark_beetle` | [forest_bark_beetle](../../../resources/enemies/forest_bark_beetle.tres) | [forest_bark_beetle_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_bark_beetle_behavior.gd) | forest |
| 吊荚摆锚 `forest_swing_pod` | [forest_swing_pod](../../../resources/enemies/forest_swing_pod.tres) | [forest_swing_pod_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_swing_pod_behavior.gd) | forest |
| 织棘蛛/单有限线 `forest_thread_spider` | [forest_thread_spider](../../../resources/enemies/forest_thread_spider.tres) | [forest_thread_spider_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_thread_spider_behavior.gd) | forest |
| 跨枝移动体 `forest_crossbranch` | [forest_crossbranch](../../../resources/enemies/forest_crossbranch.tres) | [forest_crossbranch_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_crossbranch_behavior.gd) | forest |
| 织棘蛛/双入口织线变体 `forest_bible_weaver` | [forest_bible_weaver](../../../resources/enemies/forest_bible_weaver.tres) | [forest_bible_weaver_behavior](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/enemies/forest_bible_weaver_behavior.gd) | forest |

Scene路径也由同一登记读取：平原7种沿原`patrol_drone.tscn`骨架，森林7种沿各自原场景。运动参数`aerial`不再直接选择身体；最终身体由[EnemyPresentationBinding](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/presentation/enemy_presentation_binding.gd)明确登记。森林fine身体还要求实际Bible安装的`forest_bible`主题；Lab默认身体保持自身上下文。

## 2个开发候选

| 候选 | 原机制与差异 | 原生实际上下文 |
| --- | --- | --- |
| 诱突护盾甲虫 `candidate_lure_guard` | charger＋原盾Damageable；Lab／Studio巡逻半径分别120／100 | lab、studio |
| 双通道蛾 `candidate_crosswind_moth` | 专有moth Behavior；Lab速度45／激活360，Studio保sentry零速／默认激活180 | lab、studio |

候选统一`EnemyFactory.create_candidate(identity, context)`；`review`显式使用Lab配方，不能用普通charger Definition冒充moth。候选仍为development准入，不因工厂登记升级为正式投放。

## 8个Boss场景／9个配置组合

统一`BossFactory.create(id)`或精确Manifest配对`create_recorded(scene_path, definition_path)`；返回未入树Motor，原共享Resource语义不改。各Encounter拥有激活、阶段、目标、伤害及奖励，表现消费只读`BossPresentationState`和窄查询。

| 工厂ID | Scene | Definition | 原生case |
| --- | --- | --- | --- |
| `clockwork_guardian` | [clockwork_guardian](../../../scenes/bosses/clockwork_guardian.tscn) | [clockwork_guardian](../../../resources/bosses/clockwork_guardian.tres) | `boss/clockwork_guardian` |
| `bellstrider` | [bellstrider](../../../scenes/bosses/bellstrider.tscn) | [bellstrider](../../../resources/bosses/bellstrider.tres) | `boss/bellstrider` |
| `windkeeper` | [windkeeper](../../../scenes/bosses/windkeeper.tscn) | [windkeeper](../../../resources/bosses/windkeeper.tres) | `boss/windkeeper` |
| `windkeeper_storm` | [windkeeper](../../../scenes/bosses/windkeeper.tscn) | [windkeeper_storm](../../../resources/bosses/windkeeper_storm.tres) | `boss/windkeeper_storm` |
| `thorn_guardian` | [thorn_guardian](../../../scenes/bosses/thorn_guardian.tscn) | [thorn_guardian](../../../resources/bosses/thorn_guardian.tres) | `boss/thorn_guardian` |
| `thorn_queen` | [thorn_queen](../../../scenes/bosses/thorn_queen.tscn) | [thorn_queen](../../../resources/bosses/thorn_queen.tres) | `boss/thorn_queen` |
| `rootbell_guardian_v2` | [rootbell_guardian_v2](../../../scenes/bosses/rootbell_guardian_v2.tscn) | [rootbell_guardian_v2](../../../resources/bosses/rootbell_guardian_v2.tres) | `boss/rootbell_guardian_v2` |
| `thorn_queen_v2` | [thorn_queen_v2](../../../scenes/bosses/thorn_queen_v2.tscn) | [thorn_queen_v2](../../../resources/bosses/thorn_queen_v2.tres) | `boss/thorn_queen_v2` |
| `thorn_queen_canopy` | [thorn_queen_canopy](../../../scenes/bosses/thorn_queen_canopy.tscn) | [thorn_queen_canopy](../../../resources/bosses/thorn_queen_canopy.tres) | `boss/thorn_queen_canopy` |

`windkeeper_storm`是windkeeper同场景的配置组合。各Boss保留原弱点、双目标、织网、平台及并行阶段轴。

## 后续修改从哪里进入

新增或调整物种先改实际Definition及登记；已有基础攻击的运动公式进对应策略，专有机制留在自身Behavior／Encounter。表现读取`presentation_state()`，通过最终绑定取身体；普通表现的bind／epoch同步／暂停／单次推进／dispose走[EnemyPresentationLifecycle](https://github.com/zhipijun1996/gunman-rush/blob/596a2eee230eb1b9d23dc2ff878c1ff3259cf293/scripts/presentation/enemy_presentation_lifecycle.gd)。完整恢复完成后再同步表现，留尸通过`presentation_remains()`能力取得。

本轮修复了实例健康配置共享、未知身体路由静默接受及盾反馈解绑遗漏。素材、动作设计与验收流程仍需按用户要求逐怪发现问题；验收机制仍待与用户共同修订，旧美术拒绝保留。
