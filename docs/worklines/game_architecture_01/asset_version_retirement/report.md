# C59 资源版本与退役计划（只读）

不必把所有旧版本全删，才能确保正式游戏使用新版本。需要控制的是**入口实际选择、表现装配、注册表解析和导出闭包**。旧文件单纯存在不会自动抢占新版本；但未被正式选择的旧资源仍可能因 preload 或 `all_resources` 进入包、占内存/包体，并增加维护误用风险。应先隔离、按真实消费者缩小导出，最后只删除已证明没有运行、实验、回放、来源/许可依赖的物理文件。

源基线：`c59c24fb76762a0f66033e0f79d7b2cba7a84444`。所有代码分析来自这个 Git 提交的文本快照，不把审计期间主树后继 App/Stage WIP 当成 C59。复用 `tools/project_dependencies.py:inspect`：842 个 GDScript/场景/资源源、3447 条静态边、118 处动态加载表达式、0 个该工具定义的边界错误；这不等于运行或资源删除安全证明。补充扫描 3894 个当前文本文件，记录了带行号的家族引用。媒体清单覆盖列明后缀的 1038 个 tracked 图片/声音/字体，不声称涵盖所有资产或全部历史证据。

没有改主树、运行引擎、删资源、重生成图声或发布。本报告没有检查 C59 最终 PCK；导出结论均是当前 preset/插件的静态政策，实际成员、remap、大小仍须导出后核实。远端 full185 状态不在本报告签署范围。

## 先分开四条版本轴

1. **场景风格**：Underworld 暖光、原生 fine32 地形、1wu 采样；不是要求所有 PNG 都在 underworld 同一个目录。
2. **角色/怪物身体与动作**：默认新信使、可选经典信使；平原六种修订身体加俯冲怪 authored frames；森林有自己的 fine32 物种身体。
3. **玩法 Definition/AI/地图版本**：Registry 按 behavior 与显式 revision 选配置，保存的森林 v11 可以选择旧 charger Definition；这与选哪张皮肤不是同一个开关。
4. **音效选择**：正式 demo 场景装配 selected SFX/ambience，怪物材质声和 Boss 声另有明确消费者；Lab 可以显式选择原版、v2、v3 或 ABC。

文件夹数字小、名字包含 `legacy`、`source`、`pixel`、`style_exploration` 都不能单独作为删除依据。

## 当前正式选择和不能误删的依赖

| 对象 | C59 实际选择/保留原因 | 精确证据（仓库路径:行） |
|---|---|---|
| 正式入口 | `project.godot` 启动 `game/application/demo.tscn`；场景直接挂 SelectedAmbienceRuntime 和 SelectedSfxRuntime，App 创建 PlayerWeaponFeelAudioV2 | `project.godot:6`；`game/application/demo.tscn:2`、`:8`、`:11`；`game/application/demo_app.gd:150` |
| 正式平原/森林共享场景 | App 在正式地区判定成立后 attach UnderworldPresentation；显式候选旗标走自己的分支 | `game/application/demo_app.gd:563`、`:2765`、`:2768` |
| fine32 地形 | `assets/underworld_plains/terrain/fine_32/terrain_build.json` → `fine_32/source.png`；复用 PixelFormalTerrain 的几何，不是改用旧 paint | `game/presentation/world/underworld_plains/underworld_terrain.gd:7`、`:23`、`:29`；该 build JSON `:3373` |
| 森林当前场景 | 默认森林 layout 是 v15；共享 Underworld 地形，天空和树道具仍取 `style_exploration/underworld/forest` | `game/world/generation/thorn_forest_region_generator.gd:18`、`:43`；`game/presentation/world/presentation/forest_bible_presentation.gd:3`、`:6`、`:7` |
| 平原六种怪主体 | `plains_revision_01/{patrol,charger,hopper,sentry,fan_sentry,root_bell}.png`；stable_id 有限准入，UnderworldEnemy 优先安装并返回 | `game/enemies/presentation/plains_revision_skin.gd:6`、`:32`；`game/presentation/actors/underworld_plains/underworld_enemy.gd:20` |
| 第七种俯冲怪 | 不在六种修订支持集；使用 `frames_v8/underworld_diver.png` 与现有受击/死亡表现；原 aerial.png 仍用于可见框/锚点 | `game/enemies/presentation/plains_revision_skin.gd:33`；`game/presentation/actors/underworld_plains/underworld_enemy.gd:27`、`:31`、`:35`；`game/enemies/presentation/enemy_feedback_01_frames.gd:9`、`:40` |
| 森林怪 | weaver_silk_bell_v5、fine32 guardian/queen/beetle/lantern/swing_pod/seed_sentry/crossbranch；森林 charger 单独复用 Underworld renderer | `game/presentation/actors/presentation/forest_bible_actor_presentation.gd:9`、`:11`、`:22`、`:29`、`:46` |
| Boss | PR122 Bellstrider 现 rig 使用 underworld bellstrider.png + bell.png；Pressure 使用 underworld windkeeper.png。设计迭代不要求重新换图 | `game/bosses/bellstrider/bellstrider_presentation.gd:3`、`:5`；`game/bosses/windkeeper/windkeeper_pressure_presentation.gd:3`、`:15` |
| 默认/经典主角 | 默认 courier；courier_classic 仍为 production_ready 可选项。默认运动身体继承 UnderworldPlayer，旧 run/states 仍是依赖 | `game/presentation/actors/resources/art/avatars.json`；`game/presentation/actors/art/avatar_presentation.gd:64`；`game/presentation/actors/art/player_presentation_runtime.gd:20`；`game/player/presentation/motion_visual.gd:1`；`game/presentation/actors/underworld_plains/underworld_player.gd:5` |
| 普通怪材质音 | 七怪按壳/翼/植物走 `assets/audio/plains_feedback_02/` 的 hurt/death/land；不是玩家受伤 A 的另一份随意替代 | `game/presentation/audio/plains_enemy_audio.gd:16`；`game/presentation/audio/game_audio.gd:298` |
| 正式 SFX | selected.json + director_v3 + 已选 hurt-20261030 A，严格校验后才切换 bank；枪/跳落地还有现有专属层 | `game/presentation/audio/selected_sfx_runtime.gd:4`、`:171`、`:190`、`:197`；`config/audio_director/selected/hurt-20261030.json`；`game/combat/weapons/presentation/weapon_audio_v2.gd:4` |
| 正式环境声 | Plains A / Forest A、Home life、原 BGM；SelectedAmbienceRuntime 的场景装配与完整原 16 声音 fingerprint 是当前权威，旧选择记录的阶段性文字不能覆盖代码 | `game/presentation/audio/selected_ambience_runtime.gd:3`、`:18`、`:76`、`:113`；`game/application/demo.tscn:8`；`game/presentation/audio/game_music.gd` |
| Root Bell 旧目录中仍当前的部分 | 当前 UnderworldEnemy 仍配置 RootBellPulseArt，直接 preload `region_production_v3/enemies/root_bell_burst/source/master.png` | `game/presentation/actors/underworld_plains/underworld_enemy.gd:19`；`game/enemies/presentation/root_bell_pulse_art.gd:4`、`:16` |

六怪已换新主体不等于旧 Underworld actors 全可删：`underworld_enemy.gd:132` 仍 preload 六张旧 PNG，俯冲怪锚点及不匹配修订身份的明确回退会读它们；`EnemyFeedback01Frames:9` 同时 preload 四套 legacy/Underworld frame 图。删除文件会先破坏脚本加载/manifest，不会自动让新版本“更纯”。这部分需要单列消费者迁移，而不是当无效文件直接删。

当前绑定已经有防回退措施：`EnemyPresentationBinding.replace:66` 禁止后续 pixel installer 降级已装好的 Underworld renderer；同 renderer 重绑不重复替换，Definition 未知 revision 返回空并拒绝。正式选择不是扫描目录寻找“最新文件”。本轮未证实正式默认有意外旧皮肤回退；也没有运行全部入口来签这种情况绝不存在。若有人以 `DemoApp.new()` 自造入口而漏掉 demo.tscn 的 selected 子节点，音频会保留 base 行为；应修该消费者装配，而不是删掉 base 音频迫使它变化。现有 Lab 的 opt-in 是代码明示，不能擅自升级。

## 旧版本实际消费者与处置类别

| 类别/具体对象 | 当前消费者证据 | 处置 |
|---|---|---|
| 显式旧风格对照 | `experiments/terrain/entries/{retro,basic,scribble,underworld,cavern,...}.tscn` → StyleLab；`style_lab.gd:93`、`:107`、`:137`；`game/presentation/world/style_exploration/style_terrain.gd:4` 有限五风格动态拼路径 | 保留入口及其真实资源；它们不改变普通主入口默认。未来可把发布包的实验范围独立收窄，不能本轮删除入口/假称已经停用 |
| 音效历史/试听 | `experiments/audio/audio_director_lab_v2.gd:61` 明确 v2；`audio_director_reels.gd:64` 明确 v3；`game_audio.gd:401` base bank；ambience Lab 可选 A/B | 保留原声/许可/试听选择；不能因正式选 A 就删 B/C，当前完整16文件校验本身也会拒绝缺 B |
| 非 Underworld/旧 monster host | `game/enemies/presentation/enemy_presentation.gd:38` 使用 legacy frames；`:150` 用 plains_v4 atlas，`:163`、`:252` 动态 meadow_actions；`windkeeper_presentation.gd:6` 用原 v4 Boss frames | 保留到对应明确旧/实验消费者迁移后；不连带改变历史内容 |
| pixel/plains_v3/v4 | Pixel 类仍提供共用 telegraph/几何；`shot_latch.gd:5`/`:6` preload 原图，`plains_terrain_skin.gd:8` 等有 fallback；FoundryCatalog 还将 hero manifest 纳入来源 | 按叶子审，不按目录/类名整删；区分实际绘制、加载依赖、配置 basis |
| forest 历史 layout v1/v7/v9/v10/v11... | `thorn_forest_region_generator.gd:4`、`:19`、`:46`、`:77` 保留明确 recorded 选择；普通默认为 v15 | 当前手动 legacy-compat 是否执行与是否保留消费者是两件事；未获淘汰授权不删 |
| Painterly v2 | 没有发现来自 game/experiments 的外部静态资源边；但 `assets/painterly_v2/painterly_courier_visual.tscn` 仍是独立场景，脚本 `:5` 读其 manifest，生成/质量历史仍有记录 | 不是“无消费者”：可做发布排除统一候选；保留源与独立旧场景，物理删除需另证所有历史/工具依赖已转可追溯档案 |
| 绘制母版 `plains_revision_01/source/{first-palette,master}.png` | 当前 runtime/experiments 无这两个 source 路径的直接读取；正式 Skin 只读六张裁切；manifest相对路径、provenance及两张 SOURCE-* 质量卡仍引用 | **优先发布排除候选**，不是 repo 删除候选。两 PNG 源文件共 4,160,125 bytes，未测导出衍生物大小 |
| 风格生成原图、许可、audio `_sources` | 生成记录/许可证；现 preset 已排除 `style_exploration/*/source/*.png` 和 generated；音频 `_sources/.gdignore`、forest source/.gdignore 隔离导入 | 继续原件保留/隔离；不要删许可或改写旧失败/接受证据 |

**已严格证明无任何消费者、可以立即物理删除的文件：本轮没有。** 这不是说所有旧文件都永久保留。现已具体定位 source-only 导出精简候选和没有当前 formal 外部边的 Painterly 家族；动态118处、相对 manifest 路径、工具/固定 Git/归档读取和独立场景都使“rg 没命中”不足以成为删除证明。

## 为什么 PCK 要保留 legacy plains_charger_v2.tres

- 唯一玩法权威 `game/enemies/enemy_behavior_registry.gd:7`/`:10` 注册原 SHA `1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0`。无 revision 的正常 charger 选择 `resources/enemies/plains_charger.tres`，definition_version=3、28×28；明确旧 revision 才选 legacy v2、28×32。旧资源不是贴图，删它不能改善画风一致性。
- `scripts/generation/thorn_forest_region_v2_v11.gd:32` 显式请求旧 revision；`game/world/levels/providers/legacy_region_plan_adapter.gd:74` 保留旧 Manifest 逻辑 path/SHA，再由 Factory/LevelPlan/Runtime 解析。不能把旧大小偷偷换成新28×28，碰撞与历史 Manifest 会改变。
- `EnemyBehaviorRegistry.definition_path:48` 读原文件 SHA，未知/变字节失败关闭，不静默改选当前。资源内 `res://scripts/enemies/enemy_definition.gd` 是稳定资源协议路径；不能为了目录整齐改原 bytes。
- 三个 preset 的 include_filter 都明确加这一个 `.tres`。`addons/runtime_raw_export/raw_exporter.gd:116` 从**同一个** Registry revisions 派生合同，不建平行版本表；`:134` 核所有明确输入及 SHA，`:180`/`:191` 用 `add_file(..., false)` 保留原 FileAccess bytes，**同时保留 Godot 的 .remap/.res 加载结果**。
- `tools/check_recorded_enemy_pack.gd:21`、`:23`、`:26`、`:30`、`:42` 已有真实隔离 PCK 的 raw SHA、remap、Definition 和实际碰撞尺寸检查。将来裁剪必须继续通过当前相同工具；本审计没有运行它，不能代签 C59 新包。
- 若未来明确停用所有相关历史消费者，可另做范围变更移出发布包；只要本轮还保入口/回放，删除它就是功能删除。

## 导出实际政策与污染风险

`export_presets.cfg:8/25/48` 三个平台均 `all_resources`；`:9/26/49` broad JSON +有限 raw PNG/audio/legacy Definition；`:10/27/50` exclusions。未排除 `experiments/`。因此当前政策保留实验资源有意可达，但不是最小正式包。

- `style_exploration` 74 个本清单图片中，静态 fnmatch 有25个被所有平台排除，49个未匹配；其中 forest 当前正式直接读2张，其他有实际五风格入口。不是“全旧”。
- Painterly 13张：Web排除13，Windows/Android只排除6，剩7张可进入 all_resources 导出候选。这个平台差异值得核真实 PCK，不能声称已经存在7张成员。
- 上述 plains_revision source 两张，无 `.gdignore` 祖先且三平台均不匹配排除，带 import 旁车，因此存在衍生纹理被打包的明确风险。源 PNG 大小不是包体节省承诺。
- 原 `underworld_plains/terrain/source.png` legacy16 由 raw exporter `:20` 和 `tools/underworld_delivery.py:26` 明确保留；当前 fine32 terrain 不直接绘制它。但若要从包去掉，必须同步迁移这些真实字节合同，不能只删 PNG 或绕过 checker。
- **不能全局 `*/source/*` 排除**：RootBellPulseArt 当前直接使用 burst/source/master.png，原RootBellPresentation也读 source/master。不能全局排除 `style_exploration/*`：森林正式资源仍在那里。

## 建议分批执行（尚未实施）

| 批次 | 精确目标/文件 | 消除的问题与保留行为 | 验证与回退 |
|---|---|---|---|
| R0：冻结当前选择 | 沿 EnemyBehaviorRegistry、EnemyPresentationBinding、avatars.json、SelectedSfxRuntime/SelectedAmbienceRuntime、既有 asset manifests；为原入口矩阵补确认项 | 不造新 runtime registry；将正式、显式 Lab、历史 raw 四种用途在现记录中讲清；保持图声、存档、物理、碰撞、伤害、消耗、奖励、随机全部原样 | 复用现 enemy/style/selected audio/入口检查；核 C59 对照。首批回退锚点 C59；后批使用各自实际父提交，不预编 SHA |
| R1：先减发布包，不删来源 | `export_presets.cfg` 对两张 plains_revision source PNG及必要 import衍生物做精确排除；通过既有 `tools/check_web_bundle.py`/原资源检查验证；先评估现检查是否要求包内母版，不改 provenance来源 | 保留六张正式身体、RootBell burst 原图、所有实验入口和生成/许可/质量原件。消除确定 source-only 的潜在导出浪费 | 实际 Web/Win/Android成员/remap比对；隔离资源加载、七怪/两区/主角/所有保留实验。原输入完整不删/不放预算。失败 revert R1 commit，回到R0实际提交 |
| R2：有限清理旧加载依赖 | 逐叶检查 `underworld_enemy.gd:132`、`enemy_feedback_01_frames.gd:9`、`enemy_presentation.gd` 与其 manifest/原测试；Painterly仅评估发布排除一致性 | 只去掉真实不可达的 eager preload/迁移对应仍活 consumers；俯冲锚点、显式旧渲染、经典角色、实验场景仍保原行为。凡需要换图/调锚点/删旧入口的项单独列内容迁移，不混等价重构 | 原旧/new host矩阵、spawn/restore/death/remains/RootBell脉冲与PCK加载；静态零引用不够。失败 revert R2，回R1实际提交 |
| R3：历史证据有限归档，再物理删除 | 仅对经过 R2 证明的具体叶子；既有 asset_records/provenance、有限 source snapshots、固定Git readers/许可文本协同 | 原 SHA/接受/失败字节保持；只删除无人运行且历史机制已能读取精确原件的重复副本。不淘汰实验、改协议或者把所有历史变成runtime新版 | 原历史 reader正负例（缺件/篡改必须拒）、当前资源完整性、全部入口和实际包闭包。每一删除列最后消费者及字节恢复来源；失败 revert 独立清理commit |
| R4：最终出口核验 | 原PCK raw/remap检查、bundle检查、既有完整CI与实际页面 | 固定选择与可达性得到真实产物证明；不借包小宣称品质提升 | C59/新提交实际包清单差分+公开metadata精确SHA；full/设备/用户结果分别记，未验不签 |

原缺陷/内容迁移需求另列：尚有承载老外观的保留消费者；若希望所有实验也统一新图，这是**内容版本迁移**而非保持行为不变的清理。若希望移除经典主角或历史地图，是功能范围调整。两者都不能通过文件删除偷偷实现。资源母版的来源证据属于创作/许可依赖，不能为了“仓库干净”破坏原事实。

## 外部审计附件与复现

以下完整采集件保存在审计工作区 `/workspace/refactor-evidence/asset-version-retirement-plan/`，不作为本页运行依赖；本文具体路径可对精确 C59 Git 源复核。

- `collection-receipt.json`：精确C59文本SHA向量、扫描边界、后继主树WIP披露。
- `dependency-graph.json`：复用原检查器的图和118个动态未知点。
- `family-reference-evidence.json`：24组家族/路径的当前 literal 引用，含文件/行/原文；包含注释/来源记录，不把全部命中误作 runtime。
- `tracked-media-export-candidates.json`：1038项 tracked 图声字体的 Git blob、大小与静态 include/exclude匹配；并非PCK listing，也不授予删除安全性。
- `export-preset-facts.json`：三平台原完整列表。
- `c59-text-snapshot/`：精确旧源，仅外部文本镜像用于复用原图工具，不复制媒体；`collect.py` 是一次性只读审计脚本，不安装新项目机制。

判定：**在上述静态选版及消费者范围内有证据；物理清理与最终打包范围仍待按批验证。旧资源不全删，正式默认仍可固定；先排无运行用途的发布内容，再删除真正无消费者的副本。**
