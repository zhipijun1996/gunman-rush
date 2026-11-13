# 区域素材与组装约定

沿用素材包中的 `study.json` 和 `assets/pixel/manifest.json`；接入正式游戏时映射到项目已有格式，避免重复建立平行的正式世界数据。

## 文件与归属

| 内容 | 记录位置 | 必需信息 |
| --- | --- | --- |
| 源素材 | `assets/source/` | 完整原图、生成或编辑提示词、参考来源和原作者归属 |
| 最终像素素材 | `assets/pixel/` | 独立 PNG、原生宽高、来源裁切、烘焙方式与 SHA-256 |
| 区域配置 | `study.json` 的区域项 | 正式ID、材质、实例、图层、灯光、环境运动 |
| 像素清单 | `assets/pixel/manifest.json` | `sprites`、`backgrounds`、`terrains` 与实际文件映射 |
| 47邻接 | `assets/terrain47/manifest.json` | 16区atlas、47掩码坐标、位序、归一化表、表面偏移与哈希 |
| 房间输入 | 房间已有数据或 `study.json` | 地形、角色/交互位置、附着点与镜头覆盖 |
| 验证证据 | 包内 `previews/`、Godot报告 | 对应输入版本、实际输出类型与范围 |

新记录使用正式区域ID。将旧试片 `plains`、`forest` 仅作为 `windchime_plains`、`thorn_forest` 的读取别名；避免目录、素材清单和场景各叫一个名字。

## 实体、地形与图层

实体沿用 `file,w,h,pivotX,pivotY`。用 `sourceFile`、`sourceRect`、`sha256` 记录来源；替换中心格等机械操作另记 `overrides`。地面物的锚点放在底座/根部；悬挂物按悬挂连接点定义。使用方向或尺寸变体时保留每个变体的实际锚点。

区域实例沿用 `asset,x,y,group`；平台附着物使用 `group:"attached"`，若有摆动保持根部固定。荆棘、尖石或热源需要另外记录危险方向、实际伤害轮廓与是否已接入玩法；普通装饰不可被默认为伤害对象。

旧供体地形保留 `terrains[regionId]`：`asset,tile,surfaceY,bank,coords`，需要时保留 `bankColumns`；它仍描述九宫格来源，不是v2最终邻接索引。v2使用独立47清单的 `regions[regionId]`，每区32px、8×6 atlas、47有效格，读 `maskToAtlas` 选格。16区共752个不同像素变体，平原第一组47保留源RGBA，其余15区为旧供体加新内角的机械组合。细节见 `autotile-47.md`。

房间占格使用 `terrainGrid:{tile:32,origin:[x,y],cells:[[cx,cy],...]}`；origin是世界像素位置，cells是整数格坐标，`region.terrainGrid` 可覆盖公共输入。以各材质的terrain `surfaceY`统一上移视觉地形层，使顶饰与灰盒表面对齐；外置碰撞留在原占格，避免双重碰撞。独立TileSet仍保留完整32px格碰撞。

新扩展使用独立 `region.layers` 项：

```json
{
  "id": "mid-structure",
  "asset": "region_mid",
  "kind": "mid",
  "x": 320,
  "y": 270,
  "parallax": 0.45,
  "opacity": 0.5,
  "tint": [0.6, 0.7, 0.8]
}
```

按 `sprites` 中的原生尺寸和锚点放置。`kind:"near"` 使用独立近景深度；平台附着前景仍在世界层实例中。底板使用 `backgrounds`，本套起点为0.12；这些字段表示实际独立素材，不能用同一张整图声称已拆出内部层次。

用 `region.background` 选择 `backgrounds` 的实际key，用 `region.backgroundParallax` 保存远景倍率。v2背景表有18项、实际仍为16区：平原和森林各保留旧图及一个 `_v2` 候选。不要按区域ID硬编码背景，或把背景项数当作区域数。

v2中景实例使用0.45/0.62，独立近景左右实例使用1.08/1.12；附着前景始终为1。一个PNG可以实例化在不同位置与深度，分别统计独立素材数和实例数。中近景按自己的 `tint × backgroundAmbient` 调制，不自动接收世界玩法面的局部光。

近景可使用 `mask:{type:"platform_band",surfaceY:288,above:72,below:72,edgeFade:8,heroReveal:{radiusX:30,radiusY:48,minAlpha:0.15}}`。这里 `mask.surfaceY` 是所依附平台的世界高度，必须对应真实上表面，与terrain顶饰偏移不是同一字段含义。世界坐标遮罩只收住基座、保留上部轮廓；heroReveal以半径定义角色附近的局部透明窗。镜头移动后再核对这些行为。

当前16×47包含单格、单行、单列、T形、十字和洞角。斜坡、区域间混材过渡及无限背景接续不属于该47矩阵。单张96×96供体只有9块32px部件；不能把重复9格标号成47格。保持原生比例，禁止用场景非等比缩放掩盖源图比例或裁切问题。

## 灯光与粒子

每区 `lighting` 沿用 `ambient,backgroundAmbient,heroFill,lights,beams`，按实现保留遮挡参数。每盏灯记录 `id,x,y,radius,color,energy,shadow`；按需使用 `visible,coreRadius,flicker`。检查实际素材发光面与灯的位置；颜色为0–1，能量允许大于1。

`particles` 沿用 `color,count,speed,vertical,kind`。保留确定种子、可暂停时间和显示整数网格；同帧光照对比或重建预览使用相同时间，避免把粒子变化误当成光照变化。

## 素材交接

整体重做的新素材需记录选定全屏、正式材质与角色的实际参考路径，以及完整生成提示词。概念、分层生成、机械裁切和引擎组装分别保存来源关系；某次生成没有送入的参考不能写成它的实际输入。整景稿只作为意图，不得冒充已完成独立层和真实地形接入。裁切仅用于按已设计边界分离部件，不把任意背景截块伪称为完整近景。

每次扩充保留以下关系：生成源 → 裁切矩形/原生尺寸 → 独立文件与锚点 → 区域配置 → 实际拼装证据。复用基准原素材时保持原文件和哈希，替换它时提供新版本与原因。

目视确认源图真实布局，再检查连通组件归属。本轮depth源图实际列界在约2/3宽处，celestial地标/灯列界在57.5%；等分裁切曾把断开的冰镜、柱片和星门弧误归到相邻素材。将纠正后的 `normalizedColumnEdges`、原因和对应源图哈希一起记录，源图变化后重新检查。

保留有意的透明度。v2实体和内角供体以alpha≥128生成硬边，低alpha彩色毛边在阈值后清除，并清空透明像素RGB；先检查实际alpha，不能把查看器底色当成已烘进图里的背景。原项目地形合法半透明像素、雾、柔光和运行时遮罩按语义保留，不对所有图统一二值化。最近邻烘焙后仍检查原尺寸，避免把高分辨率噪声缩成碎点。
