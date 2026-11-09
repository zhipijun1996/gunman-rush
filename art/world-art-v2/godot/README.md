# 《失序之钟》16 区域素材与景深 · Godot

这是16个区域共用同一套几何与角色比例的独立美术样例。每区有自己的材质、构件、灯具、粒子与可独立移动的景深素材。内部取景为640×360，默认以整数2倍显示；角色身体基准为44世界像素，素材以1px＝1世界单位绘制。它不改变正式游戏的视口、地图或玩法。

## 打开与操作

用Godot导入 `project.godot` 并运行 `study.tscn`。首次打开会导入纹理。当前环境用Godot 4.6.3做资源与行为检查；正式项目目标版本是否有变化，应以项目配置为准。

| 操作 | 功能 |
| --- | --- |
| 左上区域下拉，或← / → | 切换全部区域 |
| A / D、空格 | 参考角色移动、跳跃 |
| L | 场景光照 / 素材原色 |
| B | 显示 / 隐藏独立中景与近景 |
| M | 显示 / 关闭角色周围的近景避让窗口 |
| Q / E / R | 镜头移到左32px / 右32px / 居中 |
| P | 播放 / 暂停环境、视差与灯光微动 |
| H | 隐藏 / 显示文字与下拉框 |
| Esc | 退出 |

默认暂停，镜头位移为0，便于比较静态材质。换区保留角色位置；当前区域的占用格生成实际碰撞，空洞保持为空，跌出画面回到出生点。构件为装饰；荆棘等危险物为视觉素材，未接入正式游戏的伤害判定。

## 地形与真正独立的景深

所有地形按32px单格绘制。`terrainGrid` 给出占用格，`terrain47/*.tres` 提供各区域的47邻接TileSet。`grid_terrain.gd` 按8邻接掩码选格；只有相邻两条正交边都存在时，才保留对应斜角。单格、薄梁、凸角和凹角因此可以共用同一数据入口。该地图层使用真正的TileMapLayer，仍保留旧水平矩形平台输入兼容。

整张材质层上移自己的 `surfaceY`，使表面装饰超出格顶，而真实站立面保持在占用格边界。此样例关闭TileMapLayer的内置碰撞，用相同占用格另外生成StaticBody2D；这样不同材质的视觉顶饰不会移动玩法面。独立TileSet资源中也保留完整32×32格碰撞，接入其它项目时选择一种碰撞来源即可。

`assets/terrain47-manifest.json` 记录47种掩码、atlas坐标与原生资源路径；`assets/geometry.json` 记录由同一输入生成的实心矩形和露出的上表面。区域切换同时切换碰撞层，隐藏区域不会阻挡当前角色。

层级依次为背景板、独立中景、光束与世界构件、地形、角色和小物、平台附着前景、粒子、独立近景。场景树中的 `Midground` 和 `Nearground` 均为真实素材Sprite节点，来自 `region.layers`。背景板默认按0.12倍镜头位移，中景和近景倍率逐实例读取；世界地形、灯具、角色与附着前景使用同一个世界坐标系，倍率为1，避免植物根部滑动。

镜头最大支持±32px往返示范景深，显示位置取整。背景在画面边界用原图像素镜像补足少量覆盖，Canvas样例也对世界边缘使用64px补边。Godot的格子地图可提供画面之外的占用格。这是当前小取景的覆盖策略；扩展成长房间时应按镜头范围补画远景接续件，并检验实际循环接缝。

中景、近景使用独立 `tint`、`opacity` 与环境调制，默认不接受世界平台灯具的局部光。这些深度素材与玩法面并不共面；贴平台的前景则与地形一起接受世界灯光。素材的逐条位置、锚点、倍率与调制由共享JSON和 `depth-placements.json` 记录。

新近景的基座放在平台高度附近，以1.08或1.12倍移动。`platform_band` 遮罩只逐渐限制靠近地面的底座：上部轮廓可以伸出平台，底座跨越裂隙时会被收掉。遮罩在世界坐标取样，素材保持自己的独立视差，不会变成粘在地形上的纹理。平台带默认上下72px、边缘8px；可以通过 `surfaceY` 明确指定依附高度，避免多层平台时自动选错层。

`depth_mask.gdshader` 还会在角色周围形成一个30×48px椭圆避让区，中心alpha最低为0.15、边缘恢复为1。只有这一区域减弱，其他近景保持原有深色和实度。窗口跟随实际角色位置，M键可核对开关差别。`generated/masks/` 是由平台几何生成的裁切数据，环境像素美术仍来自独立PNG。

## 灯光与运动

世界层使用 `CanvasModulate` 环境底色、径向纹理的 `PointLight2D` 和地形 `LightOccluder2D`。灯位、范围、颜色、能量、微动由本区配置读取；大范围天空光不画亮核，灯具亮核与素材发光位置对齐。地形遮挡略收进表面，保留可走边受光，同时阻止厚地形内部透光。

人物弱补光只作用于角色自己的light mask。构件脚底有短接触阴影。L关闭光照时，环境调制、点光、光束、发光核和接触影关闭，保留素材已画出的明暗和景深层颜色。灯光能量可以大于1；网页渲染也在最终像素写回前保留浮点光照系数。

粒子以小亮核和短尾表达风尘、孢子、火星。显示坐标取整，遮蔽地形内和角色附近的粒子，固定种子便于复现。不同区域从共享数据读取运动方向、速度、颜色与数量。

相关原生接口：[Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html)、[CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html)、[Godot 2D灯光与阴影](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)、[PointLight2D](https://docs.godotengine.org/en/stable/classes/class_pointlight2d.html)。

## 编辑与重建

所有独立图层、Sprite、点光、遮挡多边形都可在编辑器中查看。数据位于 `assets/study.json`，像素素材清单位于 `assets/pixel/manifest.json`。地形占用格是地图源数据；编辑它以后重建，TileMap、碰撞、遮挡、粒子遮蔽与近景基座遮罩会一起更新。

```json
{
  "terrainGrid": {"tile": 32, "origin": [0, 0], "cells": [[0, 9], [1, 9], [1, 10]]},
  "layers": [{
    "id": "near-left", "kind": "near", "asset": "windchime_plains_near_v2",
    "x": 165, "y": 320, "parallax": 1.08,
    "mask": {"type": "platform_band", "above": 72, "below": 72, "edgeFade": 8,
      "heroReveal": {"radiusX": 30, "radiusY": 48, "minAlpha": 0.15}}
  }]
}
```

`terrainGrid.origin` 是世界像素坐标，`cells` 是相对于origin的格索引；`region.terrainGrid` 可覆盖公共 `data.terrainGrid`。示例中的 `layers` 位于区域配置内。独立平台附着物仍放在世界实例的 `attached` 组，移动倍率为1。

```bash
python3 build_scene.py
```

生成器在完整包中优先读取上一级共享数据和素材；独立取出Godot目录时读取自身 `assets/`。重建覆盖 `study.tscn`；手工修改请另存场景，或写回共享配置。

## 检查与限制

`build-info.json` 记录这次生成的数据和素材指纹；`lighting-checks.json` 记录区域切换、原生灯光与遮挡、47格位置与映射、碰撞区域切换、景深开关、逐像素视差、角色避让参数和暂停行为的检查；`terrain-placements.json`、`depth-placements.json`、`particle-samples.json` 可与网页的装配记录对照。

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script verify_lighting.gd
```

本环境的Godot检查使用Dummy无窗口驱动，不能据此声称原生渲染观感已经验收。交付预览来自真实素材的Canvas拼装；两种运行端的灯光混色与阴影实现不完全相同。本样例未制作法线贴图、全局光照或正式地图的完整玩法回归。

在有图形显示的电脑上保存引擎视口图：

```bash
godot --path . -- --region=world_clockheart --capture=/absolute/path/clockheart-godot.png
```

加 `--unlit` 可保存素材原色对照。无窗口驱动上的截图请求会明确报错退出，避免把空图当成实机预览。交付时可排除 `.godot/`、`__pycache__/` 和 `*.import` 缓存。
