# 《失序之钟》Level Design Harness V2 交付报告

本轮交付了一条可调用的“设计合同 → 正式 Manifest/真实 Motor 采集 → 路线诊断 → 对照 → 独立审查”生产链，并升级 Skills、模板与既有 Harness。没有大规模重做正式平原、开放未来地区或修改基础玩家机制。

任务为 `LEVEL-HARNESS-V2-01`，分支 `feature/level-design-harness-v2`。实际 fetch 基线为 `fa9b9502a3b3c6c28bb361b1512cc44b5e854564`；独立审查冻结实现为 `11827baaf259f5fc91061f5358f2621ed00e958c`。PR：[66](https://github.com/zhipijun1996/gunman-rush/pull/66)（draft）；未授权合并。本文后续证据包装不改变该冻结实现的审查范围。

交付传输：本机 Git 默认网络实测无法连接代理，改用已连接的 GitHub Git Data API 上传。服务端提交的身份/时间会产生不同 SHA；远端交付应核对文件树与本地冻结 tree `9312dcb615ed6c569965cee06a7e5e4294b97be0` 一致，保存 tree 对等证据及原本地审查提交 bundle。不能声称本地 `11827ba` 已作为相同 SHA 存在远端；远端同树实现提交为 `d540eca10d1f2f441ddbddc1663bfd9a1b4a4975`；[传输证据](evidence/level_design_v2/transport.json)记录 tree 相等，原实现 bundle 可在拥有基线的仓库验证并恢复。

第三轮独立审查对工程切片 **ACCEPT**，游戏内容验收仍 **UNVERIFIED**。完整 full Harness 在 `build/verification/harness/20261014T141019.038712Z/` 首次因并发文档更新触发冻结快照拒绝；即将冻结重跑，本文不预写 PASS；最终退出码和逐项状态由完成后的报告补充。

## 交付文件

下面按职责列实现文件；完整变更以基线到交付分支 diff 为准，临时运行产物保留 `build/`。

| 分组 | 修改/新增文件 |
| --- | --- |
| 原 Skills 升级 | `.agents/skills/region-generator/SKILL.md`、`level-module-creator/SKILL.md`、`art-director/SKILL.md`、`gameplay-reviewer/SKILL.md`、`game-quality-gate/SKILL.md`（后三者同属 `.agents/skills/`） |
| 新 Skills | `.agents/skills/challenge-choreographer/SKILL.md`、`.agents/skills/encounter-director/SKILL.md`、`.agents/skills/scene-composer/SKILL.md` |
| 路由与现有质量系统 | `AGENTS.md`、`docs/quality/policy.json`、`tools/harness/profiles.json`、`docs/quality/records/LEVEL-HARNESS-V2-01.json`、`docs/tasks.md` |
| 权威导航/交接 | `docs/current_state.md`、`docs/generation_current.md`、`docs/harness.md`、`docs/handoff.md` |
| 设计规范与审计 | `docs/level_design_harness_v2.md`、`docs/quality/level_design_v2_audit.md`、`docs/quality/level_design_contracts.md`、`docs/quality/level_design_golden.md`、本报告 |
| 五个模板 | `docs/templates/biome_design_profile.md`、`challenge_sequence.md`、`scene_composition.md`、`level_optimization.md`、`level_experience_acceptance.md`（同属 `docs/templates/`） |
| CLI/静态合同/诊断 | `tools/level_design.py`、`tools/level_design_contracts.py`、`tools/level_design_analysis.py`、`tools/run_level_design_tests.py` |
| 真实采样与输入观察 | `tools/level_design_capture.gd`、`tools/level_capability_snapshot.gd`、`tests/level_design_trace.gd`、`tests/level_capability_runner.gd`，以及对应 `.gd.uid` |
| 工坊接入 | 修改 `tools/foundry.py`；新增 `tools/level_design_golden.py` |
| 自动测试 | `tests/test_level_design_contracts.py`、`tests/test_level_design_analysis.py`、`tests/test_level_design_routing.py`、`tests/test_level_design_golden.py` |
| 跨地区/反例 fixture | `tests/fixtures/level_design_v2/plains_design.json`、`thorn_forest_design.json`、`golden_challenges.json`、`analysis_before.json`、`analysis_after.json` |
| 独立证据 | `docs/evidence/level_design_v2/independent_review/` 下三轮审查、原始复现脚本/反例、运行日志、对照失败与最终运行归档；文件及哈希见 [最终审查](evidence/level_design_v2/independent_review/final_review.json) |

原有五个 Skills 的职责和验收要求保留。新技能/模板进入原 policy 与静态质量检查，没有新建第二套 G 门槛或质量维度。

## 代码审计结论与新旧架构

[审计报告](quality/level_design_v2_audit.md) 包含实际文件/函数、消费者、八项假设的证据与严重程度、复现方法。确认正式两图仍是 `DemoApp → PlainsRegionCampaign → PlainsRegionGenerator → PlainsExplorationTopology/PlainsRouteRecipes → PlainsRegionAssembler → PlainsRegionStage`。`RunRandomStream` 与 `RunManifest` 保持既有职责。

重点纠正两处来源误用：旧 `generation_current` 状态落后于最新工坊/人物动作实现；`PlainsRoomGrammar` 属于共享或历史支路，并非当前正式两图已经采用的完整动作语法。`PlainsSetDressing` 与正式 `PlainsRegionScenery` 的消费者覆盖也不能混为一谈。

审计证明布局有固定间距/网格家族、连接按配方顺排模块并补地形；也发现已有动作配方避免重复、部分连接敌人和 Foundry 连续回放，不能声称此前完全没有编排或全部连接都是空白。是否无聊、探索和构图是否优秀，仍需真实路线、敌人范围、画面与玩家反馈。

| 六层设计 | 新增共享语义/职责 | 保留的运行基础 |
| --- | --- | --- |
| 宏观拓扑 | 语义节点/边、锁/授予、返回与选择价值 | 既有拓扑/Generator、RNG、Manifest |
| 区域身份/空间 | BiomeDesignProfile、RoomIntent、学习顺序与十项难度轴 | 现有房间/空间/模块消费者 |
| 连续动作 | 原子动作→短语→挑战→遭遇/房间→路线，状态/资源/相位/替代解 | PlayerMotor、真实输入、模块 Definition、Foundry |
| 遭遇节奏 | EncounterPlan、逐路线压力/恢复/奖励/回程诊断 | 既有敌人、机关、奖励与生命周期 |
| 场景构图 | SceneComposition、焦点/轮廓/层深/接缝/来源与合屏 | Scenery/SetDressing 各自真实消费者、资产 manifest |
| 体验验证 | 只读采集、诊断/对比、反例与来源完整性 | 原 Harness、G0–G5、十一维质量记录 |

新合同是离线 sidecar：设计意图、生成结果、运行状态、物理证据、主观评价分别标明。当前新合同没有重写生产地图布局，也未修改存档或运行 Manifest 格式。后续若字段升级，版本化更新验证器、fixture 与实际消费者；源/能力/配置变化使相应旧证据失效。运行时不调用大模型。

## Skills 自动路由

| 请求 | 首责 | 协作/退出依据 |
| --- | --- | --- |
| 优化风铃平原、制作新地区 | region-generator | 统一编排六层、样板、推广、回归与对照 |
| 连续反冲动作、短语衔接与挑战设计 | challenge-choreographer | 真实单武器能力、空间/时序/资源合同；module-creator 实现 |
| 新模块、端口/相位/邻接 | level-module-creator | 单模块及连续组合 Motor；正式池单独准入 |
| 空白/高压/重复遭遇、敌人平台联合设计 | encounter-director | 路线策略和风险收益；敌人/Boss 创作仍交原专业技能 |
| 构图重复、落点不可见、空间视觉身份 | scene-composer | 场景布局与功能可读；art-director 总负责风格/资产 |
| AI 资产系列、母版/接缝/来源 | art-director | 黄金合屏、资产 manifest、真实 GPU 与人工认可 |
| 独立体验/防伪审查 | gameplay-reviewer | 反例、实际消费者、ACCEPT/REJECT/UNVERIFIED |
| 大任务与完成声明 | game-quality-gate | 既有类型、G0–G5 和十一维；不以技术片签完整地区 |

`route --request` 输出既有生产循环任务计划，含依赖、Skills 和限制的可写范围；`--mode optimize|new_region` 可以明确路由。新地区设计阶段仅允许 docs/tests/tools，黄金与正式集成阶段再允许必要世界/Boss/美术/音频路径，仍不授权 PlayerMotor/保存/Run/配置重写。生成计划不代表已经自主完成新地区。

## 两种完整生产工作流

已有地区优化 A：

1. 读取最新正式实现与基线。
2. 收集原始反馈、Seed、设备/能力和路线。
3. 采集 Manifest/真实轨迹并建立诊断基线。
4. 排出最严重的具体路线/模块问题。
5. 写可观察体验变化与最小改进。
6. 制作少量黄金改进样板。
7. 验动作/资源、探索、美术/镜头和体验。
8. 推广已通过相关门槛的改进。
9. 原两图/生成/保存/生命周期/输入回归。
10. 同依据前后对照、独立审查，保留用户/设备待验。

全新地区制作 B：

1. 确定世界观、区域身份和难度定位。
2. 明确进入地区的实际合法能力与单武器构筑。
3. 设计不同于平原的核心机制。
4. 确定空间语法和视觉身份。
5. 设计专属机关、敌人与挑战及相互关系。
6. 制作最小黄金技术样板。
7. 验新机制和连续动作。
8. 建立有邻接/资源证据的模块库。
9. 生成多种有意义的非线性拓扑。
10. 联合编排内容、奖励、能力锁和回程。
11. 生产并组装美术，合屏验证功能可读。
12. 接入正式消费者并评测完整地区。
13. 修复最差 Seed、独立发现与玩家反馈。
14. 完成旧内容回归、正式集成和原质量审核。

两种流程共用五模板和同一机器合同。未来地区不必继承平原网格、风铃或 Boss；森林 fixture 使用非规则多层树冠设计，明确 design_only，不代表森林或未来能力已经实现，也不锁定地区数量与顺序。

## 已实现的专项检查与准确边界

| 专项 | 本轮实现 | 尚不能证明 |
| --- | --- | --- |
| Contract/Topology | schema/引用、能力分类与支持构筑、语义拓扑、授予和返回声明；排除所有大师边后按基础构筑检查目标路径，含间接授予依赖 | 几何图路径不证明真实碰撞；完整运行能力锁/换装/能量状态尚未穷尽 |
| Capability/Traversal | 真实当前装备与授予动作、Motor 参数/资源/冷却/构筑采样；正式 DemoApp Manifest，原 assembler/shotlatch 连续输入路径与状态 | 全武器、低资源/重试/相位组合、敌人遭遇与 Boss 战、实体设备 |
| Challenge | 设计动作依赖、资源/相位/恢复/设备字段；按路线区分设计意图、输入请求与实际观察的动作签名；重复动作候选 | 完整设计卡的所有入口出口/替代/时序/恢复条件已落实，或难度已校准 |
| Pacing/Encounter | 逐路线静态连接候选、实际落地低互动移动、连续压力意图/重复意图；定位 edge 和 tick | 未安装敌人的轨迹不能证明正式战斗节奏，也不能判定玩家无聊 |
| Visual | 当前场景身份折叠/重复候选及 SceneComposition 设计要求 | 实际 GPU 接缝、动态遮挡、镜头、审美或完整视觉多样性签名 |
| Evidence/Compare | 源/命令/日志/版本/完成标记/非空证据一致性、完整报告与描述符指纹、同依据统计差异 | 本地哈希不是外部记录的密码学身份认证；相同报告对照不是实际设计改善 |
| Foundry | 复用原真实 Motor 验证和输入回放；黄金卡与实际模板/种类/短语数量/原 batch SHA 绑定 | 基础技术底座不是已完成精美大师关卡，不晋级正式池 |
| Routing | 优化/新地区自动任务与依赖、专业 Skills、阶段化路径范围及正反例 | 全自动新地区创作或真人/设备签收 |

新增检查进入原 `tools/harness/profiles.json`，包括 `level-design-contracts`、`level-design-analysis`、`level-design-routing`、`level-design-golden-tests`、`level-design-runtime`、`level-design-golden`。原检查未删改标准。设计/比较输出 `REVIEW` 是保留体验审查边界，不等同完整内容 PASS。

默认观察策略为 `level-design-observation-v1`，校准状态 `uncalibrated_baseline_candidates`。例如低互动候选使用 2 秒/400 世界单位、静态连接 400 单位、重复链 3、压力意图 20 秒；这些只是可证伪的初始观察阈值，不是好玩标准。后续按地区×挑战类别×设备，结合黄金样板和真实反馈校准并版本化。不能为了通过样本放宽阈值或填入无意义机关。

## 已实测的命令与结果

以下结果来自 [最终独立审查](evidence/level_design_v2/independent_review/final_review.json)，对应冻结 `11827ba`，没有把未完成的 full Harness 包含在内。

| 执行 | 结果 | 范围 |
| --- | --- | --- |
| `python3 -m unittest discover -s tests -p 'test_level_design_*.py' -v` | 88 tests，退出 0 | 合同/分析/路由/黄金和故意失败例 |
| `capture --seed level-design-v2-baseline --strategies fast growth deep` | 137 assertions，0 failures，3 策略 | 正式 Manifest + assembler/shotlatch 真实 Motor |
| 对该 capture 执行 analyze | 退出 0；REVIEW；4 类有边界候选 | 真实本地调用一致性通过，非趣味通过 |
| 对同一 report 执行 compare | 退出 0；REVIEW；无依据冲突、统计差异全 0 | 对比正例，不是正式地图改进证明 |
| `foundry.py experience --count 6` | 6 短语、6 条连续三短语 itinerary | fresh 真实回放，3 张设计卡适配绑定；完整设计状态待验 |
| 独立 R1–R7 反例复验 | 退出 0 | 原缺陷拒绝/修复且合法替代通过 |
| 完整 `full` Harness | 首次因并发文档更新导致冻结快照变化被拒绝；冻结后重跑待完成 | `build/verification/harness/20261014T141019.038712Z/` |

真实策略：fast 2113 帧/5 边，growth 2106 帧/5 边，deep 2943 帧/7 边。Godot `4.7.2-stable (official)`；对应 Manifest Hash 为 `89e9b39286839734d9f8317a7513b50f1a79f5fe552c24573234d90264d03cdc`。

可直接复现：

```sh
python3 tools/level_design.py validate tests/fixtures/level_design_v2/plains_design.json tests/fixtures/level_design_v2/thorn_forest_design.json tests/fixtures/level_design_v2/golden_challenges.json
python3 tools/level_design.py capture --seed level-design-v2-baseline --strategies fast growth deep --output build/level_design_v2/before/capture.json
python3 tools/level_design.py analyze --capture build/level_design_v2/before/capture.json --output build/level_design_v2/before/report.json
python3 tools/level_design.py route --request '优化风铃平原' --mode optimize --output build/level_design_v2/optimize-mission.json
python3 tools/level_design.py route --request '制作荆棘森林' --mode new_region --output build/level_design_v2/forest-mission.json
python3 tools/foundry.py experience --count 6 --output build/level_design_v2/golden
```

实施一次经过授权的改进后，重新采集，保留同 Seed/能力/策略：

```sh
python3 tools/level_design.py capture --seed level-design-v2-baseline --strategies fast growth deep --output build/level_design_v2/after/capture.json
python3 tools/level_design.py analyze --capture build/level_design_v2/after/capture.json --output build/level_design_v2/after/report.json
python3 tools/level_design.py compare --before build/level_design_v2/before/report.json --after build/level_design_v2/after/report.json --output build/level_design_v2/comparison.json
python3 tools/harness.py --profile full --jobs 4 --release
```

可选 `analyze --policy <JSON>` 接受经过审查的版本化观测策略；具体字段见工具和 [统一说明](level_design_harness_v2.md)。以上 after 命令是后续用法，本轮没有冒称已改进正式地图。

## 独立审查：两次拒绝、七项修复、有限接受

审查者 `/root/independent_v2_review` 为独立只读子代理，没有修改被审查生产实现，也不代签用户/设备。第一次 `b2747be` 为 [REJECT](evidence/level_design_v2/independent_review/initial_review.json)；第二次 `7e4890a` 仍 [REJECT](evidence/level_design_v2/independent_review/second_review.json)；第三次 `11827ba` 为 [ACCEPT](evidence/level_design_v2/independent_review/final_review.json)，仅限工程切片和已测策略。

| ID | 原问题 | 修复及复验 |
| --- | --- | --- |
| R1 | 不完整合成 receipt 可被误判为真实调用来源通过 | 核对 schema/scope/命令/路径/日志/完成/源；明确仅本地一致性 |
| R2 | 空壳或重新哈希的空报告可进入 compare | 校验完整结构、描述符、统计与内容指纹；最终 CLI 证据封装后再计算；保留中途 compare 失败 |
| R3 | 没被接受的输入请求能清除低互动候选 | 请求与观察分开；无状态/资源效果的请求不证明有效互动 |
| R4 | 黄金卡可绑定错误模板/种类/短语数量 | 与原 batch SHA、实际 Manifest 逐项绑定；错误记录拒绝 |
| R5 | Godot 运行字符串与启动 banner 格式差异导致真实正例失败 | 按版本/状态/build 规范化，实际 fresh 正例通过，错误版本状态仍拒绝 |
| R6 | 把唯一必经大师路线标 hidden 就能绕过主路规则 | 排除大师边后对每个基础构筑独立搜目标，包含间接能力授予依赖；普通绕路正例通过 |
| R7 | 新地区计划派 Boss/美术等 Skills，却不给其实际目标路径 | 按阶段扩展必要 Boss/world/art/audio 路径；仍排除玩家/保存/Run/配置重写 |

初轮 Python 通过未掩盖独立反例失败；完整 REJECT→修复→复审链均保留。这也是本体系避免“漂亮数字即 PASS”的实际案例。

## 平原下一步最值得优化的具体位置

本轮可定位一个真实 **低互动候选**：

- Seed：`level-design-v2-baseline`；策略：`growth`。
- Edge：`plains/passage/area_0_2/area_1_2`，该策略第 2 条经过边。
- Tick：663–837；观测约 **2.9 秒 / 750.6 世界单位**。
- 现象：持续落地移动，没有记录到相应动作/离地/转向的有效观察。

这段证据来自 **没有敌人的 assembler/shotlatch 测试范围**。它不能证明正式场景无敌人或玩家必然觉得无聊；也可能承担观察、恢复、叙事与节奏留白。下一任务应先在同 Seed 正式场景复现，收集敌人、奖励、相机/画面与玩家反馈，再决定是合理留白、需要缩短回程，还是适合一个利用射击双重功能的短动作/决策。不能为了消除候选自动塞机关。

其他实际候选类别为 `repeated_action_intent`、`continuous_pressure_intent`、`scenery_identity_fold`。先把设计字符串、实际输入和玩家看到的场景对齐，再挑一个黄金改进；不要把四个候选都当已证实的缺陷。

## 未验证事项与保留的环境诊断

- 完整 `deliver.py --jobs 4` 在创建本地 HTTP socket 时被沙箱拒绝，退出 1；[原始日志](evidence/level_design_v2/deliver_socket_blocked.log)。未执行 GUI，不降低守门或使用旧版本截图替代。
- 首次 full 在测试期间更新文档导致 `Validation lane source differs from frozen snapshot`；[原始报告与日志](evidence/level_design_v2/first_full_snapshot_reject.tar.gz)保留，不能算完整 PASS。
- 本机没有可用 Xvfb；安装所需网络授权受阻，真实 GUI/本次 GPU 合屏与录像未验证。不能引用旧版本画面当本次证据。
- 实体键鼠/手柄/手机、目标设备性能、用户趣味/审美/手感未验证；触屏模拟也不能替代真机。
- 完整正式地图敌人遭遇与 Boss 完成未覆盖，已采轨迹仅 assembler/shotlatch；全合法武器、低资源入口、失败重试、所有动态相位和换装状态未穷尽。
- 黄金卡完整动作顺序/替代、入口出口、能量冷却、相机、失败恢复的全部设计要求尚未逐项落实；普通/进阶/大师的专属创意、难度和美术未验。
- 机制/探索/视觉的完整实测多样性签名、全自动新地区创作未完成；当前跨地区证明是合同 fixture 与可路由流程。
- 退出日志保留 ObjectDB/resource 清理警告；不能宣称无泄漏或性能通过。编辑器日志中的沙箱 socket/listen 和缺 Android build-tools 不被隐藏，未据此声明 Android/网络构建通过。
- full Harness 最终结果待补，独立审查没有代签完整项目回归。本地指纹只校验一致性，不认证外部人为改写记录。

因此本轮可声明“生产体系工程切片有真实消费者、实际反例和独立接受”，不可声明“正式平原已变好玩”“精美大师关卡已完成”或“全部设备通过”。

## 后续任务 Prompt

```text
请按 AGENTS 与 Level Design Harness V2，对风铃平原做一个有证据的黄金优化切片。
先 fetch 并确认正式消费者、最新资源/武器合同与独立分支。
复现 Seed level-design-v2-baseline 的 growth 路线，重点查看
plains/passage/area_0_2/area_1_2，已有 Motor 轨迹 tick663–837 的低互动候选。
旧证据没有敌人，先补同 Seed 正式敌人/奖励/镜头/画面与玩家反馈，判断是否合理留白。
若确有问题，只改这一类路线的最小设计：提高真实决策、射击双重用途、动作衔接或回程价值，
不改 PlayerMotor、武器、资源、随机流、保存，也不靠堆障碍或缩落点达标。
先做一份挑战/构图黄金卡，真实 Motor 连续衔接、低资源/相位和正常尺寸合屏通过后再考虑推广。
保留原失败与最差 Seed，使用同 Seed/能力/策略/阈值做前后对照，回归原两图与生命周期。
自主组织独立只读审查；实机/审美/趣味缺证据保持 unverified/awaiting-device/review。
提交独立开发分支并创建 PR，不默认合并。
```

制作未来森林时，使用 `route --request '制作荆棘森林' --mode new_region`、森林 design_only fixture 与工作流 B。先确定进入时的合法单武器构筑和真正不同的机制/空间身份，验证一个黄金技术样板，再扩展模块库、拓扑、遭遇、AI 美术系列和正式集成；不重建 Harness，也不把未来动作当现有主路保证。
