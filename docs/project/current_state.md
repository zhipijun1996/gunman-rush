# 当前开发基线

正式开发使用 [production/project.godot](../../production/project.godot)，新档从 P01 起身拾枪，已有进度从专用存档恢复。冻结平原仍由仓库根工程启动。P02 田埂第 6 版已获用户整房认可，P01、P03 及后续房间按各自的实测范围交接。[施工与验证](worklines/room_rebuild/scope.md) · [旧 demo 迁移核对](worklines/room_rebuild/runtime-inheritance.md)

| 内容 | 在重做版中的状态 |
| --- | --- |
| 怪物 | 基础怪物与区域物种复用命中、死亡和掉落；区域首领的行为、阶段及胜利收据按对应实战验收 |
| 地形 | 16 区域的 32px／47 邻接 TileSet，17 种注册材质；房间明确选材，可按区域叠涂、处理材质接缝 |
| 机关 | [公有库](../data/world_objects.md)提供 46 个基本件、8 个预组及 6 个共用驱动。16 个区域共享运行实现，可按区绑定外观。定义、对象页、真实控制器验证与试玩入口见[制作交接](worklines/mechanism_libraries/scope.md) |
| 视听 | 18 个像素动画与 15 个更新音效可用，射击、命中、开门与掉币已有普通房消费者。区域首领使用各自战场的攻击提示与停机或受击反馈，标题及区域音乐的接入状态见迁移核对 |
| 永久装备 | 60 件装备、领取来源、休息装配、强化师与战斗结算已接入普通房间；世界奖励身份和资格取自锁定内容包，各领取点的实际可达位置由对应房间和交互消费者落实 |
| 世界设计输入 | 网页和游戏锁定的 world-room-model-27 包含 16 区、310 房、392 条连接，以及任务、对白与经济定义 |
| 游戏内容 | 按[房间绑定](../../production/config/imported_world/bindings.json)查正式数据和[房间目录](../../production/rooms/world)查实体。相邻门的接收段只证明该端可接近和返回。每房的路线、动作、收益和保存另以实际验证为据 |
| 冻结内容 | 平原、旧世界拓扑、工作台草稿、旧房施工规则及旧区域排期随冻结版本复现 |

接续时查看[任务表](tasks.md)、[模块导航](module_map.md)和[普通房间规范](../bible/room_authoring.md)。冻结版本的运行记录见[平原归档](worklines/plains_bible_v2_01/scope.md)。

采用的网页内容以 `production/config/imported_world/current.lock.json` 为准。具体怪物数量、组合和位置由房间作者确定；计划收益与实机实例预算的差异用于经济复核，不阻止施工。接口与后续同步见[内容通道](../data/world/content_channel.md)。
