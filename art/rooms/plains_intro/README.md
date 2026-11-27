# 平原起步区的邻房接收段

| 接收段 | 门侧与构图 | 素材来源 |
| --- | --- | --- |
| F08 林缘回廊东口 | 门前是一段平坦林间道。低矮根冠和中景倒木让角色与地上的门闩保持可见。门两侧地表均为 y=336。 | [F08 房间](../../../production/rooms/world/p02_connections/F08.json) · [森林远景与近中景根木](../../../production/assets/world_elements/forest_stage) · [森林正式 TileSet](../../../production/terrain47/thorn_forest.tres) |
| P04 折返旧路东口 | 从 P03 上层旧路向西踏上折返道，进入两级低矮田埂后可沿原路返回。田埂与门口齐高，路旁苇草在步行面上扎根。 | [P04 房间](../../../production/rooms/world/p02_connections/P04.json) · [平原苇丛与坡草](../../../production/assets/scenery/p02) · [平原正式 TileSet](../../../production/terrain47/windchime_plains.tres) |
| P13 壁缝回访路西口 | 从 P03 东壁龛向东，先经过开阔的贴壁小路，再进入折返石檐。菌丝和远墙延续进门前看到的岩层。 | [P13 房间](../../../production/rooms/world/p02_connections/P13.json) · [沟谷远墙与菌丝](../../../production/assets/scenery/p03) · [接收段远墙](../../../production/rooms/world/p02_connections/ridge_backwall.webp) |

P13 的远墙裁自 P03 的 1920 × 1024 沟谷背壁图。两侧门线对应原图横坐标 1686。接收段在原生像素比例下继续向东取样，抵达原图右缘后沿反向岩纹延展。门口两侧因此保留相同的岩脊剪影和纹理高度。[P03 远墙原图](../../../production/assets/scenery/p03/ravine_backwall.webp)

更新 P03 远墙、移动两侧配景锚点或调整 d017 门线后，在仓库根目录运行 `python3 art/rooms/plains_intro/build_ridge_backwall.py` 重烘焙。传入 `--check` 会逐像素核对已保存的 P13 贴图。[烘焙脚本](build_ridge_backwall.py)

## 林缘栅门

d223 两侧共享木桩和门扇。四根错高立木、两根横档和斜撑取自旧平原风铃门柱，铰件与横闩取自正式鸣钟闸的铁件图集。门脚的苔根取自林缘倒木。木桩和门扇分别输出透明 PNG，开门后保留固定木桩，门扇转至侧面。[木料原图](../../../production/assets/plains_v3/windchime_gate_beam.png) · [铁件原图](../../../production/assets/mechanisms/bell_gate/bell_gate.png) · [苔根原图](../../../production/assets/world_elements/forest_stage/thorn_forest_v2_thorn_log.png) · [门桩](../../../production/rooms/world/p02_connections/forest_gate_post.png) · [门扇](../../../production/rooms/world/p02_connections/forest_gate_leaf.png)

玩家在 F08 侧接近横闩后按 ↑ 或 W 开门。门扇表现和实际碰撞共同读取已提交的捷径状态。P01 外侧可以看见门体和横闩提示，世界重新载入后两侧恢复同一状态。[门体表现与碰撞](../../../production/rooms/world/p02_connections/forest_shortcut_gate.gd) · [世界捷径回归](../../../production/tests/world_shortcuts.gd)
