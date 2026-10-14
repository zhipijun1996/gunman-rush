# PLAINS-AUTONOMY-01：平原路口地标黄金设计

2026-10-14，设计 worker `/root/audit_generation`，内容版本 `autonomy-v1`。本文件完成 G0 设计，提交独立审查；没有实现地标修复，没有签 G1–G5、用户审美、真人趣味或设备认可。采用 region-generator 统筹、challenge-choreographer 检查动作边界、encounter-director 检查敌人及留白、scene-composer 设计空间构图。宿主实际生产循环 request/response 记录位于 `build/verification/level-autonomy-plains/PLAINS-AUTONOMY-01/1/implement/`。

## 问题排序与选择

选择一个有限改进：**让已有路口身份成为真实可见、可回认的稀疏地标构图**。目标是 Q1 导航信息、Q4 地区身份和 Q6 局部空间构图；不是动作链、战斗难度或全程内容密度改善。保留现有拓扑、危险、奖励、输入、物理和资源。

| 优先级 | 实际依据 | 结论与本轮处理 |
| --- | --- | --- |
| 1 | 80 份正式运行的 textured_prop_nodes 均为 0；真实 Scenery 仅有 atmospheric veil；源码支撑过滤与正式32高路口不匹配 | 跨 seed 的确定表现缺陷，有正式消费者及画面，适合先修最小黄金样板 |
| 2 | 六张已看正常镜头图，多处用同一远景、悬台、文字命名区分路口；奖励撤离处文字与 toast 很拥挤 | 地标可辅助识别，但不能抢交互层，需视觉否决而非只验数量 |
| 3 | 80 路线中 58 次死亡、6 次策略失败，16 到达策略目标 | 保留所有失败；固定移动策略没有主动瞄准所有敌人，不能把58死亡解释成地图无解或玩家通关率。本轮不改敌人、控制策略来提高“成功率” |
| 4 | 26 个低互动候选 | 保留原时长/距离/定位和未校准阈值；装饰不改变动作签名，不消除这些候选。不加怪填满，也不事后改“休息区”标签消警 |
| 5 | 网格、重复配方、深路连段和回程的潜在问题 | 仍需逐段动作/真实敌态及玩家证据；不借本次构图修复宣称已解决 |

备选 A（选用）：只修真实支撑识别与稀疏语义构图，先代表黄金场景，失败可撤销表现而不回滚玩法。备选 B：单纯降低高度阈值并在每处复制风车/拱门——拒绝，支持缺陷会变成重复、误导和遮挡。备选 C：增加敌人/机关缩短低互动统计——本轮证据不足，改变挑战和公平成本。保持现状方案：保留文字导航且无风险，但已声明地标继续不进入消费者，不能满足地区身份与回认目的。

## 权威、能力与真实范围

完整准备输入来自宿主 request 中的 region_context/lessons，沿动作 README 最新覆盖规则读取。`regions_v0.3` 的六阶段/16地区、S1固定平原/S6世界钟心、H/W/D/U1/U2、S2单能力、S4替代与S5双移动+U1保持 LOCKED；矩阵具体机制、区域美术叙事仍按 PROPOSED 处理。本次不改变世界规则，不开放森林；森林后续仅 S2-H+基础动作 dry-run。

正式实际入口是 DemoApp → PlainsRegionCampaign → PlainsRegionStage → PlainsRegionAssembler/真实敌人/奖励/镜头/PlainsRegionScenery。两图分别 intro/Bellstrider 和 advanced/Windkeeper；Manifest 可能沿用通用 windkeeper 名称，运行 HUD/实际 Boss 消费者才决定 map 1 语义，不能根据静态标签改流程。

本基线入口 actual snapshot 为单一 `pulse_gun` Lv1、granted_actions=`jump,shot_recoil`、一跳、初始空中两发、真实射击精力与冷却；拾取后的 build/能量以各帧与 final_capability 为准。Studio 的十五装备和 implemented_independent_actions 不等于正式授予，不联合多武器测试。视觉改变不新增能力前提，也不改变任一合法构筑可走的碰撞路径；未采样的实际合法构筑仍须后续按正式解锁状态补证，不宣布全武器物理已验。

80 样本为十个 root seed × 两图 × fast/growth/deep/return，完整清单与每条失败在 baseline_summary/report。采集是 live DemoApp 的实际 Motor、敌人、攻击、奖励与镜头；输入为 synthetic router。map 2 初始化范围、Boss 战斗完成、连续两图 campaign 完成均以 capture.captured_scope 为准；当前不证明真实 Boss 战胜/连续两图通关。自动策略知道 Manifest，不代表玩家探索发现。

## 实际看图与黄金空间

本 worker 用 `view_image` 直接查看 `build/level_autonomy/visual_before/intro_deep/frames/` 下六张原图；不是从元数据推断。seed=`level-design-v2-baseline`，map 1，deep，60Hz，1280×720，正式跟随镜头，基线提交 `7c981ee77bedc238ca003212d93d10ec461ffeb3`；完整 source_files 哈希在 rendered_report，覆盖当时未提交的观察工具。

| 场景与位置 | 实际观察 | 黄金意图/否决条件 |
| --- | --- | --- |
| frame_000000，tutorial | 石灰岩起台/远山清楚，教学文字与 HUD 已占上部，无本地大型地标 | 对照场景；不加地标吸走教学落点注意，不改已认可地形母版 |
| frame_000600，area_0_1→area_0_0，玩家(-57.83,-300.07) | 三层木台、左侧真实铃部分可见，背景山谷相同；HUD写钟庭但无近景钟庭轮廓 | 黄金 A：area_0_1 的实体支撑旁用低对比遗迹形，帮助识别“来时钟庭/向上支路”；不放在攀升木台上、不遮铃/门/上层落点。此帧是攀升中景，对地面锚点还须补接近/离开图，不能强求地标始终入镜 |
| frame_000840，deep_high，玩家(-22.69,-943.64) | 下层有真实敌人，玩家在上层空中，奖励路线文字横贯画面 | 负例保护区：不在奖励挑战入口及目标落台加大型装饰；敌人轮廓、预告、起跳/落点优先 |
| frame_001440，area_1_0→area_2_0，玩家(1456.17,-700.07) | 高奖励撤离后金币/音符反馈、宝箱、OPEN RETURN SHORTCUT、文字同屏；无本地石群地标 | 黄金 B：area_1_0 回程汇合的实体侧支撑上，以低矮石群轮廓对照钟庭竖向拱形。若无避让后合法支撑则明确省略，不在木桥/宝箱/交互提示上强放。验证从左右接近均能认出汇合而不误认新奖励 |
| frame_002520，area_3_1/area_3_0 逆向下降，玩家(4200,-167.16) | 相似悬台/远山；奖励 toast 遮住画面下部，角色部分被 toast 遮挡 | 记录现有 UI 可读性缺口，不以加地标修复。黄金反例：本次不得加剧该遮挡，不能把空中下降当安全观察停留 |
| frame_002950，area_3_2→area_4_2，玩家(5599.85,699.93) | Boss 接近文字、长桥、左侧危险与金币；体力2/5 | 对照：保持 Boss 接近路线信息和危险预告；不把重复拱门铺至 prep，不暗示可休息无敌区 |

黄金 A/B 是**设计锚点**，不是已经满足位置/遮挡验收。实施前先查真实 solids、对象边界与实际镜头；原点仅用于关联区域。跨 seed 按 region role、已有 landmark 与邻接/返回语义寻找对应，不硬编码上表坐标为全地图算法。优先有实体支撑的钟庭/溪石路口；若候选全被保护区排除，保留 `omitted: clearance/support` 并返回设计选下一代表，不无限随机重抽或造平台。

## 玩家行为、节奏与联合边界

设计假设：进入路口时先见与近邻不同的轮廓，再结合现有路标/迷雾判断“继续主路、向上选奖励、沿已开捷径返回”。撤离后以相同地标回认位置，减少完全依赖文字名称。玩家记忆改善须真人检验；自动程序只证明地标出现、方向关系与遮挡约束。

动作沿既有连续序列：移动接近 → 在现有可站面观察/必要时等待敌人 → 选择已可用出口 → 原跳跃/反冲/修正/落地。这里**不新增动作转移、时序考题、资源恢复或必须停顿**，入口出口速度/资源/冷却/机关相位全部继承真实轨迹。challenge-choreographer 不为装饰虚构 accepted_action；射击与落地只有实际事件和状态才能改变动作统计。

敌人作用保持真实 AI：下层敌人可能改变起跳时机与射击方向，玩家可等待、绕过或攻击；地标不得遮住预告、把可穿越空间画成墙或把不可站装饰画成新平台。当前有敌帧不是四种敌态已验证；实现后在 alive/moving-away/dead/inactive 边界对照中确认装饰不依赖敌体支撑、命中回能或击杀才能显示。fixture 必须标注，与80次自然AI运行分开。

留白合同：purpose=路口定位/奖励反馈后的方向选择；viewer_goal=识别来路和已开出口；visible_information=真实出口、路标与可辨轮廓；recovery_rule=原地面与原资源恢复规则，不添加注能/保护；next_beat=原连接挑战；return_experience=回认同一地标后选捷径；observed_support=基线1440确有奖励/捷径反馈但缺本地轮廓；counterexample=只有重复风车且出口仍被遮挡，或敌人在攻击使停留不安全。用途不自动消除26候选。

失败成本、容错、恢复：装饰无碰撞/交互/触发，不缩有效落点和输入窗口；玩家可随时沿原出口离开，失败依正式回退/死亡流程；不得调整 protected_points、敌人攻击配额或相机来让样板“通过”。若遮挡不可解，省略该装饰而保留玩法。

## SceneComposition 与实施约束

主题沿现有嫩草/石灰岩/旧木/磨损黄铜与暖日光，保留已认可 v8 地形和远景。近中景局部焦点与远景风车分开；不把背景风车当可操作机关。使用现有 `PlainsV3Assets.texture("decor.json", id)`，实际资产来源/许可由 manifest 继承并核验，不能把地形母版认可扩大为所有 decor 已获用户认可；未知项保留 unknown。无需生成新素材，新画风不在本切片。

- 主消费者为 `scripts/art/plains_region_scenery.gd`，接入点 `scripts/demo/plains_region_stage.gd`。修支撑采集/选择时使用真实固体顶面，区分 one-way/moving；厚度不是可承重语义。地形并集和 collider 不改。
- 布置依已有 landmark 的语义：石群保持低横向轮廓、遗迹拱保持竖向负空间、风车只用于已有风车身份。`windchime` 不以假互动铃代替；无合法非互动资产时省略/明确缺口，不折为同一拱门。
- 稀疏密度有硬上限但非填充配额；首片只证明两个不同身份黄金，不以14个eligible全部非空为验收。每个输出记录 area_id、支持体、资产id、foot、显示包围盒、选取/省略理由。展示层确定性，不消费或重建玩法随机流。
- 脚点依据透明图有效底边和缩放计算，底边接触真实solid顶面；大形不能跨空洞造成假可站面。不依赖 `z_index=-10` 自动解决遮挡，背景地标也会与敌人/文字视觉重叠。
- 保护角色通行带/目标落点、world_dangers、真实铃与gate、宝箱/商店/路标、敌人预告与攻击扫掠、HUD/toast实际屏幕区域。复用 SetDressing 的避让经验而不另造玩法服务；屏幕保护须实际跟随镜头查。
- 尺寸/锚点/避让数值为设计参数，先从现有纹理和实际镜头取值并保存版本；不得声称100世界单位即经玩家校准。初版以小于主交互物的低对比轮廓为候选，出现误认/遮挡即返工。音频、动画和新粒子本轮不增加，其现有质量不因此通过。

不变量：RunManifest玩法字段、拓扑、模块/端口/地形碰撞、能力授予、PlayerMotor、武器资源、敌人/奖励/账本、随机流位置、两图生命周期/保存全部保持；相机/HUD/教学文字行为保持。可变项仅表示层支撑查询、确定性装饰选择/锚点与必要展示元数据。任何超出需返回本任务范围审查，不能擅自把构图任务变成战斗重做。

## 逐项验收、反例与后续依赖包

| ID / Q / 门槛 | 通过观察 | 必须拒绝的反例 / 返工 |
| --- | --- | --- |
| D0 / 全Q / G0 | 本文件有事实来源、选项取舍、完整边界和下列可执行判据；仅 design 可通过 | 空卡、把58死亡称地图无解、把props当趣味分、未来能力暗授：退设计 |
| A1 / Q4,Q6 / G1–G2 | 黄金A/B实际节点与纹理、脚点/solid顶面匹配，近邻轮廓不同；无支撑明确省略 | 只看节点数量、所有标签折成拱门、单向木桥上假承重：修支撑/选择 |
| A2 / Q1,Q6,Q8 / G2 | 同seed正常相机接近/离开/反向三组图及连续录像中，出口/铃/门/宝箱/敌人预告/落点可读，黄金分别可识别 | 地标漂浮、遮挡唯一落点/交互、形似可钩/可站新物体：省略/缩放/换锚点后重拍 |
| A3 / Q2,Q3,Q8 / G1,G3 | 同80条件前后玩法Manifest字段/随机流一致；路线outcome、伤害、资源/动作事件及失败位置无新差异，若差异必须逐帧解释 | 通过关闭敌人/传送/补血/换策略刷胜率，或碰撞/奖励变化：拒绝；死亡样本仍保留 |
| A4 / Q3,Q8 / G1,G4 | 黄金受影响区alive/moving-away/dead/inactive及不利机关相位、低资源、失败再试与返回不新增遮挡或通路依赖 | 敌人死后才显地标/失唯一支撑，预告被覆盖：拒绝；fixture不能冒充自然游玩 |
| A5 / Q5,Q7 / G4 | 前后低互动26候选、动作/机制签名按同政策比较；构图差异独立描述，所有十seed两图仍在矩阵 | 靠装饰消动作告警、换seed避失败、把visual hash当新玩法：拒绝 |
| A6 / Q6,Q8 / G3,G4 | 原地区/地形/生成消费者回归、docs/art/gameplay与正式GUI适用检查；保留源码指纹/退出码/日志/截图 | 仅文档通过、无实际GPU或旧build截图：未验/拒绝 |
| A7 / Q1,Q5,Q6,Q8 / G5 | 玩家评价是否更易回认/更清晰，以及实际键鼠、手柄、手机输入与缩小可读/性能证据 | AI自评代签，软件GPU帧率当手机性能：unverified/awaiting-device |

实现包：scene-composer 修表示层+支撑传递 → 两个黄金及负例真实引擎/合屏 → 独立 reviewer 按 A1–A4 尝试推翻 → 仅合格规则推广到同角色的预定seed → 原80矩阵与回归/前后报告 → 用户和设备剩余项。失败输出 finding 的 area/edge/tick、原画面、原因、最小修复及重测；不删原断言，不改阈值，不无限重抽。此设计阶段无代码晋级，后续阶段 G1/G2 也不自动代表正式内容 done。

实际存在的复现入口（以下为后续执行计划，本 worker 未重新执行采集/回归）：

```bash
python3 tools/level_formal.py --seed level-design-v2-baseline --seed-count 10 --maps 1 2 --strategies fast growth deep return --output build/level_formal/after_autonomy --jobs 4
python3 tools/level_formal.py --seed level-design-v2-baseline --seed-count 1 --maps 1 --strategies deep --capture-visible --frame-stride 120 --output build/level_formal/golden_after
python3 tools/harness.py --profile docs
python3 tools/harness.py --profile art
python3 tools/harness.py --profile gameplay
```

录像准确重放命令在基线 rendered_report.command：Godot gl_compatibility、--write-movie、fixed-fps60、tools/level_formal_capture.gd。软件GPU正常速度录像是视觉证据，非实机性能。本 worker 实际执行了原件JSON解析、源码检查、CLI --help与六张view_image；没有播放完整电影或监听音轨，动态/声音仍未验。宿主接续运行 request.checks，不把计划命令填作已通过。

## Q1–Q8 结论与可复用经验

Q1 导航/回认是待检验设计假设；Q2 动作、Q3战斗耦合无改善声明；Q4 修复实际身份缺失但不引入新机制；Q5 保留全部候选与合理留白；Q6 仅局部地标构图黄金，整体视听未验；Q7 只增加可描述的局部轮廓差异，不能宣称随机玩法丰富；Q8 以不变量、真实消费者和负例守底线，主观/设备未验。

经验 `plains-solid-landmark-support-v1`：source_kind=engine_fact+source+AI_design_hypothesis；exact_scope=当前80份正式两图及所查看intro deep画面；observation=地标声明未进入真实Scenery；heuristic=先查实际消费者/支持语义再做稀疏语义构图；positive_case=待实现后的钟庭/溪石黄金；counterexample=修厚度过滤后全图复制拱门；validated_consumer=基线DemoApp+PlainsRegionStage，改进尚未验证；authority_conflict_check=不更改S1能力/已认可地形；unresolved=动态遮挡、玩家回认、资产最终认可、设备。不得升级为所有地区必须放风车的规则。

## 原件来源账本

运行基线 source_commit 为 `7c981ee77bedc238ca003212d93d10ec461ffeb3`；实际观察工具与生产文件逐项SHA见 capture/receipt/source_files，不能只用提交号代表脏工作树。以下为设计执行时直接读取文件的SHA256；本设计与质量记录的最终 source 快照由 record.production_snapshot 绑定。

| 文件 | SHA256 |
| --- | --- |
| `docs/design/player_actions/README.md` | `26b46fcf4be3440f0d4c6563d59af7dc5595f65ea3cb1e6f5a612eae1fb92618` |
| `docs/design/player_actions/regions_v0.3.md` | `1c0e78298942fce4e0b133f4b5a52e37cf302c6af57e268747fdf7e6deb636f4` |
| `docs/design/player_actions/weapons_v0.8.md` | `0d2b908637a85270e46ede7cbb17fb8d5d8f353d901a3bda79665291c450e852` |
| `docs/quality/level_quality_dimensions.md` | `9695f1daad9b0ceca0a2d1cd0ae38f4c07b112818dc224aabb841fa564eafeac` |
| `docs/evidence/level_autonomy/baseline_summary.json` | `3fc96f740ee19cfd030c03b15dd05afc9c615249dc431700e4e94e7ec198003a` |
| `build/level_autonomy/baseline_report.json` | `a8864d84af75e11e31b41d2555769324e6c67b3bc4b78cf233f76feea9efa4a2` |
| `build/level_autonomy/visual_before/intro_deep/capture.json` | `5480be616c30a1eedc1f39c787de3b3ba100469f0b47c6f84b9869fdb1276a5c` |
| `build/level_autonomy/visual_before/intro_deep/rendered_report.json` | `960a51a8563d928edf4e20b0e4f36870ce5ab749fe2063e1421c07fc87843189` |
| `scripts/art/plains_region_scenery.gd` | `800c343e56fa721b0575ef3273e40fdb682ed4aa6b26d9b45c57b5f0c9bb7957` |
| `scripts/demo/plains_region_stage.gd` | `5aa7ad5bcb378a5221298827abe8c8b714fd3a35345549c40b0046ecb482b388` |
| `assets/plains_v3/manifest.json` | `9457bb1fb5e523b76743777ce5938f2a1096497fcee0d35e03ca4a4d07686093` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_000000.png` | `55fb90b1f19dc548e8cec796851f0448538d1682a4c1c2c77013553f013562ae` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_000600.png` | `343f0b847f4bc2b842700c8c44a994e3d3d5379142389b59625620b3b821827f` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_000840.png` | `ac2e9a428c8331a27724e5c72c94d5358b0816c11d115d223b2365a9fde14444` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_001440.png` | `b078ee1ad57792d5fcc97c2dc3f03d06aacc5725f237081eae409d463fe88cc1` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_002520.png` | `716098a6dca2cd84a3b64cb43ad3f9310f3c3958d9c0f0e1c8dc2fd75bbfbedf` |
| `build/level_autonomy/visual_before/intro_deep/frames/frame_002950.png` | `36c37fa4dd1c7b39bd3441aeb9d04f0326b91a97467bc12464b59e5328d5332c` |
