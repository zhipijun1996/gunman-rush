# PR66–70实证成本及失败审计（只读）

审计读取：2026-10-16。远端证据固定到 PR70 head `92f9336620df052913f23e4c41cc205c6686a9dd`；PR70工程源为 `fe84b4937347c8f8dd43f2c916f84689fa87cd8b`。本分析未修改生产代码、测试、历史原件，也未发送 GitHub 评论。路径均相对仓库；远端文件本机副本位于 `scratch/creative-audit/remote/`。PR元数据原件 `scratch/creative-audit/pr-66.json` 至 `pr-71.json`。正文是证据入口，不把它当作全部原始运行日志。

## 已复算的量化基线

| 范围 | 可复算事实 | 不允许推出 |
| --- | --- | --- |
| PR69调用 | `docs/evidence/production_capability_repair/harness/v3-evidence-audit.json` 的44条 `calls`；27条有 `observed_invocation_seconds`，复算和17682.78535981699s | 不是墙钟、纯模型时间或全部provider调用 |
| PR69图生 | 同件14条 `images`，13条有 `seconds`，复算636.724s | 首次缺精确工具时间；不能补估；不可据此推总项目效率 |
| PR69本地deliver | 同件 `delivery.steps` 12项秒数复算3461.096s，gameplay/art单项2593.982s | 旧入口passed不代表严格clean：后续原日志审计发现3个outer check/14个suite终态错误 |
| PR70闭窗 | `.../final_blocked_checkpoint/costs/phase-costs-as-of.json` 的149条 `events` 端点自行求区间并集，精确复算6267.742584228516s（104.462min） | 不等于完整项目总工时；关闭后静态打包另记；无端点的duration-only原件不能加入并集 |
| PR70返工 | 同件 `/observed_as_of/rework_tag_interval_union_seconds` =3068.637612581253s | 与阶段重叠，不可再相加 |
| PR70图生/租约 | 同件 `/efficiency_comparison/current`：3图toolwall193.8s、supervisor217s；一个实际工程stage2次host租约，同源恢复0新calls | 任务范围不同，不得宣称44→2、14→3生产提速；该工程stage `content_complete=false` |
| 成本未知 | PR69 `docs/quality/region_production_v3/budget.json` 的`costs`，PR70成本件`policy`/`efficiency_comparison`均保留token/price/pure-model unknown | 禁止编造美元、token、纯推理或独占网络时间 |

PR70阶段并集的可引用中文入口：`docs/evidence/production_capability_repair/final_blocked_checkpoint/costs/阶段成本与效率比较.md:3`；阶段表各行互相重叠。验证2544.873s、发布/CI2886.295s、网络/工具链1277.483s不能纵向相加。完整机器报告存`phase-costs-as-of.json`；便携账本5个JSONL在同目录`portable-ledgers/`，其原SHA、便携SHA、仅凭证URL脱敏范围由`/portable_evidence/ledger_copies`记录。

## PR66–70观察到的失败链

| PR | 已证实问题和范围 | 可追溯入口 |
| --- | --- | --- |
| 66 | 真实宿主12次；首轮3次因工具缺陷blocked，涉及跨帧accepted事件复用、摘要/不存在原件被compare接纳、source race被历史分析重新接纳；不是创作成功。full首次缺17个build证据，第二次41pass/1web fail/5skip（Foundry旧basis），后续12/12 targeted补齐，不能称一次47/47。 | `docs/level_autonomy_delivery.md:19,65,67,84`；PR66 body；`docs/evidence/level_autonomy/final_validation/` |
| 67 | 31真实生产调用/cap33封账；路线到目标51→71/80，但9双侧策略仍败；共同成功样本受伤46→49，map2主路4→10；整体Q6 REJECT。live-PNG外环3007ticks/7断言1失败；仅省PNG对照6528ticks/8断言0失败，根因未证，不能倒签TTL或默认观察器可靠。 | `docs/plains_redesign_delivery.md:3,28,50,65,89`；PR67 body；`docs/evidence/plains_redesign/c4/outer_render_failure_review.md`及final_current原件 |
| 68 | 方向仍REJECT：首承壁不可见、次版过平、第三版破口改善但岸体/建筑接合和层次不达标。v3实机2008tick策略失败；同源headless3951tick成功不能覆盖；后续v4观察器API错误后修正影片3951tick/3955frame。网络stream中断不等于后台自治恢复。 | PR68 body；`docs/quality/visual_director/run_ledger.json`（每event保留stage/status/receipt），`docs/quality/visual_director/budget.md`，`docs/evidence/visual_director/` |
| 69 | 44真实创建调用、14图生，12h预算。完整本地deliver旧门禁通过；最新发布attempt1在1.2GB模板curl28失败；有界attempt2 core55过后terrain失败、最后兼容未运行。Windows/Web产物成功不等于部署。完整商业美术REJECT。 | `docs/region_production_v3_delivery.md:13,55,76,84`；`docs/quality/region_production_v3/budget.json`；PR70原日志审计入口下列 |
| 70 | 本地b675 deliver313.965564s中止，721 deliver486.656509s失败；region断言63/0/native0仍4ObjectDB/2resources。修正确owner后原15套region215.015s严格过。A3 CI缺9证据；A4 core1357s（Harness1248.788嵌套）30pass/1fail/30unrun，冻结484资产恢复错误要求当前manifest等于旧原件。修复恢复后真实encounter负例仍20ObjectDB/7scripts泄漏，取消候选失败撤回；没有第三CI、部署或main合并。 | `docs/quality/production_capability_repair/report.md:48–64`；`.../final_blocked_checkpoint/FINAL_REVIEW.md`；`.../costs/phase-costs-as-of.json`中的status/delivery、status/ci、events |

PR70最终terrain严格正428/0、负47/1预期native0/1且clean只代表terrain；不得抵销encounter失败。退出原理的已证范围是verbose挂起`GDScriptFunctionState`/Trace观察链；不是所有泄漏都Ogg，更不能把未知Godot C++内部owner编为已定位。PR69远端terrain内部日志曾缺失，不能用本地Ogg复现追签远端同因。见PR70报告`:48–62`。

## 根因判定及改进优先级

1. **昂贵阶段前置条件晚验有直接证据。** PR66缺17证据、PR70 A3缺9证据；旧闭包检查依赖本机build可见性。PR70新提交树G0用0.083918s在60卡/506引用找9缺件；应默认先跑此守门，避免CI后才补归档。不能省略原schema/SHA/真实消费者验证。
2. **历史重建契约与当前manifest混用有直接反例。** A4 frozen484仅manifest当前字节变化，恢复器要求与旧文件相等。历史应隔离恢复，并保留原manifest、archive及逐成员fingerprint；当前运行不应被历史manifest整体锁死。见报告`:60`，原Gitblob sidecar81391B。
3. **assertions/native0与严格退出脱节造成假绿。** PR69 57日志复审3outer/14suite终态错误；PR70正确严格guard把原来假绿变红，而非变慢。先保留严格guard，再消除具体owner/coroutine，不能吞stderr、弱化负例、把预期exit1当自动clean。
4. **形体和消费者接口晚验、整体空间缺乏统一方向有跨轮证据。** PR67两版小石放大构图失败、PR68岸墙三版局部修补仍REJECT、PR69树林/Boss/岸体失败、PR70岩壁两轮校准core .984501<.995后STOP。支持“先整体构图和接口约束→可玩垂直片→拆资产家族”的改造；不支持仅凭文件数删工具或把审美失败全归图生速度。见PR70报告`:22,26`与PR67报告`:67–69`。
5. **恢复/预算机制有有效能力但范围有限。** PR70实际host2租约、同源resume0newcalls、注入源漂移exit1且state/calls不变；表明真正恢复与源新鲜守门有效。无证据证明短Prompt已能全地区自动商业生产。失败停止、独审拒绝、原件留存值得保留。
6. **不同成本必须分开。** 下载curl28/403、源守门、Godot资源退出、资产接口失败、审美REJECT是不同成本桶。PR70两次本地交付失败+两次CI各不同源attempt1，无同源重跑；不能笼统称网络重试或无效返工。

## 需要纠正的边界与未完成项

- PR69正文“只平原不森林”不是全部历史执行事实。`docs/quality/region_production_v3/budget.json:/actual_counts/host_note`记最初42created/44allocated，两未创建reservation后来分配给真实forest implement/review；最终44created。`docs/evidence/region_production_v3/forest_final_actual_loop`记录终态2calls/content_complete=false、H185assert/169ticks及两480tick负例，仍非完整地区、正式授予H或用户认可。新演练应对照此已存在样板，避免又从零造一套。
- PR70有真实A4 Web artifact12035647459/source9ffe8e7/build8db51abc2fef、3browser72checks和ZIP/PCK identity通过；不是最终fe84b49包。公开metadata仍PR67/source2c290417/build3dd966827a31；不得冒称当前上线。
- 此次只读审计尚未逐个重新下载全部旧日志、运行Godot或核实所有历史源码消费者。失败技术解释以上述原运行报告/机器审计为归因依据；没有新独立运行即不升级为新通过。

## PR69可见长租约定位（后续应优先检查这些任务的内部动作）

以下按 `v3-evidence-audit.json:/calls/*/observed_invocation_seconds` 降序，包含工具/等待，不能当模型推理时间。四项共9245.32s，存在并行，不能当墙钟：

| task/role | 可见elapsed(s) | 原invocation索引 |
| --- | ---: | --- |
| V3-TERRAIN-FAMILY-01/implement（blocked） | 2810.53 | `docs/evidence/region_production_v3/terrain_binding_02/original_blocked/V3-TERRAIN-FAMILY-01/1/implement/invocation.json` |
| V3-ENEMY-01/implement | 2398.45 | `docs/evidence/region_production_v3/enemy/root_integration/legacy_host/V3-ENEMY-01/1/implement/invocation.json` |
| V3-SCENE-LAYERS-01/implement | 2249.79 | `docs/evidence/region_production_v3/scene_layers_01/controller_terminal/V3-SCENE-LAYERS-01/1/implement/invocation.json` |
| V3-SCENE-01/implement | 1786.55 | `docs/evidence/region_production_v3/scene/closure/raw/build/verification/v3-scene/V3-SCENE-01/1/implement/invocation.json` |

进一步读取这4条远端原件时，本会话gh API返回HTTP401 `Bad credentials`，故未逐条原件再验证；没有重试认证、没有把认证故障当项目代码问题。上表仅引用已成功取得的PR70逐调用机器审计。下载到本机的正文、成本报告、预算和逐调用审计仍可复核。
