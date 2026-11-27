# P02 田埂反冲教学

[正式房间](../../../production/rooms/world/P02.json)采用 v29 的 1650 × 845.8593 局部空间。玩家从 P01 经过西边界进入，站在海拔相同的起跳地与三铃台之间。全速普通跳会落入排水沟；从西田起跳后朝身后放枪并落稳，三铃应声一次。东侧 186 单位的错高缺口可以普通跳过去，回程则可借后坐力登上较高的铃台。

| 门 | P02 本地门线中心 | P02 回程的站姿中心 | 看到和用到的地形 |
| --- | --- | --- | --- |
| d001 → P01 | (0, 413.8593) | (60, 413.8593) | 上层水平草田和远端铃架 |
| d002 → P03 | (1650, 425.8593) | (1590, 425.8593) | 草田高岸和短篱，路面平进峡谷 |
| d009 → P16 | (240, 785.8593) | (304, 732) | 西下根洞，右壁有三层回程落脚面 |
| d330 → P19 | (960, 845.8593) | (896, 786.8593) | 铃台下的排水井，回程落在左壁龛 |

西下的草径有独立前景。玩家靠近内侧低台才揭示入口并写入发现，离开后草皮重新遮住井口。西侧土壁接到根部，左右两座通口都朝下。v29 中 P16、P19 提供可往返的接收廊。低沟草虫留在回退阶背后的草径内，东田草虫沿宽路巡行。首跳起跳面、铃台、井口和门侧落脚处均留给观察和移动。

## 原生美术

地平线使用本房的田渠远景，主铃架、根洞和石井保留各自的 1:1 像素挂件。[分层岸土](../../../production/assets/scenery/p02/p02_terrace_strata.webp)从本房的[原生土层](bank_subsoil.png)烘焙，在平台草冠下面接入岩层与底部阴影，两条井的中央裸露空间都保持畅通。草幕使用原生 224 × 256 图，左上角为 (128, 562)。

在仓库根目录运行以下命令可复建岸土及检查实机控制。整房原图和正常速度的正式机位录像采用[三房录制入口](../plains_intro/v29/README.md)。

```sh
python3 art/rooms/P02/bake_terrace_strata.py
bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/plains_p02_terrace.gd
bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/p02_connections.gd
bash tools/godot.sh --headless --path production --fixed-fps 60 --script res://tests/p02_death_recovery.gd
```
