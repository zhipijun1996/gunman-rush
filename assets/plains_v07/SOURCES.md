# 平原新增美术与声音

本任务使用 image_gen 新绘独立素材，参考项目 Underworld 区域风格、原生人物尺度及现有材质方向。新绘内容不是 Asouris 原作，不附加用户已认可声明；既有 Underworld 素材归属不变。

| 母版 | 独立内容与动作 |
| --- | --- |
| collectibles-generated.png | 时间齿轮转动、血量片/共鸣片脉动、领取散光各六帧 |
| mechanisms-generated.png | 钩索装置、装备行囊、校时台、返程滑轮各六帧 |
| interiors-generated.png | 风车、谷仓、地窖、井壁四片独立可平铺背墙 |
| props-generated.png | 直桶、倒桶、储物箱、回收柜台、挂铃、旅途包 |
| mill-drive-generated.png | 独立裸齿轮与室内木架传动轴；原图、alpha裁切、等比烘焙及生成记录见source/mill-drive-generation.json |
| orchard-arches-generated.png | 两座独立挂铃果树拱架，树根接地、枝面匹配真实碰撞；生成记录见source/orchard-arches-generation.json |
| architecture-generated.png | 倒时车厢、候车棚、风车架、旧摊架、井台；未使用的旧拱形桥墩只保留母版来源 |
| thresholds-generated.png | 无拱直柱、木梁遮檐入口、低井口；固定裁切与等比原生烘焙见清单，生成提示摘要见source/thresholds-generation.json |
| clocktower-generated.png | 世界钟塔构件原母版；P32远景不再使用独立剪影 |
| clockheart-landscape.png | P32完整远景：同族高塔与山脊、谷雾一体绘制，塔基被环境遮住；640×360最近邻烘焙，提示词与源图一同保留 |
| room-orchard-generated.png / room-mill-generated.png | 现用果园断栅、木架、托梁和木台的母版；[裁切与锚点](source/room-pair-provenance.json)，原生尺寸归manifest。无消费者的大树、草根岩肩、独立亮窗、幕布墙和大装饰轮不进入现行素材清单 |
| mill-hall-generated.png / mill-window-bay-generated.png | P26整屏氛围实验：多层风车远结构与完整窗间墙；[提示词、参考、裁切、等比烘焙与哈希](source/mill-atmosphere-provenance.json)。远景轻微视差，墙身与窗光固定世界坐标，主角与玩法沿用正式入口；主厅氛围改善获用户反馈，隐藏小室使用下列专用背墙 |
| orchard-sky-generated.png / orchard-ridge-generated.png / orchard-structure-generated.png / mill-recess-generated.png | P25远山底板、自带地面的疏果林与整体门廊，P26单幅封闭小室背墙；[提示词、裁切、锚点和哈希](source/orchard-atmosphere-provenance.json)。中央高台侧柱与托臂由现用木材机械裁切复用，母版中的大树不生成运行素材；室外整体改善已获反馈，P25木桥按可见梁底修正接缝、入口木台按岩壁收口 |
| opening-sky-generated.png / opening-ridge-generated.png / opening-gallery-generated.png / station-houses-generated.png | 首段六房连续构图：低对比草原远山、自带地面的旧路遗迹与望站坡通风后廊；[提示词、裁切、锚点和哈希](source/opening-atmosphere-provenance.json)。小站以略显破败的旧住宅、连续主街与已有服务居民组织生活感；挑战平台与铃闸复用原生梁柱；P24隐藏室由现用封闭背墙按净空机械裁切。 |
| animal-residents-generated.png / aqi-animal-story-generated.png | 獾回收匠、长耳兔织时匠、狐狸旅人、野猪武器匠、猫头鹰守钟匠；每个状态四帧待机和两帧招呼，统一脚底、每状态固定比例；[最终来源与烘焙](source/inhabitants-sky-provenance.json)。人类NPC母版与旧生产路径已移除。 |
| opening_plains-layer-generated.png / orchard-layer-generated.png / clockheart_vista-layer-generated.png / plains-layer-generated.png / wind_clouds-layer-generated.png | 四类固定地表／塔景具有透明天空，独立双层流云在地表后方移动；源图、裁切与输出哈希同上，不扭动山体或塔。 |
| clockheart_hall-generated.png / clocktower_base-generated.png | Z01低对比后殿与真实左上窗、P33覆盖入口整座基台的后墙；[生成说明、源图、裁切与哈希](source/clockheart-route-provenance.json)。门洞取同一后殿的暗区，不重复亮窗；`python3 tools/art/bake_clockheart_route.py --verify`重建比对三份原生输出。 |
| windcourt-arena-generated.png / windcourt-gallery-generated.png | P14开敞残拱战场与连续后层古廊，原野和独立云层透过建筑空隙；[导图、提示词、注册位置和烘焙哈希](source/windcourt-composition-provenance.json)。残拱柱身按当前战场重绘至地面；实际平台、钩索和回程空间归P14场景与construction，生成导图只记录素材注册依据。木踏板复用现行同族表现。 |
| story-traces-generated.png | 布条桩、路线便笺板、修好的灯凳，显现只读取交谈收据与宿主房号 |

`python3 tools/art/bake_plains_v07.py` 按最终动物与天空来源清单执行固定格裁切、alpha≥128 清边、最近邻采样与固定脚底对齐；`--verify`逐像素核对现用输出。源图、每次裁切、原生高度、缩放和输出哈希见 [manifest.json](manifest.json)。场景按一素材像素/一世界单位放置；UI肖像沿统一逻辑画布比例展示。源图由 `.gdignore` 隔离，导出只使用原生资产与运行清单。

P32按`clockheart_vista`读取钟心远景，P25按`orchard`读取果园；普通室外由本房`art_placements.landscape`选择底板，首段与既有钟心路线多使用`opening_plains`，P06／P14／P27已按整房构图使用`junction_meadow`低原野与独立疏云，不改变玩法或室内外材质配置。未指定专用底板的正式房间读取本清单的`plains`透明天际线，不再从旧家园通用背景加载。远景按整数倍覆盖实际窗口并使用独立低速视差；实体仍保持1素材像素/1世界单位。室外环境底光参考技能中的认可光照配置，实际Godot方向光须以窗口光照对照审查；接入不代表最终视觉通过。室外保留已接入的地形避让前景和明确放置植被；室内由同一个房间材质判定排除天空、自动草丛、风车外立面和室外井台，使用背墙、传动架、阀门与水管。

场景材质与地形碰撞分开：直柱按真实梁底与地面拼接柱帽、等宽柱身和柱脚，不缩放宽度；室外入口仅在实际室内连接处放置门廊或井口，室内出口投来向外光。返程封墙继承宿主室内材质。普通建筑仅作构图；果园树拱由房间明确指定对应平台图像，按清单surface_height对齐枝面，树干在可穿行背景层；实际落脚面、遮弹掩体、铜铃吊台、折板与水面危险由对应组件拥有。动效只响应已接受的动作/持久化结果，不发放奖励。

十个封闭室内与田垄、岔路、旧路肩的明确桥体表面复用素材包`gear_city`原生32px地形，机械重排至现有47邻接和精确边界采样布局，不重画或缩放像素，不改变碰撞。`mill_masonry_atlas47/source`的源路径与哈希归清单；其余室外自然地形保持原草沿家族。返程金属翻板使用既有吊台材质，动画消费已提交的机关状态。风中亮点使用房号种子生成不规则聚散、独立生命周期与速度，只保留微小亮核，不画蝌蚪状尾线；与游戏随机流隔离。地刺与墙刺复用原生危险图块按朝向连续铺设，可见危险面与共享环境伤害矩形一致。

裸齿轮按72px原生尺寸旋转，碰撞使用同中心34wu圆形扫掠，轨道显示完整运动范围；换向小火星与金属轻响只表现机械运动，实际接触沿统一环境伤害与恢复策略处理。换向声复用Kenney CC0的impactMetal_light_000（项目armour.ogg），由GameAudio现有声部池播放。

`audio/water_splash.ogg` 复用项目已收录的 `assets/audio/director_v3/_sources/water/splash_09.ogg`，原来源为 [40 CC0 Water/Splash/Slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)。原作者和授权证据保留在 [v3 声音来源](../../config/audio_director/v3/sources.json)。落水声在实际扣血结果接受后，由现有 GameAudio 声部池播放；不新建独立声音服务。

井塔构件与连续井壁由 `well_tower-generated.png` / `well_curved_wall-generated.png` 机械裁切为五份原生素材，见[源图、裁切与哈希](source/well-tower-provenance.json)。背景仅取安静中心砌体；圆弧受光按真实井道与灯源计算，不重复圆柱插画。复核：`python3 tools/art/bake_clockheart_route.py --verify --provenance assets/plains_v07/source/well-tower-provenance.json`。
