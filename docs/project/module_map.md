# 重做版模块导航

以下路径相对于仓库根。修改和测试使用同一个 `production/project.godot`。

| 要修改的内容 | 实现与数据 |
| --- | --- |
| 默认试玩与存档 | [标题、暂停与世界生命周期](../../production/game/application/world_shell.gd)、[游戏世界](../../production/rooms/world/world.tscn)、[跨房宿主](../../production/rooms/world/world_game_host.gd)、[世界存档](../../production/game/platform/persistence/playable_world_save.gd) |
| 地图与实体关卡 | [世界输入](../data/world/README.md)、[房间路径绑定](../../production/config/imported_world/bindings.json)、[前三房](../../production/rooms/world)、[相邻接收段](../../production/rooms/world/receivers) |
| 装配和试玩 | [OrdinaryRoomSession](../../production/rooms/ordinary_room_session.gd)、[房间编解码器](../../production/game/world/levels/world_room_document.gd)、[共享装配](../../production/game/world/elements/world_room_assembly.gd) |
| 世界设计与内容版本 | [导入器](../../tools/content_channel/sync.py)、[内容目录](../../production/game/content/world_content_catalog.gd)、[实例绑定](../../production/game/content/world_content_room_bridge.gd)、[版本锁](../../production/config/imported_world/current.lock.json)、[接口规范](../data/world/content_channel.md) |
| 机关、组合与状态 | [索引](../../production/config/world_elements/index.json)、[行为合同](../../production/config/world_elements/behaviors)、[定义](../../production/config/world_elements/definitions)、[状态分发器](../../production/game/world/elements/world_element_runtime.gd)、[逐项说明](../data/world_objects.md) |
| TileSet、边界与混合材质 | [材质登记](../../production/config/terrain_materials.json)、[地形合成](../../production/game/presentation/world/terrain)、[地形方法](../bible/terrain_materials.md) |
| 敌人与战斗 | [物种工厂](../../production/game/enemies/enemy_factory.gd)、[物种资源](../../production/resources/enemies)、[伤害仲裁](../../production/game/combat/damage)、[掉落](../../production/game/rewards/drops) |
| 永久装备 | [目录](../../production/config/equipment.json)、[来源](../../production/config/equipment_rewards.json)、[运行与界面](../../production/game/equipment)、[房间装配方法](item_authoring.md) |
| 特效与声音 | [帧资源](../../production/assets/vfx)、[绘制](../../production/game/presentation/effects/pixel_vfx.gd)、[声音](../../production/assets/audio/vfx_renewal)、[制作配方](../../tools/vfx/effects) |
| 验证 | [房间装配夹具](../../production/tests/assembly_room.json)、[端到端检查](../../production/tests/ordinary_room.gd)、[运行检查](../../tools/check_ordinary_rooms.py) |
| 世界状态和内容交互 | [世界存档回归](../../production/tests/world_persistence.gd)、[内容交互](../../production/game/content/world_content_sites.gd)、[遭遇结算](../../production/game/content/world_room_encounter.gd) |
| 内容通道验证 | [跨端与坏包检查](../../tools/check_content_channel_integration.py)、[真实击杀及拾取](../../production/tests/content_channel_room.gd)、[检查入口](../../tools/check_content_channel.py) |

[冻结工程模块导航](https://github.com/zhipijun1996/gunman-rush/blob/4f2bb5e41573e930603789c64b52a0c15a6a3dc4/docs/project/module_map.md)用于复现原版。

重做文档用 `python3 tools/check_docs.py` 检查当前导航、任务依赖和本工程配置。显式复核旧世界时使用 `python3 tools/check_docs.py --frozen`。两套工程的 CI 作业独立运行。
