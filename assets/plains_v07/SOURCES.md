# 平原新增美术与声音

本任务使用 image_gen 新绘独立素材，参考项目 Underworld 区域风格、原生人物尺度及现有材质方向。新绘内容不是 Asouris 原作，不附加用户已认可声明；既有 Underworld 素材归属不变。

| 母版 | 独立内容与动作 |
| --- | --- |
| inhabitants-generated.png | 回收匠、织时匠、阿栖各四帧待机与两帧回应；充电站三帧待机与三帧充电 |
| aqi-story-generated.png | 同一阿栖身份的查看怀表、喝茶、修灯、远望四组，各四帧生活动作与两帧回应 |
| collectibles-generated.png | 时间齿轮转动、血量片/共鸣片脉动、领取散光各六帧 |
| mechanisms-generated.png | 钩索装置、装备行囊、校时台、返程滑轮各六帧 |
| interiors-generated.png | 风车、谷仓、地窖、井壁四片独立可平铺背墙 |
| props-generated.png | 直桶、倒桶、储物箱、回收柜台、挂铃、旅途包 |
| architecture-generated.png | 倒时车厢、候车棚、风车架、断桥墩、旧摊架、井台 |
| clocktower-generated.png | 世界钟塔独立剪影，分别烘焙远望与前庭原生尺寸 |
| story-traces-generated.png | 布条桩、路线便笺板、修好的灯凳，显现只读取交谈收据与宿主房号 |

`python3 tools/art/bake_plains_v07.py` 只执行固定格裁切、alpha≥128 清边、最近邻采样与固定脚底对齐。源图、每次裁切、原生高度、缩放和输出哈希见 [manifest.json](manifest.json)。场景按一素材像素/一世界单位放置；UI肖像沿统一逻辑画布比例展示。源图由 `.gdignore` 隔离，导出只使用原生资产与运行清单。

正式房间的远景读取 `art/world-art-v2/assets/pixel/manifest.json` 中 `windchime_plains_v2`，不再从旧家园通用背景加载。远景按整数倍覆盖实际窗口并使用独立低速视差；实体仍保持1素材像素/1世界单位。室外环境底光参考技能中的认可光照配置，实际Godot方向光须以窗口光照对照审查；接入不代表最终视觉通过。植被由房间明确放置，不按碰撞矩形自动盖章。

场景材质与地形碰撞分开：建筑仅作构图；实际落脚面、遮弹掩体、铜铃吊台、折板与水面危险由对应组件拥有。动效只响应已接受的动作/持久化结果，不发放奖励。

`audio/water_splash.ogg` 复用项目已收录的 `assets/audio/director_v3/_sources/water/splash_09.ogg`，原来源为 [40 CC0 Water/Splash/Slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx)。原作者和授权证据保留在 [v3 声音来源](../../config/audio_director/v3/sources.json)。落水声在实际扣血结果接受后，由现有 GameAudio 声部池播放；不新建独立声音服务。
