# 功能、代码、设计与验证

先选任务所在行，再在该行代码目录检索。系统所有权与复用/适配/新增判定见 [架构](architecture.md)，未接入功能不以计划类名充当代码入口。手动检查ID对应 `tools/harness/profiles.json`，日常CI使用 `tools/ci.py` 四项，执行方式见 [Harness](harness.md)。只加载相关设计与Skill。

| 修改主题 | 真实代码入口／关键符号 | 设计 | 检查入口 |
| --- | --- | --- | --- |
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
| 新世界状态／保存适配 | [MetaSaveService](../../game/platform/persistence/meta_save_service.gd)的schema/content常量、WEB_KEY及介质写入；[MetaProgression](../../game/progression/meta_progression.gd)的`_transaction/_commit`；[PlainsRegionState](../../game/world/state/plains_region_state.gd)的snapshot/restore | [保存](../bible/home_and_save.md)；尚无世界payload/独立槽，任务01E | 日常`contracts`含 [持久化事务/备份检查](../../tests/meta_notes_save_tests.gd)；`root-bell-current`只验当前生成快照，不证明新世界保存 |
| 探索知识与地图 | [PlainsMapExploration](../../game/presentation/ui/plains_map_exploration.gd)、[PlainsRegionMapModal](../../game/presentation/ui/plains_region_map_modal.gd)、`PlainsRegionState.explored` | [推进](../bible/world_progression.md)；旧网格到房间/分区知识需要01E/01F适配 | `region`及地图相关当前专项；固定世界知识/重启验收待01F |
| NPC／对话／任务／修钟 | [HomeScene](../../game/progression/home/home_scene.gd)、`DemoApp._open_home_function`、[森林发现](../../game/world/components/forest_bible_discoveries.gd)；NPC身份/任务状态/修钟消费者尚未接入 | [故事](../bible/story.md)、[对象入口](../data/README.md)；任务01G/01H | `underworld-home`、`forest-bible-app-discoveries`只覆盖已有局部入口；新增消费者按工作线验收 |
| 设置／文本／焦点与布局 | `DemoApp.apply_input_settings/_session_input`、[InputProfile](../../game/platform/input/input_profile.gd)、[ModalShell](../../game/presentation/ui/demo_ui_01/modal_shell.gd)、[MenuInput](../../game/presentation/ui/demo_ui_01/menu_input.gd)、[GameTypography](../../game/presentation/ui/demo_ui_01/game_typography.gd) | [输入](../bible/controls_contract.md)；独立设置与统一文本入口待01I，不预建空目录 | `studio-input`、`underworld-ui`；新设置跨槽/重启及文本布局检查待01I |
| 时间／音乐／镜头／卸载 | [AirFocusAbility](../../game/player/actions/air_focus_ability.gd)、[GameMusic](../../game/presentation/audio/game_music.gd)、`DemoApp._sync_music`、[StageCameraRig](../../game/world/generation/stage_camera_rig.gd)、[WorldAudioLifecycle](../../game/presentation/audio/world_audio_lifecycle.gd) | [架构时钟与生命周期](architecture.md)、[音频](../data/audio.md)；房间/修钟适配01D/01H/01I | `audio-feedback`、`entry-audio-owners`；新房票据/镜头/修钟实景按工作线验收 |
| Web与发布 | `tools/build.py`、`tools/web/`、`.github/workflows/` | [Harness](harness.md)、[交付](cloud_production.md) | 手动 `web-cache`／`web-build`／`web-bundle` |
| 文档／上下文／Skill | `AGENTS.md`、本导航、`.agents/skills/`、`tools/check_docs.py`、`tools/check_project.py` | [协作](cloud_production.md)、[开发质量](development.md) | `python3 tools/check_docs.py`、`python3 tests/test_context_navigation.py`；按需 `level-region-context` |

## 固定世界入口

现行拓扑/合同/来源关系见 [世界输入](../data/world/README.md)。`python3 tools/world/room_context.py P-R03` 按房提取，`--contract` 输出该房完整合同。`python3 tools/check_world_design.py` 验证端点、分区、唯一ID、来源与引用；`python3 tools/world/verify_import.py` 核原包。运行时房间/状态消费者尚未接入；先做MV-RUNTIME-01B的人工输入提取与等价验证，再做01C权威切换/导出，实施与验收见 [当前交接](worklines/mv_migration/scope.md)。旧生成行只定位当前消费者，不是新世界制作规范。

## 固定世界适配定位

| 当前字段／入口 | 目标缺口及施工位置 |
| --- | --- |
| LevelRequest.region_id/map_index/root_seed；LevelPlan.source_version/map_hash/spawn | 01D补room/section/door、内容版本与成对入口解析；map_hash不能代替永久房间ID，单一spawn不能表达真实来侧。先评估现有协议，按真实消费者扩展/提取薄装配 |
| LevelRuntime.assemble(state: PlainsRegionState) → 旧Assembler；DemoApp._load_stage | 01D分离旧Provider与固定手工房间装配，玩家/服务寿命独立；当前场景入口仍是demo.tscn，导入合同的scene_ref只是计划路径 |
| RunSession.reset_maps/clear_run_services；PlainsRegionState.snapshot/restore | 01E移走旧清空时机、按四种寿命持有快照；不能把旧RunManifest或历史WorldContext当新世界保存 |
| import-v04/design/build_room_contracts_v04.py、simulation/build_route_plans.py | 01B核真实读取字段，提取施工/路线人工输入；现行源与派生关系只见世界README。01C同步room_context、检查与运行导出，不留下两个可编辑源 |
| export_presets.cfg排除docs；[raw_exporter](../../addons/runtime_raw_export/raw_exporter.gd)、tools/build.py | 01C给build/world生成数据及实际手工场景明确导出消费；`web-build/web-bundle`及PCK隔离加载才证明运行包完整 |

首批按房查询P-R03/P-R01/P-R06/P-R14及必要连接P-R08；物种定位继续使用现有EnemyBehaviorRegistry/Factory、BossFactory及对象规范。场景、Definition和试玩检查按注册/真实引用查询，不新增全量索引或第二份拓扑表。

## 目录与检索

新实现归game/所属功能；scripts/scenes/resources仍有Definition、Boss场景和当前布局消费者，移除前核静态、动态与UID引用。素材及许可随assets，配置及必要源表归config，测试输入随tests/fixtures。

默认rg遵守.gitignore和.ignore，排除build、引擎缓存、大型世界导入包及独立原始来源/录制夹具；世界数据用room_context.py按房提取。需审计被排除内容时显式指定路径并用`rg --no-ignore`。临时输出只进入build/或构建产物，持久来源与测试输入由其真实消费者维护。
