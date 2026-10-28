# 当前创作入口：区域圣经 V2

当前技术消费者绑定为 [style-v17](bibles/style-continuity-20261028-v17-home-codex.json)，两区总谱 creative-v20；[本轮版本化影响](revision_creative_v20.md)仅覆盖HOME-CODEX-01原relics家园图鉴。公开style16／creative19及完整68项冻结原件保留；旧68只更新实际DemoApp／HomeScene两叶，追加5项实际Home图鉴UI／建筑入口／目录策略／配置／Profile显示快照，共73项。其他66项、所有PNG／shader／用户声音选择、Bible和32px／32wu／1wu选定整体风格不变。CHEST候选仍为diagnostic QA，本轮无正式宝箱生产变更或新PNG绑定。哈希只证明输入身份；运行、画面、用户及实体设备验收分别记录。下文旧轮版本说明保留原来源。

制作或优化地区先有该地区完整圣经，所有专业按原文设计、生成和优化。用户已提供并选择两份原件：[荆棘森林](bibles/2-thorn_forest_region_bible_v2.md)、[风铃平原](bibles/1-windchime_plains_region_bible_v2.md)；先完整森林含美术，再优化平原。[原始指令](bibles/user-request.json)是直接用户消息的逐字引用，明确不是API导出。选方向不代表新内容的美术、趣味、音频或实体设备验收。

[注册表](bibles/registry.json)列全部16区，每区最多一个current Bible，保存原文完整SHA、id/version/region、选择状态与原始授权证据。原文不改写；两份当前总谱为[森林creative-v20](thorn_forest.json)、[平原creative-v20](windchime_plains.json)，负责专业接口与消费者索引，不能取代Bible全文或运行时配置。

[当前用户细粒度选择与共享风格v5](bibles/style-continuity-20261022-v5.json)要求森林与所有后续区域继承当前正式平原的整体像素风格，仅体现地区特色。共享参考绑定实际 `PlainsRegionStage→PlainsTerrainStudy→UnderworldTerrain`、原生32px/32wu与1wu世界采样/nearest、47邻接与非整格exact-boundary adapter、原PNG/atlas/TileSet/shader和许可SHA。旧提案或失败实现不自动约束新区域，不等于把正式平原使用中的家族也丢弃。新地区从共享尺度、亮边/光照、材质与接口出发，树皮苔藓荆棘等构成森林差异。

该共享补充进入所有region worker与missing-Bible proposed输入；任一共享源漂移均阻断调用/恢复并重验。生产先实际看共享PNG及正式平原/目标地区正常比例游戏黄金对照，独立像素准入后扩产；metadata/hash只绑定来源。用户明确另选global style时才版本化替代。普通物理、global动作和无关文档不因此新增图像门槛。

历史补充v4绑定16项明确参考，其中同屏角色绑定 `UnderworldPlayer.gd` 及其直接读取的 `animation_build.json`、`run_sheet.png`、`states_sheet.png`；脚本SHA不变不能代表body像素不变。[v1与v2影响分析](bibles/style-continuity-rebind-v2.json)保留原漏绑定反例和旧验收来源，不递归猜测任意资产依赖。当前Forest Stage已挂载同一 `UnderworldTerrain`，DemoApp同用 `UnderworldPlayer`，`ForestBiblePresentation`负责地区景层/摆件；这些实际消费者存在不等于画面验收。

当前执行以style-v17技术绑定及style-v5已选像素方向为准，旧v4/16px说明仅保留原版本来源。常规资产规格填写与跨区域对照见[美术稳定输出说明](../quality/art_consistency_workflow.md)，不新增质量体系。

## 预制作与生产

已有选定Bible时自动绑定，不再比较2–3个方向。缺Bible时自主编写proposed文档、登记原任务与质量卡，只有docs/G0写集；独立G0审查与版本注册前production与prototype拒绝。损坏、重复、错区、错误版本、缺原始依据或SHA漂移属于阻塞，不能降级成“缺文档”后继续制作。没有用户新要求时无需为编写提案或常规返工反复询问。

普通地区短请求和visual-director入口共同使用原production_loop。mission准备与每个task携带完整`region_bible`绑定；worker读完整原文字节及适用章节，逐项说明贡献、协作、玩家行为/画面变化、主题冲突和真实验证。原十一维、G0–G5、完整source snapshot、原Harness检查/预算/严格退出、任务及独审体系继续有效，不另建质量系统。

先共同设计一个完整可玩艺术黄金：region/challenge/encounter组织空间、落点、相位、资源与返程；enemy/boss负责实体行为；visual/art/scene组织整体轮廓、材料、根基、层深与实际合屏；animation-vfx负责已接受事件的动作、SFX与环境动态。G2当前源完整游戏截图、正常速度影片和独立实际像素ACCEPT后，才推广第二种空间、多Seed与整区；几何连通或Hash变化不证明Motor通关、丰富度或艺术品质。

本轮BGM为`deferred_user_supplied`。Bible音乐章节保留设计意图，用户后续引入BGM；当前可做音效、风等背景动画/VFX。没听声音不能签audio，没有实体设备保留awaiting-device。

```sh
python3 tools/region_creative_direction.py --check-bibles
python3 tools/level_design.py route --request '制作荆棘森林' --output build/creative_system/start.json
python3 tools/harness.py --mission build/creative_system/start.json --execute --worker-mode host --evidence-dir build/verification/creative-start
# 缺Bible地区只产出proposed文档任务，显式production会拒绝
python3 tools/level_design.py route --request '制作萤雾沼泽' --output build/creative_system/proposed.json
# 有界开发快查不替代最终完整适用profiles
python3 tools/harness.py --profile region-bible-feedback
```

开发短反馈沿[原Harness入口](../harness.md#从需求到游戏品质)：同一root引擎租约先窄parse、再显式初始定位的局部Motor、再原fullspawn；合屏先冻结geometry/render/source metadata，音频释放按backend墙钟独立验证。各阶段和原失败分别留证，不能由局部通过升级正式内容或延长原预算。

实际双区静态对照使用 `python3 tools/run_forest_bible_golden.py --output build/<fresh> --compare-plains`，采集6森林+2正式平原同源画面。它是显式staged pose合屏，不签Motor路线、正常速度影片或设备。G的正式Motor、局部fixture及此合屏CLI使用同一 `forest_bible_world_sources.inventory()`，绑定runtime/assets/tests/tools完整增删改；采集前后漂移整轮失败，不能只冻结解释性路径列表。

route只是计划。活跃宿主实际执行源码/设计产出、Godot采证、独立审查与返工，按原租约计数；不冒称脱离宿主全自动服务或同树安全并发。`--direction`仅允许同Bible的明确版本。显式工程prototype仍需Bible，旧forest-h-slice保留历史物理回归，不能代签当前两图。

## 来源漂移与恢复

原始附件、staged记录与canonical文档必须以同一basename对应同一区域/版本，唯一该身份后再校完整SHA与bytes；不能用另一区附件的有效SHA替换当前文档。registry、原文、用户原始依据与选定总谱绑定完整SHA。production preflight在calls=0检查，worker调用前后、checkpoint与恢复都重验；手写mission同守门。区域识别同时检查实际allowed_paths与catalog/消费者路径族；匿名生成器或宽生产写集缺绑定时calls=0拒绝，跨区具体消费者拆成分别绑定的任务。已绑定宽目录在worker后仍复核实际变更路径，不能借森林Bible写平原消费者。漂移先阻断相关后继，保留原失败与source snapshot，不自动刷新SHA或续用旧通过。

重绑前在原任务证据中保存版本化影响分析：旧/新完整绑定；受影响设计、地形、敌人、Boss、美术、动画、音频和正式消费者；每项需重跑的证据；主张不受影响的证明及其精确依赖。独立审查确认后创建新版本/新任务绑定，旧回执保留原源。REWORK用于局部修复，RETHINK返回上游，DISCARD隔离候选；ACCEPT只限实际证据范围，审美不覆盖工程红灯。

每条Bible要求在同一质量记录对应：章节→目标行为/画面→实际消费者路径、SHA和版本→证据ID→technical/visual/audio/device分别状态。静态库存只能称source_present；Forest已有DemoApp._select_next_region / start_debug_region→ThornForestRegionGenerator→ThornForestRegionStage/Assembler正式源码链，不能误称缺失，也不能据此推断新版已实跑、已开放或production_pool准入。共享平原/Foundry通过不证明森林，helper不证明普通campaign。

## 历史与交付边界

当前creative-v8按[显式重绑记录](bibles/style-continuity-rebind-v4.json)继承v6／v7的完整Bible和共享母版，仅更新已验证的边界提速绑定；v6已在v5共享风格纠正上补齐实际角色body资源闭包；[v5原件](archive/creative-v5/thorn_forest.json)及[版本化影响分析](bibles/style-continuity-rebind-v2.json)保留旧绑定。v5已纠正v4中整体排除现用家族的错误；[v4原件](archive/creative-v4/thorn_forest.json)保留旧来源和错误边界，[旧v3原件](archive/creative-v3/thorn_forest.json)与[旧v2迁移](revision_creative_v3.md)保留原字节、冻结测试和失败。旧提案/失败recipe不再由普通新建/优化入口默认发出；这不排除当前正式平原仍用的Underworld tileset/整体像素家族；`visual_director.historical_recipe_plan`只保留历史配方回归元数据，无当前生产授权，运行仍受Bible守门。既有明确原生复现工具、历史Manifest/存档的原版本与hash继续保留，不增加通用historic bypass。

旧Skill入口原件和SHA见[迁移索引](../archive/skill_history/bible-v2-input/manifest.json)，历史窗口/预算按需读取。原素材、许可、冻结fixture和所有旧检查仍在。开发只跑窄反馈；冻结与发布仍fresh完整适用docs/gameplay/art/web及原CI、实际包/浏览器/公开指纹和同源正式影片。技术passed、独立专业判断、用户认可与实体设备分列，旧绿不冲销新红。时间/调用与未知成本沿原production_timing；连续两轮无实质改善停止该依赖并保留现场，不能换任务名退款。

v4仅将边界占用计算改为精确谓词前的闭AABB粗筛。原v3不动；新旧全序几何／跨区实际App与GPU矩阵等价、独审后才重绑，[影响与原件](bibles/style-continuity-20261022-v4.json)不签森林新模块美术或浏览器通过。
