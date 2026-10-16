> 本文源码行号与只读发现基于main e8ee3444的审计快照，末节第一轮精简数字已被后续恢复标题覆盖；当前精确值以docs/archive/skill_history/manifest.json为准。

# Skills / Harness / 消费者只读审计

审计依据：2026-10-16 GitHub main tree `e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7`；API抓取的16份SKILL、AGENTS、Harness/production_loop/profile/route，另取公开raw源的关键正式消费者与runner。原件在 `source/`，机器清单 `skill-inventory.json`。这是源码审计，不把历史文档声称当本轮运行实证。未删除或修改生产内容。未验证全部资产可达性，不能据此批准删除任一资产家族。

## 已有效、必须继承

- 原体系不是只有管理空壳。`tools/harness.py:120-170` 有超时、子进程回收、完成标记、引擎/生命周期错误拒绝；`:236-266` 缓存重新核对输入digest、日志、完成标记、原artifact与live output字节；`:296-383` 隔离Godot缓存/用户目录的并行lane；`:394-398,428` 已有targeted check、reuse和release禁复用。不得新造同义runner或取消退出检查。
- `tools/production_loop.py:132-315,1168-1177` 在分配worker预算前核对实际检查、路径、依赖；`:897-1012` 保存并核对实施/检查/审查/质量phase checkpoint；`:1068-1112` 有界传输重试；`:42-86` mission与单方向call预算/拓扑依赖；`:1046-1060` 独立身份约束。应在此扩展，而非另写生产循环。
- `tools/level_design.py:178-323` 已能从短请求加载地区上下文、经验、合法能力，制作九包生产依赖及auto原型入口。`region-generator/SKILL.md:134-146` 明确森林S2-H只是隔离技术片；不能删掉它，也不能将auto当整区自动制作。
- 职责已明确：`scene-composer/SKILL.md:9-39` 管空间，art管资产/风格，animation管动态，encounter管敌人与路线共同决策，reviewer只读。`visual-director/SKILL.md:10-26` 已有大形先行、黄金真实合屏、有界返工；不能笼统指责“现有完全没有整体画面流程”。缺的是更上游、可强制绑定的整个区域创作意图与方案选择。

## 可证实的结构缺口

1. **创意回退与淘汰没有执行语义。** `production_loop.py:22-35` result仅ready_for_review/accept/reject/awaiting_acceptance/blocked；`:1270-1290` reject只沿原task有界返工，source没变才阻止。不支持RETHINK回预制作、DISCARD隔离候选，也不以“画面/体验没进展”判停。Skill中两轮无进步规则（visual-director:23,42）依赖代理判断，没有结构化执行回执。
2. **没有绑定区域总谱。** `level_design.py:214-230` design四技能开始，后续生态/Boss/资产/动画包；`:263-287` task合同有goal/skills/checks/依赖/region_proof，但没有creative direction id/version/hash与冻结状态。G0模板不能阻止下游各自解读、不同主题拼接。最小补丁是给现有mission增加总谱引用及选定状态，由原validate/preflight验证；不是新增质量编号。
3. **并行承诺与执行器不同。** `production_loop.py:1160-1295` 单for循环逐task执行；独立ecology/boss/assets虽仅依赖design（`level_design.py:259-261`）仍串行。`allowed_paths`又都含宽泛scripts/art、assets、scenes等（:249-253），不能直接线程化，否则快照/租约相互误伤。先以独立工作树+单消费者整合者并行，保持原loop各自拥有源码快照；以后才改调度。
4. **短请求完整生产的续推还不闭环。** `level_design.py:292-323` auto为没有正式消费者的地区只替换成单个prototype task，将九包保存在production_plan。原loop只执行mission.tasks；需“已确认总谱+阶段proof→显式下一包mission”的可恢复推进，并保留正式开放限制，不能仅改auto名字声称完成。
5. **风险分层已有工具，默认仍贵。** `harness.py:51-67` 未知/runtime/config/普通tools一律art+gameplay+web；64个checks，profile docs/core各21，gameplay50，art48，web25，full64。`ability-creator:34`等仍要求每次profile gameplay+art，与末尾“开发先--check”（:55）并列；`region-generator:50`同样广跑gameplay。需明确开发反馈/局部验收/冻结回归/发布四层，选择实际适用check，最终标准保留。
6. **证据指纹粒度过粗。** 10个cacheable check的inputs都包含scripts/scenes/resources/assets/config/tools/tests与project/export；改一PNG或任一tool会使全部这些缓存失效。这是保守正确性，并非不安全；需要真正依赖证明后缩小，不能直接删assets或tools。
7. **inputs存在潜在语义陷阱。** `harness.py:180-190`只按路径/目录前缀匹配，不支持glob；profile部分专项声明`scripts/**`等。因此若将这些项设cacheable会漏运行依赖。当前visual-director-space等未开启cacheable，不能声称已经出现旧证据冒充；应先规范目录前缀或实现受测glob再启用缓存。

## 上下文成本：可测量，不等于token/实际耗时

16份Skill共1,386行、87,476 Unicode字符（不含链接指向文档）；exact相同且>80字符的段落去重潜力15,694字符，17.94%。统计仅为可回收文本上限，不是已节省，不按字符推断模型token。

- 8个Skill重复“读取AGENTS/current_state/handoff/架构/验收”等280字段落；8个重复242字权威全文加载；8个重复223字返工契约；7个重复367字十一维结束条款。完整来源见machine inventory。
- `production_loop.py:319-334` 每次完整嵌入task所选全部Skills，review再加gameplay-reviewer；同一轮design四专业合计30,464字符，实施+审查仅Skill正文就67,934字符。这里尚未算mission.preparation、task合同与feedback。
- `production_loop.py:1198-1203` 传全部直接依赖history与全部previous_rounds，review还叠加实施结果和checks；重试/长任务上下文持续增大。不能据此断言所有链接文档都被自动打开；实际prepare_call只嵌Skill，文档由worker按指令再读取。
- `region-generator:37,68` 先旧五层，后追加“升级六层”；`:99-146`又叠加多轮授权/经验；`art-director:102-132`与`scene-composer:85-118`重复同一失败alpha与用途教训。证据非常有价值，但不应每个worker默认全文重读同样历史数字。

建议：一个当前入口指向短公共执行契约；专业Skill只保留职责、输入、贡献、协同、实际消费者与专属反例。将历史细节保留原字节到有SHA索引的归档，当前Skill按错误类别链接而非全文复制。原prepare_call去重公共契约一次；反馈传最近未解决finding+依赖summary+artifact索引，不删原history。比较实际prompt字节和运行用时，不能宣称token/调用成本已降低。

## 消费者依赖图与六类归属

```text
AGENTS/current authority + region context/lessons
  → level_design.route → mission/tasks
  → production_loop.validate/preflight → Skill/worker → original Harness checks
  → checkpoints + quality record + independent reviewer
  → release checks / build / export proof / browser
正式空间: PlainsRegionScenery → PlainsComposition
  → PlainsSemanticLandscape + PlainsConnectedLandscape
  → active texture/family JSON/shader + actual geometry/Manifest
历史空间: --legacy-waterworks-contract → PlainsVisualSpace
测试: profile → distinct Python suite → native GDScript runners → real consumers
```

1. **正式必需**：`scripts/art/plains_region_scenery.gd:30-34`创建composition；`plains_region_composition.gd:27-38`默认创建Semantic与Connected。`:5-6`仍直接preload plains_v8石材、plains_v3木桥；`:96,167`使用plains_v3 decor，故“v3旧包”不能整体退役。`plains_semantic_landscape.gd:45-81,195`读取家族JSON并动态load纹理；导出必须保留实际FileAccess JSON，preload导入纹理则不强求raw PNG。
2. **当前开发/质量必需**：`run_generated_consumer_tests.py:6-42`的31套真实消费者、`run_plains_region_tests.py`15套；不能因名称旧直接删。`run_generated_consumer_tests.py:49-60`重复editor import和逐suite启动可以共享基础执行设施，suite断言独立保留。
3. **可复用按需加载**：非当前任务专业Skills、地形/动作/素材专项经验与可复用母版；不要默认把全部专业、全部16地区/武器全文注入每个窄工作包。
4. **历史复现与审计**：`plains_region_composition.gd:39-43`的legacy-waterworks分支仍有显式消费者，不能当死代码删除；冻结版本、原contract/失败图、旧坐标断言用版本索引按需恢复，单独profile运行。旧Manifest不可直接套新hash。
5. **可证实冗余/无消费者**：本审计只证实上述精确重复规范段落可合并；未证实任意完整资产/runner无消费者，不能批准物理删除。
6. **暂无法判断保留**：未穷尽资源动态load、导入映射、CI/PCK消费者的其余资产与历史原型。仅export排除不等于无消费者。

`export_presets.cfg:8-10,25-27,48-50` 当前三个preset已经排除build/tests/docs/tools及明确失败候选connected_cliff_v1/v2、boss_open_tuning_court_v1/v2、woodland_v2等。是有效隔离，不是尚未隔离。它仍用all_resources，需扫描整个PCK才能证明无意旧资源入包；不要根据目录名估算包大小。其include_filter三份相同长清单可以由同一权威列表生成，但必须实际比对三个preset导出与raw FileAccess载体，不能简单切selected_resources。

## 基础设施安全共享点（不合并测试语义）

- `run_plains_redesign_spatial_tests.py:165-168` / `run_plains_experience_golden_tests.py:7-11`各自包装source_files+追加自身hash；统一成原source_files的显式extra_paths参数，保留每个receipt全部原字段，前后与删额外脚本负例同跑。
- 上述两个runner的Godot argv/timeout/log/JSON SHA/失败保留逻辑可共享原harness.run_check封装；各自native validator和故意失败例不能合并或删断言。
- `run_generated_consumer_tests.py:6` 与 `run_plains_region_tests.py:3`已共享run_tests.run_engine，不应再做“消除重复runner”重写。可提取声明式suite调度/导入一次，保持独立suite进程与并行lane，不变大串行巨测。
- `run_plains_encounter_policy_tests.py:26`还import frozen_project，是活跃历史测试依赖；退役前需当前等效强验+独立历史profile，不能只移动源导致import断裂。

## 最小可逆实施顺序与验收

A. 先改现有mission contract：总谱id/version/SHA/selected状态与专业贡献/协同字段；不同主题/改SHA/缺总谱必须预检拒绝且calls0，原合法任务通过。无总谱的旧冻结mission走明确legacy路径，只用于复现，不自动约束新生产。
B. 原loop加入creative_decision accept/rework/rethink/discard，工程status仍独立；RETHINK只回到preproduction、DISCARD写隔离清单且阻断其依赖，原测试失败绝不能被审美accept覆盖；未变化两轮检测用成果/未解决finding摘要，不只文件字节变化。
C. 将重复规范抽成一次公共契约；历史原文+SHA索引可恢复。先记录上述baseline，再测route实施/审查prompt长度和实际调用时间，要求源/约束等价负例。
D. 在既有Harness添加明确四层选择，局部开发只跑相关快查，冻结完整适用回归，release仍fresh。不能把encounter生命周期红灯隐藏到historical。
E. 资产先做runtime引用+动态family+export实际PCK图，分六类且unknown保留；候选从all_resources排除可逆，不删除原件。测PCK真实字节、冷import、开发检查、冻结回归分别报告。

本审计未执行Godot/CI，因此没有声称任何工程回归通过、缩小包大小或实际节省执行时间。应由后续实施记录补齐真实正反例与前后成本。

## 本轮已实施的可逆Skills精简（后续授权）

仅修改`.agents/skills/*/SKILL.md`并新增`docs/archive/skill_history/`。16原Skill逐字归档为`baseline/<skill>/SKILL.md.source`，manifest记录完整SHA256，逐一校验一致；`.source`避免把历史原相对链接误作当前导航，恢复时仍用原位置解析。没有改旧运行记录/证据hash，没有删除测试或资产。

既有16Skill当前文本186,700 → 171,877 bytes，减少14,823 bytes（7.94%）；新增唯一前置region-creative-director 3,513 bytes后，17Skill合计175,390 bytes，相对旧16份净减11,310 bytes（6.06%）。只为实际默认文件字节量，未计公共README，也不代表真实任务prompt/token/执行时长或包大小改善。

抽离原alpha数值校准/PR69历史实录/旧轮临时授权细节，保留通用的冻结规格失败、真实采样/GPU、整根扇solid支持、自然外轮廓、完整活体出返/HP资源因果、暂停/inactive区别等规则。公共权威加载/G0–G5/十一维重复块集中引用当前创作README；专业动作、敌人、玩法、动画与真实消费者条款保持。每Skill增加简短三阶段总谱契约，明确五项专业交付及SHA变化RETHINK。

初次check_docs失败是归档Markdown相对链接+尚未生成的公共入口；历史原件改`.source`无损保存后，不再扫描为当前Markdown。公共README由主任务负责创建，需完成后重跑文档检查；此刻不宣称文档检查通过。独立审查由其他代理负责，实施者不签自己审查。

2026-10-16守门复验修正：check_quality要求8份Skill保留固定的“准入退出与返工/完成与证据”标题。已在原专业Skill恢复标题及短共同契约引用，没有改守门；当前精确16份175,749 bytes，新增导演3,513 bytes，17份179,262 bytes，净减7,438 bytes（3.98%），以manifest为准，覆盖前述中间统计。随后check_docs实际PASS：33 required documents/local links/207 task dependencies/tuning；check_quality仍因主任务3项任务索引/record不一致失败，已交主任务修复，无Skill缺项。原16份归档SHA逐一校验未变。
