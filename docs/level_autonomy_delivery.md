# PR66 自主关卡生产续轮交付报告

2026-10-14；任务 `LEVEL-AUTONOMY-01`、`PLAINS-AUTONOMY-01`、`PLAINS-ACTION-GOLDEN-01`；分支 `feature/level-design-harness-v2`，[PR66](https://github.com/zhipijun1996/gunman-rush/pull/66)。本轮已把原关卡生产体系推进到真实专业实施、独立反证、返工和两个正式平原有限切片：合法地标落地，以及“长按跨隙→稳定落地→短按释放过低顶”的动作改变。两个生产循环阶段均 `complete`，独立审查接受各自 G0/G1 工程范围，最终框架复审为 `ACCEPT_SCOPED`；47项回归由两次fresh release运行合并覆盖，未取得单次47/47 full PASS。`content_complete=false`。完整游戏质量、最终趣味、美术和实体设备尚未验收。PR 未合并 main，本轮未发布。

本报告覆盖此前“PR66仅工具、不改正式平原”的历史描述。实际修改经过用户授权的有界切片，保留唯一 PlayerMotor、单一当前武器、资源服务、随机流和保存边界。冻结动作运行源码共617文件，原件在 `build/level_autonomy/frozen_action_617/`；来源标签 `b6337d7b51385eb4fb6d57b3e44c3ed59cfe2040` 必须结合逐文件 SHA 与工作区补丁理解，不能声称它就是包含全部未提交改动的远端提交。

## 权威与自主决策边界

每次优化/新地区任务自动读取 [地区V0.3](design/player_actions/regions_v0.3.md)、[武器V0.8](design/player_actions/weapons_v0.8.md)、[最新动作入口](design/player_actions/README.md)、实际 Runtime/Definition、[Q1–Q8](quality/level_quality_dimensions.md) 与带来源的经验。authority ledger 保存路径/章节/Hash、原条款、LOCKED/PROPOSED、实现消费者、真实授予和适用范围。既有 S1–S6、16地区、H/W/D/U1/U2、S2单能力、S4替代与S5双移动+U1均继承；LOCKED不代表运行实现或正式授予，15武器候选也不能当同一时刻可组合多武器。

简短需求的技术步骤由团队继续完成，常规Bug不交用户逐项发现。用户负责核心创意取舍、审美偏好和最终体验认可；实体设备另验。当前CLI实际探测401/token refresh failure、exit1，原件保留。实际执行使用当前真实Codex宿主接同一controller租约、委派专业代理和不同只读审查代理。没有宿主的独立shell会超时停止；route计划、模板、mock worker和认证失败均不算自主生产成功。

## A．同一Harness的真实执行闭环

入口、任务类型、production_loop、G0–G5与十一维均沿用 [原Harness](harness.md) 与 [真实执行协议](quality/level_autonomy_execution.md)，没有新增一套评分/审批体系。八项专家启发式服务Q1–Q8诊断，再映射回原十一维；专家判断不能代签玩家或设备。

实际链为：冻结授权/源码/Seed→读取权威与诊断→专业设计备选→受限实现→真实checks→不同代理只读反证→finding返工→复验→保留前后原件。实施租约的原allowed_paths没有扩大；必要权威修订写回原租约实施目录，controller按原来源边界验证。中断/恢复、blocked、旧响应、失败检查和原REJECT均保留，没有复制旧通过顶替新执行。

首轮3次调用因R-A1–R-A3工具缺陷正规blocked，后续修复accepted事件跨帧复用、摘要/不存在原件被compare接纳、rejected source-race被历史分析重新接纳。R-A4恢复complete一致性与地区权威冲突也有独立复审。本次宿主账本：历史7次＋导航2次＋动作blocked1次＋动作versioned2次＝12/12。跨目录总预算由本次宿主核对；执行器硬预算仍按单mission，不是全局预算服务。

导航 `build/verification/level-autonomy-navigation-final/state.json`：calls2、complete，实际finalizer `/root`，reviewer `/root/navigation_final_review`；五项真实checks为docs、plains-autonomy-golden、level-formal-runtime、art-plains_spatial_art、region，均exit0。动作 `build/verification/level-autonomy-action-versioned/state.json`：calls2、complete，实际implementer `/root/action_finalizer`，reviewer `/root/action_versioned_reviewer`。独立代理重新运行当前正式黄金、反例与源码/版本检查后ACCEPT G0/G1；没有签G2–G5完整内容。

## B．设计专家Skills、Q1–Q8与交付接口

| 请求/问题 | 首责Skill | 实际责任边界 |
| --- | --- | --- |
| 优化既有地区/新地区组织 | region-generator | 权威、六层编排、黄金推广及同条件回归 |
| 长按/短按、反冲、连续衔接 | challenge-choreographer | 实际单武器/合法能力、输入与资源决策 |
| 模块端口/邻接/相位 | level-module-creator | 真实Definition、Motor、全身碰撞准入 |
| 敌人/平台/奖励/回程节奏 | encounter-director | 联合安排及替代；新敌人/Boss交原专责 |
| 空间身份/焦点/镜头/接缝 | scene-composer | 构图与功能可读，正式消费者合屏 |
| 风格、母版、系列素材/来源 | art-director | 实际资产生产、许可、透明/锚点与动态审查 |
| 独立反证/失败再现 | gameplay-reviewer | 新只读代理，ACCEPT/REJECT/UNVERIFIED |
| 质量记录/完成声明 | game-quality-gate | 原任务类型、G0–G5、十一维，范围不外推 |

| 交付组 | 主要文件/消费者 |
| --- | --- |
| 权威/Q/执行合同 | `docs/quality/level_quality_dimensions.md`、`level_autonomy_execution.md`、`level_autonomy_design.md`、`docs/level_design_harness_v2.md`、`AGENTS.md` |
| 经验与验收模板 | `docs/templates/level_experience_acceptance.md`、对应Skill中的来源/反例条款及authority ledger |
| 路由/权威/专家上下文 | `tools/level_design.py`、`level_region_context.py`、`level_design_contracts.py`、既有production_loop/harness |
| 正式采集/诊断/比较 | `tools/level_formal.py`、`level_formal_capture.gd`、`level_experience.py`、`level_visual_capture.py`、`level_design_analysis.py`、`tests/level_formal_trace.gd` |
| 导航实际代码/黄金 | `scripts/art/plains_region_scenery.gd`、`scripts/demo/plains_region_stage.gd`、`tests/plains_autonomy_slice_runner.gd`、`tools/run_plains_autonomy_tests.py` |
| 动作实际代码/黄金 | `scripts/generation/plains_route_recipes.gd`、`plains_region_generator.gd`、`tests/plains_action_golden_runner.gd`、`tools/run_plains_action_golden_tests.py` |
| 记录/任务/报告 | `docs/quality/records/LEVEL-AUTONOMY-01.json`、`PLAINS-AUTONOMY-01.json`、`PLAINS-ACTION-GOLDEN-01.json`、`docs/tasks.md`、本报告、current_state、handoff |

实际可执行CLI如下。它们是复验入口，不能把这段示例本身当成功日志；route后由真实宿主把计划收束到授权路径和预算，再执行mission。

```sh
python3 tools/level_design.py route --request '优化风铃平原' --output build/level_autonomy/mission.json
python3 tools/harness.py --mission build/level_autonomy/mission.json --execute --worker-mode host --evidence-dir build/verification/level-autonomy-run
python3 tools/level_formal.py --seed level-design-v2-baseline --seed-count 10 --maps 1 2 --strategies fast growth deep return --jobs 3 --output build/level_formal/new_capture
python3 tools/level_design.py experience analyze --batch build/level_formal/new_capture/batch.json --output build/level_autonomy/new_report.json
python3 tools/level_design.py experience compare --before build/level_autonomy/before-report.json --after build/level_autonomy/new_report.json --output build/level_autonomy/new_comparison.json
python3 tools/run_plains_autonomy_tests.py
python3 tools/run_plains_action_golden_tests.py
python3 tools/harness.py --profile full --release --jobs 4
```

经验回流保留事实、代理指标、AI推断、权威冲突、版本/消费者、正例与反例：props0只说明冻结消费者过滤/支撑问题；低互动候选须审查观察/恢复/叙事用途，不能每段加敌人；长按和短按的实际时长比种类Hash更能区分该短语；方向通过必须同身连续返回；getter-only资源属性必须读回实际值；内容版本更新不意味着RNG升级，也不意味着旧Manifest可在新源重演。一次Seed的几何修复不能推广成所有地区的硬规则。

本轮导航复用现有资产，没有调用图像模型造新图。未来美术按已认可母版→真实工具/完整prompt→原图来源许可/Hash→透明裁切锚点→导入→正式合屏→正常速度动态执行；未知来源/工具未用如实写unknown/unverified。外部方法只复用项目既有阅读范围，不声称本轮完整看过GDC或游玩过原作。

## C．质量定位、实际返工与独立审查

真实保留的动作失败包括20尾缝端口不合法、短thorn-hop反向不安全、GDScript浅Array副本污染fixture；独立reviewer又发现“low”组只给getter-only current赋值，实际仍满精力。通过合法consume、起点读回精确0及重跑修复，原假覆盖证据不删除。审查还独立制造collar omission/不安全margin拒绝，核对旧v8拒绝、新RunManifest roundtrip与冻结源码。独立接受对象是当前G0/G1切片，不是最终全游戏。

导航审查记录NAV-OBS-01（AtlasTexture空resource_path导致身份不稳定）、NAV-CAP-01（1200 terminal/stride重复路径令截图SHA不符）、NAV-EXIT-01（坏Sprite退出4 ObjectDB/2 resource警告）。1199补充包只是局部有效画面，未消除1200工具bug；原failed包保留。当前工具已修复1200唯一截图、Atlas身份和历史v8 scenery projection来源约束：实际1200/stride120采集为11张唯一截图（0..1200）、status=captured；focused检查experience15、analysis24、routing10、receipts11通过，历史80/phase对照观测器仍按冻结原件重算，不能用新工具重标旧结果或放松SHA。新1200包仍为 `frame_budget_exhausted`，只证明截屏边界有效；实际日志仍有8 ObjectDB泄漏与2 retained-resource警告，不能宣称无泄漏。

| Q维度 | 已有事实 | 未验边界 |
| --- | --- | --- |
| Q1探索 | 两个合法稀疏地标，局部轮廓区分 | 玩家回认、选择价值与记忆 |
| Q2动作 | 正式hold43/7变化、连续双向低精力黄金 | 玩家学习/技巧乐趣、其他武器/设备 |
| Q3联合战斗 | 正式敌人保留，实际接触/伤害和相位对照 | 存活/离开/死亡/未激活四态联合矩阵、失败再试 |
| Q4地区 | S1–S6/16区及能力权威，森林9checks dry-run | 新地区消费者、运行H正式授予、完整机制进化 |
| Q5节奏 | 26→27候选真实保留，两策略目标变化 | 留白用途与整局情绪/趣味 |
| Q6视听 | 地标与动作局部合屏、真实正常音画 | 全Seed动态遮挡、完整听看、用户审美 |
| Q7重玩 | 区分结构/动作/互动/探索/视觉，实际一行变化 | 长期重复游玩、有意义选择多样性 |
| Q8公平工程 | 真低精力、坏岸拒绝、受限租约/源绑定 | 真机负荷/性能、完整生命周期/泄漏、最终认可 |

完整Boss战役、未实现能力/成长接入、手机/手柄实物、目标硬件性能与用户趣味/审美仍未验。synthetic PC router和浏览器GUI技术动作均不能证明实体掌机/手机。

最终独立 `/root/final_framework_review` 已实际给出 `ACCEPT_SCOPED`：接受有界自主框架、专业/权威路由、本地源码/租约/证据一致性、正式平原当前代码G0/G1与合并fresh回归覆盖；不签完整地区/模块库、G2–G5、用户或实体设备。其独立复核13个归档、3084成员Hash、4个真实host角色nonce/canonical身份；实际重跑production_loop37、receipts11、experience15、analysis24、routing10、quality26及黄金正反例。Hash/lease仍是可信宿主下的本地一致性机制，不是外部身份认证。

最终回归必须按真实多次记录读取：首次full（`20261014T191002.107447Z`）因隔离工作区缺17个build证据引用失败，已用可携带原件绑定修复，原失败保留。第二次full release（`20261014T192052.042354Z`）声明47项，实际执行42项，41通过、1项web-build失败、5项依赖跳过，Foundry严格basis保护拒绝旧来源；失败状态没有改写。真实重验证Foundry36短语/18连续路线后，56JSON的326值仅basis/hash/manifest_hash更新，几何/能力/输入/轨迹不变。最后fresh targeted release（`20261014T194018.990751Z`）12/12通过，包含web-build/web-bundle及此前5个缺项、质量/路由/loop复验。两次回归合并覆盖全部47项，**不能写单次47/47 full PASS**。此前V2 40/40与单项黄金也没有替代本轮回归。

最终审查还实际发现通用小写task ID的done变更漏被大写限定diff parser守门；修复safe-ID解析后，原真实Git小写/大写反例均拒绝，独立quality26通过。旧check_docs依赖parser仍较窄，运行mission拓扑依赖验证仍生效，没有发现内容/G5完成绕过。原REJECT/失败、修复与复审均保留。最终原件已归档到 `docs/evidence/level_autonomy/final_validation/`，原build目录不删除。

实际浏览器GUI已由原工具重试完成：[报告](evidence/level_autonomy/final_validation/browser/browser-report.json)8checks、failed0，build_id `b7a77bbe1b5b`，1280×720 Chromium触屏模拟，实际WebM与PNG留证。独立profile一次注入9notes是存档边界fixture，真实Home互动/按钮买vitality1消耗5，再reload保存4notes/vitality1；真实departure生成20节点正式平原、无fallback；迷雾大图隐藏未见终点，focus/wheel zoom/drag/Escape通过；真实键鼠长按跳、移动、鼠标释放和短跳有画面变化。未检出script/shader/pageerror，但日志1条404保留，不能写零console warning。该段未实际捡到notes，earned-note reload仍unverified；不是完整地区遍历、Boss胜利或实体手机/手柄。首次缺Playwright FFmpeg的失败报告/日志保留，实际下载安装后同工具单次重跑通过。任务仍review/awaiting-device；有界工程范围接受，整款游戏高质量尚未完成。

完整build原件包括：CLI401；所有blocked/interrupted/recovered租约、prompt/request/response/schema；原审查REJECT/修复/复审；基线80、导航80、动作80、相位前后各8；动作控制对照；黄金正负例；媒体与原1200/108失败；基线615、导航616、动作617冻结源。历史schema1基线显式匹配 `e56c29d` 的615文件，原运行标签 `7c981ee` 不重写。[已归档索引](evidence/level_autonomy/package-index.json)列逐文件SHA和压缩原件；解包到仓库根可恢复原相对路径，Hash是本地一致性校验，不是外部身份认证。

## D．正式平原优化与原始前后证据

导航修复实际消费者 `PlainsRegionStage → PlainsRegionScenery`：32高junction不再被旧40最小厚度过滤，Stage传入真实支撑，让既有A竖拱与B低石群稀疏地标落在合法实体地面。黄金正例32断言/0失败、exit0；实际Sprite上移20的反例32/3、exit1。检查的是实际Sprite底边、StaticBody支撑和局部避让；暂停fixture只证明该技术范围。

动作先从真实已到达路线选问题，而非虚构一个方便测试的Seed：`level-design-v2-baseline/02`，map2、deep，attempt0，`area_3_1→area_4_1`。保留旧配方、短thorn-hop备选和失败，最终只替换既有 `thorn_gap` 一行：`plains_thorn_cells → plains_gear_brook` 改为既有certified `plains_thorn_bridge`340＋`plains_low_arch`640。玩家先长按跨隙，落地恢复后读低顶，再短按、7tick释放。未新增动作、能力、武器或强制损血/射击回能要求。

980长度留下20尾缝，原20薄台端口验证失败。最终仅该组合/该尾缝向左叠入实心arch20，生成40宽collar，右端及接收侧one-way不变；geometry序列化 `standing_margin=16`，实际hydration消费者重建distinct ports，12半宽身体仍有4支撑余量，其余节点默认20。没有放宽通用薄台规则。内容版本v8→v9，RNG派生版本仍v4，selector、随机抽样规则、其他recipe、Motor、武器/资源和MetaSave不变；[兼容与迁移](quality/plains_v9_migration.md)单列旧Manifest边界。

冻结阶段黄金171断言/0失败、exit0原件保留；最终当前黄金追加16项按真实accepted_tick排序、连续落地后下一跳的断言，187/0、exit0。四组入口方向×初始精力普通/真实0（100、0、100、0），每组同一生命/同一Motor出发及返回，共8条连续leg；原不可变driver、全身扫掠、实际接受jump/release/landing与自然资源保留。实际删除接收岸collider，29断言/4失败、exit1，证明坏几何被拒绝。黄金没有敌人，正式活敌人观测另列，不能外推完整战斗路线。

| 同条件正式观测 | 原始v8基线 | 导航后v8 | 导航＋动作v9 |
| --- | --- | --- | --- |
| 10 root Seed×2图×fast/growth/deep/return | 80份 | 80份 | 同一80份 |
| 策略目标到达/死亡/策略失败 | 16/58/6 | 16/58/6 | 18/56/6 |
| 低互动候选 | 26 | 26 | 27 |
| textured props | 所有案例0 | 64组＋2、16组＋1 | 保留导航切片 |
| Manifest/动作/结果 | 原始基线 | 80对所有非视觉数据无差异 | 内容版本/配方改变；78组outcome不变 |

v9两组变化为root Seed00、map1的fast/growth由死亡到策略目标；这80组没有新增死亡/策略失败结果。目标是采集策略终点，不是Boss全通关、玩家成功率或趣味分。额外两图×fast/deep×wait60/120的8组相位：旧3目标/3死亡/2策略失败，新5目标/1死亡/2策略失败；两处wait60 fast（map1、map2）由死亡到目标。既有死亡、策略失败和最差Seed全部保留，候选增加也没有藏掉。

实际控制差异最明确的一段仍是Seed02、map2 deep：旧tick3276..3630，新..3631；两次jump旧hold43/43、air42/42，新hold43/7、air42/20。两边该段HP均2→1，各一次敌人接触，recovery0、shot0。它证明真实输入时长和空中轨迹改变；没有证明敌人接触消除或玩家更喜欢。原 `actual_action_signature` 只编码事件种类，单看jump/landing序列会漏掉hold差异，故另留 `action_control_comparison.json`，不得以种类Hash签动作丰富度。

正常速度前后媒体匹配同Seed02/map2/deep：before使用冻结导航616来源的独立项目，3755物理轨迹ticks、33截图、目标到达；after retry3756物理ticks、33截图、目标到达。实际MP4分别3761/3762视频帧，含各6初始化帧，时长62.683/62.700秒；物理tick不等于movie frame数。均正式相机1280×720、真实Xvfb/llvmpipe、60FPS/48kHz双声道。开头先显示正式boot地图，再由真实loader载入请求的map2，这是合法独立测试入口，不冒称已打赢map1 Boss。宿主实际看before3360刺台跳、after3360跨隙落岸、after3480低顶齿轮段，能确认局部空间差异。首份after108tick `tutorial_policy_failed`及accepted-jump失败保留，原因未闭环，不能归因CPU或宣称录像全确定。正常音画产物、静帧查看不等于完整播放/听音审查、实体输入或目标设备性能。

## E．荆棘森林沿既有权威的制作演练

荆棘森林仅design/authority/route dry-run，9项checks，沿既有S2-H与基础动作；H运行授予尚缺，不能暗加W/D/U1/U2、开放地区、生成新美术或完成森林。 已实际读取LOCKED阶段/能力与PROPOSED候选矩阵，保留来源账本；S2森林仅H＋基础动作，单一当前武器。dry-run证明工具读取规则并组织设计依赖，不能证明森林可达、完整资产或正式生产成功。新地区流程为权威/合法基础构筑→地区身份和六层设计→机制黄金→连续模块/遭遇/构图→正式集成→旧内容回归→独立与玩家/设备验收；未来森林不复制平原网格、Boss或地标要求。

## 可以下载和复核的证据

| 证据 | 固定文件 |
| --- | --- |
| 最终回归与框架复审 | [47项合并覆盖](evidence/level_autonomy/final_validation/coverage_summary.json)、[full1原失败](evidence/level_autonomy/final_validation/20261014T191002.107447Z-report.json)、[full2原失败](evidence/level_autonomy/final_validation/20261014T192052.042354Z-report.json)、[fresh12/12](evidence/level_autonomy/final_validation/20261014T194018.990751Z-report.json)、[独立审查](evidence/level_autonomy/final_validation/review.md)、[最终原件包](evidence/level_autonomy/final_validation/final-regression-and-independent-review.tar.gz) |
| 最终浏览器GUI | [实际报告](evidence/level_autonomy/final_validation/browser/browser-report.json)、[build-info](evidence/level_autonomy/final_validation/browser/build-info.json)、[WebM录像](evidence/level_autonomy/final_validation/browser/video/page@251dc83ff721fad1a767fdbd1c6284fd.webm)、[原FFmpeg缺失失败](evidence/level_autonomy/final_validation/browser_missing_ffmpeg_failure.json) |
| 原始80基线/导航/动作 | [baseline archive](evidence/level_autonomy/baseline-80-originals.tar.gz)、[navigation archive](evidence/level_autonomy/navigation-after-80-originals.tar.gz)、[action archive](evidence/level_autonomy/action-after-80-originals.tar.gz) |
| 严格报告与配对 | [baseline](evidence/level_autonomy/baseline_report_strict.json)、[navigation compare](evidence/level_autonomy/navigation_comparison.json)、[action compare](evidence/level_autonomy/action_comparison.json)、[实际hold对照](evidence/level_autonomy/action_control_comparison.json) |
| 相位8组 | [原phase archive](evidence/level_autonomy/phase-before8-after8-originals.tar.gz)、[action phase archive](evidence/level_autonomy/action-phase8-originals.tar.gz)、[action phase compare](evidence/level_autonomy/action_phase_comparison.json) |
| 全执行/原失败/独立审查 | [production archive](evidence/level_autonomy/production-execution-failures-and-reviews.tar.gz)、[截图边界/录像失败](evidence/level_autonomy/rendering-failures-and-boundary.tar.gz) |
| 冻结源615/616/617 | [baseline source](evidence/level_autonomy/baseline-source-615.tar.gz)、[navigation source](evidence/level_autonomy/navigation-source-616.tar.gz)、[action source](evidence/level_autonomy/action-source-617.tar.gz)、[action source manifest](evidence/level_autonomy/action-source-manifest.json) |
| 动作前后正常音画 | [before MP4](evidence/level_autonomy/media/action_before/gameplay.mp4)、[after MP4](evidence/level_autonomy/media/action_after/gameplay.mp4)、[before capture](evidence/level_autonomy/media/action_before/capture.json)、[after capture](evidence/level_autonomy/media/action_after/capture.json) |
| 动作原帧 | [before3360](evidence/level_autonomy/media/action_before/frame_003360.png)、[after3360](evidence/level_autonomy/media/action_after/frame_003360.png)、[after3480](evidence/level_autonomy/media/action_after/frame_003480.png)、[全部before screenshots](evidence/level_autonomy/action_before-screenshots.tar.gz)、[全部after screenshots](evidence/level_autonomy/action_after-screenshots.tar.gz) |
| 导航前后正常音画 | [before MP4](evidence/level_autonomy/media/navigation_before/gameplay.mp4)、[after MP4](evidence/level_autonomy/media/navigation_after/gameplay.mp4)、[after1440](evidence/level_autonomy/media/navigation_after/frame_001440.png)、[after1560](evidence/level_autonomy/media/navigation_after/frame_001560.png) |

压缩包包含原仓库相对路径、原JSON与逐文件manifest；解包到独立工作区复核，避免覆盖当前工作树。精选MP4均小于100MB，原AVI/全帧大产物留build，原失败不删除。完整来源以各receipt/source manifest为准，媒体报告的source_commit标签不能替代逐文件source_files。

最终包装的独立只读[复审](evidence/level_autonomy/final_validation/postpack-review.json)再次给出 `ACCEPT_SCOPED`；完整[修改文件及SHA索引](evidence/level_autonomy/final_validation/changed_files.json)和[发布证据SHA索引](evidence/level_autonomy/final_validation/published-files.json)用于复核，均不替代玩家认可。

## 五个交付问题

1. **下次只说“把平原做得更有趣”，可以自主完成什么？** 能读最新权威、路由、采样与诊断，设计备选、受限实现、真实检查、不同代理审查、返工及对照。本轮已真实完成导航和输入时长变化的G0/G1有限切片；主观好玩与整图完成仍需相关证据，standalone CLI401时须真实Codex宿主接租约。
2. **说“开始制作荆棘森林”，能组织制作吗？** 能按S2-H自动加载地区/武器/叙事/美术/能力锁、建立依赖和专业分工。本轮只证明9checks dry-run；实际H授予、新机制/模块/敌人/资产、正式集成与完整验收须真的实施。
3. **怎样主动发现无聊、重复、敌位和视觉问题？** 从实际轨迹/资源/敌态/镜头定位候选，由专家判断合理留白与真实决策，写可证伪finding交责任Skill，再固定条件验证和独立反证。障碍数、装饰量、Hash和策略到达数都不单独签好玩。
4. **本轮真实改善了什么？** 两个原先全0的地标能合法落地；单一既有配方形成长按跨隙接7tick短按低顶，实际空中时长42→20。80组中两策略从死亡到目标，额外相位8组中两处同样改变；仍27候选、56死亡、6策略失败，不宣称整局体验已经优秀。
5. **哪些自动，哪些需要真人/外部工具？** 权威加载、host委派、采集/严格重算/比较、检查、独立技术反证、预算检查与明确停止、归档已真实可用；中断后保留记录，经宿主检查重新准备；新画风/核心创意取舍、最终审美趣味、实体输入与硬件性能要对应真实证据，实际CLI登录/AI图像工具也须可用，CLI401认证失败不能由执行器自动修复。技术缺陷继续自主修，不把这些边界变成常规每步审批。

建议下一次prompt：“沿已验证Harness、最新权威与Q1–Q8，先由独立设计审查结合正常音画辨别平原27个低互动候选的观察/恢复用途，再选一个小范围敌人—地形联合实验；保留真实四敌态、低资源、失败重试与返回，固定原最差Seed和10Seed两图矩阵。由专业Skill实施、不同只读代理反证与有界返工，用正常速度音画和实际输入/资源说明决策变化，更新PR与原质量记录；保留最终玩家/实体设备未验，不代签好玩。”
