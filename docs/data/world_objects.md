# 可交互元素库（简称机关）

对象通过外形、预告、运动和反馈让玩家理解功能。共同伤害规则见 [伤害合同](../bible/damage_and_respawn.md)，组合场所见 [平原](../bible/regions/windchime_plains.md) 与 [森林](../bible/regions/thorn_forest.md)。本页定义对象行为，数值从所在地图或对象配置读取。

本页是可交互元素库的唯一说明入口。每种元素的独立定义位于 `config/world_elements/definitions/`，行为合同位于 `behaviors/`，唯一注册索引为 [index.json](../../config/world_elements/index.json)。实例化、信号和状态共用规则归[关卡要素圣经](../bible/world_elements.md)；本页维护对象行为、适用场景和配置入口，数值以定义文件为准。

## 房间制作方式

1. 配置房间空间、出口与镜头，使用 `room.standard` 根定义。
2. 从本库放置实例，设置稳定 ID、定义版本、位置和参数。地形与危险按同一目录读取，实体地形由组装服务批量生成，保持连续的47邻接表面。
3. 风铃／开关的 `links` 指定输出、目标实例 ID、目标输入；接收者独立管理门、移动平台或齿轮状态。房内连接不得指向未装载房间；跨房开锁由世界 action 提交事实，目标读取该事实。
4. NPC、奖励、遭遇和剧情使用登记宿主。参数中的 action／NPC ID 仍属于世界相应数据主人；新增奖励或NPC时一并登记权益，不能复制旧的永久领取身份。
5. 普通房间不添加专属脚本。星桥灰盒用 `presentation.trial`；房间服务与Boss内场等内部组件不出现在放置列表。

静态岩土／砌体与空中实体平台共用47地形；木梁、单向平台和移动平台采用对应构件外观。四向尖刺的区域皮肤与支撑材质分开配置，实例可覆盖；危险轮廓和方向仍由玩法定义负责。建筑外观本身没有碰撞，需要实体平台组合；无碰撞布景不会创建站立面。

## 扩展一种机关

同一行为换皮或调参时增加独立定义文件并登记到索引；需要新的触发／响应方式时增加独立行为实现及合同。声明参数、输入输出、状态版本和持久范围，再给出默认定义、编辑分类和外观。为真实触发、拒绝、暂停、重入和保存失败补充针对性检查。已有机关通过本页及定义文件管理；编辑器只配置实例，不另存一套行为定义。

可攻击隐藏入口、伸缩刺、风场、弹跳蘑菇和空中浮石尚未作为新玩法实现。后续分别用受击、定时、场域、接触和运动行为加入本目录。它们共享实例和状态接口，各自拥有碰撞、力或伤害，不以隐藏贴图代替玩法状态。

## 铃锁与通路

射击铃锁由真实射击命中触发，铃声、摆动和相连门的变化同时反馈。普通门打开后保持通路；限时门显示剩余窗口，到时恢复；正在穿门时延迟关闭，不能夹住或弹出玩家。此类短时开合属于当前房间的动作瞬态，暂停冻结计时，重入/死亡重建时关闭，不写成永久开门权益。真实弹丸的资格与伤害/死亡时序仍沿ShotLatch；铃声、门运动与进度灯消费接受后的命中。双铃顺序门先完成当前铃再处理下一铃，顺序与关联通道可辨认。

移动平台控制铃切换运行与停靠，击中后的声音不能只表示开门。固定世界中的控制铃通过既有ShotLatch接收真实弹丸；App在伤害/死亡裁决后提交同一世界账本中的机关状态，成功后才切换碰撞或承载。停靠相位和运行状态跨房、保存及死亡保留，休息不偷偷恢复原位；入口和上层都可看到对应控制铃，任何停台位置都能再次启动。背面捷径铃要求玩家先抵达指定上岸控制位置，再发出真实射击；从入口远射不提前开捷径。门、铃与平台用一致符号和空间关系表明关联，失败命中不假报成功。

## 索点与果实

普通钩索锚命中后按 H 规则拉近、踢离；明确标记为停靠点的锚允许暂挂，随后可跳跃、射击或再次使用 H 离开。两类目标用形状提示区分，不仅换颜色。

森林果实长在可见枝梢、根或洞壁上，果梗交代宿主；它是索点，不因果实外观自动提供治疗或额外资格。移动活锚的行为归 [森林敌人](enemies/forest.md)。未授予 H 时，目标存在不等于授予能力；实际命中与恢复规则归 [能力](abilities.md)。

## 平台与危险

单向平台的可站面与实体厚墙可辨，装饰枝叶不伪装可站面。移动平台按可观察轨迹运行，起动、停顿和转向连续；相邻动作有可执行时机与接收位置。沿折线导轨行驶的检修笼在每个转角减速到停，再沿下一段起动，原路返回；不能瞬移换轨或靠重置角色位置承载。导轨、各停靠层和控制铃共同提示去向，轨迹全程须容纳站立角色，载具相位继续使用同一机关状态。

尖刺、锯轮与地表危险的方向、运动范围和有效伤害区域一致。循环危险在进入威胁前可观察，机关与敌人不能遮死唯一出口，安全点不能落在其完整运动范围内。

## 检查点与补给

安全检查点在玩家真实落地、恢复位置有完整支撑且无危险侵入时激活。悬空掠过不设置恢复点；选中反馈明确，后续回退遵守 [伤害合同](../bible/damage_and_respawn.md)。

空中补射击点在玩家缺少射击次数时提供补充，成功补给后熄灭；满资源或站地重叠不抢先耗掉它。它补的是射击次数，与地面恢复时间能量、回血、H 资格分别显示。

## 宝箱、商店与出口

| 宝箱档次 | 外观与反馈 |
| --- | --- |
| medium | 蓝色平盖箱，关闭与开启姿态 |
| high | 紫色拱盖箱，关闭与开启姿态 |
| region_top | 金色紧凑钟箱，关闭与开启姿态 |

宝箱仅在奖励成功提交后开盖；取消、拒绝或保存失败保持关闭，返回已领地点仍保持开启，不再发奖。静态开／关姿态与完整开盖动画分别判断，外观映射与尺寸取 [chest_art.json](../../config/chest_art.json)。森林困难可选资源箱借用金箱外观，奖励仍按该箱真实内容说明。

商店显示价格、当前收益与失败原因，刷新和购买沿 [奖励构筑](../bible/rewards_and_builds.md)。出口显示实际去向与准入条件，主路不能依赖未来能力。对象代码与对应检查见 [模块导航](../project/module_map.md)。

## 已登记定义与参数入口

以下包含变体及技术组件，不把美术变体计为新玩法。所有参数和默认值均在对应文件维护。

### 交互与奖励

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `switch.shot` | 射击风铃 | 可放置 | [定义](../../config/world_elements/definitions/switch.shot.json) |
| `gate.masonry` | 砌体机关门 | 可放置 | [定义](../../config/world_elements/definitions/gate.masonry.json) |
| `interaction.return_gate` | 捷径门 | 可放置 | [定义](../../config/world_elements/definitions/interaction.return_gate.json) |
| `interaction.action` | 世界行动宿主 | 可放置 | [定义](../../config/world_elements/definitions/interaction.action.json) |
| `interaction.sign` | 告示 | 可放置 | [定义](../../config/world_elements/definitions/interaction.sign.json) |
| `reward.host` | 奖励宿主 | 可放置 | [定义](../../config/world_elements/definitions/reward.host.json) |

### 固定与移动平台

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `platform.moving` | 移动载台 | 可放置 | [定义](../../config/world_elements/definitions/platform.moving.json) |
| `platform.solid` | 实体地形平台 | 可放置 | [定义](../../config/world_elements/definitions/platform.solid.json) |
| `platform.one_way` | 可穿越平台 | 可放置 | [定义](../../config/world_elements/definitions/platform.one_way.json) |
| `platform.timber` | 木制可穿越平台 | 可放置 | [定义](../../config/world_elements/definitions/platform.timber.json) |
| `platform.beam` | 固定结构梁台 | 可放置 | [定义](../../config/world_elements/definitions/platform.beam.json) |

### 危险

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `hazard.gear` | 移动齿轮 | 可放置 | [定义](../../config/world_elements/definitions/hazard.gear.json) |
| `hazard.spikes` | 附着尖刺 | 可放置 | [定义](../../config/world_elements/definitions/hazard.spikes.json) |
| `hazard.area` | 危险区域 | 可放置 | [定义](../../config/world_elements/definitions/hazard.area.json) |

### assemblies

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `assembly.bell_gate` | 风铃与机关门 | 可放置 | [定义](../../config/world_elements/definitions/assembly.bell_gate.json) |
| `assembly.bell_carrier` | 风铃与升降台 | 可放置 | [定义](../../config/world_elements/definitions/assembly.bell_carrier.json) |
| `assembly.masonry_portal` | 砌体门廊（实体组合件） | 可放置 | [定义](../../config/world_elements/definitions/assembly.masonry_portal.json) |

### 无碰撞布景

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `decor.mill_transmission_hall` | mill_transmission_hall | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_transmission_hall.json) |
| `decor.mill_drive_frame` | mill_drive_frame | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_drive_frame.json) |
| `decor.storage_crates` | storage_crates | 可放置 | [定义](../../config/world_elements/definitions/decor.storage_crates.json) |
| `decor.travel_bundle` | travel_bundle | 可放置 | [定义](../../config/world_elements/definitions/decor.travel_bundle.json) |
| `decor.barrel` | barrel | 可放置 | [定义](../../config/world_elements/definitions/decor.barrel.json) |
| `decor.gear_lamp` | gear_lamp | 可放置 | [定义](../../config/world_elements/definitions/decor.gear_lamp.json) |
| `decor.waiting_shelter` | waiting_shelter | 可放置 | [定义](../../config/world_elements/definitions/decor.waiting_shelter.json) |
| `decor.merchant_counter` | merchant_counter | 可放置 | [定义](../../config/world_elements/definitions/decor.merchant_counter.json) |
| `decor.station_houses` | station_houses | 可放置 | [定义](../../config/world_elements/definitions/decor.station_houses.json) |
| `decor.plains_grass` | plains_grass | 可放置 | [定义](../../config/world_elements/definitions/decor.plains_grass.json) |
| `decor.tilted_barrel` | tilted_barrel | 可放置 | [定义](../../config/world_elements/definitions/decor.tilted_barrel.json) |
| `decor.hanging_chime` | hanging_chime | 可放置 | [定义](../../config/world_elements/definitions/decor.hanging_chime.json) |
| `decor.orchard_fence` | orchard_fence | 可放置 | [定义](../../config/world_elements/definitions/decor.orchard_fence.json) |
| `decor.well_masonry` | well_masonry | 可放置 | [定义](../../config/world_elements/definitions/decor.well_masonry.json) |
| `decor.well_window_rail` | well_window_rail | 可放置 | [定义](../../config/world_elements/definitions/decor.well_window_rail.json) |
| `decor.well_daylight_slit` | well_daylight_slit | 可放置 | [定义](../../config/world_elements/definitions/decor.well_daylight_slit.json) |
| `decor.bellgarden_shrine_leaves` | bellgarden_shrine_leaves | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_shrine_leaves.json) |
| `decor.bellgarden_terrace_flowers` | bellgarden_terrace_flowers | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_terrace_flowers.json) |
| `decor.bellgarden_basin_flowers` | bellgarden_basin_flowers | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_basin_flowers.json) |
| `decor.bellgarden_shrine` | bellgarden_shrine | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_shrine.json) |
| `decor.bellgarden_court_growth` | bellgarden_court_growth | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_court_growth.json) |
| `decor.bellgarden_courtwall` | bellgarden_courtwall | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_courtwall.json) |
| `decor.bellgarden_foundation` | bellgarden_foundation | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_foundation.json) |
| `decor.bellgarden_shaftmouth` | bellgarden_shaftmouth | 可放置 | [定义](../../config/world_elements/definitions/decor.bellgarden_shaftmouth.json) |
| `decor.spring_cellar` | spring_cellar | 可放置 | [定义](../../config/world_elements/definitions/decor.spring_cellar.json) |
| `decor.well_winch_mount` | well_winch_mount | 可放置 | [定义](../../config/world_elements/definitions/decor.well_winch_mount.json) |
| `decor.gear_city_v2_pipe_junction` | gear_city_v2_pipe_junction | 可放置 | [定义](../../config/world_elements/definitions/decor.gear_city_v2_pipe_junction.json) |
| `decor.forecourt_foundation` | forecourt_foundation | 可放置 | [定义](../../config/world_elements/definitions/decor.forecourt_foundation.json) |
| `decor.gear_city_v2_valve_panel` | gear_city_v2_valve_panel | 可放置 | [定义](../../config/world_elements/definitions/decor.gear_city_v2_valve_panel.json) |
| `decor.grain_loft` | grain_loft | 可放置 | [定义](../../config/world_elements/definitions/decor.grain_loft.json) |
| `decor.opening_road_ridge` | opening_road_ridge | 可放置 | [定义](../../config/world_elements/definitions/decor.opening_road_ridge.json) |
| `decor.mill_post_segment` | mill_post_segment | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_post_segment.json) |
| `decor.mill_beam_segment` | mill_beam_segment | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_beam_segment.json) |
| `decor.forecourt_architecture` | forecourt_architecture | 可放置 | [定义](../../config/world_elements/definitions/decor.forecourt_architecture.json) |
| `decor.windchime_plains_v2_chime_span` | windchime_plains_v2_chime_span | 可放置 | [定义](../../config/world_elements/definitions/decor.windchime_plains_v2_chime_span.json) |
| `decor.windchime_plains_v2_road_marker` | windchime_plains_v2_road_marker | 可放置 | [定义](../../config/world_elements/definitions/decor.windchime_plains_v2_road_marker.json) |
| `decor.windchime_plains_near_v2` | windchime_plains_near_v2 | 可放置 | [定义](../../config/world_elements/definitions/decor.windchime_plains_near_v2.json) |
| `decor.leaf_sprig` | leaf_sprig | 可放置 | [定义](../../config/world_elements/definitions/decor.leaf_sprig.json) |
| `decor.windchime_plains_mid_v2` | windchime_plains_mid_v2 | 可放置 | [定义](../../config/world_elements/definitions/decor.windchime_plains_mid_v2.json) |
| `decor.training_atrium` | training_atrium | 可放置 | [定义](../../config/world_elements/definitions/decor.training_atrium.json) |
| `decor.junction_transfer` | junction_transfer | 可放置 | [定义](../../config/world_elements/definitions/decor.junction_transfer.json) |
| `decor.orchard_ridge` | orchard_ridge | 可放置 | [定义](../../config/world_elements/definitions/decor.orchard_ridge.json) |
| `decor.mill_walkway` | mill_walkway | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_walkway.json) |
| `decor.orchard_mill_entrance` | orchard_mill_entrance | 可放置 | [定义](../../config/world_elements/definitions/decor.orchard_mill_entrance.json) |
| `decor.mill_hall_depth` | mill_hall_depth | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_hall_depth.json) |
| `decor.aqi_ribbon` | aqi_ribbon | 可放置 | [定义](../../config/world_elements/definitions/decor.aqi_ribbon.json) |
| `decor.longbridge_hanger` | longbridge_hanger | 可放置 | [定义](../../config/world_elements/definitions/decor.longbridge_hanger.json) |
| `decor.longbridge_rearwall` | longbridge_rearwall | 可放置 | [定义](../../config/world_elements/definitions/decor.longbridge_rearwall.json) |
| `decor.longbridge_wellmouth` | longbridge_wellmouth | 可放置 | [定义](../../config/world_elements/definitions/decor.longbridge_wellmouth.json) |
| `decor.longbridge_crane` | longbridge_crane | 可放置 | [定义](../../config/world_elements/definitions/decor.longbridge_crane.json) |
| `decor.market_stalls` | market_stalls | 可放置 | [定义](../../config/world_elements/definitions/decor.market_stalls.json) |
| `decor.bell_post` | bell_post | 可放置 | [定义](../../config/world_elements/definitions/decor.bell_post.json) |
| `decor.market_terrace` | market_terrace | 可放置 | [定义](../../config/world_elements/definitions/decor.market_terrace.json) |
| `decor.clockheart_hall` | clockheart_hall | 可放置 | [定义](../../config/world_elements/definitions/decor.clockheart_hall.json) |
| `decor.clockheart_ruin` | clockheart_ruin | 可放置 | [定义](../../config/world_elements/definitions/decor.clockheart_ruin.json) |
| `decor.well_service_reveal` | well_service_reveal | 可放置 | [定义](../../config/world_elements/definitions/decor.well_service_reveal.json) |
| `decor.carriage` | carriage | 可放置 | [定义](../../config/world_elements/definitions/decor.carriage.json) |
| `decor.bank_moss` | bank_moss | 可放置 | [定义](../../config/world_elements/definitions/decor.bank_moss.json) |
| `decor.mill_hidden_wall` | mill_hidden_wall | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_hidden_wall.json) |
| `decor.opening_hidden_wall` | opening_hidden_wall | 可放置 | [定义](../../config/world_elements/definitions/decor.opening_hidden_wall.json) |
| `decor.concealing_grass` | concealing_grass | 可放置 | [定义](../../config/world_elements/definitions/decor.concealing_grass.json) |
| `decor.orchard_frame_brace` | orchard_frame_brace | 可放置 | [定义](../../config/world_elements/definitions/decor.orchard_frame_brace.json) |
| `decor.opening_guard_gallery` | opening_guard_gallery | 可放置 | [定义](../../config/world_elements/definitions/decor.opening_guard_gallery.json) |
| `decor.junction_rotor` | junction_rotor | 可放置 | [定义](../../config/world_elements/definitions/decor.junction_rotor.json) |
| `decor.junction_facade` | junction_facade | 可放置 | [定义](../../config/world_elements/definitions/decor.junction_facade.json) |
| `decor.mill_window_bay` | mill_window_bay | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_window_bay.json) |
| `decor.mill_timber_bent` | mill_timber_bent | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_timber_bent.json) |
| `decor.mill_gear` | mill_gear | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_gear.json) |
| `decor.mill_corbel` | mill_corbel | 可放置 | [定义](../../config/world_elements/definitions/decor.mill_corbel.json) |
| `decor.windmill_frame` | windmill_frame | 可放置 | [定义](../../config/world_elements/definitions/decor.windmill_frame.json) |
| `decor.shelter_courtyard` | shelter_courtyard | 可放置 | [定义](../../config/world_elements/definitions/decor.shelter_courtyard.json) |
| `decor.shelter_shaft` | shelter_shaft | 可放置 | [定义](../../config/world_elements/definitions/decor.shelter_shaft.json) |
| `decor.windcourt_gallery` | windcourt_gallery | 可放置 | [定义](../../config/world_elements/definitions/decor.windcourt_gallery.json) |
| `decor.windcourt_pavilion` | windcourt_pavilion | 可放置 | [定义](../../config/world_elements/definitions/decor.windcourt_pavilion.json) |

### 内部服务与技术组件

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `room.standard` | 标准房间 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/room.standard.json) |
| `internal.arena` | Boss场地模块 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/internal.arena.json) |
| `internal.fact_visual` | 世界状态表现 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/internal.fact_visual.json) |
| `internal.arena_terrain` | 模块地形表现 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/internal.arena_terrain.json) |
| `internal.room_assembly` | 房间组装服务 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/internal.room_assembly.json) |

### 移动辅助

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `traversal.hook` | 钩索锚点 | 可放置 | [定义](../../config/world_elements/definitions/traversal.hook.json) |
| `traversal.climb_wall` | 攀爬墙 | 可放置 | [定义](../../config/world_elements/definitions/traversal.climb_wall.json) |
| `traversal.hook_point` | 固定钩索点 | 可放置 | [定义](../../config/world_elements/definitions/traversal.hook_point.json) |

### 角色宿主与怪物

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `character.npc` | NPC宿主 | 可放置 | [定义](../../config/world_elements/definitions/character.npc.json) |
| `character.enemy` | 怪物出生点 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/character.enemy.json) |
| `enemy.chime_target` | 怪物 · chime_target | 可放置 | [定义](../../config/world_elements/definitions/enemy.chime_target.json) |
| `enemy.patrol` | 怪物 · patrol | 可放置 | [定义](../../config/world_elements/definitions/enemy.patrol.json) |
| `enemy.charger` | 怪物 · charger | 可放置 | [定义](../../config/world_elements/definitions/enemy.charger.json) |
| `enemy.diver` | 怪物 · diver | 可放置 | [定义](../../config/world_elements/definitions/enemy.diver.json) |
| `enemy.hopper` | 怪物 · hopper | 可放置 | [定义](../../config/world_elements/definitions/enemy.hopper.json) |
| `enemy.sentry` | 怪物 · sentry | 可放置 | [定义](../../config/world_elements/definitions/enemy.sentry.json) |
| `enemy.fan_sentry` | 怪物 · fan_sentry | 可放置 | [定义](../../config/world_elements/definitions/enemy.fan_sentry.json) |
| `enemy.ground_fan_sentry` | 怪物 · ground_fan_sentry | 可放置 | [定义](../../config/world_elements/definitions/enemy.ground_fan_sentry.json) |
| `enemy.root_bell` | 怪物 · root_bell | 可放置 | [定义](../../config/world_elements/definitions/enemy.root_bell.json) |
| `enemy.forest_lantern` | 怪物 · forest_lantern | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_lantern.json) |
| `enemy.forest_seed_sentry` | 怪物 · forest_seed_sentry | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_seed_sentry.json) |
| `enemy.forest_bark_beetle` | 怪物 · forest_bark_beetle | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_bark_beetle.json) |
| `enemy.forest_swing_pod` | 怪物 · forest_swing_pod | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_swing_pod.json) |
| `enemy.forest_thread_spider` | 怪物 · forest_thread_spider | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_thread_spider.json) |
| `enemy.forest_crossbranch` | 怪物 · forest_crossbranch | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_crossbranch.json) |
| `enemy.forest_bible_weaver` | 怪物 · forest_bible_weaver | 可放置 | [定义](../../config/world_elements/definitions/enemy.forest_bible_weaver.json) |

### 环境区域

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `zone.environment` | 环境区域 | 可放置 | [定义](../../config/world_elements/definitions/zone.environment.json) |

### 恢复与保存

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `recovery.anchor` | 安全恢复点 | 可放置 | [定义](../../config/world_elements/definitions/recovery.anchor.json) |
| `recovery.station` | 充电保存站 | 可放置 | [定义](../../config/world_elements/definitions/recovery.station.json) |

### 基础地形

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `terrain.polygon` | 多边形实体 | 可放置 | [定义](../../config/world_elements/definitions/terrain.polygon.json) |

### 遭遇

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `encounter.waves` | 波次遭遇 | 可放置 | [定义](../../config/world_elements/definitions/encounter.waves.json) |
| `encounter.windkeeper` | 牧风者遭遇 | 可放置 | [定义](../../config/world_elements/definitions/encounter.windkeeper.json) |
| `encounter.bellstrider` | 巡游机遭遇 | 可放置 | [定义](../../config/world_elements/definitions/encounter.bellstrider.json) |

### 剧情与教学

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `story.sequence` | 剧情事件 | 可放置 | [定义](../../config/world_elements/definitions/story.sequence.json) |
| `story.intro` | 开场与教学 | 可放置 | [定义](../../config/world_elements/definitions/story.intro.json) |

### 表现

| 定义 | 用途／名称 | 放置 | 参数源 |
| --- | --- | --- | --- |
| `presentation.trial` | 星桥灰盒表现 | 由服务或专用流程创建 | [定义](../../config/world_elements/definitions/presentation.trial.json) |
