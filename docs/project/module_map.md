# 重做版模块导航

以下路径相对于仓库根。修改和测试使用同一个 `production/project.godot`。

| 要修改的内容 | 实现与数据 |
| --- | --- |
| 装配和试玩 | [OrdinaryRoomSession](../../production/rooms/ordinary_room_session.gd)、[房间编解码器](../../production/game/world/levels/world_room_document.gd)、[共享装配](../../production/game/world/elements/world_room_assembly.gd) |
| 机关、组合与状态 | [索引](../../production/config/world_elements/index.json)、[行为合同](../../production/config/world_elements/behaviors)、[定义](../../production/config/world_elements/definitions)、[状态分发器](../../production/game/world/elements/world_element_runtime.gd)、[逐项说明](../data/world_objects.md) |
| TileSet、边界与混合材质 | [材质登记](../../production/config/terrain_materials.json)、[地形合成](../../production/game/presentation/world/terrain)、[地形方法](../bible/terrain_materials.md) |
| 敌人与战斗 | [物种工厂](../../production/game/enemies/enemy_factory.gd)、[物种资源](../../production/resources/enemies)、[伤害仲裁](../../production/game/combat/damage)、[掉落](../../production/game/rewards/drops) |
| 特效与声音 | [帧资源](../../production/assets/vfx)、[绘制](../../production/game/presentation/effects/pixel_vfx.gd)、[声音](../../production/assets/audio/vfx_renewal)、[制作配方](../../tools/vfx/effects) |
| 验证 | [全新房间数据](../../production/tests/assembly_room.json)、[端到端检查](../../production/tests/ordinary_room.gd)、[运行检查](../../tools/check_ordinary_rooms.py) |

[冻结工程模块导航](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/module_map.md)用于复现原版。
