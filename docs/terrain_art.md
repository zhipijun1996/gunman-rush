# 平原 Demo 地形与装饰资源

## 交付与风格

32 个可独立导入的透明 SVG：22 个地形部件、10 个装饰。采用参考样片的草顶、冷灰岩石、低饱和绿色与少量黄铜；这是适合 Demo 的简化矢量表现，不等同于概念图的写实绘画密度。未来可保留锚点和连接契约替换更精细贴图。

- 地形：草顶 left / middle / right / isolated 各 3 变体；rock_fill 3 变体；rock_edge 左右；inner_corner 左右；thin_platform 左中右。
- 装饰：两种草丛、白花、金花、小石、石群、断柱、黄铜残环、垂藤、远景风车。
- 预览：[浏览器联系表](../assets/terrain/plains/contact_sheet.html)、[连续拼接预览](../assets/terrain/plains/seam_preview.png)。
- 导入数据：[完整元数据](../assets/terrain/plains/metadata.json)、[资源清单片段](../assets/terrain/plains/manifest_fragment.json)。

## 尺寸与对齐

统一 64 逻辑单位网格，每格 128 美术像素。使用 0.5 渲染缩放。所有草顶和薄平台的可站立表面为 SVG y=16 像素，即缩放后 y=8。将视觉节点相对游戏碰撞顶面偏移 y=-8 逻辑单位即可对齐；图片画布左上角不能直接当碰撞面。

地形 origin 为 [0,16]；填充和边缘为 [0,0]；普通装饰为底部中心，垂藤为顶部中心。装饰的 metadata.anchor_px 指示摆放锚点。SVG 均无碰撞定义，必须使用游戏对象已定义几何。薄平台图片 128×48，只有上表面参与既有单向平台玩法。inner_corner 是表面过渡装饰片，不代表曲线或斜坡碰撞。

## 生成组合与排除区域

1. 顶部行按 left → middle（可重复、可换三种变体）→ right 拼接；单格使用 isolated。
2. 下方 rock_fill 支持横向和纵向重复；边缘片用于外轮廓遮饰，连接标签由 metadata 指定。
3. 薄平台按照 left → middle → right 拼接，由世界组件控制是否单向与是否移动。
4. 普通装饰只能使用 decoration_safe 区；远景风车只能放背景层。建议最低间距 24 逻辑单位，由内容配置调节。
5. 顶面附近 0–24 美术像素是落点可读性保护区；不得随机添加遮挡前景。细小背景草花可放在平台后层，但仍需手机验证。
6. 模块入口出口、资源补充目标、危险运动路径和角色通道由地图系统给出额外排除区，美术系统不得覆盖。
7. 装饰单独使用随机流；风车和断柱默认不可镜像，避免光照和造型方向变化。装饰没有碰撞，禁止作为可站立目标。

## AI 制作与复现

全部资源由 AI 编写的确定性 SVG 生成器制作，没有人工绘制或外部素材。母版参考为已批准平原概念图；素材本身不含模型栅格生成内容。固定 seed 每个变体独立，源文件与哈希均保留于元数据。后续区域应保留 connectors、锚点、像素密度与交互色彩契约，只更换材质和形状。

```bash
python3 tools/build_terrain_art.py
python3 tools/check_terrain_art.py
python3 tools/check_docs.py
```

`check_terrain_art.py` 使用 Pillow 与 Godot 的真实 SVG 栅格化，检查全部素材、画布尺寸、哈希、锚点与草地/填充重复边界像素；有失败退出码。生成器对草顶一像素连接边做固定颜色保护，防止抗锯齿引入细缝。检查更新 seam_preview.png。联系表不作为游戏资源导入。

## 验收记录

2026-10-09：build_terrain_art.py 退出码 0，生成 32 SVG；check_terrain_art.py 退出码 0，全部 SVG 栅格化通过，三种草顶横边和三种填充横纵边通过精确像素检查；check_docs.py 退出码 0。

用于独立 SVG 检查的已安装 Godot 为 4.6.3，项目规范要求 4.7.2。本工作没有创建工程或修改物理参数。正式工程导入需要在要求版本复验；手机可读性、实际随机模块组合与目标机性能尚未验证，状态为 awaiting-device / awaiting-integration。

## 手绘平台补充素材

新增 [painted_platform.png](../assets/terrain/plains/painted_platform.png)，通过 image_gen 引用批准平原样片生成，透明背景 PNG 原样复制，无裁切、重采样或 Python 图像修改。画布 2172×724；alpha >16 的主体边界约为 [43,152,2130,588]。草叶上缘不等于碰撞表面，暂定 origin=[44,235] 像素，需游戏中确认后固定。

这是完整左右端头的平台候选，保留自然石材与植被的绘画密度；不是精确无缝 tile，禁止横向、纵向直接重复。可作为固定宽度独立落脚台；不同宽度的需求优先使用现有无缝矢量套件，或另外生成并验收新的完整平台。大幅拉伸会使石材变形，需限制缩放比例。背景零 alpha 与主体外极低 alpha 抗锯齿像素均保持生成原样。

完整提示词、参考图、来源、SHA256、透明选项和候选状态保存在 [painted_platform_provenance.json](../assets/terrain/plains/painted_platform_provenance.json)。已加入 metadata 与 manifest_fragment。确定性矢量生成器保留已有 PNG 补充条目，不会覆盖其图像。2026-10-09 验证：33 个素材真实栅格化、尺寸、哈希与既有无缝边界检查通过，退出码 0；手机可读性和碰撞对齐未验收。
