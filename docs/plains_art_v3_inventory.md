# 平原精修 v3：最新运行美术消费者审计

审计基线为 `feature/plains-art-v3` 创建时的 `faecae2e838a262542f6b125418677ff49b90d5e`。本文件记录精修前实际消费者，不把仓库中存在的素材等同于运行已接入。2026-10-10 用户认可十六场景示意图的精细手绘风格，并授权依据最新分支精修第一大关平原；正式地区数量、身份和其他地区开放规则继续沿用世界文档。

## 实际消费者与替换位置

| 表现类别 | 运行消费者 | 精修前实际素材或绘制方式 | 精修建议与必须保留的契约 |
|---|---|---|---|
| 玩家身体、腿、围巾、独立武器 | `scenes/player/player.tscn` → `assets/characters/courier/courier_visual.tscn` / `courier_visual.gd` | `body.svg`、`leg.svg`、`scarf.svg`、`weapon_arm.svg` 四种分层 SVG；用节点位置与旋转实现六类状态 | 优先提供同一设计的无枪身体、腿、围巾、独立武器分层稿，统一比例与 pivot。固定已有六状态、脚底原点、`set_state`/`set_facing`/`set_aim_direction` 接口。烘焙持枪动作图不可替换独立 360° 瞄准 |
| 玩家表现状态来源 | `scripts/art/player_visual_adapter.gd` | 从 Controller 与 Motor 只读取得 idle/run/jump/fall/recoil/death；0.14 秒 recoil 表现窗 | 保留消息来源、暂停与会话清理。不得为动画变更 Motor、发射时间或动作资源 |
| 天空、丘陵、草甸 | `scripts/art/plains_background.gd` | `assets/painterly_v2/background/{sky,hills,meadow}.png`；有限画幅、不无限拼接 | 新分层画幅保持独立透明远景和天空覆盖。当前画幅常量 1672×941，换尺寸需同步以纹理尺寸求比例。长横/纵/方形镜头必须不露空白 |
| 大气透视 | `scripts/art/distant_plains.gdshader` + Background 层参数 | 饱和度 `[0.08,0.12,0.23]`、雾 `[0.30,0.42,0.29]`、轻虚化 | 原版手绘进入运行后会被显著灰化；新素材验收应同时看原稿和真实 shader 合屏。前景平台清晰，远景低对比的既定要求保留；不要用全场高对比代替精美 |
| 草地厚平台与墙体 | `scripts/art/plains_terrain_skin.gd:draw_platform`，由 `PlainsPlatformVisual` 及模块调用 | 草沿 `painterly_v2/terrain/grass_ledge.png` + 厚岩层 `assets/terrain/plains/rock_fill_1.svg`，SVG 岩层是真正运行中的混搭缺口 | 提供草左端/中段/右端、岩面/侧壁/底沿。厚岩层须验证重复边界，未通过则有限块拼贴并保留技术 fallback。端头不得横向拉长 |
| 静态薄平台与移动平台 | `draw_platform` 高度≤32分支；`ModuleMovingPlatform` → `draw_moving_platform` | 同一 `painterly_v2/terrain/wood_bridge.png`，固定比例，端头+截取中段组装 | 精细木桥与钟械移动平台可不同材质但同画风。保持物理顶面与位置；移动轨道、速度、携带与相位不变 |
| 平台源区域与落脚线 | `PlainsTerrainSkin._painted_strip` | 统一比例0.14，端头世界宽≤28，中段每112重用；草落脚 y324，木 y295；亮色直线表明真实物理顶面 | 新 atlas 用显式 region/stand_y/cap 元数据替换硬编码源位置；旧常量不可直接套新图。展示 48/80/144/320/1024 等宽度与高墙，确认端头不交叉、不露缝、不移落脚面 |
| 移动锯机关 | `scripts/generation/module_saw_hazard.gd` → `PlainsTerrainSkin.draw_saw` | `painterly_v2/objects/saw.png`，源区域 `(75.5,66.5,1102,1102)`；运行危险半径外轮廓提示 | 可精修锈铜/钢齿细节，但 source center/pivot 和 opaque radius 需重新记录。绝不从 PNG 自行改危险半径或扫掠判断 |
| 段内锚点 | 固定 `DemoStage._draw`、模块表现 → `draw_anchor` | `painterly_v2/objects/checkpoint.png`，裁切 `(194,59,924,1066)`，世界高40 | 清楚的小型机械铃/旗，避免与家园发光花或回血补给混淆。装饰不承诺回血、复活全重置或额外资源 |
| 巡逻无人机 | `scripts/enemies/enemy_presentation.gd` | 仅 `patrol_drone_patrol.svg` 与 `patrol_drone_dead.svg`；方形显示宽高为碰撞最长边×1.4；血量小圆点 | 缺少手绘身体和破损态，可提供同稿 idle/patrol/dead 与 rotor 分层。按中心 pivot 均匀缩放；不要把保留 telegraph 稿表现成已实现攻击状态 |
| 第十关 Boss | `scripts/bosses/boss_presentation.gd` | 纯六边形轮廓、多色核心线；真实 phase1/2变色、警告弧线、HP矩形 | 优先补精细钟械守卫本体与破损/发光核心。不新增攻击；既有 telegraph、phase、终止与血条必须仍能读懂。素材构图以 collision_size 参考但不能用图像改碰撞 |
| 玩家弹体与 Boss 弹体 | `scripts/combat/player_projectile.gd` / `scripts/bosses/boss_projectile.gd` | 玩家金色圆；Boss橙色圆及柔光 | 小型手绘弹芯可替换圆形主体，保持敌我不同轮廓/颜色；显示直径对齐现有 radius，外围纯光晕不得伪装伤害范围 |
| 局内金币与永久音符 | `scripts/demo/generated_demo_stage.gd:_draw` | 金币两圆；紫色音符线+圆。未消费已有 UI 素材 | 新独立图标建议金币为铜金钟币、音符为紫晶音符；14px左右当前金币显示需小尺寸轮廓验收。保持 claimed、kind、拾取判定和两个账本分离 |
| HP 补给 | 正式 `GeneratedDemoStage._draw`、固定 `DemoStage._draw` | 绿色圆+十字；使用后标志与文字变化 | 提供回血瓶/医疗机械匣，active/used两态或透明降亮度。不得复用 jump/shot recharge 图表达 HP恢复 |
| 房间奖励与商店标志 | 同上，`ROOM_MARKERS` | 圆点、文字牌；Boss奖有金色呼吸圆环 | 提供道具匣/商店小摊/金币匣/回血匣显示资源，保持实际房间内容；商店素材不伪造额外 NPC或商品 |
| 双出口与下关类型 | `DemoStage._draw_exit_icon`；正式生成关继承调用 | 空心矩形出口 + 程序线条 shop/coin_reward/health_reward/boss；其余默认菱形，combat/item_reward目前不分明 | 新六类型 glyph：combat、item_reward、coin_reward、health_reward、shop、boss。出口门框独立、图标独立；locked/available保持明显，并保留文字冗余与真实不同空间位置 |
| 道具二选一 | `scripts/ui/stage_reward_modal.gd` | `DemoMenu.create_theme`普通面板与文本按钮；实际 Modifier文字与稀有度 | 新手绘卡框/道具图标可改善。稀有度 BLUE/PURPLE/GOLD仍以文字+色彩呈现，按钮只发布 item_id，不改随机候选/领取事务 |
| 血量与精力 HUD | `scripts/ui/actor_resources_hud.gd` | StyleBoxFlat细条与英文数值；仅 Health/Stamina（原型 AirFocus读数） | 新钟械HUD外框/健康图标/能量图标；数值留引擎文本，不烘焙。不得暗示普通移动/跳跃/射击新耗精力 |
| 移动/跳跃/射击/命中粒子 | `scripts/art/player_feedback.gd` | 程序圆粒；事件已接入、有界64、可关闭、独立局部序列 | 透明短促尘团/火花纹理可映射现有粒子，保留事件和预算。装饰不可采样地图/奖励 RNG，不改变伤害、时间倍率或位移 |
| 触摸控件与瞄准引导 | `scripts/ui/touch_overlay.gd`、`scripts/demo/demo_aim_guide.gd` | 半透明圆、弧、按钮矩形、文字；右摇杆松手开火契约 | 只加轻边框/纹理，hit区域保持原值；危险、落点和瞄准方向不得被纹理挡住；暂停/返回确认保留 |
| 标题与主菜单 | `scripts/ui/demo_menu.gd` | `title_home/title_logo.png`、`home_background.png`；atlas装饰；实际按钮仍StyleBoxFlat | 本轮平原精修不需重新生成已统一的标题。可复用已有 UI atlas做边框，仍保留 engine文字、焦点/按下/禁用状态和完整开发入口 |
| 可控制家园与NPC | `scripts/demo/home_scene.gd` | `title_home/home_background.png`铺1280×720；`title_home/npcs.png`只有upgrade NPC真正生成。另两个角色/成就交互点存在但不实例化人物 | 新资源如提供三个NPC，应把“可用功能/未开放位置”明确区分；不把尚未实现角色或成就伪装成解锁完成。衣装师/记录员逐步解锁是设计契约，不能仅增加精美立绘就算功能实装 |

## 存在但未成为上述正式运行消费者的旧素材

`assets/painterly_v2/character/` 二十帧动作仍是候选，角色场景当前不实例化 `PainterlyCourierVisual`。它的枪烘焙进动作图，不能取代正确独立枪表现。`assets/objects/`、`assets/ui/`、`assets/vfx/`的大量 SVG，及敌人分层/命中/telegraph素材，多数是旧技术包、保留态或预览素材；新增精修覆盖率应按上表真实消费者计，不能按文件数宣称“全游戏已替换”。

`scripts/world/` 的旧 SawHazard、Checkpoint、RechargePoint、WorldSwitch、CombatTarget、ChallengeGoal 和 OneWayPlatform 仍有程序绘制；默认入口不把 LEGACY 契约作为正式十关验收。若继续作为开发入口保留，可以复用同一视觉皮肤，但不可为补美术改掉 Legacy/正式伤害与回退边界。

## 精修验收最低集合

1. 真实默认入口 TITLE → Home → 随机平原，至少查看厚岩台/薄木桥/移动台/锯/锚点/无人机与 Boss。原图画册仅为风格证据，不等同游戏接入证据。
2. 任意尺寸端头组装、镜像、长横/纵/方形镜头；站立线、动态危险边界、跳跃落点、移动台不遮挡。未经检查不声明平铺无缝。
3. 角色六态与向左/向右/上/下/斜向瞄准；独立枪实际旋转和脚底位置稳定。若仅静态分层精修，应称“六类程序动作表现”，不称完整 AI逐帧动画。
4. 金币与音符、HP补给与动作补给、家园发光花与段锚点分别可识别。双出口六类型以形状+文字+状态表达。
5. 有实际运行改动时运行对应 player_visual/enemy/boss/menu/home_ui 和总测试，以及 docs/world检查；设备输入与最终视觉仍待真机，不用headless代替。

本审计只读源代码并记录缺口，没有修改脚本、碰撞、输入、随机流或美术文件。精修最终 manifest、已接入/候选状态及验证结果由主任务交付记录。
