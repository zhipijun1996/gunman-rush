# 永久装备的制作与接入

[装备系统](../data/items.md)规定攻击归属、三种时钟、强化、装配和保存。重做版的装备 ID、等级参数、负荷、互斥、主动功能和金币价格由[正式目录](../../production/config/equipment.json)持有。角色、武器、空间效果与界面共用这份目录。

## 装备图像

每件装备交付一张以永久 ID 命名的 64×64 透明 PNG，保存在[图标目录](../../production/assets/equipment/icons)。在 [EquipmentCatalog.ICONS](../../production/game/equipment/equipment_catalog.gd) 登记纹理后，装备列表和房间领取点均按 32×32 显示；详情使用同一张图，名称、效果与适用条件从装备目录读取。强化师使用独立的六帧角色动画。新增或替换时在这三处按实际显示尺寸检查轮廓、透明边缘及文字布局。

沿用的 40 件从[既有图集登记](../../config/item_v5_art.json)按同一永久 ID 的区域提取、裁去留白后归一到 64×64；原画来源见[图集记录](../../assets/items/v5/manifest.json)。本次为 73、75、80、83、84、87、89、96、99、103、104、105、117、119、139、141、143、144、EQ_LAMP、EQ_FILTER 使用 ImageGen 制作独立图案并按同一规格导入。强化师复用[原角色素材](../../assets/plains_v07/native/weaponsmith.png)，保留六帧、锚点与每秒六帧的播放节奏。

## 房间装配

| 放入房间的定义 | 房间作者填写 | 玩家行为 |
| --- | --- | --- |
| equipment.reward | position、[来源清单](../../production/config/equipment_rewards.json)内的 source_id、可选 requirements | 靠近并交互，一次提交永久所有权和来源收据 |
| recovery.station | position | 打开装配界面，执行装卸或明确选择休息 |
| equipment.smith | position | 预览已有装备的当前等级、下一级参数及价格，确认后扣金币 |
| equipment.secret | position、source_id 指向揭示入口的世界旗标 | 装备听壁铜铃时，在未揭示入口附近给出提示 |
| reward.resource | position、resource_kind、amount | 拾取音符、生命、时间能量或共鸣，拾铃磁盘扩大合法拾取范围 |

奖励来源和房间实例各自拥有稳定身份。一次世界来源可以在编辑阶段检查，跨房访问仍由同一领取收据去重。正式地图确定位置后，把对应来源放进可达房间，使用该地图的前置条件验证整条路线。直接拾取资源与交互领取装备使用各自的输入条件。

房间条件中用 `equipped:EQ_LAMP`、`equipped:EQ_FILTER` 检查实际装配。容量成长通过世界永久奖励写入 `inventory.capacity_upgrades`。快捷功能在装备界面选择，施放使用玩家的主动装备动作。

## 存储与验证

`OrdinaryRoomSession.open` 接受世界存储；进入下一房时将原会话作为第三个参数。转场写入成功后交给新房。独立试玩场景通过 `profile_slot` 选择持久档位。背包、金币、来源、强化、生命与装备状态随同一世界修订提交。未提供存储的独立房间用于内存试玩。

运行 `python3 tools/check_ordinary_rooms.py`。该命令在生产工程中导入资源并执行普通房间和[装备集成测试](../../production/tests/equipment.gd)。测试现场组装奖励点、强化师与休息站；正式地图的摆放属于房间数据。
