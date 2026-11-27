# P02 田埂反冲教学美术

西田与对岸钟架等高，站在入场点可以同时观察起跳边缘和落点。失足后走下西侧草坡即可进入 P16；东侧回收台下有一口向下贯通的排水井，连接 P19。地形、镜头提示与四个出口的位置以[房间文档](../../../production/rooms/world/P02.json)和锁定的世界模型为准。

## 可玩层与景深

矩形地形内部实际使用正式 32 px／47 邻接图集。草坡、井沿与非整格的地形边缘从同源材质按碰撞轮廓精确裁切。西草缝用两簇有独立根部的草形成视线缺口；较长的草穗从右侧长向通道，发现后逐渐退隐。草径后方的天然岸体从左屏边一直连到田埂外角。贴着顶沿的短根投影和两端侧光让玩家看清它是可通行的凹坡。井口两侧分别使用一格宽的区域砌石，实际开口宽 96 世界单位。井中的湿石在角色后方，矿痕沿重力方向下行。最深处的可行方向延续到 P19。

灌溉远景来自本房制作的[田野原画](irrigation_panorama_master.webp)。远处的天空、田渠和谷仓共用透视，导出时降低农田的局部反差与饱和度，让近处草边和钟架先被看见。远景随镜头产生视差，两岸钟架、草根与井壁使用房间坐标。

## 原生素材与导出

运行图位于 [production/assets/scenery/p02](../../../production/assets/scenery/p02)，均可在仓库根目录执行以下命令重建。脚本使用 Pillow 与 NumPy。

```sh
python3 art/rooms/P02/build_scenery.py --out /tmp/p02-scenery
```

| 运行画件 | 原料与处理 |
| --- | --- |
| `irrigation_panorama.webp` | 本房的田野原画按 1392 × 662、144 色导出。 |
| `windchime_plains_v2_chime_span.png` | [既有平原三铃](../../../art/world-art-v2/assets/pixel/v2/windchime_plains_v2_chime_span.png)，原尺寸 146 × 89。 |
| `p02_reed_screen.png` | [平原隐蔽草](../../../assets/plains_v07/native/concealing_grass.png)，调整朝向与尺寸，仅叶尖探入通道。 |
| `p02_slope_grass.png` | [平原草株](../../../art/world-art-v2/assets/pixel/plains_grass.png)，以 1:1 角色尺度沿草坡地表贴合根部。 |
| `p02_grass_bank.png` | 取[原生岩层](../../../assets/plains_v3/terrain/organic_cliff_fill.png)的节理，结合[岸根](../../../assets/plains_v07/native/bank_moss.png)嵌入背坡。剪影只覆盖草径后侧；地形前缘由 TileSet 绘出。 |
| `p02_well_lining.png` | 从[井壁原画](../../../assets/plains_v07/native/interior_well.png)采集曲面砖缝与渗水。右肩紧接东岸伸出的 72 世界单位，井身落在两侧砌石之间。 |
