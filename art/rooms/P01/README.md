# P01 风铃坡起点

出生点左侧是林缘低台，右侧是通往 P02 的平整草路。回头走下两级田阶，即可从平原侧看到西门的横闩和后方的荆棘老树。林缘捷径由 F08 一侧开启。门号、方向、房间边界和开门状态取自锁定世界与正式房间。[房间实例](../../../production/rooms/world/P01.json)

试枪架的两根木柱、一根横梁和旗杆给玩家提供固定的高度参照。可反复阅读的告示位于架前。角色在中央草地上原地起跳，朝脚下射击即可穿过木台，落在风旗旁。从任一端离台都能落回草地。地面留给首次瞄准与观察，全程没有敌人和伤害区。沿主路步行可直接进入 P02。

## 原生素材

所有构件按最终尺寸烘焙，实例以底边中心定位。木架后方是与 P02 连续的灌溉田野。西侧老树落在低田地表，低反差树线的切边埋入岸后。深色土层和草冠继续由正式平原 TileSet 绘制。

| 运行件 | 原料与处理 |
| --- | --- |
| `p01_forest_distance.png` | 取林缘双层树林原画的下排树冠，压低对比和饱和度后埋入坡后。[树林原画及来源](../../../assets/region_production_v3/spaces/woodland_two_depth_ridges_v2/) |
| `p01_forest_verge.png` | 取荆棘森林的扭根与枝冠，删去透明留白，按 285 px 宽导出，保留完整根脚。[森林原画及来源](../../../assets/forest_bible_v2/manifest.json) |
| `p01_loft_frame.png` | 原生木构的两只石脚支承横梁。风铃取自同区立式风铃的悬挂部分，接在梁下。[木构](../../../assets/plains_v07/native/mill_timber_bent.png) · [风铃](../../../assets/plains_v07/native/hanging_chime.png) |
| `p01_wind_ribbon.png` | 原有布旗立在木台末端，杆脚贴在实际台板上。[布旗](../../../assets/plains_v07/native/aqi_ribbon.png) |
| `p01_verge_fence.png` | 田间矮篱沿东路生长，作为从试枪架走向田埂的沿途标记。[田篱](../../../assets/plains_v07/native/orchard_fence.png) |

从仓库根目录运行以下命令可重建全部五张图。试枪架的站立面由普通房现成木平台实例负责，画件只提供承重构造和风铃。

```sh
python3 art/rooms/P01/build_scenery.py
```
