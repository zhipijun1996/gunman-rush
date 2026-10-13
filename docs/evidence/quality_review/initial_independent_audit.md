# 正式平原独立审查：REJECT

2026-10-13；reviewer=`/root/independent_gameplay_audit`，独立于本轮实现者 `/root`。本代理没有修改正式生产代码、资源、测试或权威文档。此报告是本轮独立审查附件，任务归属由主代理写入本轮质量记录；不为未获认可内容签用户通过。

审查冻结版本 `5fd9c272d74616ae477809fa4285f609e6b697c6`，分支 `feature/quality-review-and-production-loop`。实际浏览器包 `build_id=1b35f464a05a`、source_commit=`759e56e323dbd5df12cf55cdf12b59daf51dbf69`。独立执行 `git diff --quiet 5fd9c27 759e56e -- scripts scenes resources config assets project.godot` 退出 0，确认这些运行目录一致。主代理稍后开始修改工作区，以下源码行号与判断均指冻结的 5fd9，不自动适用于后续修改。

读过 AGENTS、gameplay-reviewer/art-director Skills、current_state、handoff、architecture、acceptance_tests、Visual Bible、art_quality_target、D081/D082 和相关正式消费者。未用旧报告的 PASS 作为结论，也未宣称玩家认可。

## 方法与实际范围

从普通浏览器 Title→ENTER HOME→真实键盘行走→家园出发门→正式第一图进入。未注入存档、状态、位置、奖励、关卡或能力。普通 D/Space 输入造成首次坑落与段回退，并打开暂停；这是受控输入尝试，不代表通关技巧，也不能以跳跃失败推断地图不可达。正式控制台记录 `family=crossroads areas=20 fallback=`。未获得 seed/完整 manifest，因此本次 GUI 的精确随机布局重播未验证。

已实际查看 home、formal-entry、formal-motion-0/1/3/5 PNG，逐份对照代码。完整正常速度输入录像已保存，但本接口只实际检查静帧序列，未把“生成了视频”说成“完整连续动画已审”。没有听音频。第二图、Boss 正式通关、长时性能、保存损坏恢复、真机、手柄和玩家趣味反馈未实际运行。

证据目录 `build/verification/independent-audit-gui/`；`evidence.json` 含包身份、输入脚本、图像/视频 SHA256、计算量和未验列表。GUI 命令 `python3 /tmp/gunman_independent_gui.py` 退出 0；原脚本复制为目录中的 `capture_script.py`。控制台有一个未归因的 HTTP404，无 SCRIPT ERROR；不能因此宣称网络资源完全无误。

## 必修发现

### IQA-01 / P1：普通敌人的暂停和地图操作改变战斗结果

**客观源码失败；确切敌人相位的 GUI 反例尚未运行。** 正式 `DemoApp.open_region_map()` 调 `_pause_for_menu()`（`scripts/demo/demo_app.gd:675`、`:700`）；后者在暂停前调 `_cancel_enemy_attacks(true)`（`:706`）。该函数仍无条件对每只普通敌人执行 `cancel()`（`:1443`、`:1448`），true 仅保护 Boss。`scripts/enemies/enemy_attack_behavior.gd:136`–141 清掉所有敌弹，把状态改为 recovery，并把 cooldown 补到完整恢复时间。

可复现反例：进入普通敌人攻击范围，待 telegraph 接近结束或弹体正在接近时打开地图/菜单，立即关闭。攻击消失，敌人进入新恢复段；重复操作可以持续中断攻击。此效果与暂停时长无关，也不消费资源。它使读预警、选择起跳/走位被无成本 UI 操作替代；与“暂停使用游戏 clock”和状态保持原则不一致，Boss/普通敌人表现也不一致。

返工 G1/G3：区分暂时冻结、取消未提交玩家意图、actor/stage 失效三种生命周期。暂停应保留已经开始的普通敌人相位和有效弹体；若产品真有“暂停清敌弹”规则，需要明确设计决定，不应靠公共 cancel 意外实现。验证应比较同一正式场景相位在暂停前/恢复后的状态、剩余时钟、弹体位置和下一次实际伤害时间；再检查地图/菜单/商店各入口，不只测一个已知按钮。

### IQA-02 / P1：普通敌人实心头壳存在无法命中的可见区域

**客观几何不一致；具体射击 GUI 尚未运行。** `scripts/enemies/enemy_motor.gd:6`–10 用 Definition 建唯一矩形碰撞，charger/sentry/hopper 的 `collision_size=Vector2(28,32)`，局部范围 `[-14,-16]..[14,16]`（例如 `resources/enemies/plains_charger.tres:13`）。`scenes/enemies/patrol_drone.tscn` 没有与可见头壳匹配的额外受击形状。

但 `scripts/enemies/enemy_presentation.gd:76`–94 从 meadow_actions manifest 以独立比例绘制：默认 beetle idle 的 alpha≥128 外框 `[-28.28,-28.10]..[28.42,16]`，sentry 为 `[-15.07,-28.97]..[20.24,16]`。不仅是脚、触角或透明边：局部 `(0,-23)` 对应 beetle.png `(262,151)`、sentry.png `(234,119)`，实际 alpha 都为252；已查看原图，该位置是主躯干/头部。基础玩家弹半径3，沿局部 y=-23 水平扫过时最低处仍为-20，距碰撞顶-16尚有4单位，所以射穿这块可见实体而不进入受击体。

玩家影响：看起来命中敌人却无伤害、无命中回能；教学需要真实命中返还弹药/精力，使这类不一致直接影响操作判断。它不能靠“表现不决定玩法”免审，表现仍须解释真实玩法。

返工 G2：在既有碰撞约束内重新校准表现比例/锚点/姿态。不要为适配画面悄悄扩大已验碰撞。验证应从全部正式种类、左右朝向、关键帧自动生成视觉核心体与真实 hurtbox 叠图，并用真实弹体扫过轮廓的内/外侧；装饰超界必须明确标注可忽略部位，不能只比 alpha 外框大小。

### IQA-03 / P2：正式第一屏地形仍有周期性拼接断层

**实际合屏可观察缺陷；“精美程度”的最终接受仍属用户待审。** `formal-entry.png`、`formal-motion-0.png` 长平台中，草顶到岩壁的图像在 x≈222、478、734、990 一类位置出现规则重置，岩根在平直底边被切断，相邻重复块底部形态不连续。首屏右侧长岸尤其容易看到同一苔岩图案重复；并非旧文档里的概念推断。

源码对应 `scripts/art/plains_cohesion_art.gd:5`、`:11`–18，GRASS 宽656、SCALE .2，完整带地侧岩壁的同一矩形被直接循环，每131.2世界单位重复；StageCameraRig 的1.95倍率令屏幕周期为255.84像素，与上述重复一致。`scripts/art/plains_terrain_skin.gd:101` 的 `_draw_ground_edge` 已直接交给这个 strip，并没有用先前设计的左右 cap 参数处理其可见端头。全局 world sampling 能避免模块重新起算，却不能保证 source 的左右像素本来就连续。

返工 G2：黄金样板覆盖长岸、短台和外露底部，先解决 source 纹理边界与根部裁切，再扩产。验证需平移摄影机通过至少三个纹理周期，同时比短台/长岸/内外角/深墙矩阵。保留原有碰撞，不能靠缩短平台或藏视角过关。此项可客观确认出现接缝；是否达到用户想要的手绘品质仍不能由本代理替用户认可。

## 需要设计/视觉复审的观察（不冒充已证实玩法失败）

- **种类提前识别不足**：`enemy_presentation.gd:62`–65 对 diver 和 fan_sentry 共用同一 aerial atlas 区域；`:80` 让 charger 与 hopper 共用同一 beetle。两组行为在开始预警后才靠轨迹线等变化区分。对首次遇敌的玩家，能否在接近前预测“扑击/远程”需要实际小尺寸盲辨测试；当前没有玩家证据，记 subjective/unverified，不因为五个 behavior_id 就宣布五类视觉性格完成。
- **提示与场景层次**：正式截图中金色教学字直接覆盖亮草原背景，缺描边/背板；`demo_stage.gd:128`–134 只设置字号与 tint。背景和文字亮度接近，第一屏第三行还能与角色重叠。1280截图仍可读，但手机缩小可读性/阅读时机未验。应在真实缩小尺寸和动作状态下比较，不能仅凭 OCR 能识别判定读起来舒服。
- **动画、镜头**：正式短序列中观察到落坑后HP5→4、回到起点，玩家未在所看帧完全出屏。该片段不证明全速长落、反冲逆向、Boss 大体型合屏或全套动作连续性。应继续验证，不授予动画/镜头完整 PASS。

## 维度与结论

| 维度 | 状态 | 本次依据/边界 |
| --- | --- | --- |
| design | failed | IQA-01 UI 操作绕过路径压力；其他玩法趣味 unverified |
| technical | unverified | 运行入口成功；未独立执行全部 gameplay suite |
| formal_integration | passed（窄范围） | 普通家园入口确实进入正式1/2随机地图；不涵盖完整二图/Boss |
| visual | failed | IQA-02几何、IQA-03合屏接缝；用户定稿未验 |
| animation | unverified | 仅实际查看静帧序列，未充分检查连续动作 |
| audio_vfx | unverified | 未听音频、未完整看命中/击败效果 |
| gameplay | failed | IQA-01、IQA-02代码反例；GUI确切反例待补 |
| performance | unverified | 无目标设备帧时/长期节点统计 |
| independent_review | passed | 不同独立代理读取正式代码与运行证据、未参与修复；仅表示执行了独立审查 |
| device | unverified | Chromium软件WebGL不等于目标设备 |
| player_acceptance | unverified | 没有真人认可来源 |

**REJECT 当前声明的内容质量通过。** IQA-01/02/03须返工/复审；不因此否定已执行的技术验收，也不以未完成真机或用户验收伪造通过。

`python3 tools/quality.py check` 退出0，仅1份质量记录一致性通过，工具明确声明不认证玩法品质。`python3 tools/harness.py --profile docs` 退出1；日志 `build/verification/independent-audit-docs.log`、`build/verification/harness/20261013T005956.482015Z/docs.log`。失败是并行中新建 ability/weapon/player skill 引用尚未出现的 `docs/quality/review_method.md`，主代理确认属于本轮未完成修改；**不是冻结基线5fd9的旧错误，也不是本次游戏缺陷依据**。保留失败不覆盖；修复后由主代理重跑。

## 可重复、非针对既知 bug 的审查机制

1. **先冻结包和真实消费者**：记录 full SHA、资源/配置版本、包 hash、正式入口和能力快照；审查者从普通入口走，开发 fixture 只补边界，不替代正式流程。
2. **行为×生命周期矩阵**：从每个实际状态机列 idle/预警/攻击/恢复/死亡，再系统插入暂停、地图、受伤回退、重载、离场。检查资源守恒、游戏时钟守恒、唯一奖励与旧 epoch 失效。不从某个已知故障名称写专用断言，而是检查所有正式消费者的公共不变量。
3. **视觉→玩法双向审计**：每种对象的可站边、危险边、可击核心都有可追溯坐标；用同尺寸碰撞叠图和真实 sweep 做“看起来能碰/应碰”和“看起来没碰”的成对反例。区分躯干、装饰、阴影，避免机械地要求所有 alpha 都等于碰撞。
4. **先抽样再扩展相位/组合**：每种正式模块/敌人/机关至少一个入口+回程+最坏相位，并按尺寸、方向、速度和危险组合分层随机抽样；记录失败 seed。seed/hash 不同不等于体验不同，比较实际动作序列、等待窗口、路线选择与恢复成本。
5. **固定黄金合屏和正常速度片段**：同一相机/分辨率跑长岸、窄台、竖井、密集战斗、逆向反冲和跌落；检查接缝、落点可见、角色/弱点辨识。画面指标发现问题，审查者给意见；用户认可和真机手感另留原始证据。
6. **保留否决和复审链**：每条发现带原图/视频时间段/代码版本/反例输入、修复 SHA 与受影响重验范围。改后冻结新版本再交独立审查，不能用作者更新的截图替换失败原件后直接判 PASS。
