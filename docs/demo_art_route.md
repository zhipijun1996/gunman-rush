# Demo 美术路线与随机地图接口

2026-10-09 用户确认平原样片方向，授权 subagent 并行制作整个 demo 美术，并要求后续与另一个 Codex 的开发分支同步。当前美术分支 `feature/demo-plains-art`，基于 main `64ec8bbb07a2c4d44e6709e1182dbf0e2dddf226`。main 仍为文档基线；读取过 `feature/enemy01-patrol` 的玩家、机关、触控与敌人接口，未改动其实现。

## 范围与完成口径

首个区域为平原：开阔天空、草坡、远山、风车、少量石材与机械遗迹。交付角色六类程序动画、平原地形连接件和装饰、四层背景、机关与资源装置、触控 HUD、面板与特效，以及巡逻无人机和训练靶。89 件运行 SVG 与 2 件手绘 PNG 为可导入 demo 候选，不代表已经接入另一个分支或通过手机验收。两张 AI 绘画母版、手绘平台/锯轮候选及提示词保留；运行矢量素材较母版简化，最终合屏观感需用户验收。音频、后续区域和完整 Boss 不属于本次视觉 demo 包。

城堡、火山、冰川、森林、墓地后续各制作区域套件；共用角色比例、笔触、功能颜色、图标与 UI。新区域不能只改变危险颜色；cyan 菱形表示射击补充，amber 双箭头表示跳跃补充，危险以锐利轮廓和运动共同提示。跳跃补充素材已经预留，不表示当前开发分支已实现对应能力。

## 资源入口

- 统一清单：[assets/manifest.json](../assets/manifest.json)，包括稳定 ID、路径、尺寸、内容 SHA256、包清单与待验收状态。
- 可直接本地打开：[preview/index.html](../preview/index.html)，实际 SVG 拼装、种子、六动作、落点保护区与全资源目录。
- 角色：[character_art.md](character_art.md)。平原：[terrain_art.md](terrain_art.md)。背景：[background_art.md](background_art.md)。对象与 HUD：[objects_art.md](objects_art.md)。敌人：[enemy_art.md](enemy_art.md)。

## 固定与随机地图

制作单位是美术部件；随机抽取单位是经过玩法验证的房间模块。先从固定挑战提取 5–8 个模块，再做路线难度起伏和分支。当前预览仅演示视觉组合，没有动作轨迹、资源约束和机关时间窗验证，不能据此宣称地图可通关。

房间定义需要 `id/version/size/ports/required_abilities/entry_resources/difficulty/checkpoints/hazard_phase`；美术定义附 `biome/skin_version/connection_slots/decoration_zones/exclusion_zones/background_profile`。入口出口除位置外，还需接受速度、最低跳跃/射击资源和安全落点窗口。平台图片不能决定碰撞；机关图片不能决定伤害时刻。

平原逻辑网格建议 64，贴图格 128，渲染比例 0.5。站立面在贴图 y=16，即逻辑 y=8，实例化时按 anchor 对齐游戏平台表面。横向地形使用 left/middle/right 连接件；填充块横纵循环。接缝由实际栅格检查确认。任意长度平台由开发方按已确定碰撞尺寸切分/裁剪，不拉伸整个端头。

装饰随机与玩法随机使用独立随机流；装饰不改变模块顺序、资源、机关相位和碰撞。落点边缘、补充目标、锯轮路径禁止前景遮挡。锯轮图半径 60 px；缩放使用 gameplay_radius/60，绝不将碰撞半径改成图片大小。背景允许 X 循环，禁 Y 循环；参数见各包清单。

RunManifest 记录 seed、generator_version、content_manifest_hash、physics_config_hash、模块顺序、能力配置与机关相位；相同 seed 在内容版本变化后不保证相同关卡。

## 开发分支接入

角色 scene 是无碰撞 cosmetic Node2D。现有玩家碰撞 24×36，脚底 y=18；将 CourierVisual 挂在 `(0,18)` 并缩放 `36/104`。通过 `set_state/set_facing/set_aim_direction` 更新表现。`died` 驱动死亡；`ShootAbility.shot_fired` 驱动反冲；运动状态由 Motor 提供。旧灰盒 Silhouette 和 `_draw` 的替换由开发分支处理，避免在未确定目标分支时覆盖代码。

HUD 只换视觉，保留 TouchOverlay 的输入、多指捕获、安全区与取消逻辑。文本由 Label 绘制；卡片与面板不把文字烘焙进图片。敌人资产不改变 AI、生命与碰撞。对象 inactive/active/open/closed 对应已有对象运行状态；未实现的功能维持预留。

## 当前开发分支接入

2026-10-10用户授权评估并接入此美术风格作为第一个平原大关基础。最新来源为 `feature/demo-plains-art` 的949d884，开发集成分支 `feature/plains-art-integration` 基于 `feature/seamless-mixed-modules` 317619c；最新main仍64ec8bbb，未把旧美术分支代码覆盖到最新开发。

选择性导入assets、原创来源和构建检查工具，保留现有玩法/任务/交接文档并人工同步。共享PlainsTerrainSkin负责任意大小模块和固定房间，PlainsBackground为整个区域提供连续横向视差；高攀升不垂直重复背景。PlayerVisualAdapter只订阅/观察，保持24×36碰撞和真实射击入口。未来模块默认沿用草顶/冷灰岩/旧黄铜/危险红橙的功能语言，不把装饰当跳台。正式10/Boss10和开发3关规则不变，本轮并未完成正式10关随机集成。

纯表现不参与地图/奖励/机关随机流，不改变Manifest v4玩法布局。原painted PNG仍候选，不擅自拉伸或视作无缝tile。运行SVG是简化矢量demo表现，不将其宣称为手绘母版同等质量；真实整关与手机反馈后继续精修。

## 验证与后续

运行 `python3 tools/build_art_catalog.py`、`python3 tools/check_art.py`、`python3 tools/check_terrain_art.py`、`python3 tools/build_art_preview.py`、`python3 tools/check_docs.py`。生成器重建后必须更新统一清单和预览。

原美术分支使用Godot4.6.3的历史验证不能代替本次。当前集成使用实际Godot4.7.2，运行与画面结果另记handoff；Android/iPhone手机画面和性能仍未验证。浏览器预览交互测试尝试被本环境 Chromium sandbox socket 权限阻塞；静态 JS、资源路径及合成画面另行检查。所有素材状态保持 `demo_candidate_awaiting_device`。


后续平原模块的主题编排、现有挑战映射与未实现装饰见[平原模块设计](plains_module_design.md)。不同大小/多端口模块使用同套皮肤，真正路线难度仍由玩法与轨迹验证决定。


## 地区与故事的上位锚点

平原及后续区域统一按[世界与故事](world_and_story.md)与[设计目录](world_regions.json)制作；新名称仍工作名，目录不可当运行开放状态。已有SVG套件保留作为首区demo基础，角色身份不因造型候选定稿。完整原始交接可追溯，风格、剧情和区域配色优先以上位锚点为准，物理锚点仍遵循各art契约。

## 2026-10-10 用户品质反馈覆盖

当前包已技术接入开发分支，但用户对精美度不满意。简化SVG保持占位与低成本回退，不作为最终视觉定稿。正式生产与用户视觉门槛见[art_quality_target.md](art_quality_target.md)，世界与16个候选地区的场景介绍见[world_and_story.md](world_and_story.md)。已有91候选及历史验证保留，新精修样板未交付；先用同一段平原关卡比较材质/光照/角色合屏，用户认可后扩产。不得沿“全部候选已上传”推断正式美术已完成。

本轮十项反馈的生成候选与运行接入见 [plains_visual_refresh.md](plains_visual_refresh.md)：自然四层平原、金币/音符、藤叶门、荆棘与橡实甲虫。PNG 的实际生成来源见 `assets/plains_refresh/manifest.json`；视觉/真机验收仍与功能验证分开。
