# P01 风铃坡起点

出生点左侧是林缘低台，右侧是通往 P02 的平整草路。回头走下两级田阶，即可从平原侧看到西门的横闩和后方的荆棘老树。林缘捷径由 F08 一侧开启。门号、方向、房间边界和开门状态取自锁定世界与正式房间。[房间实例](../../../production/rooms/world/P01.json)

首次进入时，角色倒在出生地的草面上，约 1.69 秒后自行坐起、站稳。地上的枪在出生点右侧 47 个世界单位。靠近后按 ↑ / W，或点触屏的「互动」拾取。游戏仅在拾取成功后启用瞄准释放的射击与反冲。醒来、拾取分别写入普通房进度，在两者之间离开、死亡或读档都可以回来捡枪。

试枪架的两根木柱、一根横梁和旗杆给玩家提供固定的高度参照。可反复阅读的告示位于架前。角色在中央草地上原地起跳，朝脚下射击即可穿过木台，落在风旗旁。站稳后可开启木箱，散落的五枚金币由玩家拾取。从任一端离台都能落回草地。地面留给首次瞄准与观察，全程没有敌人和伤害区。沿主路步行可直接进入 P02。

## 原生素材

所有构件按最终尺寸烘焙，实例以底边中心定位。木架后方是与 P02 连续的灌溉田野。西侧老树落在低田地表，低反差树线的切边埋入岸后。深色土层和草冠继续由正式平原 TileSet 绘制。

| 运行件 | 原料与处理 |
| --- | --- |
| `p01_forest_distance.png` | 取林缘双层树林原画的下排树冠，压低对比和饱和度后埋入坡后。[树林原画及来源](../../../assets/region_production_v3/spaces/woodland_two_depth_ridges_v2/) |
| `p01_forest_verge.png` | 取荆棘森林的扭根与枝冠，删去透明留白，按 285 px 宽导出，保留完整根脚。[森林原画及来源](../../../assets/forest_bible_v2/manifest.json) |
| `p01_loft_frame.png` | 原生木构的两只石脚支承横梁。风铃取自同区立式风铃的悬挂部分，接在梁下。[木构](../../../assets/plains_v07/native/mill_timber_bent.png) · [风铃](../../../assets/plains_v07/native/hanging_chime.png) |
| `p01_wind_ribbon.png` | 原有布旗立在木台末端，杆脚贴在实际台板上。[布旗](../../../assets/plains_v07/native/aqi_ribbon.png) |
| `p01_verge_fence.png` | 田间矮篱沿东路生长，作为从试枪架走向田埂的沿途标记。[田篱](../../../assets/plains_v07/native/orchard_fence.png) |

倒地与起身沿用角色原有的像素动作，最后一帧回到当前角色的站立姿态。草上的枪取自现行英雄武器原图，摆放与拾取由房间的 `p01_sidearm` 位置控制。宝箱使用同一套闭合与打开画件。[受伤后起身动作](../../../production/game/player/presentation/authored_poses.gd) · [地面枪](../../../production/assets/plains_v3/hero/weapon.png) · [闭合木箱](../../../production/assets/underworld_plains/actors/chest.png) · [打开木箱](../../../production/assets/underworld_plains/objects/opened_chest.png)

从仓库根目录运行以下命令可重建全部五张图。试枪架的站立面由普通房现成木平台实例负责，画件只提供承重构造和风铃。

```sh
python3 art/rooms/P01/build_scenery.py
```
