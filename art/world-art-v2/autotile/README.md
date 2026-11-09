# Underworld 32px：16 区域的 47 邻接

地形资产入口是 `assets/terrain47/manifest.json`。每个区域拥有一张 **256×192、8 列×6 行** 的透明 PNG；前 47 格有效，第 48 格为空。每格 **32×32 原生像素**，世界单位比例保持 **1px = 1wu**。

## 47 格从哪里来

风铃平原保留既有 `fine32-terrain.png` 第一组 47 格的 RGBA 像素，旧掩码坐标关系来自 `references/underworld-origin/formal-fine32-terrain_build.json`。

其余区域复用上一版各自的 96×96 地形材料，并以已认可的五区材质方向为共同基准。每个 32×32 格由四个 16×16 象限组成。一个象限只有五种合法情况：外凸角、横边、竖边、中面、内凹角。原九宫格提供前四类；新增绘制的内凹角提供第五类。因此输出包含单块、单行、单列、端点、T 形、十字、洞口等真实状态，没有把同九格重复标号为 47 格。

`autotile/recipes/<区域>.json` 记录每个输出的来源文件、SHA-256、裁切矩形和目标象限。新内角保留独立源与烘焙记录。生成程序只裁切、合成和打包已有绘画，不绘制纹理或材质细节。

## 掩码契约

掩码从上方向开始，顺时针排列：

| 方位 | N | NE | E | SE | S | SW | W | NW |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 位值 | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 |
| Godot `CellNeighbor` | 12 | 15 | 0 | 3 | 4 | 7 | 8 | 11 |

只有某个对角的两条相邻直边都存在，才保留该对角位。例如，NE 只在 N 与 E 同时存在时保留。256 个原始八邻域由此归并为 47 个规范掩码；其升序排列就是 atlas 的行优先顺序。不要把 atlas 索引当作掩码值。

| 例子 | 规范掩码 |
|---|---:|
| 独立单格 | 0 |
| 单列中段，仅上、下相连 | 17 |
| 单行中段，仅左、右相连 | 68 |
| 十字中心，四直边有邻居，四对角空 | 85 |
| 左上出现内凹角，其余完整 | 127 |
| 完全内部 | 255 |

全部 256 项归一化结果、47 项索引及 Godot 位对应关系都在 manifest，浏览器与 Godot 消费同一份契约。

## Godot 使用

将 `godot/terrain47` 拷入 Godot 项目的 `res://terrain47`，把区域的 `.tres` 指定给 `TileMapLayer.tile_set`。每个资源都有 source **0**、terrain set **0**、terrain **0**，采用 **Match Corners and Sides**，含 47 个不同图块和完整 peering bits。编辑器可直接使用地形连接绘制。

运行时可以让 Godot 根据占格自动连接：

```gdscript
layer.tile_set = load("res://terrain47/thorn_forest.tres")
layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
layer.set_cells_terrain_connect(cells, 0, 0, false)
```

`cells` 是 `Array[Vector2i]`。最后一个参数为 `false`，让空地参与匹配，洞口和外缘才能按该占格明确选取。也可读取 manifest 的 `maskToAtlas` 后直接 `set_cell(cell, 0, atlas_coord)`，两条路径使用同一个索引。

### 地形位置与碰撞

`terrainGrid = {tile:32, origin:[x,y], cells:[[cx,cy],...]}` 中，`origin` 是像素位置，`cells` 是整数格坐标。装饰草冠、冰面等存在 `surfaceY` 的视觉偏移。

本次房间展示沿用外置灰盒碰撞：可把整个视觉 TileMapLayer 的 y 统一减去该区域的 `surfaceY`，并关闭它的 `collision_enabled`；原碰撞仍在 grid origin。不要逐个瓦片作不同位移。

独立 `.tres` 提供完整 32×32 方格碰撞，方便单独导入。使用该碰撞时，草冠透明区域属于视觉装饰，具体站立面可按游戏原有碰撞系统校准。内角的美术倒角不会擅自缩小玩法碰撞。

每一区域是同一材质的 47 邻接；不同区域之间的混合材料过渡不是这 47 格的内容。

## 扩充区域或重烘焙

1. 先补完整的该区九宫格来源与四个内凹角。保持旧地形的材料核心色、像素密度、亮边宽度和重力方向。
2. 内角原生条带为 `assets/terrain47/corners/<区域>.png`，尺寸 64×16。四格顺序是 NW、NE、SE、SW；方位表示该象限缺口靠近的外角。每格是 16×16，缺口接触相邻两条外边，另外两条边应保留实体连接。源图裁切矩形写在 `autotile/corner-sources.json`，执行 `python3 autotile/bake_corners.py` 可重复烘焙；不要把图像生成时承诺的网格位置当成已验证的裁切位置。
3. 修改来源后运行 `python3 build-autotiles.py`。若缺少任何区的内角，程序会停止，不会生成占位图。
4. 运行 `python3 autotile/validate_godot.py`。它临时创建只有地形资源的小项目，生成 `.tres` 并验证引擎匹配，完成后清理临时导入缓存。
5. 检查原生拼装图，而非只看素材 atlas。`previews/<区域>_all47.png` 为每种掩码构建真实邻域，描边标识被测试的中央格；`<区域>_features.png` 展示连续地形、洞口、窄台、柱和交叉结构。

## 验证证据

- `validation-report.json`：752 个格的唯一性、来源拷贝一致性、47 个中心邻域、共享边是否存在完整断口，以及边缘 alpha 差异的统计。
- `godot-validation.json`：实际 Godot 版本、每区 47 格资源、terrain peering bits、碰撞、原生地形连接选择结果；256 种未归一化邻域另行核对。
- `previews/all-regions-atlas.png` 与 `previews/all-regions-features.png`：总览。单区域原生预览保留独立文件。

结构验证不等于美术验收。石材缺口或草尖的边缘 alpha 可以不同；报告不声称每条接缝颜色完全相同，也不把 headless 检查称为 GPU 场景验收。

## 官方 API 依据

- [TileSet：地形模式与 CellNeighbor](https://docs.godotengine.org/en/stable/classes/class_tileset.html)
- [TileData：terrain peering bits 与碰撞多边形](https://docs.godotengine.org/en/stable/classes/class_tiledata.html)
- [TileMapLayer：set_cells_terrain_connect](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
