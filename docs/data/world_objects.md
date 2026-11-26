# 普通房间机关库

每项机关／组合件有一个定义文件与一页对象说明。定义声明版本、可配置值和行为，行为合同声明合法字段、输入输出与可保存状态；房间只记录实例、连线与覆盖参数。定义中的 documentation 以仓库根目录为基准。

[基本机关库定稿](失序之钟_基本机关库.md)记录 46 项设计及模式，[预组与组合推荐](失序之钟_预组与组合推荐.md)记录 8 个预组及用法。下方对象目录列出游戏当前可以创建的实例；逐模式验收见[制作交接](../project/worklines/mechanism_libraries/scope.md)。

## 制作时怎样选库

正式房间在 `root.properties.region_id` 指定所属区域。可摆放清单从[机关定义](../../production/config/world_elements/definitions)的 `usable_regions` 生成。`["*"]` 向所有区域开放；具体区域列表可以覆盖一个或多个区域。预组取自身和全部成员可用范围的交集。未指定区域的房间只取公有清单，未知区域或越区引用会在装配前报错。区域 ID 与[地形登记表](../../production/config/terrain_materials.json)一致。房间可独立选择地形材质。

在仓库根目录查询作者可用的机关，每项输出定义 ID、中文名和对象页。省略区域只列公有库。

```sh
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- --regions
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- thorn_forest
bash tools/godot.sh --headless --path production --script res://scripts/list_mechanisms.gd -- --describe assembly.bell_gate
```

- **公有机关**承担跨区通用的动作、交互或组合。各区引用同一份定义及行为合同。区域清单的 `skins` 按定义 ID 提供外观，只能填写该定义声明的 `region_skin_fields`。材质引用地形登记表，贴图引用游戏实际导入的 PNG。未配置的外观沿用机关自身默认值。
- **区域特色机关**用于该区独有的玩法，或具有区域特色、应能整体复用的组合。先创建独立定义和对象页，在机器索引登记定义，并在定义的 `usable_regions` 写入适用区域。能由现有组件实现的组合直接引用其定义和端口。组合只在全部成员均可用的区域列出。创建组合时将来源定义随子实例保存，换区后重新校验。
- **判断归属**时先看玩家动作、触发条件、反馈和恢复方式。只变化贴图或材质就在区域清单配置外观；单房的位置、速度、行程和连线写入实例。改变共用行为合同或新增独特玩法时，再评估是否需要独立定义。

## 公有机关目录

46 个基本件与 8 个预组均向 16 个区域开放。房间保存预组展开后的成员、参数、稳定 ID 和连线。

| 编号 | 对象说明 | 定义 ID |
| --- | --- | --- |
| C01 | [射击风铃](mechanisms/switch.shot.md) | `switch.shot` |
| C02 | [砌体机关门](mechanisms/gate.masonry.md) | `gate.masonry` |
| C03 | [移动载台](mechanisms/platform.moving.md) | `platform.moving` |
| C04 | [移动齿轮](mechanisms/hazard.gear.md) | `hazard.gear` |
| C05 | [附着尖刺](mechanisms/hazard.spikes.md) | `hazard.spikes` |
| C06 | [钩索锚点](mechanisms/traversal.hook.md) | `traversal.hook` |
| C07 | [固定钩索点](mechanisms/traversal.hook_point.md) | `traversal.hook_point` |
| C08 | [捷径门](mechanisms/interaction.return_gate.md) | `interaction.return_gate` |
| C09 | [世界行动宿主](mechanisms/interaction.action.md) | `interaction.action` |
| C10 | [环境区域](mechanisms/zone.environment.md) | `zone.environment` |
| C11 | [危险区域](mechanisms/hazard.area.md) | `hazard.area` |
| C12 | [安全恢复点](mechanisms/recovery.anchor.md) | `recovery.anchor` |
| C13 | [告示](mechanisms/interaction.sign.md) | `interaction.sign` |
| C14 | [充电保存站](mechanisms/recovery.station.md) | `recovery.station` |
| G01 | [坍塌与显隐台](mechanisms/platform.crumble.md) | `platform.crumble` |
| G02 | [可击碎障碍](mechanisms/terrain.breakable.md) | `terrain.breakable` |
| G03 | [受击滑轨台](mechanisms/platform.shot_rail.md) | `platform.shot_rail` |
| G04 | [移动钩点](mechanisms/traversal.moving_hook.md) | `traversal.moving_hook` |
| G05 | [伸缩刺](mechanisms/hazard.retracting_spikes.md) | `hazard.retracting_spikes` |
| G06 | [压力踏板](mechanisms/switch.pressure.md) | `switch.pressure` |
| G07 | [弹射器](mechanisms/traversal.launcher.md) | `traversal.launcher` |
| G08 | [转向梁与旋转指针](mechanisms/platform.rotating_beam.md) | `platform.rotating_beam` |
| G09 | [传送带](mechanisms/platform.conveyor.md) | `platform.conveyor` |
| G10 | [悬挂重物](mechanisms/hazard.falling_weight.md) | `hazard.falling_weight` |
| G11 | [可引爆容器](mechanisms/hazard.explosive_container.md) | `hazard.explosive_container` |
| G13 | [周期发射口](mechanisms/hazard.periodic_emitter.md) | `hazard.periodic_emitter` |
| G15 | [通过感应器](mechanisms/switch.crossing.md) | `switch.crossing` |
| G17 | [诱敌声源与响叶地毯](mechanisms/interaction.sound_lure.md) | `interaction.sound_lure` |
| G20 | [周期冲压机](mechanisms/hazard.cyclic_press.md) | `hazard.cyclic_press` |
| G21 | [推行货箱](mechanisms/terrain.push_crate.md) | `terrain.push_crate` |
| G22 | [黏滞与光滑地面](mechanisms/surface.motion.md) | `surface.motion` |
| G23 | [滞弹雾](mechanisms/zone.projectile_drag.md) | `zone.projectile_drag` |
| G24 | [消弹薄幕](mechanisms/zone.projectile_barrier.md) | `zone.projectile_barrier` |
| G25 | [遮视芦苇](mechanisms/zone.sight_occluder.md) | `zone.sight_occluder` |
| G26 | [升浮气泡](mechanisms/traversal.rising_bubble.md) | `traversal.rising_bubble` |
| G27 | [局部灯台与引路灯虫](mechanisms/environment.local_light.md) | `environment.local_light` |
| G28 | [可射穿栅栏](mechanisms/terrain.projectile_grate.md) | `terrain.projectile_grate` |
| G29 | [同房折跃门](mechanisms/traversal.portal_pair.md) | `traversal.portal_pair` |
| G30 | [可控水位](mechanisms/zone.water_level.md) | `zone.water_level` |
| G31 | [伸展菌伞与生长根柱](mechanisms/terrain.extending.md) | `terrain.extending` |
| G32 | [反射冰镜](mechanisms/surface.projectile_mirror.md) | `surface.projectile_mirror` |
| G33 | [感光花盘](mechanisms/switch.light.md) | `switch.light` |
| G34 | [可穿遮掩藤幕](mechanisms/zone.foreground_cover.md) | `zone.foreground_cover` |
| G35 | [钩索牵引块](mechanisms/traversal.pull_block.md) | `traversal.pull_block` |
| G36 | [定点避害罩](mechanisms/zone.environment_shelter.md) | `zone.environment_shelter` |
| P06 | [蒲公英浮台](mechanisms/platform.windchime_dandelion.md) | `platform.windchime_dandelion` |
| C15 | [风铃与机关门](mechanisms/assembly.bell_gate.md) | `assembly.bell_gate` |
| C16 | [风铃与升降台](mechanisms/assembly.bell_carrier.md) | `assembly.bell_carrier` |
| G12 | [配重双台](mechanisms/assembly.counterweight_pair.md) | `assembly.counterweight_pair` |
| G14 | [双路切换组](mechanisms/assembly.dual_route_switch.md) | `assembly.dual_route_switch` |
| G16 | [一次性开路组](mechanisms/assembly.one_shot_route.md) | `assembly.one_shot_route` |
| P01 | [风车渡台](mechanisms/assembly.windchime_windmill.md) | `assembly.windchime_windmill` |
| P02 | [交替翻板桥](mechanisms/assembly.windchime_flip_bridge.md) | `assembly.windchime_flip_bridge` |
| P04 | [传铃栈道](mechanisms/assembly.windchime_bell_walkway.md) | `assembly.windchime_bell_walkway` |

运动和状态协调器随预组装配。组合多个布尔端口时可引用[条件驱动](mechanisms/internal.bool_condition.md)。

[机器索引](../../production/config/world_elements/index.json) · [房间组装](../bible/room_authoring.md)
