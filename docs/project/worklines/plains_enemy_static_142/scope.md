# 平原怪物静态审批

## 已明确的用户取舍

用户澄清B/C这批造型其实都挺好，主要问题是颜色与背景容易混淆。此前把问题理解为造型失败而制作D和全新兽类的一批，是错误方向；这些候选停止使用。当前保留B/C的形体、细节、像素画法与阶段身份，只校准真实关卡的颜色／明暗分离。造型认可不等于显示材质、正式合屏、动画或全套静态最终审批。

基线仍为PR142 `cc62d369d3cec2597db483f1137ff976e25863cf`，分支 `art/plains-enemy-static-pr142`。范围七类普通怪、鸣铃巡游机、牧风者一／二阶段，共十张静态图；二阶段风车保持从头顶生长。整套静态审批前不制作动画或替换生产绘制器。

## 当前输入与实现

- 从Git `a5668a4`逐字节恢复C的 `art/reviews/plains_enemies_pr142/`，包含原源图／提示词、cutouts、static、清单和拼版。没有重新生成、重采样或重画当前PNG。原始B可从 `b4d4488`追溯；当前显示试验固定使用C，使变量仅为材质。
- `tools/art/build_plains_enemy_static_142.py`恢复为原确定性烘焙工具，按原裁切框与native尺寸复现；本轮素材恢复直接来自Git字节，不经过重新烘焙。
- PR142室外天空使用unshaded材质，世界实体接受CanvasModulate与DirectionalLight2D；室内接受环境光与局部灯。该差异可能压低实体暗部，不能只凭离线拼版判断同屏辨识度，也不能据此认定所有问题都来自照明。
- `tools/art/plains_enemy_separation.gdshader`是隔离预览材质：温和收敛饱和度、根据背后已渲染画面保护暗背景前的中间亮度及局部上缘，亮背景前加深1素材像素内侧轮廓。保留标准场景照明，不使用unshaded或发光外圈；不改alpha、UV、尺寸、形体或背景。Shader参数就是本次候选数值来源。
- 这是显示层候选，不代表画师精修PNG，未接入正式怪物资源。屏幕取样、轮廓与光照交互在移动、特效遮挡及目标设备上的表现仍未验证。

## 实际对照

捕获工具 `tools/art/capture_plains_enemy_context.gd`使用真实FixedWorldApp，在P-R03、P-R06、P-R10、P-R11与P-R14中冻结原怪与AI，放置C静态图；两侧使用同一PNG、原生尺寸、脚底位置、原主角、正式1.6倍相机、TileSet、背景／前景、HUD和场景光照。每个场景分别输出 `original` 与 `separated`，共六组十二张1280×720截图。静态位置为夹具，不是实际战斗布怪。

制作方观察：暗室中披布、木根的中间亮度与局部受光上缘更清楚；亮天空前主要变化在原轮廓内侧，主体颜色变化较小。主体细节和风格继续沿C原图，没有增加外部光圈。该观察不代签用户对辨识度与风格的判断。

Boss场地原相机仍把地面压在视口底部；大风车、HUD和反冲空间必须在后续实际动作中验证。本次不改相机、地形、碰撞或战斗配置。

## 交付与复现

`build/plains_enemies_pr142/separation/context/`包含六组原截图、独立离线 `review.html`、四场景概览及证据哈希；`level-static-review.zip`包含截图与预览页。页面支持原版／调整版滑杆、纯单侧、六场景切换、1:1及当前截图下载。

图形环境执行 `bash tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --script tools/art/capture_plains_enemy_context.gd`；再执行 `python tools/art/package_plains_enemy_context.py`。原始素材来源和裁切参数仍归恢复的 `manifest.json`。

## 清理与边界

- 删除已否决的全新兽类目录 `art/reviews/plains_enemies_pr142_restart/`及其烘焙工具；D仍只留在Git。恢复的B/C是用户最新澄清指定保留的造型来源，取代先前“排除A—D”的取舍。
- `art/reviews/.gdignore`继续隔离候选。PR142有消费者的旧运行帧在静态审批期间保留，通过后随新完整动画接入再删除。错误基线PR143保持关闭作废状态。
- 本轮没有图像生成、动画制作、生产接入、合并或部署。

## 实际检查

已核验恢复的27个C文件与 `a5668a4` 逐字节一致，六组原图／调整版的相机、位置、尺寸与包围盒一致，全部轮廓位于视口内。两侧为先后渲染帧，排除标题和怪物包围盒后仍有9—158个像素差异；背景资源／配置未修改，不声称同帧背景逐像素一致。详情归 `source-integrity.json`。

CI四项通过（35.48秒，`build/plains_enemies_pr142/separation/ci.log`），文档及diff检查通过。浏览器本地HTTP检查六组图片加载、原图／调整按钮、滑杆、下载目标与390px布局，无页面脚本错误；file直开与动态材质表现未作为已通过项。

## 下一动作

用户只需审看相同造型下的可辨识度与颜色关系。根据反馈调整显示或必要的局部配色，保持已认可的造型；完整静态合屏获准后再制作动画、接入与验证，不再启动整批造型重生成。
