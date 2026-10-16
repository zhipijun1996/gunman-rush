# PR69 V3 独立执行证据审计

审计者 `/root/v3_evidence_audit`，只读；适用 game-quality-gate、gameplay-reviewer、art-director、visual-director。读取 AGENTS、current_state、handoff、原 budget、全套 V3 quality 文本和精选原执行档案。审计源为父任务指定 PR69 HEAD `4f2066fd`。未改生产代码、账本、原失败或质量判定。证据镜像 `/workspace/scratch/v3audit/`，结构化结果 `/workspace/scratch/v3-evidence-audit.json`。

本报告判断生产能力/证据/交付瓶颈，**没有打开游戏像素或播放影片，故不额外签美术、动画、音轨或玩家体验 ACCEPT**；下述视觉缺陷均明确来自已留存的不同作者原审查。44 次是原生产 host 请求，不是本轮全部 provider 调用；后继直接工程和独审不应藏进44内。

## 主要结论

V3 的真实收获是几个有限消费的手绘资产、RootBell 单一空间切片和大量原链路修复；没有达到整区商业美术或泛化自主生产目标。最大的浪费发生在“资产/空间需求不匹配后，再花集成、采证与独审成本证明不匹配”、验收消费者晚暴露兼容问题、稀疏证据/导入权限/控制器孤儿恢复，以及最终昂贵回归后的发布失败。14 次图生本身不是12小时主体：13次有工具wall数据合计636.724秒（10.61分钟）；RootBell首次只有请求到文件75.974秒与结果检索269.817秒上界，不能混作精确API耗时。模型实施纯推理、集成、返工、网络独占时间没有足够事件数据，无法可靠分摊。

最终本地 D `50fb10c749871cb555f24fab84b3f539abde49fb` 原12步 deliver均成功，子步骤总3461.096秒（57.68分钟），gameplay/art占2593.982秒（43.23分钟）。公开版仍PR67 `3dd966827a31`，V3没有上线。attempt1 1.2GB模板curl28超时与attempt2 terrain-family资源退出失败是两个独立事件；后者远端原内部日志缺失，PR69仅增强诊断，本地45/0仍被resource ERROR guard拒绝，根因未修。

## 证据驱动瓶颈与实际动作

| ID / 瓶颈 | 原事实、证据定位 | 实施建议与成功/失败验证 |
|---|---|---|
| B1 原画形体与真实消费者缺少可组合接口 | bank原比例未达、workshop500宽地基不容；CLIFF厚度必要条件131.485<146；PANEL full-contact失败；Boss v2 protected rect仍47525个alpha128像素、空隙285.328而非680。`art/*/production_report.md`、原family/tool_return | 生成前冻结真实union外边/落点保护/完整根/侧底连接及尺寸区间，按角色语义拆岩壁端/转折/连续体与独立有根植生。先一个实景后推广。正例：完整不拉伸源+真实根+接缝+三镜头；反例：放大石簇、根落单向桥、内侧连线侵入保护区、图集间隔不足、裁掉原脚。原失败不由另用途追认 |
| B2 中景植物的“有根”被整条坡脊视差替代 | woodland v1间隔21px<80，下层950宽仅236高；改远景用途后独审仍见水平根像wallpaper；v2间隔/padding/高度仍失败STOP，最终停用留下中景缺口。`woodland_root_repair.md`、`scene_layers_01.md` | 本轮植物应以真实地形的根锚/平台坡肩局部组与景层运动模型共同设计，而非一图两长树林。正例：根与支撑同坐标系，冠层产生有限动势；反例：根随parallax漂离、横底露边、遮唯一落点。不能拿停用旧图当作新增画质达标 |
| B3 联合空间设计晚于独立模块制作 | RootBell1/40地图、intro0/20/advanced1/20，只适用620 double_gear；80路线20地图RootBell=0。正式宏观岩体仍矩形/旧柱重复，资产目标与玩法所需尺度分离。`root_bell_encounter_v2_card.md`、`ecology_delivery_review.md`、delivery | 同一空间卡同时冻结主轮廓、进出视线、敌mark/射程/return、机关相位、玩家观察/绕过/打断/返程解、所需资产接口；保留已改进路线。只用少数现有geometry做黄金，不重写全平原。正例两种空间判断使用相同AI；反例只换位置/贴图、强制怪不死才可通路、替代唯一安全落点 |
| B4 生命周期错误被“功能断言通过”遮蔽 | terrain早期25/0后coverage失败，20map418/0仍退出resource错误；movie10ObjectDB/4resources；RootBell最终formal20/17；森林105ObjectDB/63resources。`terrain_family_01.md`、`forest_final_actual_loop/README.md` | 先用verbose/实例所有者/循环资源引用定位真实泄漏，保留ERROR guard；不要统一贴flaky或只加wait/maxfps。正例重复创建/释放后退出零错误；反例故意保留Node/Resource仍失败。区分原生场景断言、生命周期、宿主线程调度；本地复现不推定远端同因 |
| B5 对真实consumer inventory假设错误 | terrain假定每图有24×110，实际有24×619/429；旧v9/v10/v11背景/analysis/RunManifest/pressure消费者使最终回归多次拒绝；Web实际PCK缺raw而include声明已在。`terrain_family_01.md`、`final_release_failures/README.md` | 在素材/生态修改前生成实际消费者与形态inventory，改动后先受影响短专项，再完整发布。正例真实缺型正确fallback且代表型强测；反例删某正式consumer/改atlas/删PCK raw必须拒绝。不要为测试造不存在的形态 |
| B6 调用前依赖/权限预检不足 | evidence-repair实施后global quality276稀疏历史缺项且误跑Godot；森林预检遗漏38知识/历史依赖；terrain导入元数据越租约被blocked。`check_preflight.md`、`budget_audit.json`、`forest_final_actual_loop/README.md` | 现有preflight已覆盖许多此类问题，应复用而不是另造通用框架；新增真实任务包依赖解析（selected profile命令/历史record→evidence/导入sidecar），先calls0阻断再物化。正例exact同SHA物化后可派发；反例symlink/uid1000 unreadable/未选runner基础依赖/越权.import仍calls0。不能靠略过global quality |
| B7 控制器消失造成重验、响应孤儿 | enemy旧3calls含未消费R2，另2重验；terrain binding review真实ACCEPT但未收取；shared env旧running不改签；recovery drill3call含撤销review。`completed_lease_recovery.md`、`terrain_parent_integration/README.md` | 当前collector仅单任务首review有限适用；本轮沿既有checkpoint/resume/锁加入明确terminal与待收响应索引，优先复验响应/源/lease后收集，不能重派同nonce或回退款。正例同源终态replay0新调用；反例live controller/撤销/变源/同作者响应拒绝。不要声称任意kill恢复已成立 |
| B8 返工与验证预算挤占内容/发布 | 原40cap升44，全部用满；森林startup4+最终2共6/44（13.64%）是未来技术slice，content_complete=false；pipeline4+恢复drill3共7/44（15.91%）为明确process目标，非直接画面产出。`budget.json`、budget_audit、forest final | 无需否定这些有效工作，但本轮聚焦平原应不再跑森林。预算按依赖、风险与已准入家族分池；给独审与最终发布保留额度/时间，不以host计数冒充生产力。正例失败方向STOP而无关合格族继续；反例换task名隐形重开boss/woodland/岸体或吃掉最终review配额 |
| B9 发布供应链和断点恢复 | attempt1模板curl28、attempt255pass/terrain fail/最后forest未执行；短暂401轮询退后由宿主续查；publisher无正式resume。`final_delivery_50fb10c/README.md`、delivery | 工具链分engine/templates，缓存精确版本/校验；下载断点临时文件与完整校验；按网络/认证/完整性/代码失败分类有界重试。publish checkpoint绑定run_id/attempt/SHA/source_digest，恢复先查既有run，避免重复dispatch；artifact必须含native report/log。正例中断恢复同run并校验live build-info；反例错SHA/错attempt/401认证重试/测试失败被当network重跑 |
| B10 历史验证复用复杂而阶段成本缺失 | 80路线26复用54新跑，6版本798输入逐blob重建；PR68→V3严格纯美术比较REJECT，同v11挂藤前后才可比；host invocation seconds含工具/引擎等待。delivery、canonical comparison | 报告记录事件区间与父子阶段：实施、图生、集成、验证、审查、返工、网络等待、发布；并行用区间并集算wall而非相加。复用记录完整输入投影、正式consumer、命令/环境/marker和所适用质量范围；正例文档变化可复用明确专项，反例runtime/driver/source/asset变更必须失效。当前43.23分钟full harness是可比较基线，不凭27段不完整host时间估全12小时 |

## 阶段可见时间与产出

原窗口 UTC 2026-10-15 17:02:25 至 2026-10-16 05:02:25，最长12小时。预算文件status仍running、content_complete=false，不能仅凭deadline推定实际持续有效生产12小时。

- 44个唯一创建nonce全部记消耗，包括失败/撤销/中断；21:10审计时42，两个未创建reservation后来分配给真实森林implement/review，44终态不退款。
- 本审计取到33个与原hash对应raw response，27个原invocation可见seconds；合计17682.785秒是**重叠的角色elapsed局部和**，含角色内部图生、引擎/校验/等待，不是纯模型时间，不是全V3墙钟，不可加上图生后再报总成本。11个raw response/17个duration没有在本次文本审计中独立取得，逐项表明来源/缺失。
- 14次图生均有原PNG/provenance或tool_return。13次工具wall合计636.724秒，RootBell首次精确API duration未暴露，request→文件75.974秒可见、结果检索上界269.817秒另列。不要将269.817全归图生，也不要把PNG mtime代理当服务端计费时长。
- 最终local deliver12步总3461.096秒：Foundry构建41.775；stamp1.507；gameplay/art2593.982；3个Lab测试10.857；Windows构建10.545；web harness309.792；3个浏览器专项291.901；动作movie200.737。各子步骤有exit0；报告明确不含阶段间人工检查与调度开销。
- token、价格、image具体model ID、纯实施时间、专属返工时间、网络等待累计：not_exposed/未充分记录，不能回填虚构数字。

## 44次原调用逐项归属/结果/耗时可见性

序号是本审计按原budget审计排序生成，**不是V3原执行全局时间序号**；精确nonce/hash与来源在JSON。ready_for_review不等于审查通过，accept也只限原scope。

| 审计序 | task / round / role | nonce | 原结果或可见状态 | 角色elapsed秒 |
|---|---|---|---|---|
| 1 | CLIFF-01 / 1 / implement | `8f327b20` | ready_for_review | 584.659 |
| 2 | CLIFF-01 / 1 / review | `f21161c1` | reject | 243.403 |
| 3 | PANEL-01 / 1 / implement | `9516cdd8` | ready_for_review | 520.705 |
| 4 | PANEL-01 / 1 / review | `03c66216` | reject | 316.846 |
| 5 | V3-ASSET-01 / 1 / implement | `48e80ef9` | ready_for_review | not_exposed |
| 6 | V3-ASSET-01 / 1 / review | `945f83d0` | ACCEPT_SCOPED_original_spec_REJECT | not_exposed |
| 7 | V3-ASSET-BOSS-01 / 1 / implement | `1a2196cc` | ready_for_review | 233.253 |
| 8 | V3-ASSET-BOSS-01 / 1 / review | `58ff4deb` | reject | 285.076 |
| 9 | V3-ASSET-BOSS-02 / 1 / implement | `23a5e92a` | ready_for_review | 355.547 |
| 10 | V3-ASSET-BOSS-02 / 1 / review | `85c112c8` | reject | 143.934 |
| 11 | V3-ASSET-CLOCK-01 / 1 / implement | `d0051abe` | ready_for_review | not_exposed |
| 12 | V3-ASSET-CLOCK-01 / 1 / review | `70322d7f` | accept | 341.106 |
| 13 | V3-ASSET-WOODLAND-01 / 1 / implement | `0709669f` | ready_for_review | not_exposed |
| 14 | V3-ASSET-WOODLAND-01 / 1 / review | `514c1c2e` | reject | 494.601 |
| 15 | V3-ENCOUNTER-V2-01 / 1 / implement | `5d43d281` | ready_for_review | not_exposed |
| 16 | V3-ENCOUNTER-V2-01 / 1 / review | `abe97272` | reject | not_exposed |
| 17 | V3-ENEMY-01 / 1 / implement | `41a86158` | ready_for_review | 2398.453 |
| 18 | V3-ENEMY-01 / 1 / implement | `e8316ac9` | ready_for_review | 91.101 |
| 19 | V3-ENEMY-01 / 1 / review | `172458f2` | accept | 190.497 |
| 20 | V3-ENEMY-01 / 1 / review | `5cf14283` | reject | 350.487 |
| 21 | V3-ENEMY-01 / 2 / implement | `7b9ccc5b` | ready_for_review | not_exposed |
| 22 | V3-ENEMY-EVIDENCE-REPAIR-01 / 1 / implement | `43bca68a` | ready_then_checks_failed | not_exposed |
| 23 | V3-ENEMY-FORMAL-01 / 1 / implement | `288b275b` | formal_candidate_limited | not_exposed |
| 24 | V3-FOREST-STARTUP-01 / 1 / implement | `cd2a3f3c` | ready_for_review | not_exposed |
| 25 | V3-FOREST-STARTUP-01 / 1 / review | `ad2500ab` | reject | 282.717 |
| 26 | V3-FOREST-STARTUP-01 / 2 / implement | `e28bf887` | ready_for_review | not_exposed |
| 27 | V3-FOREST-STARTUP-01 / 2 / review | `eefef864` | reject | 340.661 |
| 28 | V3-PIPELINE-01 / 1 / implement | `b9042e58` | ready_for_review | 956.857 |
| 29 | V3-PIPELINE-01 / 1 / review | `8fcc6a9a` | reject | 154.119 |
| 30 | V3-PIPELINE-01 / 2 / implement | `0f3def7d` | ready_for_review | 311.999 |
| 31 | V3-PIPELINE-01 / 2 / review | `45736ed8` | accept | 245.555 |
| 32 | V3-REAL-RECOVERY-DRILL / 1 / implement | `b58fdf05` | request_created_terminal_not_recovered_in_text_audit | not_exposed |
| 33 | V3-REAL-RECOVERY-DRILL / 1 / review | `2413c86b` | request_created_terminal_not_recovered_in_text_audit | not_exposed |
| 34 | V3-REAL-RECOVERY-DRILL / 1 / review | `54dd34a0` | interrupted_revoked | not_exposed |
| 35 | V3-SCENE-01 / 1 / implement | `00757892` | ready_for_review | 1786.549 |
| 36 | V3-SCENE-01 / 1 / review | `2801f9a8` | accept | 431.348 |
| 37 | V3-SCENE-LAYERS-01 / 1 / implement | `76ecff0f` | ready_for_review | 2249.786 |
| 38 | V3-SCENE-LAYERS-01 / 1 / review | `977e8483` | accept | 857.946 |
| 39 | V3-SHARED-ENVIRONMENT-01 / 1 / implement | `bcea8bc1` | orphan_implementation_no_response | not_exposed |
| 40 | V3-TERRAIN-BINDING-02 / 1 / implement | `e08d05b2` | orphan_binding_worker | not_exposed |
| 41 | V3-TERRAIN-BINDING-02 / 1 / review | `e115d91a` | accept | not_exposed |
| 42 | V3-TERRAIN-FAMILY-01 / 1 / implement | `865f9a23` | blocked | 2810.526 |
| 43 | level-new_region-thorn_forest-prototype / 1 / implement | `17f02d8d` | ready_for_review | 547.619 |
| 44 | level-new_region-thorn_forest-prototype / 1 / review | `8ef93619` | accept | 157.436 |

## 14次图生逐项结果

下表按资产名排序，**不是全局调用顺序**。原图返回不代表原消费者合同达标；alternate-role另有有限正式准入不追认原规格。

| 家族/输出 | 可见秒数 | 原结果与最终用途 |
|---|---|---|
| bank_shoulder_wide_v1 | 52.329 | 原近岸比例失败；限定rear escarpment正式使用 |
| boss_open_tuning_court_v1 | 41.887 | 原quiet680/轮廓失败；未接入 |
| boss_open_tuning_court_v2 | 45.474 | 形体改善但quiet680原合同仍失败；2/2 STOP未接入 |
| clock_regulator_court_v1 | 47.851 | 源G0接受；真实钟庭限定使用 |
| distant_limestone_ridge_v1 | 35.417 | 独立远脊真实视差有限使用 |
| limestone_bank_section_v1 | 56.151 | 原420×152必要厚度失败；仅外露端/底采样新合同有限使用，body仍v8 |
| supported_overhang_limestone_bank_v1 | 53.800 | 厚139.9423<146且standing32.91%；2/2 STOP未接入 |
| suspended_mechanical_baffle_v1 | 46.730 | 原完整24×110/full-contact失败；新采样合同有限真实panel使用 |
| windmill_highland_v1 | 54.608 | 原240与实际200用途失败；完整146宽另合同有限使用 |
| windmill_repair_workshop_complete_v1 | 56.579 | 原500宽/比例失败；完整330宽真实静态地基正式使用 |
| woodland_two_depth_ridges_v1 | 53.624 | 原间隔/下层比例失败；改用途试景后横根wallpaper独审失败，最终停用 |
| woodland_two_depth_ridges_v2 | 38.041 | 120间隔/16padding/高度失败；2/2 STOP未接入 |
| root_bell | exact not_exposed；request→file75.974；retrieval≤269.817 | 正式RootBell动作/定点burst图集使用；不等于全生态或动画听音通过 |
| root_bell_burst | 54.233 | 正式RootBell动作/定点burst图集使用；不等于全生态或动画听音通过 |

## 建议本轮有界执行顺序与复核

1. 先隔离复现terrain退出资源错误并修真正owner/reference/teardown；同期只做原证据审计、真实union/RootBell consumer inventory和新旧截图基线。下载失败分类、发布resume可与游戏修复分离。
2. 选择自然岩壁连接与有根中景植物两个家族，单一真实平原空间卡明确轮廓/可读落点/根/敌人mark与机关；每族最多2轮，不合格保留STOP，无依赖合格族继续。先真实合屏，后小规模复用。
3. 优先复用现有RootBell mark→delay→fixed pulse/真实弹体interrupt、活怪绕过和死后通过机制，扩展成相反观察/撤离/返程空间判断。先证明每一种不同判断，而非调概率。具体形态合法性应由负责正式几何/AI审计者进一步验证。
4. 生产阶段报告必须直接来自实际调用/命令/事件，不止Skills新增文字；一次真实资产production与一次缺依赖/错素材/错source等负任务验证实际阻断/复用行为。
5. 定向短专项全绿且像素明确改善后只跑一次受影响完整profile和准确源build/publish。若失败保留断点，修复后仅允许指纹/依赖证明适用的复用；最终build/live fingerprint必须与本轮代码一致。
6. 独立作者审真实原尺寸游戏帧、至少连续进入/经过/返程窗口、RootBell正反解、完整退出日志及发布闭包。商用美术未达则明确REJECT，技术可试玩部署不代签用户/设备认可。

效率比较应报告本轮新资产准入/原规格失败/正式消费者覆盖、真正新增空间判断、各阶段可见wall与总wall区间，不用断言数/文档数/host数作为成绩。V3的14图生/44calls、1/40RootBell coverage、43.23分钟最终gameplay/art、57.68分钟deliver和未发布是准确基线；当前没有证据给出“本轮将提升X%”的承诺。
