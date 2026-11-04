# 功能、代码、设计与验证

先选任务所在行，再在该行代码目录检索。手动检查ID对应 `tools/harness/profiles.json`，日常CI使用 `tools/ci.py` 四项，执行方式见 [Harness](harness.md)。只加载相关设计与Skill。

| 修改主题 | 真实代码入口／关键符号 | 设计 | 检查入口 |
| --- | --- | --- | --- |
| 正式入口与一局装配 | [DemoApp](../../game/application/demo_app.gd)、[RunComposition](../../game/application/run_composition.gd)、[RunSession](../../game/application/run_session.gd) | [架构](architecture.md)、[流程](../bible/run_and_routes.md) | `core` |
| 能力与地区推进 | [RunCampaignProgression](../../game/application/run_campaign_progression.gd)、`DemoApp._select_next_region` | [流程](../bible/run_and_routes.md)、[地区门槛](../evidence/sources/design/player_actions/regions_v0.3.md) | `core`、`level-region-context` |
| 输入／菜单取消 | [InputRouter](../../game/platform/input/input_router.gd)、[InputSetup](../../game/platform/input/input_setup.gd) | [操作](../bible/controls_contract.md) | `core`、`studio-input` |
| 跳跃／反冲／钩索 | [PlayerMotor](../../game/player/player_motor.gd)、[PlayerController](../../game/player/player_controller.gd)、`game/player/actions/` | [物理](../bible/player_mechanics.md)、[动作入口](../data/player_actions.md) | `core`、`weapon-feel` |
| 时间能量／弹药／共鸣 | `PlayerController.enable_shot_energy`、[当前时间能量定义](../../game/player/resources/demo_ui_01/time_energy_v2.tres)、`game/combat/resources/` | [资源](../bible/combat_and_recharge.md) | `core`、`all-weapons` |
| 武器与攻击 | [WeaponCatalog](../../game/combat/weapons/weapon_catalog.gd)、`game/combat/weapons/`、`resources/weapons/` | [武器设计入口](../data/player_actions.md) | `all-weapons`、`weapon-feel`、`studio-input` |
| 伤害／段回退 | [FrameDamagePolicy](../../game/combat/damage/frame_damage_policy.gd)、`game/combat/respawn/` | [伤害回退](../bible/damage_and_respawn.md) | `core`、`underworld-damage-feedback` |
| 道具配置与效果 | [ItemCatalogV5](../../game/loadout/catalog/item_catalog_v5.gd)、[ItemRuntime](../../game/loadout/effects/item_runtime.gd)、`config/item_v5_*.json` | [奖励构筑](../bible/rewards_and_builds.md)、[维护](item_authoring.md) | `item-v5-core-effects` |
| 背包／装备／容量 | [RunInventory](../../game/loadout/inventory/run_inventory.gd)、[EquipmentService](../../game/loadout/equipment/equipment_service.gd)、[BuildState](../../game/loadout/stats/build_state.gd) | [奖励构筑](../bible/rewards_and_builds.md) | `gear-inventory`、`gear-ui` |
| 商店与奖励 | [ShopService](../../game/economy/shops/shop_service.gd)、[RewardService](../../game/rewards/grants/reward_service.gd)、[RunWallet](../../game/economy/shops/run_wallet.gd) | [奖励构筑](../bible/rewards_and_builds.md) | `core`、`item-v5-core-effects` |
| 家园／永久保存／图鉴 | [MetaProgression](../../game/progression/meta_progression.gd)、[MetaSaveService](../../game/platform/persistence/meta_save_service.gd)、[HomeItemCodex](../../game/presentation/ui/home_item_codex.gd) | [家园保存](../bible/home_and_save.md) | `core`、`underworld-home` |
| 平原生成 | [PlainsLevelProvider](../../game/world/levels/providers/plains_level_provider.gd)、[PlainsRegionGenerator](../../game/world/generation/plains_region_generator.gd) | [生成](../bible/procedural_generation.md)、目标地区Bible | `region` |
| 森林默认／版本／状态 | [ThornForestRegionGenerator](../../game/world/generation/thorn_forest_region_generator.gd)、[当前v15布局](../../scripts/generation/thorn_forest_region_v2_v15.gd)、`ForestLevelProvider` | [生成](../bible/procedural_generation.md)、目标地区Bible | `python3 tools/run_forest_bible_world_contract.py`及相关Motor检查 |
| mapgen生成与生命周期 | [RuntimeMapGenerationJob](../../experiments/generation/runtime_map_generation_job.gd)、[RuntimeMapGeneratedSlice](../../experiments/generation/runtime_map_generated_slice.gd)、`config/mapgen_candidate.json` | [生成](../bible/procedural_generation.md)、[当前切片范围](worklines/mapgen_host_windchime_041/scope.md) | `mapgen-candidate-installation`、`runtime-map-generated-identity`、`runtime-map-generation-job`、`runtime-map-generated-slice` |
| mapgen风铃／端口／机制 | [RuntimeMapV2Provider](../../game/world/levels/providers/runtime_map_v2_provider.gd)、[风铃开发入口](../../experiments/generation/runtime_map_windchime_slice.gd)、`game/world/levels/content/` | [生成](../bible/procedural_generation.md)、[工作线](worklines/mapgen_host_windchime_041/scope.md) | `runtime-map-windchime`；runner入口为 [聚合检查](../../tools/check_runtime_map_windchime.py) |
| 森林Boss版本选择 | [生成器选择器](../../game/world/generation/thorn_forest_region_generator.gd)、[BossFactory](../../game/bosses/encounter/boss_factory.gd)；默认v15图二选择Canopy，其余显式布局按选择器核对 | [森林](../bible/regions/thorn_forest.md)、[Boss规范](../data/README.md) | 对应版本原生专项，注册存在不代表默认使用 |
| 普通怪／Boss | [EnemyFactory](../../game/enemies/enemy_factory.gd)、[BossFactory](../../game/bosses/encounter/boss_factory.gd)、`game/enemies/`、`game/bosses/` | [战斗原则](../bible/game_design.md)、[对象索引](../data/README.md)、[冲锋怪样例](../data/enemies/plains_charger.md) | `enemy-structure-native`、对应Boss专项 |
| 世界画面／动作／音频 | `game/presentation/`、`game/player/presentation/`、[GameAudio](../../game/presentation/audio/game_audio.gd) | [Visual Bible](../bible/visual_bible.md)、[动画](../bible/visual_bible.md)、[创作入口](content_pipeline.md) | 对应 `underworld-*`／音频检查 |
| Web与发布 | `tools/build.py`、`tools/web/`、`.github/workflows/` | [Harness](harness.md)、[交付](cloud_production.md) | 手动 `web-cache`／`web-build`／`web-bundle` |
| 文档／上下文／Skill | `AGENTS.md`、本导航、`.agents/skills/`、`tools/check_docs.py`、`tools/check_project.py` | [协作](cloud_production.md)、[开发质量](development.md) | `python3 tools/check_docs.py`、`python3 tests/test_context_navigation.py`；按需 `level-region-context` |

## 平原冲锋怪实现定位

设计正文见 [平原冲锋怪](../data/enemies/plains_charger.md)。本表提供实现和验证入口，便于按本次修改选择代码。

| 修改内容 | 入口 |
| --- | --- |
| 身份、构建和放置 | [EnemyBehaviorRegistry](../../game/enemies/enemy_behavior_registry.gd)、[EnemyFactory](../../game/enemies/enemy_factory.gd)、[PlainsRegionStage](../../game/world/levels/providers/plains_region_stage.gd)；显式历史 revision 与当前资源分开 |
| 参数 | [plains_charger.tres](../../resources/enemies/plains_charger.tres) 的巡逻／尺寸／时序／冲速；[patrol_health.tres](../../resources/enemies/patrol_health.tres) 的生命；未覆写字段取 [EnemyDefinition](../../scripts/enemies/enemy_definition.gd)；实例覆写由 Factory 限定 |
| 攻击、受伤与移动 | [EnemyActor](../../game/enemies/enemy_actor.gd)、[EnemyAttackBehavior](../../game/enemies/behaviors/enemy_attack_behavior.gd)、[ChargerAttackStrategy](../../game/enemies/behaviors/charger_attack_strategy.gd)、[EnemyMotor](../../game/enemies/enemy_motor.gd)；通用击退参数为 [feedback.tres](../../game/combat/damage/feedback.tres) |
| 正式身体与声音 | [UnderworldActorInstaller](../../game/presentation/actors/underworld_plains/underworld_actor_installer.gd) → [EnemyPresentationBinding](../../game/presentation/actors/presentation/enemy_presentation_binding.gd) → [UnderworldEnemy](../../game/presentation/actors/underworld_plains/underworld_enemy.gd)；声音见 [PlainsEnemyAudio](../../game/presentation/audio/plains_enemy_audio.gd) |
| 保存与接触 | EnemyActor 的 region_snapshot／restore_instance_health、攻控 restore_region_state 与 Stage 账本；接触由 [DemoApp](../../game/application/demo_app.gd) 和 [DemoContactEmitter](../../game/combat/damage/demo_contact_emitter.gd) 装配 |
| 检查 | 手动 `enemy-structure-native`、`enemy-region-state`；涉及尸体时选 `enemy-corpse-save`、`enemy-corpse-snapshot`。正常速度音画与正式遭遇结果留在任务证据 |

## 目录职责与保留路径

`game/`按application、player、combat、loadout、enemies、bosses、economy、rewards、progression、world、presentation、platform归属功能。`experiments/`拥有可启动开发入口和练习政策，正式核心不依赖实验业务规则。

`scripts/generation/`仍有森林v15及显式版本布局；`scripts/*/*_definition.gd`仍有资源类身份。`scenes/bosses/`由BossFactory直接加载，`resources/`仍存武器、Boss及部分玩家的当前定义。旧路径的目录名不代表失效；移动需覆盖动态加载、UID、版本／导出消费者。

资产与许可归`assets/`，参数和authoring归`config/`。`docs/evidence/`中的源码是证据副本，默认代码检索不进入该目录。完整目录维护见 [项目结构](../README.md)。
