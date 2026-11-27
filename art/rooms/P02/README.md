# P02 田埂反冲教学美术

西田与对岸钟架等高，站在入场点可以同时观察起跳边缘和落点。从西田断边失足会落在草坡。靠近草丛时叶片退开，顺天然土井下落可进入 P16；在 P16 井口正下方起跳即可返回。东侧回收台另有一道通往 P19 的砌石排水井。地形、镜头提示与四个出口的位置以[房间文档](../../../production/rooms/world/P02.json)和锁定的世界模型为准。

## 可玩层与景深

矩形地形内部实际使用正式 32 px／47 邻接图集。草坡、井沿与非整格的地形边缘从同源材质按碰撞轮廓精确裁切。西草缝用两簇有独立根部的草形成视线缺口；较长的草穗从右侧长向通道，发现后逐渐退隐。草径后方的天然岸体从左屏边一直连到田埂外角。贴着顶沿的短根投影和两端侧光让玩家看清它是可通行的凹坡。井口两侧分别使用一格宽的区域砌石，实际开口宽 96 世界单位。井中的湿石在角色后方，矿痕沿重力方向下行。最深处的可行方向延续到 P19。

灌溉远景来自本房制作的[田野原画](irrigation_panorama_master.webp)。远处的天空、田渠和谷仓共用透视，导出时降低农田的局部反差与饱和度，让近处草边和钟架先被看见。五个房间从同一张原画取景。穿门时接收房沿用遮幕前最后一帧的田野采样，镜头在新房开始移动后，根据成对门截面所在的统一坐标继续视差。两岸钟架、草根与井壁使用各自的房间坐标。

## 四个门口

西、东两条田路分别延续到 P01 和 P03，角色脚下使用同一种平原草冠。d009 位于 P02 西侧草缝下方，两岸之间有 96 世界单位的竖直开口。P02 的脚下截面与 P16 的头顶截面使用同一段土筋、短根和侧壁。玩家从上层田沿落到低台，在草边发现入口，随后下落穿过截面。在 P16 原地起跳可回到 P02 的近岸凹阶，再跳两次回到草坡。P19 的井口继续使用 P02 井心的 96 像素宽原画，井底接收段接在同一列砖缝和渗水痕下面。竖井两侧各留一格砌石，顶部开口由真实可通过的几何确定。

每个方向可用同一真实控制器重拍。以下命令从 P02 一侧向西进入 P01；其余门号是 `d002`、`d009` 和 `d330`，反向取 `to-field`。输出记录穿越截面、幕内换房和恢复控制的实际渲染帧，可据此从影片截取门前与门后各一秒。

```sh
bash tools/godot.sh --path production --fixed-fps 60 --write-movie /tmp/d001.avi \
  --script "$PWD/art/rooms/P02/capture_passage.gd" -- d001 from-field
```

八次采集各自的 AVI 和日志按 `<门号>-<方向>.avi` 与同名 `.log` 放入同一目录。以下命令导出双向单片、成对正常镜头、总片和逐门帧表。水平门的屏高取自截面内侧四个世界单位的真实地面射线，竖井记录截面中心。

```sh
python3 art/rooms/P02/assemble_passages.py /tmp/p02-door-recordings build/review/P02/passage-seams
```

八向采集根据房间声明的截面法线选取输入。横门从内侧踏出，向下的门从实际碰撞地面走入开口，朝上的门由角色起跳。独立单片会预先在声明的发现点触发解锁。另一个连续拍摄脚本从全新进度的 P02 西田开始，经真实发现、下落、跳返和两次攀阶回到田埂。以下命令生成带简短中文字幕的连续原速片，音轨来自正式游戏。

```sh
bash tools/godot.sh --path production --fixed-fps 60 --write-movie /tmp/grass-route.avi \
  --script "$PWD/art/rooms/P02/capture_grass_route.gd" > /tmp/grass-route.log
python3 art/rooms/P02/cut_grass_route.py /tmp/grass-route.avi /tmp/grass-route.log /tmp/P02-grass-shaft.mp4
```

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
| `p02_root_throat.png` | 取同源土岩和草根制作宽 96 px 的草口内壁，另向右延伸 36 px 作为凹阶背土。同一块 132 × 262 px 的岩纹分别接在 P02 的 [258,834] 和 P16 的 [422,289]，在成对的门截面保持原生像素相位。 |
| `p02_well_lining.png` | 从[井壁原画](../../../assets/plains_v07/native/interior_well.png)采集曲面砖缝与渗水。右肩紧接东岸伸出的 72 世界单位，井身落在两侧砌石之间。 |
