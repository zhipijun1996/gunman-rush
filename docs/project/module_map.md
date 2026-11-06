# 功能、代码、设计与验证

先选任务所在行，再在该行代码目录检索。系统所有权与复用/适配/新增判定见 [架构](architecture.md)，未接入功能不以计划类名充当代码入口。手动检查ID对应 `tools/harness/profiles.json`，日常CI使用 `tools/ci.py` 四项，执行方式见 [Harness](harness.md)。只加载相关设计与Skill。

| 修改主题 | 真实代码入口／关键符号 | 设计 | 检查入口 |
| --- | --- | --- | --- |
| 固定世界入口／过房／失败恢复 | [FixedWorldApp](../../game/application/world/fixed_world_app.gd)、[FixedWorldProvider](../../game/world/levels/providers/fixed_world_provider.gd)、[FixedWorldRoom](../../game/world/levels/fixed_world_room.gd)、[首批手工房](../../game/world/regions/P/rooms/) | [架构](architecture.md)、[世界输入](../data/world/README.md) | `world-build`、`world-loop`；正常入口smoke |
| 旧原型入口与一局装配 | [DemoApp](../../game/application/demo_app.gd)、[RunComposition](../../game/application/run_composition.gd)、[RunSession](../../game/application/run_session.gd) | [架构](architecture.md)、[流程](../bible/world_progression.md) | `core` |
| 能力与地区推进 | [RunCampaignProgression](../../game/application/run_campaign_progression.gd)、`DemoApp._select_next_region` | [流程](../bible/world_progression.md)、[地区门槛](../bible/regions.md) | `core`、`level-region-context` |
| 输入／菜单取消 | [InputRouter](../../game/platform/input/input_router.gd)、[InputSetup](../../game/platform/input/input_setup.gd) | [操作](../bible/controls_contract.md) | `core`、`studio-input` |
| 跳跃／反冲／钩索 | [PlayerMotor](../../game/player/player_motor.gd)、[PlayerController](../../game/player/player_controller.gd)、`game/player/actions/` | [物理](../bible/player_mechanics.md)、[动作入口](../data/player_actions.md) | `core`、`weapon-feel` |
| 时间能量／弹药／共鸣 | `PlayerController.enable_shot_energy`、[当前时间能量定义](../../game/player/resources/demo_ui_01/time_energy_v2.tres)、`game/combat/resources/` | [资源](../bible/combat_and_recharge.md) | `core`、`all-weapons` |
| 武器与攻击 | [WeaponCatalog](../../game/combat/weapons/weapon_catalog.gd)、`game/combat/weapons/`、`resources/weapons/` | [武器规范](../data/weapons.md) | `all-weapons`、`weapon-feel`、`studio-input` |
| 伤害／段回退 | [FrameDamagePolicy](../../game/combat/damage/frame_damage_policy.gd)、`game/combat/respawn/` | [伤害回退](../bible/damage_and_respawn.md) | `core`、`underworld-damage-feedback` |
| 道具配置与效果 | [ItemCatalogV5](../../game/loadout/catalog/item_catalog_v5.gd)、[ItemRuntime](../../game/loadout/effects/item_runtime.gd)、`config/item_v5_*.json` | [奖励构筑](../bible/rewards_and_builds.md)、[对象规则与参数](../data/items.md)、[维护](item_authoring.md) | `item-v5-core-effects` |
| 背包／装备／容量 | [RunInventory](../../game/loadout/inventory/run_inventory.gd)、[EquipmentService](../../game/loadout/equipment/equipment_service.gd)、[BuildState](../../game/loadout/stats/build_state.gd) | [奖励构筑](../bible/rewards_and_builds.md) | `gear-inventory`、`gear-ui` |
| 商店与奖励 | [ShopService](../../game/economy/shops/shop_service.gd)、[RewardService](../../game/rewards/grants/reward_service.gd)、[RunWallet](../../game/economy/shops/run_wallet.gd) | [奖励构筑](../bible/rewards_and_builds.md) | `core`、`item-v5-core-effects` |
| 家园／永久保存／图鉴 | [MetaProgression](../../game/progression/meta_progression.gd)、[MetaSaveService](../../game/platform/persistence/meta_save_service.gd)、[HomeItemCodex](../../game/presentation/ui/home_item_codex.gd) | [家园保存](../bible/home_and_save.md) | `core`、`underworld-home` |
| 旧原型平原生成 | [PlainsLevelProvider](../../game/world/levels/providers/plains_level_provider.gd)、[PlainsRegionGenerator](../../game/world/generation/plains_region_generator.gd) | [生成](../bible/room_authoring.md)、目标地区Bible | `region` |
| 森林默认／版本／状态 | [ThornForestRegionGenerator](../../game/world/generation/thorn_forest_region_generator.gd)、[当前v15布局](../../scripts/generation/thorn_forest_region_v2_v15.gd)、`ForestLevelProvider` | [生成](../bible/room_authoring.md)、目标地区Bible | `python3 tools/run_forest_bible_world_contract.py`及相关Motor检查 |
| 森林H控制器回归 | [显式夹具](../../tests/fixtures/forest_slice_regression.json)、[夹具绑定](../../tools/forest_slice_fixture.py)，分别运行当前默认短钩及历史长钩 | H-only测试资格与现行世界进度独立；只保护真实Router／Motor、弹药和物理反例，不验固定世界房间 | `forest-current-slice`、`forest-historical-slice`、`forest-slice-fixture-tests`；不读取历史源码包 |
| 开发回归mapgen生成与生命周期 | [RuntimeMapGenerationJob](../../experiments/generation/runtime_map_generation_job.gd)、[RuntimeMapGeneratedSlice](../../experiments/generation/runtime_map_generated_slice.gd)、`config/mapgen_candidate.json` | [生成](../bible/room_authoring.md) | `mapgen-candidate-installation`、`runtime-map-generated-identity`、`runtime-map-generation-job`、`runtime-map-generated-slice` |
| mapgen风铃／端口／机制 | [RuntimeMapV2Provider](../../game/world/levels/providers/runtime_map_v2_provider.gd)、[风铃开发入口](../../experiments/generation/runtime_map_windchime_slice.gd)、`game/world/levels/content/` | [生成](../bible/room_authoring.md) | `runtime-map-windchime`；runner入口为 [聚合检查](../../tools/check_runtime_map_windchime.py) |
| 森林Boss版本选择 | [生成器选择器](../../game/world/generation/thorn_forest_region_generator.gd)、[BossFactory](../../game/bosses/encounter/boss_factory.gd)；默认v15图二选择Canopy，其余显式布局按选择器核对 | [森林](../bible/regions/thorn_forest.md)、[Boss规范](../data/README.md) | 对应版本原生专项，注册存在不代表默认使用 |
| 普通怪／Boss | [EnemyFactory](../../game/enemies/enemy_factory.gd)、[BossFactory](../../game/bosses/encounter/boss_factory.gd)、`game/enemies/`、`game/bosses/` | [战斗原则](../bible/game_design.md)、[对象索引](../data/README.md)、[冲锋怪样例](../data/enemies/plains_charger.md) | `enemy-structure-native`、对应Boss专项 |
| 铃锁／平台／索点／补给 | `game/world/components/` 中 `ShotLatch`、`BacksideShotLatch`、`ModuleMovingPlatform`、`GrappleAnchor`、`ForestFruitAnchor`、`RechargePoint`、`SafeCheckpoint`；参数随所选 Provider／Manifest 和 WorldDefinition | [世界对象](../data/world_objects.md)、[能力](../data/abilities.md) | `core`、`forest-ecology`、`forest-depth-enemies`；具体地图另核其专项 |
| 世界画面／动作／音频 | `game/presentation/`、`game/player/presentation/`、[GameAudio](../../game/presentation/audio/game_audio.gd) | [Visual Bible](../bible/visual_bible.md)、[动画](../bible/visual_bible.md)、[创作入口](content_pipeline.md) | 对应 `underworld-*`／音频检查 |
| 新世界状态／保存 | [FixedWorldState](../../game/world/state/fixed_world_state.gd)、[WorldSaveService](../../game/platform/persistence/world_save_service.gd)；可靠IO复用MetaSaveService | [保存](../bible/home_and_save.md)；能力/Boss/收据/周期/敌人/休息点/已到达房间和试制NPC装备委托已接入，正式内容待01G/H | `world-loop`含写失败、损坏恢复、同帧死亡和独立进程重启；旧Meta回归仍由`contracts`覆盖 |
| 探索知识与地图 | `FixedWorldState.explored`、`FixedWorldApp.show_map`；旧PlainsMapExploration/MapModal保留原型回归 | [推进](../bible/world_progression.md)；[FixedWorldMap](../../game/presentation/ui/world/world_map.gd)复用地图手势，显示实际到达的世界房形；房内分区与其余地区待扩展 | `world-loop`核浏览不写探索、过房与重启 |
| 首环路NPC／永久装备／委托 | [WorldNpc](../../game/npcs/world_npc.gd)、[WorldServices](../../game/progression/world/world_services.gd)、[服务面板](../../game/presentation/ui/world/world_services_view.gd)；参数归config/world/demo_services.json | [保存](../bible/home_and_save.md)、[世界输入](../data/world/README.md)；试制配置不代签正式48件/剧情 | `world-loop`含事务30、真实触屏购买/装备/升级/维修/周期使用、独立进程重启；Room检查验NPC绑定 |
| NPC／对话／任务／修钟 | [HomeScene](../../game/progression/home/home_scene.gd)、`DemoApp._open_home_function`、[森林发现](../../game/world/components/forest_bible_discoveries.gd)；NPC身份/任务状态/修钟消费者尚未接入 | [故事](../bible/story.md)、[对象入口](../data/README.md)；任务01G/01H | `underworld-home`、`forest-bible-app-discoveries`只覆盖已有局部入口；试制NPC/委托已接入WorldServices；正式叙事按工作线验收 |
| 设置／文本／焦点与布局 | `DemoApp.apply_input_settings/_session_input`、[InputProfile](../../game/platform/input/input_profile.gd)、[ModalShell](../../game/presentation/ui/demo_ui_01/modal_shell.gd)、[MenuInput](../../game/presentation/ui/demo_ui_01/menu_input.gd)、[GameTypography](../../game/presentation/ui/demo_ui_01/game_typography.gd) | [输入](../bible/controls_contract.md)；新入口由[WorldSettings](../../game/platform/settings/world_settings.gd)、WorldSettingsView和WorldText持有独立设置/文本；完整平台范围仍属01I | `studio-input`、`underworld-ui`；新设置跨槽/重启及文本布局检查待01I |
| 时间／音乐／镜头／卸载 | [AirFocusAbility](../../game/player/actions/air_focus_ability.gd)、[GameMusic](../../game/presentation/audio/game_music.gd)、`FixedWorldApp.load_room/_acquire`、[WorldRecoilGuard](../../game/player/actions/world_recoil_guard.gd) | [架构](architecture.md)、[音频](../data/audio.md)；普通跟随/战场固定镜头和票据已接入，修钟/平台完整验收待01H/I | `world-loop`、`audio-feedback`、`entry-audio-owners` |
| Web与发布 | `tools/build.py`、`tools/web/`、`.github/workflows/` | [Harness](harness.md)、[交付](cloud_production.md) | 手动 `web-cache`／`web-build`／`web-bundle` |
| 文档／上下文／Skill | `AGENTS.md`、本导航、`.agents/skills/`、`tools/check_docs.py`、`tools/check_project.py` | [协作](cloud_production.md)、[开发质量](development.md) | `python3 tools/check_docs.py`、`python3 tests/test_context_navigation.py`；按需 `level-region-context` |

## 固定世界入口

现行拓扑、人工施工/路线源与派生关系见 [世界输入](../data/world/README.md)。`python3 tools/world/room_context.py P-R03`按房提取，`--contract`查看单房合同；`python3 tools/world/build.py`编译全部合同并仅打包已施工房；`check_world_design.py`验证ID、端点、条件、引用。实现和验收见 [当前交接](worklines/mv_migration/scope.md)。

| 修改点 | 唯一入口与消费者 |
| --- | --- |
| 房间身份与门 | LevelRequest.room_id/entry_door_id/expected_hash → FixedWorldProvider.resolve；原有region/map/seed只供旧Provider |
| 房间布置与装载 | regions/P/rooms手工场景 → FixedWorldRoom；App持有共享玩家和服务，过房只替换房间实例 |
| 世界状态与动作 | FixedWorldState提交事实/周期/收据，App编排真实交互、伤害和恢复；不用RunSession清空策略 |
| 数据构建与导出 | config/world → tools/world/compile_contracts.py/build.py → ignored build/world；raw_exporter校源/场景hash后显式加入PCK |
| 回归 | `world-build`验源与手工场景边界，`world-routes`验图路线，`world-loop`验实际输入战斗/往返/独立重启；`world-pack`在空项目加载实际PCK，Web画面另验 |

首批P-R03/P-R01/P-R08/P-R06/P-R14按房查询；物种沿EnemyFactory/BehaviorRegistry与BossFactory定位。旧生成行仅定位仍被使用的开发消费者，不是新世界制作规范。

## 目录与检索

新实现归game/所属功能；scripts/scenes/resources仍有Definition、Boss场景和当前布局消费者，移除前核静态、动态与UID引用。素材及许可随assets，配置及必要源表归config，测试输入随tests/fixtures。

默认rg遵守.gitignore和.ignore，排除build、引擎缓存、大型世界导入包及独立原始来源/录制夹具；世界数据用room_context.py按房提取。需审计被排除内容时显式指定路径并用`rg --no-ignore`。临时输出只进入build/或构建产物，持久来源与测试输入由其真实消费者维护。
