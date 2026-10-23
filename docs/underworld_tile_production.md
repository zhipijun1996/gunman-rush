# Underworld 风铃平原：Tile 与场景生产流程

## 2026-10-22 粒度更新

用户已明确选择细粒度，当前共享标准为[style-v5](creative_direction/bibles/style-continuity-20261022-v5.json)：原生32px/32wu、世界表现1wu采样；保留47邻接与精确边界合同。以下旧16px数值只作历史/旧消费者说明，不能当作新生产目标。正式接入与限制见[FINE-SPACE-05](evidence/fine_space_05/README.md)。

任务 `UNDERWORLD-PLAINS-01`。用户选择 Underworld，并要求三个独立景深、完整平原迁移，以及与平台材质融合的伤害 Tile。本文件是当前生产方法；本轮实际消费者、验证和未验范围以 production manifest、运行回执和任务质量记录为准。

## 参考开放素材：提取规则，不只抽颜色

1. 保存作者发布页、许可原文、原始压缩包/PNG、来源 URL 与 SHA256。Underworld 发布页为 `https://asouris.itch.io/underworld-tileset`，作者的 “Feel free to use it however you want” 是自定义使用许可；不改称 CC0。其他参考包分别查许可，不把一个包的许可传给另一个包。
2. 先以原生像素和实际游戏比例查看：Underworld 原生 16px Tile；记录 source tile px、world tile wu、导入 nearest、透明边与参考角色尺度，不能将 16px 误记成新地基的 64px。每区沿用一致的像素尺度和轮廓语法；配色、材料、生态与地标各自生产。
3. 提取亮边宽度、暗实体占比、色阶、凹角阴影、断面、植物剪影和留白。先盘点 top/bottom/left/right、四凸角、四凹角、fill、薄台、单格孤块、内洞。原图缺哪类就记录缺口，不能复制一种填充凑满索引后称完整美术。
4. 保存实际裁切配方与 mask→atlas 映射。项目风格实验使用 `N=1,NE=2,E=4,SE=8,S=16,SW=32,W=64,NW=128`；另一个旧工具有不同 bit 顺序，不能互换整数而不转换。对角邻居只有两相邻正交邻居都存在才保留，256 种输入规范化为 47 个状态。
5. 程序复建必须能从原图逐块 crop/合法镜像/paste 得到同一 atlas 字节或像素；记录每片源矩形与目标矩形。生成或重绘的新材料家族另起来源，不伪称作者原图。

## 生成 Tile：先材料母版，再边界矩阵

先声明用途、世界/像素尺度、材质家族、亮边/光源、色域、允许透明边、连接带、凹角、seed 与预算。向 imagegen 提交材料母版或完整物件请求，附已准入 Underworld 同族参考，要求无文字、无展示边框、无无关 UI、适合真实边界的连续材料。新材料可以有本区色系；统一的是画法、像素尺度、光向与接口，而不是十六区全蓝或全紫。

必须保留：真实提示词、参考 PNG/SHA、实际工具回包、原始 PNG/SHA、时间/调用计数、已暴露的模型信息与未知项。不能把计划请求当已生成，也不能写猜测的模型/费用。原图失败保留，不覆盖或改规格救图。

图生擅长材质与造型，不保证严格 Tile 网格。收到原图后先实测 alpha、完整主体、根颈、跨格污染与边缘。程序可以无损裁切、重新组织 atlas、明确声明的镜像和采样适配；不能程序绘出全套美术再标成 AI 原画。切片必须保留完整根/端头，不能等分裁断物体。

以单族代表块和组合黄金实景开始，检查长短平台、厚薄、内外角、孔洞、竖壁、相邻间隙、堆叠、单格、拼接顺序与不同模块分块。连接带先冻结；变化尽量在内部，顶面/端头有共同接口。技术覆盖不代签用户审美。

16区的候选色域/材料/生态见[地域视觉分工](region_visual_identity.md)，不是统一蓝紫色。当前复用有许可的 Underworld 原生 Tile 是合法生产路径，不强制对已合适的材质重抽图。森林树皮、工城金属等真实新材料需要独立母版和上述流程；不能只改岩石颜色称完成。

## 用 Tile 做关卡：先占用与语义，再选择画片

模块设计先交出 `tile_family_ids`、尺度、实体占用、one-way、moving、端口 halo、危险表面区间、装饰 keepout 和例外。玩法的合法动作、资源与能力不为图片修改。先验证材料能表达真实平台，再扩模块池。

网格地图先合并世界占用及至少一格 halo，最后统一求 47-mask；模块边不能分别封死，否则相邻模块形成假外墙。solid/one-way/moving 不混邻接，移动平台在自身参考系拼接。危险材质状态与占用状态正交，不因为有刺就破坏邻接。

正式平原已有非整格矩形碰撞，不能把坐标吸到 32wu 格点来方便拼图。本轮可使用 `blob47_core_with_exact_boundary_adapter`：完全落在实体内部的格子用真实 TileMapLayer；外露非整格边用同源材料按精确并集边界采样。须明确报告“47 内核 + 精确边界适配”，不冒称整张正式地图是完整 47 TileMap 或 dual-grid。绘制切片可拆分，但碰撞和实体并集不变。

验证既包含 atlas 和接缝，也包含真实 Motor 的主支路、出返程、one-way、移动相位、危险边界和资源因果。图连通、静态镜头与摄像机巡览不等于通关。

## 背景：三张独立图、三种相机速度

天空底色不计入三张图。三层为不同图像内容：远层围合/天际、次远层地形/建筑轮廓、近环境层枝叶/岩体框景。中近层有透明空域，远层可自带天空且更低对比/更淡/更大尺度，近层轮廓更清晰；玩法层保持最清楚的安全、危险与角色边界。不要同一全景套三次透明度，也不要把三件小道具叫三个景深背景。

当前远层横向以同源边缘交替镜像重复，中近层采用同方向重叠与透明边缘渐隐，避免风架成对镜像；源图保留不改，不声称图生已产生无缝母版；纵向位移有明确的屏幕高度比例限幅，远层另外保持不透明覆盖。以下公式适用于未到限幅的区间；极限位置验证实际覆盖而非继续外推斜率。

令相机实际屏幕中心为 `C`，冻结锚点为 `C0`，相机位移 `ΔC=C−C0`。每层的横纵向可各自设置系数。当前背景在CanvasLayer中绘制，若某轴 camera factor 为 `f`，屏幕上图案移动 `−f·ΔC`，这里f的单位为屏幕像素/相机世界单位。若换成世界坐标层且该轴相机zoom为z，对应世界锚点为 `P=P0+(1−f/z)·ΔC`；`f=0` 固定在屏幕，`f=z` 才与世界实体在屏幕上同速。不能在非1倍zoom时把f直接当作归一化的世界速率。本轮三组具体系数从运行 manifest 读取，横纵轴分别按远→近递增；不要在工具、文档、脚本另造三套默认值。

使用实际 `Camera2D.get_screen_center_position()`，包括镜头 smoothing、限位及偏移后的中心。背景的运动与角色移动、风摆不同；纯风动画不算相机视差。回执保存两个以上不同相机中心及每层原点，核对斜率；实际 GPU 动态序列看出层次才可声称视觉景深成立。

覆盖验证：水平长距离、纵向井庭、回程、左右/上下限位、宽屏与竖屏。请求窗口尺寸不等于实际viewport，回执必须记录actual viewport并断言PNG像素尺寸；本轮720×1280通过真实SubViewport取图验证。需要重复时使用实际可平铺图/边缘与确定的重复周期；透明部分露出天空是设计，但图片矩形边缘、黑条或重复硬接缝是失败。前景不能遮唯一落点、敌预告、玩家或 UI；必要时减密、移锚或改素材，不简单加雾掩盖。

## 装饰：有根、有空域、可撤销

每件物件记录源 region、像素尺寸、世界比例、root/吊点、支撑类型、z 层及允许变体。草花、石簇、风铃、枯枝、钟杆各有用途，不能把小石簇放大成山壁或把花放成巨树。

从实际静态实体并集外露面选地面根基；根扇应有足够支撑，非仅 anchor 点刚好落在实体内。悬挂物绑定上侧支撑和正确吊点，不能把脚底锚点当顶端。one-way、破桥、moving 若允许专门挂件，要绑定该支撑生命周期和参考系；支撑删除/破碎后移除挂件。

装饰使用独立 seed / coordinate hash，不消费地形、遭遇、奖励的 RNG。先构图槽位，再抽有限变体；保留观察区、安全落点、危险轮廓、敌预告、射击通道、UI 与移动扫掠 keepout。密疏和局部灯光有预算，不靠随机塞满产生丰富度。灯光与微粒只辅助画面，不能盖住边界失败。

机器检查有根/keepout/独立 seed 声明及运行回执；真实遮挡看 GPU，AABB 候选不直接等于像素遮挡。验证移动/删除支撑和故意错误根锚能被拒绝。

正式平原保留风车高地、溪谷井庭、断钟庭与修理营地四种空间身份。近处的风架、钟拱、修理棚按真实静态平台与根扇放置。基线黄金镜头的溪谷没有满足净空的地面井架槽位，不能放松支撑检查：井架改为独立的远处局部构图，完整石基来自原图，低对比冷灰、位于玩法层后方，不带 standing_edge、不声称物理支撑，也不提供碰撞。`UnderworldLocalComposition`读取同一scenery manifest，拒绝前景、亮绿可踩边、功能keepout相交与实体遮挡超预算；这与grounded装饰是两种明确语义。实际地标截图、原bottom-center射线和缺支撑/冒充地标等反例一起记录。其他种子有合法槽位时仍可放近处实体支撑井架，远井与近井可以并存；不得把基线无槽位外推到全区。E的20实际地图有77个grounded物件/77条真实StaticBody射线、17个合法近井与20个非物理远井。稀缺槽位先尝试有限的合理完整尺寸（修理棚120/96/80/64/56wu），保持全根与whole keepout；用同一真实20地图回归，不能仅固定黄金seed通过。

## 融合平台的伤害 Tile

用户要求伤害材质成为平台表面的一部分。平台实体连续，荆棘根须从相同暗色土石/根皮的表层长出，危险起止有自然过渡；顶刺、侧刺、顶底转折和安全端头按暴露面方向拼，不在平台外再加一块悬浮刺台或新的实体底座。真实尖端必须与伤害范围一致，不能用装饰叶片伪装可踩面。

视觉与语义分离：同一个平台 Tile 家族有 safe/thorn 材质状态；伤害仍由原 hazard/Area、原碰撞接触和原 damage 服务处理，带明确 metadata/custom data 与消费路径。保持既有伤害量、无敌窗、生命周期、移动扫掠与基础碰撞，不为了融合把刺隐藏到安全地面或增加伤害宽度。坑内原 hazard 若没有支撑，先复用实际已有边/底的贴合表现，无法合理贴合就记录例外；不能凭空添 solid 救图。

必测：安全→危险与危险→安全接缝、两端/转角、近边界内外接触、背面/下方接触、同帧/无敌窗、支撑/场景销毁、暂停与重进。无伤害控制反例与危险材质漂浮/额外基座反例均保留。视觉融合、真实伤害和正常速度可读性分别报告。

## Skills分工

五份Skills引用本流程并使用同一production manifest：

- [art-director](../.agents/skills/art-director/SKILL.md)：许可、视觉锚点、真实图生、材料母版与Tile接口黄金。
- [scene-composer](../.agents/skills/scene-composer/SKILL.md)：三层独立景深、实际相机运动、区域地标、装饰根基和遮挡。
- [level-module-creator](../.agents/skills/level-module-creator/SKILL.md)：实体/薄台/移动语义、邻接halo、端口、危险表面与净空。
- [region-generator](../.agents/skills/region-generator/SKILL.md)：模块组合、独立装饰seed、同源随机回归与16区材料差异。
- [visual-director](../.agents/skills/visual-director/SKILL.md)：黄金→第二空间→整体合屏、不同作者审查、实际输出与未验范围。

不在每份Skill复制一套不同参数；原物理、伤害、模块准入及G0–G5继续沿用现有权威来源。

## 可执行入口与完成边界

`assets/underworld_plains/production_manifest.json` 引用真实运行读取的 terrain/scenery/hazard 清单；不允许仅为测试准备一份与游戏不同的参数。`tools/underworld_pipeline.py audit` 只读来源与这条实际消费链，报告许可/像素/47边角、三图与三系数、装饰及危险接口；`tests/test_underworld_pipeline.py` 对同一输入逐项制造坏例。注册检查 `underworld-pipeline` 运行正例及反例；`underworld-terrain` / `underworld-formal-terrain` / `underworld-scenery` / `underworld-hazards` 分别执行真实几何、正式两图与 Boss 断地刷新、镜头/装饰、实际伤害消费者。运行检查沿用项目严格 engine wrapper，脚本/着色器错误、超时、原生泄漏或缺完成 marker 都失败。它们追加到既有 art/gameplay/full，不取代原 checks。

```sh
python3 tools/underworld_pipeline.py audit --output build/underworld_plains/pipeline.json
python3 tests/test_underworld_pipeline.py
python3 tools/underworld_pipeline.py runtime --suite scenery
python3 tools/underworld_pipeline.py runtime --suite hazards
python3 tools/run_underworld_terrain_tests.py
python3 tools/run_underworld_formal_terrain_tests.py
python3 tools/harness.py --check underworld-pipeline --check underworld-terrain --check underworld-formal-terrain --check underworld-scenery --check underworld-hazards --check underworld-formal --check underworld-raw-export --release --jobs 1
```

源码许可/复建、CPU 几何、真实运行、GPU 静态、动态读图、用户选择、实体设备各有自己的证据。测试、层数、Hash 或截图数量不能代签商业品质。失败保存原件后修对应工序；缺用户/设备继续保留 review/awaiting-device，不反复请求已授权的技术修改。

`underworld-formal`补充默认玩家/敌人/商人/奖励/拾取与两图重载、暂停等真实消费者；图生身体为状态驱动pose/叠层，不冒称完整手绘动作帧。原始alpha1尾部可污染bbox，本轮以alpha>8定位主体再保留内部RGBA裁切，配方明确记录。背景源SHA只在资源加载时缓存，不能在每帧读取并哈希整幅PNG；本轮实际12.108ms/update性能缺陷及无像素变化修复均保留。

导出须区分两条消费链：Texture2D经ResourceLoader读取导入ctex；FileAccess.get_sha256读取原始PNG。Godot的include_filter列PNG不保证原始字节可读。本轮E包画面/ctex正确而三层原图SHA为空，原失败保留；修复复用既有`addons/runtime_raw_export/raw_exporter.gd`，从三个preset明确登记7个实际源PNG，按原production manifest/SHA绑定后`add_file(...,false)`，保留正常纹理导入。新`underworld-raw-export`验证旧规则和错SHA/缺binding/排除冲突/alias/wildcard/缺raw/篡改字节/空Web三层hash反例，真实包还要逐原始字节及导入纹理闭包核对；不能仅看本地源存在或编辑器通过。


## 六项试玩反馈后的共享表现合同

人物、商人和家园人形NPC共用 `UnderworldActors.HUMANOID_HEIGHT`，比较实际非透明身体高度，不能把带留白画布当身高。玩家以实际Motor法向速度与最后移动方向驱动身体，左右跑动独立可读；武器与枪口继续由原CourierVisual负责。真实生成关键帧、完整原图、失败的等格假设及明确裁切配方保留在 `player_animation/`，不把平移同一姿势称为新动作。

移动平台与门/支撑消费 `mechanisms/mechanisms_build.json` 的同族材料；端头、长边与厚度分别平铺，保留真实碰撞和携带。绘制命令引用的Texture2D必须由绘制消费者持续持有：函数内临时load可能在GPU执行前释放RID，实际造成整块纯白；无脚本错误也不能代替像素检查。所有功能铃复用同一图和accepted事件反馈，不以装饰风铃冒充功能机关。

家园使用同族Tile、三层真实景深和完整房屋物件。先保留真实四项功能ID/锚点，再布置有根房屋、统一身高的NPC与明确预留位置；预留不发假业务请求、不授予资源。远处标签简短、低对比且有显示范围，详情只在近处显示；文字样式只在近远状态变化时更新，不能每帧重建字体布局。

UI使用共享原生Theme/StyleBox、来自已核许可Tile的九宫边框，以及有真实来源的物品图。窗口、按钮、disabled/focus、取消/重开、HUD、地图、触屏与窄屏都走原控制器；换肤不能重写交易、奖励和导航。中文字体必须实际包含所用glyph或显式打包fallback，不能依赖开发机系统字体。表现层不缓存含有业务owner的Callable/Resource循环引用；卸载检查保留严格资源守门。

新增Harness检查 `underworld-player-animation`、`underworld-mechanisms`、`underworld-home`、`underworld-ui` 与原七项共存。它们分别测试真实左右动作与生命周期、弹丸触发/平台携带、家园真实往返/预留语义、实际鼠标/触屏/应用UI路径。各自连续画面、正式场景合屏和网页仍需独立验证，数值通过不等于用户审美认可。

## 战斗与多层空间返工的经验入口

本轮十一项实际缺陷、根因、修复/反例与适用范围见[第三轮战斗与场景经验](underworld_feedback_r3.md)。受伤从实际已提交事件进入表现，环境原点退场和出生点恢复分开；surface危险与旧fall_plane分开而保留真实地形合同。门的实际actuator、宝箱的已领取ledger、弹体最终绘制消费者先盘点，不能只改同名helper。家园锚点按真实二维足点查询，多层必须实际基础单跳到达/返回；新检查计数不能替代旧适用守门逐条迁移。
