# 正式平原自主优化：消费者与证据缺口审计

2026-10-14；只读审计工作基线 `7c981ee77bedc238ca003212d93d10ec461ffeb3`，分支 `feature/level-design-harness-v2`；开始时工作区干净。本文件是后续设计 worker 的输入，不是已完成优化或完整体验验收。本轮授权一个范围可控的正式平原优化；至少十个代表 root seed、intro/advanced 两图、多拓扑、主路/成长/高奖励/回程策略、正式敌人机关奖励镜头和正常画面均需真实证据。

采用 `region-generator` 的旧地区优化工作流，已读 AGENTS、current_state、handoff、生成/人物/资源/奖励权威入口，以及 `docs/design/player_actions/regions_v0.3.md`、`weapons_v0.8.md`。以下源码未修改；本文件之外不写生产代码。

## 权威范围

- 正式消费者仍为两张非线性平原地图：map 1 为 intro/Bellstrider，map 2 为 advanced/Windkeeper。`PlainsRegionCampaign.seed_for(root,2)` 加 `/plains/map_2`，实例前缀、账本和 Boss 角色独立。
- 正式开局以实际 `DemoApp` 单装备快照为准：基础普通枪、一跳、基础两发未命中空中射击；H/W/D 与十五种 Studio 装备不等于正式已授予内容。不能为了覆盖矩阵临时假定同时拥有全部武器。
- 武器 V0.8 的单武器、分支锁定、真实运动与资源要求继续有效；设计方向、Studio 已实现、正式授予三者分开。
- 森林仅做 regions V0.3 的 dry run：S2 森林 H + 基础跳跃/R，入门到隐藏挑战都不能强制 W/D/U1/U2。S4 替代解法与 S5 双移动锁保留原要求；不开放地区、不写新世界连边。

## 正式入口与当前测试的覆盖差异

| 入口 | 已有行为 | 新任务不能直接借用的完成声明 |
| --- | --- | --- |
| `scripts/demo/demo_app.gd` `start_plains`、`_load_stage` | 实际角色、构筑、钱包、资源、两图生成、敌人伤害、段回退、掉落、奖励/商店、镜头 | 仅调用生成器并实例化 assembler 不是这个完整消费者 |
| `scripts/demo/plains_region_stage.gd` `_ready` | 实际 assembler、敌人实例、Boss、奖励、地图迷雾、scenery 与 terrain art | 生成 Manifest 不能证明这些节点已安装并参与运行 |
| `scripts/demo/generated_demo_stage.gd` `_spawn_enemies_from_plan` | 使用 Manifest 的 behavior/patrol/aerial/dive_depth 创建真实 EnemyActor | 不可用敌人数量替代实际对玩家施压 |
| `demo_app.gd:328–345` | bind_damageable、bind_encounter、protected_points、1/2 同时攻击限制与接触发射器 | 单独 pressure fixture 没覆盖整张正式世界 |
| `demo_app.gd:434` `_physics_process` | 实际 pickup 事务、锚点、死亡/伤害、Boss 进入与封场 | 关闭 app physics 会消除这些正式行为 |
| `tools/level_design_capture.gd` | 取 map 1 正式 Manifest 后 abandon/free app，再跑无敌人 assembler | 不能签 map 2、含敌人完整路线或正式奖励体验 |
| `tests/plains_region_trace.gd` `journey` | fast 到 prep；growth 到 medium 区、商店和 prep；tour 全连接；真实 Motor/机关 | growth 没领取奖励或购物；fast 终点为 Boss 前整备点，不是 Boss 胜利 |
| 同文件 `deep_trial` / `adventure` | 进入高奖励平台，真实单向下降撤离，到另一 junction | 宝箱坐标到达不是宝箱领取，也不是获得构筑后的路线验证 |
| `tests/plains_campaign_fixture.gd` `second_map` | reset_at + 直接 DamageRequest 击败小 Boss，再确认 map 2 | 明确结果/生命周期 fixture，绝非真实输入 Boss 通关 |
| `tests/plains_exploration_pressure_runner.gd` | 真实 fan/diver/ferry 局部无伤、不杀敌通过 | 在模块入口建 fixture，不能作为完整正式探索旅程 |
| `tools/verify_plains_region_browser.py` | 正常 Title/Home/出发、迷雾地图与教学输入、截图 | 文件本身声明不是全循环/高奖励真人或浏览器通关 |

特别风险：`tests/random_stage_tests.gd tick()` 手动调用 `controller.physics_tick()`；直接绑定仍自动执行的正式 Controller 会每帧重复求解。生产采集必须明确唯一 tick 所有者。`DemoApp` 的 physics priority=900，伤害策略=1000，镜头=1200；帧证据应在这些正式过程完成后记录，不能只看 Motor 前状态。

## 至少十 Seed × 两图 × 四策略的可执行采集设计

1. 固定 root seed 清单，不失败重抽。至少包含旧 `level-design-v2-baseline`，其余来自确定序列；记录两个 map 的实际 family 分布，若十个未覆盖三族，追加预先说明的代表 seed，保留原十个及所有失败。拓扑抽样与完整路线结果独立。
2. 每个策略创建真实 DemoApp，`meta_persistence_enabled=false` 仅隔离真实存档副作用，仍使用实际 fresh health/config。保留 app/stage/player/controller/policy/segment/镜头，复用其 assembler 与 shot-latch consumer，不额外复制一套敌人或碰撞。
3. 从旧 driver 复用路径与模块输入方法，但将 fixture/tick/释放生命周期与路线逻辑分离：绑定实际 app 的 actor 与世界；只向真实 router 提交动作，唯一 Controller 每帧最多一次 physics_tick。不能复用父 journey 的自动 free 把 app 提前销毁。
4. 正式敌人自动 AI、攻击、弹体、碰撞、伤害与掉落全开。每段记录实际敌人 ID/behavior/状态/攻击 serial/HP，玩家 HP/资源/伤害结果、阶段 epoch、碰撞安全/环境回退。不要冻结 AI、改 invulnerability、关闭接触或用生命注入取得 PASS。受伤是记录的真实体验，不应被假装零伤；致死/卡死/超时为失败并保留最差 seed。
5. 四策略明确目标：`fast` 从入口到 Boss 前 prep；`growth` 至实际 medium cache、真实领取一项预先声明的合法选择、到商店并依真实余额预览/购买，然后 prep；`highreward` 至实际高奖励、领取、单向撤离；`return` 在同一次连续世界中从已到达目标回已访问 junction/入口，允许已真实打开的背面捷径。返回不能重新 fixture/spawn。
6. 路线选择可使用 Manifest BFS，但应声明“自动策略知道全图”，不能把它算作真实玩家发现路线。需要另存地图实际 explored 状态、观察/选择截图；主观探索仍人工评审。
7. 奖励交互走 `router interact → DemoApp.interact/_queue_action → _commit_interact → _region_interact`；选择通过实际 reward modal 信号或同一合法提交入口，记录 offered/selected/claimed receipt。不能直接改 build/wallet/claimed。道具可能改变 tuning/空中次数，入口/出口及获得后的 capability 均要真实记录，不能沿用 driver 内写死“两发归满”而误判合法构筑。
8. map 2 的正式获取有明确分界：真实小 Boss 战斗→死亡动画/原奖励→确认→`_advance_region_map` 才是连续 campaign 证据。若独立初始化 map 2 或用现有 outcome fixture，应单列 `map2_initialization_fixture`，只能证明第二图内容运行，不能宣称已真实完成两图 campaign。若用户要求严格全流程，需补真实 Boss 输入策略，不能用该 fixture 替代。
9. 每条路线记录 root_seed、map_index、实际 map seed/hash、RunManifest、初始及变更能力、路径/决策/奖励收据、所有请求与实际观测、敌人状态、伤害/回退、相机 center/zoom/world view、完整日志与终点。截图在真实跟随镜头下取得；代表和最差 seed 保存正常速度带音轨录像。
10. 自动过程有界：每 edge/策略明确 tick budget，失败保留最后状态与原因并继续其余预定样本；不得无限重抽。报告覆盖数必须按 root seed、map、策略分别列 pass/fail/unverified，不拿 80 个生成成功冒充 80 条完整旅程。

PC router 轨迹仍是 synthetic_router 的真实 Motor 测试，不是键鼠 UI、手柄或手机实机证明。GUI 必须实际鼠标/键盘/触屏路径；实体手机与手柄手感仍单列。

## 一个优先黄金优化候选：路口地标实际缺失与回程辨识

目前不预定新增敌人或机关。候选是恢复**可辨认的探索路口地标和有方向的构图**，改善空间记忆、目的地预告与回程辨识，保留安静段落。完整基线与画面复核后再决定是否实施。

代码证据：

- `PlainsRegionGenerator._candidate` 的 junction floor 为 `Rect2(-HALF,18,HALF*2,32)`，即 400×32；部分 junction 是 one-way。
- `PlainsRegionStage._ready:81–89` 只传入模块非 one-way 平台，不包含 assembler.ground_supports。
- `PlainsRegionScenery.ground_for:35` 要求平台宽至少180、高至少40、横向覆盖 area origin、纵向距 origin<100。32高的正式 junction 因而不满足该条件。
- `_ready` 找不到 floor 就 continue，根本不会调用 `_add_prop`。仅统计 Manifest 的五类 landmark 或假设均已绘制会夸大实际场景内容。
- 即便有支撑，`_ready:29` 仍把五类标签折为 windmill/ruin_arch，并添加固定 ivy/stones。这个映射是后续身份设计输入，不能越过“实际是否实例化”的前置核验。

只读静态重算（不是 Godot 节点盘点/截图）的结果：从现有真实 Manifest 读取 inline geometry，外部模块读取实际 `.tres` 的 platforms/one_way，按该源码原条件查询支撑。

| 既有证据 | 难度 | eligible area 数 | 找到支撑数 |
| --- | --- | ---: | ---: |
| `build/level_design_v2/capture.json`，seed `level-design-v2-baseline` | intro | 14 | 0 |
| `build/verification/harness/20261014T142446.861362Z/artifacts/region/generated/plains_cohesion/geometry_woven_layers.json`，seed `corpus/woven_layers/0` | advanced | 17 | 0 |
| 同目录 `geometry_linked_rings.json`，seed `corpus/linked_rings/0` | advanced | 14 | 0 |
| 同目录 `geometry_crossroads.json`，seed `corpus/crossroads/0` | advanced | 17 | 0 |

复算最初两次解析脚本因 `.tres` 空格格式和 typed array 表达不同而失败，修正解析后得到上表；这些是只读解析错误，不是游戏失败。不以这四份既有输出代替本轮十 seed 新基线。运行确认应从正式 stage 取 `PlainsRegionScenery` 子节点 inventory，区分 veil 与 props，并检查实际合屏。

设计切片建议：以**真实承重的 solid 平台顶面**为锚点依据，不能仅由视觉岩块厚度决定是否可以放地标；保持 one-way、危险落点和功能对象避让。按区域 role、实际邻接方向和可见空间选择少量构图，让入口/营地/可选高处/回程汇合点有可记忆差异。复用现有已准入素材和命名流，不消费玩法 RNG，不改 collider、奖励/经济、Motor 或输入。不能简单把高度40改成更低数字然后全图密铺相同风车来宣称完成。

可证伪的黄金验收：正式 inventory 证明预期少量关键点真实出现；地标接触支撑且不漂浮；落点/危险/敌人 telegraph、铃与门、宝箱/商店、路标与HUD仍可读；同 seed 基线与改进的 gameplay Manifest、碰撞、敌人/奖励数据一致；原连续路线实测不劣化；实际截图显示不同路口轮廓和方向信息。审美与玩家是否更容易记路仍须人工结论，不能用 sprite 数量或视觉 hash 签通过。

## Q1–Q8 的客观依据与保留项

| 维度 | 这轮应收集 | 不可伪造的剩余判断 |
| --- | --- | --- |
| Q1 探索 | 实际路线选择、发现/领取/回程、迷雾与地标可见证据 | 自动全图知情 BFS 不等于发现乐趣 |
| Q2 动作 | 真实入口出口、接受效果、方向/相位/资源连续链 | recipe 标签不等于精妙动作 |
| Q3 敌人与地形 | 实际攻击/躲避/射击方向、唯一落点可用性、伤害/撤离 | 敌人计数不等于有意义压力 |
| Q4 区域特色 | 正式场景中已出现的风铃/地标/空间与玩法联系 | 五标签不等于五构图 |
| Q5 节奏留白 | 实际无交互/观察/恢复区间、连续压力与奖励间隔 | 静谧与空白需结合意图和画面判断 |
| Q6 构图视听 | 同镜头合屏、遮挡、接缝、正常速度音画 | 自动通过不能代签精美 |
| Q7 重复游玩 | 同能力/策略跨 seed 的图、动作、遭遇、发现、视觉描述 | 坐标或 hash 变化不算新体验 |
| Q8 公平工程 | 真实碰撞/资源/回程、失败原因、随机复现与原回归 | 回放一种策略不覆盖所有玩家 |

## 现有可运行入口与实施后所需新证据

```bash
python3 tools/level_design.py capture --seed level-design-v2-baseline --strategies fast growth deep --output build/level_design_v2/baseline/capture.json
python3 tools/level_design.py analyze --capture build/level_design_v2/baseline/capture.json --output build/level_design_v2/baseline/report.json
python3 tools/run_plains_region_tests.py
python3 tools/verify_plains_region_browser.py <实际构建URL>
python3 tools/capture_actions.py
```

最后一个命令是现有动作录像工具，**不是平原路线录像**；复用其实际 GPU/60FPS/音轨与 ffprobe 验证方法，须新增正式路线消费者。`--headless` 不得当像素合屏证明。当前 capture CLI 的 scope/receipt 明确只接受无敌人三策略，新增正式模式必须扩展校验和负例，不能只改 scope 字符串冒充升级。

以上命令列为复现入口，本只读审计没有运行 Godot/GUI 或生成本轮新基线。本轮实施、十 seed 结果、黄金优化选择、实际画面、独立审查与失败返工由主任务和独立 worker 完成，并保存真正的 worker 调用/产出，不能把本报告当作那条执行闭环。
