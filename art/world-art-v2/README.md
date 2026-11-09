# 失序之钟 · 16 区域美术素材库 v2

本目录随 **Codex Cloud接入包1.0.0** 分发。先阅读项目根的 `ROOM-ART-START.md`；完整技能位于 `.agents/skills/godot-room-art/`。本目录保存唯一的原生PNG，Godot资产副本由恢复工具生成。

这版在上一版 Underworld 细像素材质与光照基准上，补齐16区47邻接、扩充特色道具、重画独立景深，并重画风铃平原与荆棘森林的远背景。新背景与新增设计属于本轮候选，保留旧版素材供比较；不把本轮输出自动视为用户已认可的正式区域美术。

## 这次交付

| 内容 | 数量与范围 |
| --- | --- |
| 原生32px地形 | 16区 × 47合法八邻接 = 752格；每区一张256×192透明atlas |
| 特色道具 | 每区4个，共64个独立透明PNG |
| 重绘景深 | 每区1个中景＋1个低矮近前景，共32个独立透明PNG |
| 重绘远背景 | 风铃平原、荆棘森林各1张640×360背景；旧背景仍保留 |
| 实拼示例 | 16区使用同一32px占格布局，含薄平台与地形洞口，便于比较材料和光照 |

保持1原生像素=1世界单位，地形32px，角色身体44wu，纹理nearest，显示位置取整数。新增道具与地形荆棘都是美术素材，不自动附带碰撞伤害或新玩法。

## 先看效果

`previews/regions-overview.png` 展示16区当前拼装。安装本地Node依赖后，`node build-preview.cjs` 生成16区离线交互预览 `world-art-preview.html`；生成后的HTML无需联网，可换区、开关光照和景深、暂停/播放、移动镜头与开关角色局部避让。主包不重复内嵌这份包含全部PNG的HTML。

平原/森林前后对照与已认可视觉参考保存在技能 `assets/`。需要动态预览时运行 `node render-study.cjs --video`，额外需要ffmpeg。前后对照、地形矩阵和素材联系表仍保留在历史完整交付包；本Cloud包以当前资产、恢复入口和少量基准图为主。

PNG和视频由实际独立素材在Canvas中拼装渲染。Godot完成原生资源、选格与场景行为检查；本环境未取得Godot窗口画面的录屏。示例灰盒不是16个正式设计完成的关卡。

## 文件包怎么用

| 文件 | 用途 |
| --- | --- |
| `godot-room-art-cloud.zip` | 完整技能、视觉参考、本目录素材与配方、Godot可重建样例、锁文件与工具。首次接入使用。 |
| `godot-room-art-cloud-sources-terrain-backgrounds.zip` | 可选：本轮2张背景、4张内凹角生成源图。提示词和裁切记录已在主包。 |
| `godot-room-art-cloud-sources-props-depth.zip` | 可选：本轮4张道具、4张景深生成源图。提示词和裁切记录已在主包。 |

三包统一以 `godot-room-art-cloud/` 为顶层，在同一父目录解压合并。每个ZIP小于20MB，各自可解压。普通拼装、预览和Godot准备只需主包；重裁本轮生成素材再加可选源图。旧版生成源图按技能资产索引恢复。

## Godot入口

先从项目根执行 `python3 tools/art_bundle.py setup godot` 与 `python3 tools/art_bundle.py prepare-godot`，然后打开本目录 `godot/project.godot` 运行主场景。A/D移动、空格跳跃，方向键或下拉框换区域；其他按钮对应光照、景深与环境运动。32px占格坐标在 `study.json` 的 `terrainGrid`；编辑后按需要重建派生样例，保留手工场景修改。

单独导入47邻接时，复制 `godot/terrain47/` 为项目的 `res://terrain47/`，选择对应区域 `.tres`。地形连接采用 Match Corners and Sides，source/terrain set/terrain均为0。完整掩码、Godot位对应、选格规则、碰撞与美术表面偏移说明见 `autotile/README.md`。

## 新的景深放置规则

附着于平台的草裙、苔块等保持世界速度1，锚点随平台移动。独立近前景使用完整、低矮、末端自然收细的轮廓，放在主平台高度附近；本样例视差为1.08/1.12。`platform_band` 遮罩约束基座与洞口，`mask.surfaceY` 明确绑定的平台世界高度，局部 `heroReveal` 只减弱角色附近的遮挡。

地形自身 `surfaceY` 是tile图像中可站立表面的位置，用于整层美术偏移；它与 `mask.surfaceY` 不是同一坐标含义。碰撞仍来自原始32px占格，不随装饰草沿偏移。中景位于平台后，基座藏入地形；远背景使用单独的低速视差。

近前景含透明边宽224px，高48–69px；中景含透明边宽242px。保留源图比例，不为统一高度做非等比拉伸。镜头±32样例有背景覆盖；长房间、竖向房间需按实际相机范围另补背景/中景覆盖。

## 继续扩充与重建

直接调整现有素材和摆放时，无需重生成或重裁PNG：编辑 `study.json`，运行 `node build-preview.cjs` 与 `node render-study.cjs --all`。

重新烘焙本轮图像时：先合并两份新源图包，运行 `python3 bake-v2-assets.py`；内角按 `autotile/corner-sources.json` 与 `python3 autotile/bake_corners.py` 重建，再运行 `python3 build-autotiles.py`。切片以实测bbox、源SHA和网格记录为准，不能仅按提示词声称的等分网格裁切。

`configure-v2.py` 从保留的v1配方重建本轮默认样例，会替换手工修改过的study；仅在需要恢复默认时运行。`build-catalog-v2.py` 更新配方索引。旧九宫格裁切脚本仅作历史来源，勿用于覆盖本轮manifest。

依赖：Python 3＋Pillow/NumPy/SciPy，Node.js＋package.json所列依赖；视频额外需要ffmpeg。Godot实测版本4.6.3。图像生成由内置图像工具完成，代码只执行裁切、最近邻烘焙、透明阈值、合成及运行时光照/遮罩，不用程序噪声替代作者纹理。

## 来源与检查范围

`v2-source-generation-record.json`、各 `v2-*-prompts.json`、`v2-assets-map.json`、`v2-assets-report.json` 与 `autotile/recipes/` 记录源图、提示词、实测裁切矩形、处理方式和SHA。平原47格保留项目既有fine32 atlas第一组的原RGBA像素；其他15区保留旧材质象限，并补绘真实内凹角供体。

数学与像素覆盖见 `autotile/validation-report.json`；Godot实际选格见 `autotile/godot-validation.json`，包含16×47中心匹配和256原始八邻域归一化验证。Canvas与Godot场景行为报告分别保存在 `previews/assembly-checks.json`、`godot/validation-report.json`。这些检查不代替正式关卡的可达性设计、游戏回归或最终美术验收。

基础材质沿用 Asouris 的 [Underworld Tileset](https://asouris.itch.io/underworld-tileset) 及项目已有fine32派生资源，保留来源说明；原素材、项目派生与新增生成素材分别记录。
