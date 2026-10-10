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

## 分支同步

用户尚未指定另一个 Codex 的目标分支。已提供 [sync_art_branch.py](../tools/sync_art_branch.py)：指定分支后 fetch 并记录远程 SHA、变更文件和需要复查的接口；不会覆盖或自动合并。命令示例：`python3 tools/sync_art_branch.py --branch feature/enemy01-patrol --watch 20 --interval 30`。每次检查间隔 30 秒，20 次后退出；未启动常驻后台任务。

目标分支确认后：读取其 AGENTS 和场景接口 → 在美术分支适配表现 → 两边检查 → 更新 PR。发生冲突时保留双方改动并人工适配；禁止强推。会话结束后不会继续实时同步；持续运行须由开发环境显式启动监控脚本。

## 验证与后续

运行 `python3 tools/build_art_catalog.py`、`python3 tools/check_art.py`、`python3 tools/check_terrain_art.py`、`python3 tools/build_art_preview.py`、`python3 tools/check_docs.py`。生成器重建后必须更新统一清单和预览。

可用 Godot 4.6.3，仅验证 SVG 兼容与角色表现；目标 4.7.2、游戏分支集成、Android 手机画面和性能尚未验证。浏览器预览交互测试尝试被本环境 Chromium sandbox socket 权限阻塞；静态 JS、资源路径及合成画面另行检查。所有素材状态保持 `demo_candidate_awaiting_device`。
