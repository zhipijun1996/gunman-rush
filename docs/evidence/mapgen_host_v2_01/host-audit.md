# MAPGEN-HOST-V2-01 宿主只读映射

宿主 `30e36c9abe223f26e666ceaf796e3fe9cb58e10f` / `feature/mapgen-host-v2-01`；上游map-gen `178c40164c2f7371ce1c8a56cde658e84a4f42c2`。只读源审计，无Godot/测试/生产或任务配置写入。当前真正API为 `mapgen/README.md:101`、`mapgen/api.py:41`、`mapgen/export.py:4` 和 `schemas/runtime-map.schema.json:1` 的 runtime-map/v2；`delivery/templates/CONTRACT.md` 是原0.1.0的v1，仅作历史，不能用来验新v2。

结论：现有 **Request→Provider→Plan→LevelRuntime** 是可复用的装配边界，且player/services/伤害/生命周期已有单一owner；但正式App和两个Stage仍读取原legacy_generated，当前裸Plan并未接通App。第一轮应实现一个source-owned v2 provider/物化内容入口和对应真实Stage消费者，把现有原生player/services注入；不能恢复PR123旧App包装器或每模块实例化玩家/服务/原source scene。

## 逐项映射与缺口

| v2项目 | 已有可复用位置（宿主相对路径:行） | 当前缺口/第一轮约束 |
| --- | --- | --- |
| 请求/身份 | `game/world/levels/level_request.gd:1`；App `game/application/demo_app.gd:456` 制request；`level_build_result.gd:1` | 原request只有root_seed/region/map/tuning reference/hash/root_bell/capabilities；缺v2整数seed、完整immutable input snapshot/config/library SHA/实现/fingerprint、真实terminal/filter/clearance与content_store引用。不要把mutable PlayerTuning直接当可重放外部请求。第一轮可以读取官方930001产物；不必把Python生成算法移入Godot。 |
| Provider | `providers/plains_level_provider.gd:4`、`forest_level_provider.gd:4` | 两者调用旧算法并以LegacyRegionPlanAdapter转换；v2必须独立明确schema/status/fingerprint/content store键校验，PASS外拒绝装配，不能调用旧generate后冒充接入，也不沿旧expected_hash历史模式搜索来替代v2输入。 |
| 计划 | `level_plan.gd:1`；`level_module_placement.gd:1`；`level_plan.gd:27` validation | region/source/version/seed/map_hash/bounds/spawn/anchors/modules/actors/boss/pickups/caches可复用。现placements强制PlatformingModuleDefinition；缺v2多Port权限/face/surface、显式routes/封口、物化compiled-content和required_services完整表达。validation检查基本有限几何/ID与旧ownership，未验证v2图/连接/内容引用/奖励语义。不可把不支持字段吞掉。 |
| 实例装配 | `level_runtime.gd:4` 调 `plains_region_assembler.gd:19`；后者`:60` 按placement定义、position、clock创建一次module | 保留Runtime无生成器/RNG/run services的性质；source adapter必须在ready前提供最终物化数据。旧ModuleDefinition只能装配它本来支持的几何/机制；若第三仓有接受compiled JSON的builder，应在这个边界复用并注入shared services，避免原scene.ready重建原compiled碰撞后再覆盖变量。 |
| 坐标/镜像/来源偏移 | `plains_region_assembler.gd:66` module.position；`platforming_module.gd:24` local rect；`module_reflection.gd:6` 旧反射 | v2 `origin_blocks * coordinates.block_size_pixels + local_pixel`。module只设origin像素，地形/Port/机制局部数据不再加origin；Stage直属actor/reward要各加一次origin。block_size从输入取，不能固定128。`content_transform_applied=true`后不调用ModuleReflection、不对父节点负scale、也不叠source_affine/sceneOriginOffset/source_bounds。图中Port ID不解释为左右；mirror不交换from/to。 |
| 实例ID/对象ID | `level_plan.gd:41` 防module实例ID重名及`/`→`_`节点名冲突；Assembler`:64`显示名；`demo_app.gd:622` policy用enemy_manifest.id | v2不使用数组下标作为身份。adapter稳定键应为`run_id/map_id/instance_id/local_object_id`（API export.py:77），显示Node.name与事务ID分离。当前actors/pickups/cache分别本类去重，并非跨种类全局namespace；mechanism/saw runtime ID仍含get_instance_id，只适合当前epoch，不能充当保存身份。 |
| 地形/单向/碰撞 | `game/world/components/platforming_module.gd:24–43`；`scripts/generation/platforming_module_definition.gd:6` | 现矩形StaticBody layer1及one_way_platform组可复用；一份物化地形只建一套实体。旧source scene与content_ref不能同时装。旧definition.requires平台/anchor和entry/exit都为旧站点语义，不要用伪anchor满足验证而丢多口/竖向口。 |
| 机制/方向/轨迹 | `platforming_module.gd:45–59`；`module_saw_hazard.gd:19,27`；`module_moving_platform.gd:12,27,49`；`generated_shot_latch_encounter.gd:7` | 原生saw/ferry/ShotLatch可复用真实执行组件，但旧Definitions分别只正弦线段和两端线性ferry，不代表支持compiled椭圆/ellipse_x_sign、弹丸方向、复杂配对。v2原字段应由第三仓builder逐项消费或带instance/module/field拒绝。旧ShotLatch encounter依赖node_index与generated.manifest，`:20`还按mirrored_horizontal翻sequence_offset，不可直接拿来给已物化v2再镜像。 |
| 连接/Port/封口 | `level_plan.gd:52` connections只认id/condition及backside几何；`plains_region_assembler.gd:42`只建backside gate；`platforming_module.gd:116` port_accepts | v2连接a/b是端点排序，不是移动方向；应核真实Port权限、face、surface、接缝及有向Route。旧port是玩家body center（`scripts/generation/platforming_module_port.gd:5`），不应直接等同接口中心。v2 seals须真实碰撞建一次，不是隐藏Port/画调试色块，也不能伪成旧backside gate。主路graph只是静态路线证据，不等于物理连续可达。 |
| 敌人/伤害 | `level_runtime.gd:17` EnemyFactory；`demo_app.gd:618` policy.bind_damageable→actor.bind_encounter；`enemy_actor.gd:186` restore_instance_health | 可复用原正式EnemyActor/Damageable/FrameDamagePolicy/表现组件；物化content敌人逐个保留定义/位置/关联机制与本地ID。`generated_demo_stage.gd:256` 当前仍按encounter_plan.enemies循环再索引level_plan.actors，须变成计划实际actor rows驱动，不能填旧随机encounter_plan重新抽怪。Factory未知种类明确拒绝，不删敌或替普通目标。 |
| 奖励/金币/宝箱 | `level_runtime.gd:30,36` restore pick/cache；`demo_app.gd:2055`真实pickup grant；`:2448` chest claim | 原wallet/meta/reward提交与去重服务复用，ID完整命名空间。原物化金额/物品/关联奖励保留；不能用App`:897`旧manifest.enemy_drops生成器策略替换source奖励，也不把普通房奖励抵扣target_reward_instances。旧chest tier/V5随机候选并非任意compiled奖励原义；需明确adapter绑定，不静默改奖。 |
| Spawn/锚点 | `level_plan.gd:12` spawn；`demo_app.gd:562` return_to_segment(stage.spawn)；`scripts/generation/platforming_module_definition.gd:130`旧standing check | v2 `player_spawn=null/UNRESOLVED`，start_departure仅graph port，不得以被封原entry生玩家。宿主单独记录spawn_binding：真实24×36 player（`game/player/player.tscn:18`）净空/支撑/无伤及到departure路径。原旧standing check用12×18并要脚底+18支撑，是参考验证，不等于已给新图找好出生点。 |
| Boss/结束 | `level_runtime.gd:24` BossFactory显式id；`plains_region_stage.gd:15`恢复后bind；App`:645`局部伤害绑定、`:860`击败结算 | v2 boss_encounter需宿主绑定，boss_completion unresolved且初始exit可能封；不能按map_index猜Boss或伪打开封口。明确BossFactory定义、arena/spawn/入口封锁、致死优先、奖励后完成/传送方案；最小切片若不含Boss要显式以slice范围隔离，不能走原Stage中无条件boss.add_child/health路径假装全图完成。 |
| State/恢复 | `plains_region_state.gd:16,20,23`；`run_session.gd:32` map state；`plains_region_stage.gd:321` capture | 可复用run-local ledger及期望map hash守门，但要以v2 input fingerprint/map_id/content hash绑map，不能声称已有永久全run resume。保存actor IDs/health/phase、机制状态/clock、claimed/drop与Boss；当前clocks按module instance、shot latch按旧manifest记录，需v2模块/对象稳定key。跨实例同local ID的机制与奖励必须独立，重载不喷新奖励/重建RNG。 |
| Record/重放 | `run_manifest.gd:46` record_output幂等；App`:708` stage_tuning/layout等 | 原Manifest目前只承认旧生成版本/结构（`:20,81,286`），不能直接把v2塞generated_layout并签可恢复。新source record要记录schema、完整request/config/library/implementation指纹、content哈希、宿主spawn/Boss绑定及native capability snapshot；如只开发fixture，明确不声称兼容永久存档，保原旧schema检查。 |
| 取消/异步 | `_load_stage:385`先capture/invalidate_actor/cancel敌/机关再释放；`DemoLifetime:10,17`；App`:2364`取消边界；upstream api.py:56/68 | 生命周期可复用；若异步生成，每请求捕获run/stage/actor token+fingerprint，cancel hooks只取消生成，不操纵Godot树。回到主线程构建前、逐实例创建前、完成提交前都核token；CANCELLED/失败无map不能装。当前同步加载没有worker/result owner；第一轮读取冻结官方输出仍应防旧回调。新模块内延迟弹丸/配对timer需接lifetime并在unload/return/end取消。 |

## 单player/services/collision的实际owner

`RunComposition.create_player:6`只在一次出发创建原 `game/player/player.tscn`；`demo_app.gd:330–342`随后配置真实能力/永久升级；`RunSession.create_run_services:39`创建build/wallet/rewards/shop，`:50`同一item_runtime。App`:568–575`每Stage一个FrameDamagePolicy，模块所有伤害绑定这一个policy/lifetime/玩家；不要在每个content实例里创建policy或调用Player.reset_at。

第一轮连续地图/切片的每个实例都是**同一Stage下面的局部模块**，普通Port跨越不触发 `_load_stage`，不重设controller/资源。`PlayerController.return_to_segment:253`保HP/stamina/cooldown但确实reset jump/action_resources、清弹丸；因此它只能用于既有合法段回退/首次放置，不能当每模块传送/“补资源接口”。`reset_at:235`更会reset health，绝不用于跨模块。MovingPlatform`:27`已使用Godot平台速度让唯一Motor.step消费，不搬动玩家、不二次move_and_slide。

可以复用RunComposition/RunSession成为显式接入点，但它们当前不是source-provider注册器；小幅给现App插入真实provider/Stage分支，复用随后原生services绑定即可。不要恢复PR123历史App wrapper、不复制整套玩家/钱包/物理/场景树再包装“兼容层”。PR123只作为错误架构/旧合同反例。

## 当前硬阻断与建议第一轮顺序

1. **兼容数据假可选**：`LevelBuildResult.legacy_generated:6`写optional，但App`:479,495,713,715,734`、PlainsStage`:83,98,134,321`、GeneratedStage`:256,366,383`仍直接读manifest/encounter_plan/shop/shot_latch等。新Provider单独return裸Plan会在正式流程失效。先把本轮真实v2源所需的view/记录/状态消费者显式接线到新Stage/typed source记录，不能伪造旧manifest过关。
2. **物化builder**：先官方930001的两相邻真实实例（含镜像/封口/机制/敌/奖励至少一个真实消费者），源坐标按一个公式，碰撞只建一份，unknown字段拒绝并报告。读取固定输出不等于移植生成器；API失败绝不fallback旧地图/换seed。
3. **宿主绑定**：从真实controller生成能力/24×36净空快照；确定安全spawn到departure；全部模块原生行为/奖励ID命名空间；Boss和结束另显式绑定，未含者标slice，不改原schema的unresolved证明。
4. **恢复/取消/事实记录**：同一map重载已开门/机关phase/敌HP/逐枚领取不重置；同模块重复实例不串状态；取消或切图后旧弹丸/生成结果/计时器不能提交。再扩为整图原实例/奖励/route，不借旧PR123包装器。

## 能力快照的具体缺口

现App request.capabilities（`:463`）只有grapple、weapon_id、campaign abilities、item IDs及forest layout选项；later manifest.capability_snapshot（`:718`）补max_jumps/max_air_shots、item provenance/gear，却仍非API完整原生能力+外形+tuning档位。`RunComposition.configure_capabilities:20`只根据connected/forest启energy/grapple，不是Route能力证明。

最小宿主快照应只从实际controller派生：jump_ability.enabled与max_jumps决定jump/double_jump；shoot/recoil enabled、当前weapon实际recoil路径/energy模式决定shot_recoil；traversal.hook_enabled决定grapple；实际CollisionShape尺寸决定clearance。不能因请求示例列grapple就额外grant。并记录tuning原值/配置SHA、weapon定义/能量policy版本、装备来源/当前规则档位，以复验route.capability_requirements/source_validation。API只静态筛能力，不检查连续耗能/冷却/HP/机关时态（upstream README:71）；官方request930001默认含四能力不等于普通平原玩家已有grapple。

未执行：引擎装配/源原生机制验证/物理路线/碰撞重复计数/连续输入/恢复/取消/跨实例交易/手机/正式全图。后续证据必须实际观察同一套player/services、模块物化内容和合法连续动作，不能拿schema/graph PASS签playable_in_host。
