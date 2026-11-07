# 原生32px的47邻接

## 读取实际版本

当前v2包含16区×47格，共752个不同像素变体。读取包内 `assets/terrain47/manifest.json`，不要把旧 `assets/pixel/manifest.json` 的九宫格供体字段当作最终47索引。原生文件为 `assets/terrain47/<region_id>.png`；每张256×192，8列×6行，47格有效，最后一格透明。

沿用1素材像素=1世界单位、32px地形、约44wu角色身体。每个最终图块是32px，16px象限只是拼装单位，不改变游戏格尺寸或像素密度。

## 规范位序

| 方位 | N | NE | E | SE | S | SW | W | NW |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 掩码位值 | 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 |
| Godot CellNeighbor枚举值 | 12 | 15 | 0 | 3 | 4 | 7 | 8 | 11 |

只有对角的两条相邻直边都存在，才保留该对角位。将256个原始八邻域归并为47个规范掩码；依其升序排列atlas位置。读取manifest的 `normalizeTable` 和 `maskToAtlas`，不要混淆格索引与掩码值。

例如：0为独立格，17为单列中段，68为单行中段，85为四直边连接且四对角空的十字中心，127为仅左上凹入，255为完整中面。该集合覆盖端点、薄柱、T形、十字和洞口，不包含斜坡或不同材料之间的混合过渡。

## 从真实供体补齐

风铃平原使用已认可 `fine32-terrain.png` 的第一组47格，按旧 `formal-fine32-terrain_build.json` 裁切，逐格保留原RGBA。原768×192文件继续保留；重新打包得到的256×192 PNG可以有新文件哈希，不得把它声称为原PNG字节相同。

其余15区复用已认可九宫格的边、外角和安静中面，并增加每区四个内凹角，共60个新绘象限。每个象限由两条直边和一个对角决定五种状态：外角、两种边、中面、内角。按规范掩码组合四个16×16象限；禁止把九格复制标号成47格，也不要用代码画假纹理。

制作新的内角供体时：

1. 输入本区旧地形局部、安静core颜色、亮边宽度、像素密度和光源方向。每格只在指定角出现小缺口；缺口必须接触该角两条外边，其余边有实体连接。
2. 用独立透明格表达NW、NE、SE、SW，保持重力敏感的草、冰挂和根系方向。先看实际源图，再测每格主体bbox；不能盲信生成提示词的等分网格。
3. 保存四张源图、提示词和源哈希，按已确认crop最近邻烘焙为16px。生成供体使用alpha≥128，清空透明像素RGB；不改变原平原合法的251–253等alpha值。
4. 只复制靠洞角的作者像素，通过确定的几何mask接回本区旧core。v2使用距空角约8px的范围；不合成新纹理、不重新随机散点、不用整片亮供体覆盖安静中面。
5. 输出每区64×16条带，四格依次NW、NE、SE、SW，方位表示透明缺口所处外角。保留原donor条带、最终条带、每步crop、mask规则和SHA-256。

供体与复现入口位于包内：

| 内容 | 路径 |
|---|---|
| 已确认源图裁切 | `autotile/corner-sources.json` |
| 最终内角和来源 | `assets/terrain47/corners/manifest.json` |
| 内角烘焙 | `autotile/bake_corners.py` |
| 47规范逻辑 | `autotile/mask47.py` |
| 47atlas烘焙 | `build-autotiles.py` |
| 每区逐格来源 | `autotile/recipes/<region_id>.json` |

## Godot与房间几何

用 `terrainGrid:{tile:32,origin:[x,y],cells:[[cx,cy],...]}` 表示占格。origin为世界像素，cells为整数格索引，区域可覆盖公共grid。以同一占格生成TileMap、外置碰撞、遮光与景深基座遮罩，避免它们各用不同旧矩形。

每区 `.tres` 位于 `godot/terrain47/`，source0、terrain set0、terrain0，匹配模式为 `MATCH_CORNERS_AND_SIDES`，八个peering bits按manifest配置。`set_cells_terrain_connect(cells,0,0,false)` 让空地参与连接；也可用同一 `maskToAtlas` 直接选格。

房间样例统一把视觉TileMap上移本区terrain `surfaceY`，占格碰撞保持原世界坐标，关闭TileMap内置碰撞。单独导入资源的全32px碰撞仍可使用，接入时选择一种碰撞来源。不要把terrain的顶饰偏移与近景 `mask.surfaceY` 的世界平台高度混用。

## 检查真实范围

执行 `python3 build-autotiles.py`，再执行 `python3 autotile/validate_godot.py`。后者只创建含相关资源的最小Godot项目，生成并检查TileSet，保存报告后清理临时导入目录。

v2已有：752个唯一像素图块、2,867次来源拷贝核对、47种中央邻域、3,840条占格共享边检查；没有完全断开的共享边。60个内角的透明缺口都在指定角，两条朝内边实心。局部石屑和草尖的alpha差异允许存在，不据此宣称颜色完全无缝。

Godot4.6.3原生terrain连接实测选对16×47个fixture中心，并选对256个原始八邻域的规范结果。这证明索引与引擎连接，不证明GPU画面、正式游戏接入、敌人战斗或跳跃可达性。

目视 `autotile/previews/<region>_all47.png` 和 `<region>_features.png` 的洞角、薄柱、单格及材料接续。总览是拓扑诊断拼装，不能当成已完成房间。新房仍需配合区域构件、光照和景深；只有实际验收过的画面才更新用户认可记录。

官方依据：[TileSet](https://docs.godotengine.org/en/stable/classes/class_tileset.html)、[TileData](https://docs.godotengine.org/en/stable/classes/class_tiledata.html)、[TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)。接口按目标Godot版本复核。
