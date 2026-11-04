# 任务索引

按任务ID或主题搜索本表，只读取选定任务及直接依赖。每个ID一行；负责人、写集、恢复命令放工作线。状态描述对应任务的验收范围，代码合入不自动签用户或设备认可。

当前产品见 [当前状态](current_state.md)，协作和局部交接见 [生产规则](cloud_production.md)。`review`任务从证据中的未验维度继续；已结束任务不作为新会话的默认上下文。

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| CI-SLIMDOWN-01 | 四项日常CI与显式手动专项，PR133已合入 | — | review | [工作线](worklines/ci_slimdown_01/results.md) |
| CODEX-CONTEXT-01 | 精简当前文档、Skill与交接 | — | in_progress | [工作线](worklines/codex_context_01/scope.md) |
| MAPGEN-HOST-WINDCHIME-041 | 0.4.1真实生成/多端口准入/完整起点钟门与最终集成 | MAPGEN-GODOT-04 | review | [结果](worklines/mapgen_041_windchime/results.md) |
| CI-SELECTED-INPUTS-01 | prepare精确同run输入工件复用与可见进度 | MAPGEN-GODOT-04 | review | [结果](worklines/mapgen_041_windchime/results.md) |
| MAPGEN-CI-PYTHON-PIN-01 | 固定双通道Python补丁身份，保原合流守门 | MAPGEN-GODOT-04 | review | [任务](evidence/mapgen_host_04_acceptance/ci-python-pin/README.md) |
| MAPGEN-HOST-04-ACCEPTANCE-01 | 性能归因/库复用/Web及精确head完整CI | MAPGEN-GODOT-04 | review | [任务](worklines/mapgen_host_04_acceptance/scope.md) |
| MAPGEN-GODOT-04 | 0.4真实生成/重新绑定/机制/Web与覆盖重提 | MAPGEN-GODOT-03 | review | [任务](worklines/mapgen_godot_04/scope.md) |
| MAPGEN-GODOT-03 | 0.3原生生成来源/生命周期/Web链路及独立M35 | MAPGEN-HOST-V2-02 | review | [任务](worklines/mapgen_godot_03/scope.md) |
| MAPGEN-INITIAL-SPAWN-01 | 生成暂停期初始定位拒绝的独立修复 | MAPGEN-GODOT-03 | review | [任务](quality/records/MAPGEN-INITIAL-SPAWN-01.json) |
| MAPGEN-HOST-V2-02 | PR127权限/参考包/身份与实际Web接入修订 | MAPGEN-HOST-V2-01 | review | [任务](worklines/mapgen_host_v2_02/results.md) |
| MAPGEN-HOST-V2-01 | runtime-map/v2真实模块受控装载与宿主反馈 | MAIN-REFACTOR-MERGE-01 | review | [任务](worklines/mapgen_host_v2_01/results.md) |
| MAIN-REFACTOR-MERGE-01 | PR126已合入，验收来源待归集 | DEATH-RUNTIME-01 | review | [任务](worklines/main_refactor_merge_01/scope.md) |
| DEATH-RUNTIME-01 | 保持死亡动画，优化死亡运行成本 | FIRST-USE-STUTTER-01 | review | [任务](worklines/death_runtime_01/scope.md) |
| FIRST-USE-STUTTER-01 | 定位Chrome首次air与敌战卡顿，证据驱动最小修复 | COMBAT-PERF-DEPLOY-01 | review | [任务](worklines/first_use_stutter_01/scope.md) |
| COMBAT-PERF-DEPLOY-01 | 原所有者内优化战斗热点并部署同源试玩 | MOBILE-COMBAT-MESH-02 | review | [任务](worklines/combat_perf_deploy_01/results.md) |
| MOBILE-COMBAT-MESH-02 | 复用现Pose派生量及实际零权重叶子计算 | MOBILE-COMBAT-PRESENTATION-01 | review | [任务](worklines/mobile_combat_mesh_02/results.md) |
| MOBILE-COMBAT-PRESENTATION-01 | 两怪物宿主单帧重复同步收敛，保原表现契约 | GAME-ARCH-TECHNICAL-CLOSEOUT-01 | review | [任务](worklines/mobile_combat_presentation_01/results.md) |
| GAME-ARCH-TECHNICAL-CLOSEOUT-01 | 架构技术收口 | GAME-ARCH-LAYOUT-01 | review | [任务](quality/records/GAME-ARCH-TECHNICAL-CLOSEOUT-01.json) |
| POPUP-TOUCH-PAIRING-01 | 独立弹窗触摸配对修复 | GAME-ARCH-TECHNICAL-CLOSEOUT-01 | review | [任务](quality/records/POPUP-TOUCH-PAIRING-01.json) |
| BROWSER-CONSUMER-REFRESH-01 | 当前浏览器消费者与严格共用定位 | POPUP-TOUCH-PAIRING-01 | review | [任务](quality/records/BROWSER-CONSUMER-REFRESH-01.json) |
| UI-CI-OWNERSHIP-01 | 真实UI测试叶与模块责任映射 | MODULE-CALL-BOUNDARIES-01 | review | [任务](quality/records/UI-CI-OWNERSHIP-01.json) |
| CI-CURRENT-01 | 当前消费者测试契约与历史CI分类 | WINDKEEPER-PRESSURE-01 | in_progress | [任务](worklines/ci_current_01/scope.md) |
| WINDKEEPER-PRESSURE-01 | 60HP牧风者六招三阶段主动追压与连续原声审核 | — | review | [任务](worklines/windkeeper_pressure_01/spec.md) |
| BELLSTRIDER-REWORK-01 | 40HP上端唯一弱点、三招与回冲、机械失效/实体奖励、正式原声实战与工… | — | review | [任务](worklines/bellstrider_rework_01/spec.md) |
| AUDIO-MERGE-120-121 | 采用确切受伤A，保历史整合PR120+121并通过原完整门禁后合mai… | AUDIO-FEEDBACK-06 | review | [任务](worklines/audio_merge_120_121/scope.md) |
| AUDIO-FEEDBACK-06 | 标题即播、碰墙固定新版1、参考空洞骑士重做受伤候选 | AUDIO-FEEDBACK-05 | review | [任务](worklines/audio_feedback_06/scope.md) |
| AUDIO-FEEDBACK-CI-01 | 精确selector尾部新增回归清单同步 | AUDIO-FEEDBACK-05 | review | [任务](quality/records/AUDIO-FEEDBACK-CI-01.json) |
| AUDIO-FEEDBACK-05 | 五项实玩声音修复及新版hurt/wall | — | review | [任务](quality/records/AUDIO-FEEDBACK-05.json) |
| MOBILE-WEB-FPS-04 | 正式Web帧时间、真实大地图空中攻击A/B/A及前景无损优化；PR12… | MOBILE-WEB-AUDIO-FIX-03 | awaiting-device | [任务](quality/records/MOBILE-WEB-FPS-04.json) |
| MOBILE-WEB-AUDIO-FIX-03 | 独立供音接入普通Web；关闭瞄准附加声，修复机关风铃 | MOBILE-WEB-AUDIO-02 | in_progress | [任务](quality/records/MOBILE-WEB-AUDIO-FIX-03.json) |
| MOBILE-WEB-AUDIO-02 | 已恢复工坊音色；定位主线程供音排队并发布同包线程对照，待真机 | MOBILE-WEB-PERF-01 | in_progress | [任务](quality/records/MOBILE-WEB-AUDIO-02.json) |
| MOBILE-WEB-PERF-01 | 移动Web总线与重复unpause根因复现、音频针对性修复 | MOBILE-UI-CLARITY-01 | awaiting-device | [任务](quality/records/MOBILE-WEB-PERF-01.json) |
| MOBILE-UI-CLARITY-01 | 修复共享UI比例与Web清晰度并快速部署 | — | awaiting-device | [任务](quality/records/MOBILE-UI-CLARITY-01.json) |
| AUDIO-AMBIENCE-01 | 两区环境音候选、轻微衬底混音与真实场景试听 | AUDIO-DIRECTOR-04 | review | [任务](worklines/audio_ambience_01/scope.md) |
| AUDIO-HOME-01 | 家园平静底声与NPC生活音试听 | AUDIO-AMBIENCE-01 | review | [任务](worklines/audio_home_01/scope.md) |
| AUDIO-ROLLOUT-01 | 已选音效合main与快速试玩 | AUDIO-HOME-01 | review | [任务](worklines/audio_rollout_01/scope.md) |
| MAIN-MERGE-WEB-111 | PR111正常合入与实际main网页试玩 | CHEST-ART-01 | in_progress | [任务](worklines/main_merge_web_111/scope.md) |
| CHEST-ART-01 | 三档宝箱关闭／开启六态美术与正式地图辨识 | ITEM-ART-01 | review | [任务](worklines/chest_art_01/spec.md) |
| ITEM-AUTHOR-01 | 道具配置覆写、下架与数据式新增 | ITEM-V5-01 | review | [任务](item_authoring.md) |
| ITEM-ART-01 | 72独立道具图标与专用事件特效 | ITEM-AUTHOR-01 | review | [任务](worklines/item_art_01/spec.md) |
| ITEM-V5-01 | 实现道具V5的72件、16成长与9有效联动 | RUN-GEAR-01 | review | [任务](worklines/item_v5_01/scope.md) |
| RUN-GEAR-MERGE-05 | 补齐style14与过期style13拒绝的版本契约 | RUN-GEAR-MERGE-04 | review | [任务](quality/records/RUN-GEAR-MERGE-05.json) |
| RUN-GEAR-MERGE-04 | 合入守门的creative精确版本测试同步 | RUN-GEAR-UI-02 | review | [任务](quality/records/RUN-GEAR-MERGE-04.json) |
| RUN-GEAR-R2-03 | 修复当前R2测试的家园入口与布局等待 | RUN-GEAR-UI-02 | review | [任务](quality/records/RUN-GEAR-R2-03.json) |
| RUN-GEAR-UI-02 | 暂停直达背包、图标网格与左右分页 | RUN-GEAR-01 | review | [任务](quality/records/RUN-GEAR-UI-02.json) |
| RUN-GEAR-01 | 正式本局背包、齿轮负荷与暂停换装基础 | — | review | [任务](quality/records/RUN-GEAR-01.json) |
| ENEMY-ALL-02 | 全现存怪物同体动作与实机审核 | ENEMY-WORKFLOW-01 | review | [任务](worklines/enemy_asset_audit_01/README.md) |
| ENEMY-WORKFLOW-01 | 怪物开发skills与实际制作交接 | ENEMY-COMPLETION-01 | done | [任务](../.agents/skills/enemy-creator/references/development_workflow.md) |
| ENEMY-COMPLETION-01 | 每物种完成标准与制作卡统一 | — | done | [任务](quality/enemy_completion_standard.md) |
| ENEMY-CONTINUITY-01 | 冲锋怪完整链核对 | ENEMY-COMPLETION-01 | review | [任务](design/enemies/plains_charger.md) |
| AUDIO-DIRECTOR-03 | 功能音色与真实有声对比录屏 | AUDIO-DIRECTOR-02 | review | [记录](quality/records/AUDIO-DIRECTOR-03.json) |
| AUDIO-DIRECTOR-04 | 用户逐事件选声与组合实景试听 | AUDIO-DIRECTOR-03 | review | [记录](quality/records/AUDIO-DIRECTOR-04.json) |
| AUDIO-DIRECTOR-02 | 现成CC0三套与真实情境工坊 | AUDIO-DIRECTOR-01 | review | [记录](quality/records/AUDIO-DIRECTOR-02.json) |
| AUDIO-DIRECTOR-01 | SFX统一审计、候选与手机Sound Lab | — | review | [记录](quality/records/AUDIO-DIRECTOR-01.json) |
| PLAYTEST-FEEDBACK-20261024 | 试玩性能、统一受击、固定HUD、家园武器与开始入口 | FOUR-LINE-INTEGRATION-01 | review | [任务](worklines/playtest_feedback_20261024/scope.md) |
| FOUR-LINE-INTEGRATION-01 | 四线正式集成、默认人物与5首原MP3 | PLAYER-PRESENTATION-01, ENEMY-FEEDBACK-01, DEMO-UI-01, FINE-SPACE-05 | review | [任务](integration/four_lines_20261023.md) |
| DEMO-UI-01 | Demo UI／HUD／家园交互 | — | review | [任务](quality/records/DEMO-UI-01.json) |
| DEPTH-FRAME-06 | 中景地标与前景 | — | review | [任务](quality/records/DEPTH-FRAME-06.json) |
| FINE-SPACE-05 | 正式细粒度与共享空间表现 | — | review | [任务](quality/records/FINE-SPACE-05.json) |
| FOREGROUND-CONTINUITY-08 | 固定前景与稳定恢复 | — | review | [任务](quality/records/FOREGROUND-CONTINUITY-08.json) |
| LIGHT-STUDY-01 | 光色实验 | — | review | [任务](quality/records/LIGHT-STUDY-01.json) |
| PIXEL-LIGHT-STUDY-02 | 像素对齐与局部灯光实验 | — | review | [任务](quality/records/PIXEL-LIGHT-STUDY-02.json) |
| SPATIAL-RHYTHM-07 | 沿途疏密与留白 | — | review | [任务](quality/records/SPATIAL-RHYTHM-07.json) |
| CLOUD-EFFICIENCY-01 | 稀疏Harness隔离、必需输入物化与Skills提效 | — | done | [记录](quality/records/CLOUD-EFFICIENCY-01.json) |
| PLAYER-PRESENTATION-01 | 主角连续动作代表样板 | CLOUD-EFFICIENCY-01 | in_progress | [任务](quality/records/PLAYER-PRESENTATION-01.json) |
| ENEMY-FEEDBACK-01 | 两类普通怪物共享受击／死亡样板 | CLOUD-EFFICIENCY-01 | review | [任务](quality/records/ENEMY-FEEDBACK-01.json) |
| PLAINS-GOLDEN-01 | 平原两候选与黄金切片 | CLOUD-EFFICIENCY-01 | planned | — |
| CLOUD-PRODUCTION-01 | Cloud生产与交付机制 | — | review | [任务](cloud_production.md) |
| CLOUD-PREVIEW-01 | 显式开发入口与录屏样例 | CLOUD-PRODUCTION-01 | review | [记录](harness.md) |
| MAIN-CLOSEOUT-20261022 | 统一现状源码与历史到main，建立并行开发基线 | PARALLEL-INTEGRATION-01 | done | [任务](quality/records/MAIN-CLOSEOUT-20261022.json) |
| FOREST-VARIETY-04 | 六类探索场所、两图真实网络与每图8–12/15–20分钟初步体验目标 | FOREST-VARIETY-03 | in_progress | [任务](design/forest_exploration_v18.md) |
| FOREST-VARIETY-03 | 保留旧森林设计、扩模块库与真实随机回环，纠正首段曲线 | FOREST-EXPLORATION-02 | in_progress | [任务](design/forest_variety_feedback_20261022.json) |
| UNDERWORLD-FEEDBACK-03 | 平原受伤、环境交互、连续Boss与家园反馈 | UNDERWORLD-PLAINS-01 | review | [任务](underworld_feedback_r3.md) |
| MAIN-PR96-REPAIR-01 | main CI修复／PR96整合／稳定镜头／旧八房瘦身 | PARALLEL-INTEGRATION-01 | review | [任务](evidence/main_pr96_repair01/main-P66e8/README.md) |
| FOREST-FRUIT-ROUTES-04 | 森林果实目标与推荐／可选／恢复点位梳理 | FOREST-FOCUS-ROUTES-03 | review | [任务](design/forest_fruit_routes_v14.md) |
| FOREST-FOCUS-ROUTES-03 | 钩索独立focus反馈与森林v13交织探索 | FOREST-GRAPPLE-02 | in_progress | [任务](quality/records/FOREST-FOCUS-ROUTES-03.json) |
| PARALLEL-INTEGRATION-01 | 最新并行分支整合与Web重部署 | FOREST-GRAPPLE-02 | in_progress | [记录](quality/records/PARALLEL-INTEGRATION-01.json) |
| FOREST-GRAPPLE-CONSUMERS-02 | 本轮动作／版本与严格因果验收消费者迁移 | FOREST-GRAPPLE-02 | in_progress | [任务](quality/records/FOREST-GRAPPLE-CONSUMERS-02.json) |
| FOREST-GRAPPLE-02 | 钩拉手感／停留环／15%双瞄准／纵向连续动作密度 | FOREST-FEEDBACK-01 | in_progress | [任务](quality/records/FOREST-GRAPPLE-02.json) |
| FOREST-FEEDBACK-01 | 扩大森林／真实空中连续动作／生态与地块场景语言 | FOREST-DEPTH-02 | in_progress | [任务](quality/records/FOREST-FEEDBACK-01.json) |
| FOREST-DEPTH-02 | 森林动作空间／探索／生态／两Boss重构及现有流程改进 | FOREST-PLAYABLE-01 | in_progress | [记录](quality/records/FOREST-DEPTH-02.json) |
| FOREST-DEPTH-TEST-CONSUMERS-01 | 测试消费者真实App／Node生命周期／严格退出与证据修复 | FOREST-DEPTH-02 | review | [任务](quality/records/FOREST-DEPTH-TEST-CONSUMERS-01.json) |
| FOREST-DEPTH-PLAINS-AUDIO-01 | 旧平原黄金测试的真实回退音频清理与负例严格性 | FOREST-DEPTH-02 | review | [任务](quality/records/FOREST-DEPTH-PLAINS-AUDIO-01.json) |
| FOREST-DEPTH-CANOPY-READER-01 | Guardian奖励后当前Canopy图2的版本身份读取器迁移 | FOREST-DEPTH-02 | review | [任务](quality/records/FOREST-DEPTH-CANOPY-READER-01.json) |
| FOREST-DEPTH-PREFLIGHT-ASSET-CLOSURE-01 | G依赖闭包／preflight词法复用 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/G_bounded_followup01/README.md) |
| FOREST-DEPTH-PLAINS-EXPERIENCE-RELEASE-01 | F实际负例泄漏与原夹具release | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/plains_experience_release01/README.md) |
| FOREST-DEPTH-PLAINS-EXPERIENCE-FOLLOWUP | E失败分账与inner原件收集 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/plains_experience_artifacts01/README.md) |
| FOREST-DEPTH-GIT-FIXTURE-FOLLOWUP | 原CI清理失败与本地夹具隔离 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/git_fixture_lifecycle01/README.md) |
| FOREST-DEPTH-TWIN-PORT-REVIEW | 双洞隔离黄金淘汰与清理 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/twin_port_rejected01/README.md) |
| FOREST-DEPTH-ROOT11-ENTRY-REVIEW | v11入口扩展退休与原件保留 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/root11_entry_rejected01/README.md) |
| FOREST-DEPTH-TRAILING-BUD-REVIEW | 尾苞01–03停止与封存 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/trailing_bud_rejected01/README.md) |
| FOREST-DEPTH-MOBILE-ANCHOR-REVIEW | Whole-body黄金淘汰与证据保存 | FOREST-DEPTH-02 | review | [任务](evidence/forest_depth_v2/mobile_anchor_rejected01/README.md) |
| FOREST-DEPTH-CI-LANES-01 | CI两lane覆盖与同源证明收口 | FOREST-DEPTH-02 | review | [任务](quality/records/FOREST-DEPTH-CI-LANES-01.json) |
| FOREST-PLAYABLE-01 | 森林两图／能力和地区选择／调试直选 | FOREST-DESIGN-01 | review | [记录](quality/records/FOREST-PLAYABLE-01.json) |
| FOREST-DESIGN-01 | 荆棘森林随机区域／怪物G0设计 | GRAPPLE-FIX-01 | review | [任务](design/thorn_forest_region.md) |
| UNDERWORLD-PLAINS-01 | Underworld正式平原、玩家动作/机关/商人、家园与UI及Til… | WINDCHIME-FIVE-STYLE-01 | review | [记录](quality/records/UNDERWORLD-PLAINS-01.json) |
| WINDCHIME-FIVE-STYLE-01 | 五锚点与Underworld/Cavern三地区实机比较 | WINDCHIME-PIXEL-01 | review | [记录](quality/records/WINDCHIME-FIVE-STYLE-01.json) |
| WINDCHIME-PIXEL-01 | 新像素风格重制正式平原两图、三层独立视差 | WINDCHIME-STYLE-01 | review | [记录](quality/records/WINDCHIME-PIXEL-01.json) |
| WINDCHIME-STYLE-01 | 风铃平原新参考风格素材与手工实景 | TILE-MAP-PLAN-01 | review | [记录](quality/records/WINDCHIME-STYLE-01.json) |
| TILE-MAP-PLAN-01 | 视频方法到后续tile map生产规划 | ART-BLOB47-CARTOON-02 | review | [记录](quality/records/TILE-MAP-PLAN-01.json) |
| ART-BLOB47-CARTOON-02 | 向洞窟探险2/马里奥制造2饱满卡通方向重定向 | ART-BLOB47-FOUNDATION-01 | review | [记录](quality/records/ART-BLOB47-CARTOON-02.json) |
| ART-BLOB47-FOUNDATION-01 | 从零47-tile地基、三层美术流程和可试玩候选 | — | review | [记录](quality/records/ART-BLOB47-FOUNDATION-01.json) |
| PLAINS-WORLD-REBUILD-01 | 从世界结构共同生成连续平原操作与绘画 | — | review | [记录](quality/records/PLAINS-WORLD-REBUILD-01.json) |
| PLAINS-ART-LANGUAGE-01 | 模块与大地图生成阶段共同引入可执行美术语言 | — | review | [记录](quality/records/PLAINS-ART-LANGUAGE-01.json) |
| PLAINS-LANDFORM-01 | 环境构造先行的平原关卡与美术联合生产 | — | blocked | [记录](quality/records/PLAINS-LANDFORM-01.json) |
| PLAINS-JOINT-RECOIL-01 | 一个真实反冲挑战联合产出碰撞、完整岸体和接口 | PLAINS-REGIONAL-01 | blocked | [记录](quality/records/PLAINS-JOINT-RECOIL-01.json) |
| PLAINS-REGIONAL-01 | 正式随机整区与同源地貌/全图美术生产 | PLAINS-JOINT-01 | blocked | [记录](quality/records/PLAINS-REGIONAL-01.json) |
| PLAINS-JOINT-01 | 同一场所意图联合推导几何、体块、构图与景层 | — | review | [记录](quality/records/PLAINS-JOINT-01.json) |
| PLAINS-PLACES-01 | 完整体块与随机场所艺术生产 | — | review | [记录](quality/records/PLAINS-PLACES-01.json) |
| P1-ENV-ROUTING-01 | 当前美术入口与测试绑定迁移 | P1-ENV-01 | done | [记录](quality/records/P1-ENV-ROUTING-01.json) |
| P1-ENV-01 | 平原完整环境与随机场所共同生产 | ART-DIRECTION-02 | blocked | [记录](quality/records/P1-ENV-01.json) |
| ART-DIRECTION-02 | 四方向重新探索，等待用户选择 | PAINTED-TERRAIN-01 | review | [记录](quality/records/ART-DIRECTION-02.json) |
| PAINTED-TERRAIN-01 | B曲线驱动绘画截面与空间生产 | VISUAL-LANGUAGE-01 | review | [记录](quality/records/PAINTED-TERRAIN-01.json) |
| VISUAL-LANGUAGE-01 | B雨釉与偏心视觉开发/原生可逆样板 | SPATIAL-GOLDEN-01 | blocked | — |
| STORY-WORKFLOW-01 | 剧情写作方法、任务模板与Codex Skill | STORY-DESIGN-03 | review | [记录](quality/records/STORY-WORKFLOW-01.json) |
| STORY-DESIGN-03 | 统一最后一天循环、家园逻辑与多通细案 | STORY-DESIGN-02 | review | [记录](quality/records/STORY-DESIGN-03.json) |
| STORY-DESIGN-02 | 多次通关、时间规则、活老师责任与16区Boss剧情重写 | STORY-DESIGN-01 | review | [记录](quality/records/STORY-DESIGN-02.json) |
| STORY-DESIGN-01 | 完整背景、16区叙事、家园NPC与碎片呈现提案 | — | review | [记录](quality/records/STORY-DESIGN-01.json) |
| GRAPPLE-FIX-01 | 钩索射程、小跳与移动敌人一致性修复 | ACTION-BUDGET-01 | review | [记录](quality/records/GRAPPLE-FIX-01.json) |
| CONTINUOUS-SOURCE-CALIBRATION-01 | 实际失败母版的连续源校准工程 | PRODUCTION-CAPABILITY-REPAIR-01 | review | [记录](quality/records/CONTINUOUS-SOURCE-CALIBRATION-01.json) |
| PRODUCTION-CAPABILITY-REPAIR-01 | PR69真实失败驱动的发布/Harness/阶段报告修复 | — | blocked | [记录](quality/records/PRODUCTION-CAPABILITY-REPAIR-01.json) |
| PLAINS-CONNECTED-FAMILIES-01 | 自然岩壁连接与完整有根中景资产家族 | PRODUCTION-CAPABILITY-REPAIR-01 | in_progress | [记录](quality/records/PLAINS-CONNECTED-FAMILIES-01.json) |
| PLAINS-ROOTBELL-SPATIAL-01 | RootBell联合空间与不同合法判断 | PRODUCTION-CAPABILITY-REPAIR-01 | review | [记录](quality/records/PLAINS-ROOTBELL-SPATIAL-01.json) |
| V3-FOREST-STARTUP-01 | 短句森林H-only开发样板 | V3-PIPELINE-01 | blocked | [记录](quality/records/V3-FOREST-STARTUP-01.json) |
| V3-EVIDENCE-RELIABILITY-01 | V3 ROOT证据可靠性与UID拒读保护 | — | review | [记录](quality/records/V3-EVIDENCE-RELIABILITY-01.json) |
| V3-PIPELINE-01 | V3阶段恢复与区域职责路由 | — | review | [记录](quality/records/V3-PIPELINE-01.json) |
| V3-ASSET-CLOCK-01 | V3宽低原创旧钟机械遗迹母版 | — | review | [记录](quality/records/V3-ASSET-CLOCK-01.json) |
| V3-ASSET-WOODLAND-01 | V3远/中远树林坡脊双cutout母版 | — | review | [记录](quality/records/V3-ASSET-WOODLAND-01.json) |
| V3-ASSET-01 | V3共享岩肩与完整维修建筑母版 | — | review | [记录](quality/records/V3-ASSET-01.json) |
| PLAINS-PRODUCTION-V3-01 | 平原全域体验与区域自主生产V3 | VISUAL-DIRECTOR-01 | in_progress | [记录](quality/records/PLAINS-PRODUCTION-V3-01.json) |
| PLAINS-VISUAL-REMAKE-01 | 平原全区域美术重制 | VISUAL-DIRECTOR-01 | planned | — |
| VISUAL-DIRECTOR-01 | 自动美术导演与真实水工井庭黄金 | PLAINS-REDESIGN-01 | review | [记录](quality/records/VISUAL-DIRECTOR-01.json) |
| PLAINS-REDESIGN-GUI-LOCATOR-01 | 修复实际地图按钮截图定位并完整复验GUI | PLAINS-REDESIGN-Q6-ROLLBACK-01 | done | [记录](quality/records/PLAINS-REDESIGN-GUI-LOCATOR-01.json) |
| PLAINS-REDESIGN-Q6-ROLLBACK-01 | 回退已拒绝Q6候选并复验原可玩表现 | PLAINS-REDESIGN-Q6-CLIFF-ASSET-01 | review | [记录](quality/records/PLAINS-REDESIGN-Q6-ROLLBACK-01.json) |
| PLAINS-REDESIGN-Q6-CLIFF-ASSET-01 | 两处真实构图所需单次高侧壁资产 | PLAINS-REDESIGN-Q6-REWORK-01 | blocked | [记录](quality/records/PLAINS-REDESIGN-Q6-CLIFF-ASSET-01.json) |
| PLAINS-REDESIGN-Q6-REWORK-01 | 两处Q6黄金构图返工 | PLAINS-REDESIGN-SCENE-01 | blocked | [记录](quality/records/PLAINS-REDESIGN-Q6-REWORK-01.json) |
| FOUNDRY-PLAINS-V10-REVALIDATE-01 | 开发工坊v10依据重验证 | PLAINS-REDESIGN-01 | in_progress | [记录](quality/records/FOUNDRY-PLAINS-V10-REVALIDATE-01.json) |
| PLAINS-REDESIGN-GOLDEN-01 | 精巧连续动作黄金 | PLAINS-REDESIGN-01 | review | [记录](quality/records/PLAINS-REDESIGN-GOLDEN-01.json) |
| PLAINS-REDESIGN-SPATIAL-01 | 两图语义空间生成 | PLAINS-REDESIGN-GOLDEN-01 | in_progress | [记录](quality/records/PLAINS-REDESIGN-SPATIAL-01.json) |
| PLAINS-REDESIGN-EXPERIENCE-01 | 探索动作与联合遭遇返工 | PLAINS-REDESIGN-SPATIAL-01 | in_progress | [记录](quality/records/PLAINS-REDESIGN-EXPERIENCE-01.json) |
| PLAINS-REDESIGN-ENCOUNTER-01 | 正式敌情感知自动试玩 | PLAINS-REDESIGN-EXPERIENCE-01 | review | [记录](quality/records/PLAINS-REDESIGN-ENCOUNTER-01.json) |
| PLAINS-REWARD-ENTRY-01 | 高奖入口联合遭遇返工 | PLAINS-REDESIGN-ENCOUNTER-01 | in_progress | [记录](quality/records/PLAINS-REWARD-ENTRY-01.json) |
| PLAINS-REDESIGN-SCENE-01 | 四身份场景合屏 | PLAINS-REWARD-ENTRY-01 | review | [记录](quality/records/PLAINS-REDESIGN-SCENE-01.json) |
| PLAINS-REDESIGN-01 | 平原整体设计实战 | LEVEL-AUTONOMY-01 | review | [记录](quality/records/PLAINS-REDESIGN-01.json) |
| ALL-WEAPONS-01 | 全武器与360钩索 | TRAVERSAL-REWORK-01 | review | [记录](quality/records/ALL-WEAPONS-01.json) |
| ACTION-BUDGET-01 | 位移预算与动作收束 | WEAPON-FEEL-01 | review | [记录](quality/records/ACTION-BUDGET-01.json) |
| WEAPON-FEEL-01 | 六项武器手感返工 | STUDIO-INPUT-01 | review | [记录](quality/records/WEAPON-FEEL-01.json) |
| STUDIO-INPUT-01 | 武器点选与练习巡逻 | ALL-WEAPONS-01 | review | [记录](quality/records/STUDIO-INPUT-01.json) |
| TRAVERSAL-REWORK-01 | 墙跳/钩索与输入返工 | AIR-REFILL-01 | review | [记录](quality/records/TRAVERSAL-REWORK-01.json) |
| AIR-REFILL-01 | 空中续航与试玩 | ACTOR-ACTIONS-01 | review | [记录](quality/records/AIR-REFILL-01.json) |
| PLAINS-TERRAIN-03 | 木桥返工与覆盖闭环 | PLAINS-TERRAIN-02 | review | [记录](quality/records/PLAINS-TERRAIN-03.json) |
| PLAINS-TERRAIN-02 | 美术正式接入 | PLAINS-QUALITY-01 | review | [记录](quality/records/PLAINS-TERRAIN-02.json) |
| DOC-01 | P0历史 | — | done | — |
| DOC-02 | P0 | DOC-01 | done | — |
| ENV-01 | P1 | DOC-01 | review | — |
| CORE-01 | P1 | ENV-01 | review | — |
| CORE-02 | P1 | CORE-01 | review | — |
| DELIVERY-EFFICIENCY-01 | P1 | ACTION-BUDGET-01 | review | [记录](quality/records/DELIVERY-EFFICIENCY-01.json) |
| BASE-01 | P1 | DOC-02 | done | — |
| INPUT-01 | P1 | CORE-02 | awaiting-device | — |
| INPUT-PC-01 | P1 | INPUT-01 | awaiting-device | — |
| WIN-01 | P1 | INPUT-PC-01 | awaiting-device | — |
| APK-01 | P1 | INPUT-01 | awaiting-device | — |
| WORLD-01 | P1历史 | CORE-02 | awaiting-device | — |
| LEVEL-01 | P1历史 | WORLD-01, APK-01 | awaiting-device | — |
| FRAME-01 | P2准备 | BASE-01 | done | — |
| HEALTH-01 | P2 | FRAME-01 | done | — |
| ENEMY-01 | P2 | HEALTH-01 | done | — |
| DAMAGE-01 | P2 | ENEMY-01 | done | — |
| SEGMENT-01 | P2 | DAMAGE-01 | done | — |
| DEATH-01 | P2 | SEGMENT-01 | done | — |
| SUPPLY-01 | P3 | DEATH-01 | done | — |
| BUILD-01 | P3 | SUPPLY-01 | done | — |
| REWARD-01 | P3 | BUILD-01 | done | — |
| SHOP-01 | P3 | REWARD-01 | done | — |
| RUN-01 | P4 | SHOP-01 | done | — |
| BOSS-01 | P4 | RUN-01 | done | — |
| HOME-01 | P4 | BOSS-01 | done | — |
| LEVEL-02 | P4 | HOME-01 | awaiting-device | — |
| RUN-TEN-01 | P5 | HOME-01 | done | — |
| UI-01 | 独立 | HOME-01 | done | — |
| GEN-DESIGN-01 | P5 | RUN-TEN-01 | done | — |
| GEN-MODULES-01 | P5 | GEN-DESIGN-01 | review | — |
| GEN-PREVIEW-01 | P5独立试玩 | GEN-DESIGN-01 | review | — |
| GEN-SEAM-01 | P5独立试玩 | GEN-PREVIEW-01 | review | — |
| GEN-CHALLENGE-01 | P5独立试玩 | GEN-SEAM-01 | review | — |
| GEN-PORTS-01 | P5独立试玩 | GEN-SEAM-01 | review | — |
| PLAINS-GEN-01 | P5独立试玩 | BIOME-DESIGN-01, GEN-SEAM-01 | review | — |
| GEN-LAYOUT-01 | P5 | GEN-MODULES-01, LEVEL-02 | planned | — |
| GEN-DIFFICULTY-01 | P5 | GEN-LAYOUT-01, BIOME-DESIGN-01 | planned | — |
| GEN-01 | P5 | RUN-TEN-01, GEN-DIFFICULTY-01 | planned | — |
| LEVEL-GEN-01 | P5 | GEN-01 | planned | — |
| LOOP-01 | P5 | LEVEL-GEN-01 | planned | — |
| META-01 | P6 | LOOP-01 | planned | — |
| SAVE-01 | P6 | META-01 | planned | — |
| CONTENT-01 | P6 | SAVE-01 | planned | — |
| WORLD-STORY-01 | 设计锚点 | DOC-02 | review | — |
| BIOME-DESIGN-01 | 设计规划 | WORLD-STORY-01, GEN-DESIGN-01 | review | — |
| REGION-ROUTE-01 | P6内容切片 | WORLD-STORY-01, GEN-01 | planned | — |
| STORY-01 | P6 | WORLD-STORY-01, REGION-ROUTE-01, SAVE-01 | planned | — |
| ART-POLISH-01 | 独立美术精修 | WORLD-STORY-01, ART-PLAINS-01 | planned | — |
| ART-PLAINS-01 | 独立 | DOC-02 | review | — |
| ART-01 | 独立 | DOC-02 | ready | — |
| WALL-SLIDE-01 | 后续能力 | BUILD-01, PLAINS-GEN-01 | planned | — |
| WALL-ROUTE-01 | 后续能力路线 | WALL-SLIDE-01, REGION-ROUTE-01 | planned | — |
| ART-LATEST-01 | 表现 | ART-PLAINS-01 | review | — |
| PLAINS-MODULES-02 | P5切片 | PLAINS-GEN-01 | done | — |
| PLAINS-TEN-GEN-01 | P5切片 | PLAINS-MODULES-02, RUN-TEN-01 | done | — |
| NOTES-META-01 | 最小P6切片 | HOME-01 | done | — |
| SAVE-NOTES-01 | 最小P6切片 | NOTES-META-01 | done | — |
| PLAINS-TEN-DEVICE-01 | 设备验收 | PLAINS-TEN-GEN-01, SAVE-NOTES-01 | awaiting-device | — |
| WEB-LOAD-01 | 表现/工具 | PLAINS-TEN-GEN-01 | done | — |
| PLAINS-VIEW-01 | 表现 | ART-LATEST-01 | review | — |
| HOME-UI-02 | P4表现 | SAVE-NOTES-01 | done | — |
| PLAINS-VARIETY-02 | P5 | PLAINS-TEN-GEN-01 | done | — |
| EXIT-REWARD-02 | P3/P5 | PLAINS-TEN-GEN-01 | done | — |
| FEEL-VFX-01 | 表现/调参 | PLAINS-TEN-GEN-01 | review | — |
| RUN-EIGHT-01 | P5修订 | PLAINS-TEN-GEN-01 | done | — |
| GEN-SPATIAL-01 | P5优先 | PLAINS-VARIETY-02 | review | — |
| EXIT-CONFIRM-01 | P3/P5 | EXIT-REWARD-02 | done | — |
| PLAINS-ART-02 | 表现 | ART-LATEST-01 | review | — |
| HURT-FEEL-01 | 表现/调参 | FEEL-VFX-01 | review | — |
| HK-COMPARE-01 | 参数报告 | PLAINS-GEN-01 | done | — |
| GEN-BRANCH-01 | P5切片 | GEN-SPATIAL-01 | review | — |
| GEN-LIBRARY-02 | P5切片 | GEN-BRANCH-01 | review | — |
| TOUCH-FLOAT-01 | 输入 | INPUT-01 | review | — |
| ENEMY-DROP-01 | P3/P5切片 | GEN-SPATIAL-01 | review | — |
| PLAINS-SCALE-01 | 表现 | PLAINS-ART-02 | review | — |
| INPUT-COMFORT-01 | 输入 | TOUCH-FLOAT-01 | review | — |
| SEED-FRESH-01 | P5修复 | GEN-BRANCH-01 | review | — |
| GEN-VARIETY-DESIGN-01 | P5设计 | GEN-BRANCH-01 | done | — |
| GEN-RECOIL-GATE-02 | P5 | GEN-LIBRARY-02, INPUT-COMFORT-01 | planned | — |
| GEN-ARCHETYPE-01 | P5 | GEN-VARIETY-DESIGN-01, GEN-RECOIL-GATE-02 | planned | — |
| GEN-ENCOUNTER-01 | P5 | GEN-ARCHETYPE-01 | planned | — |
| GEN-NOVELTY-01 | P5 | GEN-ENCOUNTER-01, SEED-FRESH-01 | planned | — |
| PLAINS-SINGLE-JUMP-01 | P5 | GEN-LIBRARY-02 | review | — |
| ROUTE-SIGN-01 | P5 | GEN-LIBRARY-02 | review | — |
| GEN-ENCOUNTER-02 | P5 | GEN-LIBRARY-02 | review | — |
| GEN-BLUEPRINT-02 | P5 | GEN-ENCOUNTER-02 | review | — |
| GEN-RISK-01 | P5 | GEN-BLUEPRINT-02, ROUTE-SIGN-01 | review | — |
| GEN-RECOVERY-01 | P5 | PLAINS-SINGLE-JUMP-01 | review | — |
| GEN-RHYTHM-01 | P5 | GEN-BLUEPRINT-02 | review | — |
| CAMERA-COMFORT-01 | P5 | GEN-BLUEPRINT-02 | awaiting-device | — |
| PLAINS-ART-V3-01 | P5 | GEN-BLUEPRINT-02 | awaiting-device | — |
| GEN-BRIDGE-RHYTHM-02 | P5 | GEN-BLUEPRINT-02 | review | — |
| PLAINS-READABILITY-01 | P5 | GEN-BLUEPRINT-02 | awaiting-device | — |
| GEN-GROUNDED-01 | P5 | GEN-BLUEPRINT-02 | awaiting-device | — |
| CONTROL-COMFORT-02 | P5 | GEN-BLUEPRINT-02 | awaiting-device | — |
| PLAINS-ENCOUNTER-DENSITY-01 | P5 | CONTROL-COMFORT-02, GEN-GROUNDED-01 | awaiting-device | — |
| PLAINS-HAZARD-DENSITY-01 | P5 | CONTROL-COMFORT-02 | awaiting-device | — |
| SHOT-LATCH-TRIAL-01 | P5 | PLAINS-ENCOUNTER-DENSITY-01, PLAINS-HAZARD-DENSITY-01 | awaiting-device | [任务](windchime_trial.md) |
| PLAINS-CONTINUITY-02 | P5 | GEN-GROUNDED-01 | awaiting-device | — |
| SHOT-LATCH-RUN-01 | P5 | SHOT-LATCH-TRIAL-01 | awaiting-device | — |
| PLAINS-ENEMY-ACTIONS-01 | P5 | PLAINS-ENCOUNTER-DENSITY-01 | awaiting-device | — |
| PLAINS-LIVING-REVIEW-01 | P5 | PLAINS-CONTINUITY-02, SHOT-LATCH-RUN-01, PLAINS-ENEMY-ACTIONS-01 | awaiting-device | — |
| PLAINS-COHESION-03 | P5 | PLAINS-CONTINUITY-02 | awaiting-device | — |
| WINDKEEPER-01 | P5 | SHOT-LATCH-RUN-01 | awaiting-device | — |
| PLAINS-FEEDBACK-02 | P5 | PLAINS-ENEMY-ACTIONS-01 | awaiting-device | — |
| PLAINS-MAIN-01 | P5 | PLAINS-COHESION-03, WINDKEEPER-01, PLAINS-FEEDBACK-02 | done | — |
| POPT-01 | P5 | WINDKEEPER-01 | review | [任务](plains_optimization_runtime.md) |
| POPT-02 | P5 | POPT-01 | review | [任务](plains_optimization_runtime.md) |
| POPT-03 | P5 | POPT-02 | review | [任务](plains_optimization_runtime.md) |
| POPT-04 | P5 | POPT-03 | awaiting-device | [任务](plains_optimization_runtime.md) |
| POPT-05 | P5 | POPT-04 | awaiting-device | [任务](plains_optimization_runtime.md) |
| POPT-06 | P5 | POPT-05 | awaiting-device | [任务](plains_optimization_runtime.md) |
| POPT-07 | P5 | POPT-06 | done | [任务](plains_optimization_runtime.md) |
| POPT-08 | P5 | POPT-07 | awaiting-device | [任务](plains_optimization_runtime.md) |
| PLAINS-FEEDBACK-01 | 首区优化 | PLAINS-GEN-01 | review | [任务](plains_combat_variety_audio.md) |
| GEN-ROOM-GRAMMAR-01 | 首区生成 | PLAINS-GEN-01 | review | [任务](plains_room_grammar.md) |
| GEN-ROOM-PLAYTEST-01 | 首区设备试玩 | GEN-ROOM-GRAMMAR-01 | awaiting-device | — |
| GEN-PLAINS-REGION-01 | 首区生成 | GEN-ROOM-GRAMMAR-01 | review | [任务](plains_connected_region.md) |
| GEN-PLAINS-REGION-PLAYTEST-01 | 首区设备试玩 | GEN-PLAINS-REGION-01 | awaiting-device | — |
| PLAINS-TWO-MAPS-01 | 首区流程 | GEN-PLAINS-REGION-01 | review | — |
| PLAINS-FOG-MAP-01 | 首区探索 | PLAINS-TWO-MAPS-01 | review | — |
| PLAYTEST-PUBLISH-01 | 试玩交付 | PLAINS-FOG-MAP-01 | review | — |
| PLAINS-PRESSURE-01 | 首区内容 | PLAINS-TWO-MAPS-01 | review | — |
| PLAINS-BOSS-REDESIGN-01 | 首区Boss | PLAINS-PRESSURE-01 | review | — |
| PLAINS-SPATIAL-01 | 首区空间战斗 | PLAINS-BOSS-REDESIGN-01 | review | — |
| PLAINS-EXPERIENCE-01 | 多维平台肉鸽体验与精力道具 | PLAINS-SPATIAL-01 | review | — |
| PLAINS-EXPLORATION-01 | 首区探索/操作与奖励 | PLAINS-EXPERIENCE-01 | review | [任务](plains_exploration_expansion.md) |
| PLAINS-PLATFORM-PLAY-01 | 首区表面机关与平台Boss | PLAINS-EXPLORATION-01 | review | [任务](plains_interactive_platforms.md) |
| PLAINS-COHESION-01 | 首区连贯美术和空间压力 | PLAINS-PLATFORM-PLAY-01 | review | [任务](plains_cohesion.md) |
| WEB-LOAD-02 | 试玩传输与缓存 | WEB-LOAD-01, PLAINS-COHESION-01 | review | [任务](web_loading_resilience.md) |
| PROJECT-HARNESS-01 | harness / skills v1 | — | review | — |
| QUALITY-SYSTEM-01 | 生产流程、八个 Skills、证据约束 | — | done | [任务](quality/implementation_report.md) |
| HARNESS-WEB-01 | 基线严格 Web 导出失败定位 | — | blocked | — |
| PAUSE-TEST-MIGRATION-01 | 暂停冻结语义回归测试迁移 | QUALITY-SYSTEM-01 | review | [记录](quality/records/PAUSE-TEST-MIGRATION-01.json) |
| QUALITY-LOOP-01 | 质量迭代 | QUALITY-SYSTEM-01 | blocked | [记录](quality/records/QUALITY-LOOP-01.json) |
| PLAINS-QUALITY-01 | 当前内容审查 | QUALITY-LOOP-01 | review | [记录](quality/records/PLAINS-QUALITY-01.json) |
| FOUNDRY-01 | 开发工坊 | GEN-MODULES-01 | awaiting-device | [任务](platforming_foundry.md) |
| FOUNDRY-MAIN-01 | 实验室主线融合 | FOUNDRY-01, QUALITY-SYSTEM-01 | awaiting-device | [记录](quality/records/FOUNDRY-MAIN-01.json) |
| ACTION-DESIGN-01 | 设计收录与流程规划 | — | review | [记录](quality/records/ACTION-DESIGN-01.json) |
| ACTION-INVENTORY-01 | 角色/动作盘点 | ACTION-DESIGN-01 | planned | — |
| ACTION-INPUT-01 | 三端操作原型 | ACTION-INVENTORY-01 | planned | — |
| ACTION-RUNTIME-01 | 单武器动作最小切片 | ACTION-INPUT-01 | planned | — |
| ACTION-ENERGY-01 | 共鸣最小切片 | ACTION-RUNTIME-01 | planned | — |
| ACTION-GOLDEN-01 | Courier三连+W样板 | ACTION-RUNTIME-01 | planned | — |
| ACTION-BRANCHES-01 | 六分支与H/D | ACTION-GOLDEN-01 | planned | — |
| ACTION-SKILLS-01 | 六Lv.3主动技 | ACTION-BRANCHES-01, ACTION-ENERGY-01 | planned | — |
| ACTION-LOCKS-01 | 成长与地区锁 | ACTION-SKILLS-01 | planned | — |
| ACTION-DEVICE-01 | 全范围体验 | ACTION-LOCKS-01 | planned | — |
| ACTOR-ACTIONS-01 | 人物连续动作实现 | ACTION-DESIGN-01 | review | [记录](quality/records/ACTOR-ACTIONS-01.json) |
| LEVEL-HARNESS-V2-01 | 生产体系 | DELIVERY-EFFICIENCY-01 | review | [记录](quality/records/LEVEL-HARNESS-V2-01.json) |
| LEVEL-AUTONOMY-01 | 自主关卡生产 | LEVEL-HARNESS-V2-01 | review | [记录](quality/records/LEVEL-AUTONOMY-01.json) |
| PLAINS-AUTONOMY-01 | 平原验证切片 | LEVEL-AUTONOMY-01 | review | [记录](quality/records/PLAINS-AUTONOMY-01.json) |
| PLAINS-ACTION-GOLDEN-01 | 平原跨沟与低顶短动作链 | PLAINS-AUTONOMY-01 | review | [记录](quality/records/PLAINS-ACTION-GOLDEN-01.json) |
| FOUNDRY-AUTONOMY-REVALIDATE-01 | 开发工坊v9依据重验证 | LEVEL-AUTONOMY-01 | review | [记录](quality/records/FOUNDRY-AUTONOMY-REVALIDATE-01.json) |
| V3-SCENE-01 | V3主要空间表现消费者 | — | review | [记录](quality/records/V3-SCENE-01.json) |
| V3-ENEMY-01 | V3-ENEMY-01 | — | review | [记录](quality/records/V3-ENEMY-01.json) |
| CLIFF-01 | V3完整低宽岸端断面母件 | — | review | [记录](quality/records/CLIFF-01.json) |
| PANEL-01 | V3窄悬空机械石挡板母件 | — | review | [记录](quality/records/PANEL-01.json) |
| V3-SCENE-LAYERS-01 | 钟庭与两深度树林真实消费者 | V3-SCENE-01 | review | [记录](quality/records/V3-SCENE-LAYERS-01.json) |
| V3-COMPLETED-LEASE-RECOVERY-01 | 当前已完成review租约收集 | — | review | [记录](quality/records/V3-COMPLETED-LEASE-RECOVERY-01.json) |
| V3-ASSET-BOSS-01 | V3原创Boss完整双侧调律后庭 | — | review | [记录](quality/records/V3-ASSET-BOSS-01.json) |
| V3-ASSET-BOSS-02 | V3 Boss后庭最后一次母版AI编辑 | — | review | [记录](quality/records/V3-ASSET-BOSS-02.json) |
| V3-CHECK-PREFLIGHT-01 | 已选检查输入物化前置与真实命令合同 | PLAINS-PRODUCTION-V3-01 | done | [记录](quality/records/V3-CHECK-PREFLIGHT-01.json) |
| V3-ENCOUNTER-V2-01 | Implement Root Bell encounter-v2 ph… | PLAINS-PRODUCTION-V3-01 | review | [记录](quality/records/V3-ENCOUNTER-V2-01.json) |
| V3-ENEMY-EVIDENCE-REPAIR-01 | Repair only the actual Root Bell fo… | PLAINS-PRODUCTION-V3-01 | review | [记录](quality/records/V3-ENEMY-EVIDENCE-REPAIR-01.json) |
| V3-TERRAIN-BINDING-02 | Process-only source and evidence re… | PLAINS-PRODUCTION-V3-01 | review | [记录](quality/records/V3-TERRAIN-BINDING-02.json) |
| V3-TERRAIN-FAMILY-01 | Actual authored limestone end/body/… | PLAINS-PRODUCTION-V3-01 | review | [记录](quality/records/V3-TERRAIN-FAMILY-01.json) |
| V3-SHARED-ENVIRONMENT-01 | 共享独立天空/远山与冠沿轻风 | PLAINS-PRODUCTION-V3-01 | ready | [记录](quality/records/V3-SHARED-ENVIRONMENT-01.json) |
| V3-RELEASE-ADMISSION-01 | 原G1准入项自动消费真实版本化回放与拒绝证据 | PLAINS-PRODUCTION-V3-01 | review | [记录](quality/records/V3-RELEASE-ADMISSION-01.json) |
| CREATIVE-SYSTEM-01 | 三阶段创作系统与可逆瘦身 | — | review | [记录](quality/records/CREATIVE-SYSTEM-01.json) |
| HARNESS-STORAGE-01 | 隔离工作盘预检与clone原诊断 | CREATIVE-SYSTEM-01 | review | [记录](quality/records/HARNESS-STORAGE-01.json) |
| PLAINS-CREATIVE-SLICE-01 | 正式平原艺术样板 | CREATIVE-SYSTEM-01 | review | [记录](quality/records/PLAINS-CREATIVE-SLICE-01.json) |
| FOREST-CREATIVE-DRILL-01 | 短Prompt有限演练 | CREATIVE-SYSTEM-01 | review | [记录](quality/records/FOREST-CREATIVE-DRILL-01.json) |
| SPATIAL-PRODUCTION-01 | 空间创作执行根因修复 | — | review | [记录](quality/records/SPATIAL-PRODUCTION-01.json) |
| SPATIAL-GOLDEN-01 | 草海联合可玩黄金与有限组件复用 | SPATIAL-PRODUCTION-01 | blocked | [记录](quality/records/SPATIAL-GOLDEN-01.json) |
| P1-NATIVE-01 | P1实际平原美术转译 | ART-DIRECTION-02 | review | [记录](quality/records/P1-NATIVE-01.json) |
| P1-RANDOM-01 | P1正式随机平原接入与可选少女外观 | P1-NATIVE-01 | review | [记录](quality/records/P1-RANDOM-01.json) |
| FOREST-CI-COMPAT-01 | 森林兼容字体闭包及共享表现类型依赖修复 | CI-BIBLE-ADMISSION-01 | in_progress | [任务](quality/records/FOREST-CI-COMPAT-01.json) |
| AVATAR-SHARED-STYLE-01 | 历史及当前共享角色外观消费者守门与快反馈 | CI-BIBLE-ADMISSION-01 | in_progress | [任务](quality/records/AVATAR-SHARED-STYLE-01.json) |
| CI-BIBLE-ADMISSION-01 | PR全范围素材登记、精确源码CI与重复事件修复 | REGION-BIBLE-WORKFLOW-01 | in_progress | [任务](quality/records/CI-BIBLE-ADMISSION-01.json) |
| REGION-BIBLE-WORKFLOW-01 | 地区圣经前置、版本绑定与harness/skills流程 | MAIN-PR96-REPAIR-01 | in_progress | [任务](quality/records/REGION-BIBLE-WORKFLOW-01.json) |
| FOREST-BIBLE-V2-01 | 按圣经完成荆棘森林空间、完整美术与环境演出 | REGION-BIBLE-WORKFLOW-01 | in_progress | [任务](quality/records/FOREST-BIBLE-V2-01.json) |
| PLAINS-BIBLE-V2-01 | 森林后按圣经优化风铃平原 | FOREST-BIBLE-V2-01 | planned | [任务](quality/records/PLAINS-BIBLE-V2-01.json) |
| FOREST-EXPLORATION-02 | 实机反馈：森林双图差异、多难度分支奖励、平缓教学及钩索可见/固定点起跳 | — | in_progress | [任务](quality/records/FOREST-EXPLORATION-02.json) |
| HIGH-DENSITY-TERRAIN-03 | 高分辨率地形对齐与克制材质实验 | PIXEL-LIGHT-STUDY-02 | review | [记录](quality/records/HIGH-DENSITY-TERRAIN-03.json) |
| TERRAIN-DENSITY-04 | 完整母版转47格与固定暖光粗细对照 | HIGH-DENSITY-TERRAIN-03 | review | [记录](quality/records/TERRAIN-DENSITY-04.json) |
| HOME-CODEX-01 | 家园道具图鉴、音符永久解锁与出发携带一件 | CHEST-ART-01 | review | [任务](worklines/home_codex_01/scope.md) |
| PLAINS-MONSTER-REVISION-01 | 用户规格返工平原7怪、去普通HP与辅助线、真实比例与工坊复审 | ENEMY-WORKSHOP-01 | review | [记录](quality/records/PLAINS-MONSTER-REVISION-01.json) |
| PLAINS-MAIN-MERGE-01 | 用户授权七怪工作线快速合main，保主线音频/性能并验证冲突 | PLAINS-MOTION-LOOT-02 | review | [任务](worklines/plains_motion_loot_02/main_merge.md) |
| PLAINS-MOTION-LOOT-02 | 七怪全身动作、伤亡音画、固定金币与概率补给完整动画 | PLAINS-MONSTER-REVISION-01 | review | [记录](quality/records/PLAINS-MOTION-LOOT-02.json) |
| PLAINS-MOTION-LOOT-GUARD-02 | 真实面额消费者、绑定与167检查清单的限定迁移独审 | PLAINS-MOTION-LOOT-02 | review | [任务](quality/records/PLAINS-MOTION-LOOT-GUARD-02.json) |
| PLAINS-ROOT-BELL-COIN-GUARD-02 | 根铃实际替换的物种固定金币合同验收迁移 | PLAINS-MOTION-LOOT-02 | review | [记录](quality/records/PLAINS-ROOT-BELL-COIN-GUARD-02.json) |
| PLAINS-DROP-RECEIPT-GUARD-02 | 连续掉落物理保存与不可变结算合同的正式测试迁移 | PLAINS-MOTION-LOOT-02 | review | [任务](quality/records/PLAINS-DROP-RECEIPT-GUARD-02.json) |
| ENEMY-WORKSHOP-01 | 怪物工坊与逐动作网页审核 | ENEMY-STRUCTURE-01 | review | [记录](quality/records/ENEMY-WORKSHOP-01.json) |
| ENEMY-STRUCTURE-01 | 全现有怪物程序整体重构 | ENEMY-ALL-02 | review | [记录](quality/records/ENEMY-STRUCTURE-01.json) |
| PLAINS-REVISION-GUARD-01 | 旧frame到同体rig测试消费者守门迁移独审 | PLAINS-MONSTER-REVISION-01 | review | [记录](quality/records/PLAINS-REVISION-GUARD-01.json) |
| MONSTER-LEGACY-SCOPE-01 | 冻结历史森林回放保留manual，同时真实当前registry/App… | PLAINS-MONSTER-REVISION-01 | review | [记录](quality/records/MONSTER-LEGACY-SCOPE-01.json) |
| MONSTER-PLANNER-SCOPE-01 | planner清单守门适配：保原四摘要与两lane | PLAINS-MONSTER-REVISION-01 | review | [记录](quality/records/MONSTER-PLANNER-SCOPE-01.json) |
| MAIN-UNIFY-20261031 | 整合122与107到含124/125的main，排除123，冻结架构底… | CI-CURRENT-01 | in_progress | [任务](worklines/main_unify_20261031/scope.md) |
| AI-LEVEL-DESIGN-01 | 四层契约、来源审计、离线AI评价与有界生成验证闭环 | CLOUD-EFFICIENCY-01 | review | [任务](ai_level_design_v1/README.md) |
| AI-LEVEL-PILOT-01 | 平原/森林小样、强替代、几何对照及失败回流 | AI-LEVEL-DESIGN-01 | review | [任务](ai_level_design_v1/pilot_design.md) |
| LEVEL-TOOLS-INTEGRATION-01 | PR107离线工具与两Boss主线并集 | MAIN-UNIFY-20261031 | in_progress | [任务](evidence/main_unify_20261031/level-tools/README.md) |
| GAME-ARCH-CI-01 | CI去重与game源码/导出守门 | MAIN-UNIFY-20261031 | in_progress | [任务](worklines/game_architecture_01/execution.md) |
| GAME-ARCH-SESSION-01 | mechanic | GAME-ARCH-CI-01 | in_progress | [记录](quality/records/GAME-ARCH-SESSION-01.json) |
| GAME-ARCH-LEVEL-01 | 纯值地图请求、已解析Plan与实际运行装配；四正式地图接入并保留旧格式… | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-LEVEL-01.json) |
| GAME-ARCH-ENTITY-01 | 三个地图消费者共用敌人快照与恢复，候选行为归现有Registry | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-ENTITY-01.json) |
| GAME-ARCH-LOADOUT-01 | 库存修复及回滚、钱包余额、道具收益和主动施放的真实消费者收敛 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-LOADOUT-01.json) |
| GAME-ARCH-ENTRY-01 | 正式预览与测试共用生产音频生命周期，保留同帧停止既有限制 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-ENTRY-01.json) |
| GAME-ARCH-AUDIO-01 | 单独修复已知音频宿主串用与按钮重复触发；不改音频资源 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-AUDIO-01.json) |
| GAME-ARCH-MESH-01 | 同一次绘制共用姿态解析及UV权重，逐顶点字节等价优化 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-MESH-01.json) |
| FOREST-V11-DEFINITION-01 | 历史v11定义版本混用独立修复 | GAME-ARCH-LEVEL-01 | in_progress | [记录](quality/records/FOREST-V11-DEFINITION-01.json) |
| GAME-ARCH-LAYOUT-01 | 实际功能目录、资源引用及测试/CI输入迁移 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-LAYOUT-01.json) |
| GAME-ARCH-BOSS-STATE-01 | Boss自身快照、生命与决斗恢复所有权收口 | GAME-ARCH-ENTITY-01 | in_progress | [任务](quality/records/GAME-ARCH-BOSS-STATE-01.json) |
| GAME-ARCH-TEST-MIGRATION-01 | 当前与历史测试消费者迁移收口；62文件限定独审 | GAME-ARCH-LAYOUT-01 | in_progress | [任务](quality/records/GAME-ARCH-TEST-MIGRATION-01.json) |
| AUDIO-LAB-MATERIAL-01 | 显式 Lab enemy_hurt ABC 试听与七怪材质路由兼容缺陷… | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/AUDIO-LAB-MATERIAL-01.json) |
| GAME-ARCH-OWNERSHIP-02 | Latch、terminal reentry 与 Boss Arena… | GAME-ARCH-BOSS-STATE-01 | in_progress | [任务](quality/records/GAME-ARCH-OWNERSHIP-02.json) |
| GAME-ARCH-ENGINE-01 | 固定上游Godot回补构建、八文件推广与严格工具链安装整合 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/GAME-ARCH-ENGINE-01.json) |
| CI-BOSS-CONSUMERS-01 | 当前Boss测试消费者与历史fixture边界迁移 | GAME-ARCH-OWNERSHIP-02 | in_progress | [任务](quality/records/CI-BOSS-CONSUMERS-01.json) |
| UNDERWORLD-DEFERRED-LIFETIME-01 | Underworld延迟节点释放与world归属缺陷修复 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/UNDERWORLD-DEFERRED-LIFETIME-01.json) |
| CI-FOUNDRY-CONSUMERS-01 | Android同源Foundry消费者、开发池刷新与三入口统一CI覆盖 | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/CI-FOUNDRY-CONSUMERS-01.json) |
| ASSET-METADATA-LAYOUT-01 | 功能目录迁移后的三条当前资产登记SHA修复 | GAME-ARCH-LAYOUT-01 | in_progress | [任务](quality/records/ASSET-METADATA-LAYOUT-01.json) |
| CI-CONSUMER-PATHS-01 | 既有18消费者装配、输入闭包与真实失败收据 | GAME-ARCH-LAYOUT-01 | in_progress | [任务](quality/records/CI-CONSUMER-PATHS-01.json) |
| ROOT-BELL-PAUSED-RESTORE-01 | 暂停恢复新epoch时同步清RootBell旧命中颗粒 | CI-CONSUMER-PATHS-01 | in_progress | [任务](quality/records/ROOT-BELL-PAUSED-RESTORE-01.json) |
| R3-CURRENT-CONTENT-CONTRACT-01 | 当前Bell真实平台正例、共享夹具与默认完整战斗消费者迁移 | CI-CONSUMER-PATHS-01 | done | [任务](quality/records/R3-CURRENT-CONTENT-CONTRACT-01.json) |
| STAGE-CLAIM-CACHE-OWNER-01 | Stage领取状态归属与共用宝箱候选规则 | GAME-ARCH-LAYOUT-01 | in_progress | [任务](quality/records/STAGE-CLAIM-CACHE-OWNER-01.json) |
| MODULE-CALL-BOUNDARIES-01 | 收紧App/地图/怪物调用边界与模块CI责任 | GAME-ARCH-LAYOUT-01 | in_progress | [任务](quality/records/MODULE-CALL-BOUNDARIES-01.json) |
| CURRENT-AUTHORITY-CI-01 | 当前技术绑定与当前/历史CI分区 | MODULE-CALL-BOUNDARIES-01 | in_progress | [任务](quality/records/CURRENT-AUTHORITY-CI-01.json) |
| BIBLE-VALIDATION-COST-01 | 单次验证共享路径与读取上下文 | CURRENT-AUTHORITY-CI-01 | in_progress | [任务](quality/records/BIBLE-VALIDATION-COST-01.json) |
| APP-WORLD-COMPOSITION-01 | Stage/Actor取消、地图伤害与Boss场地接线 | MODULE-CALL-BOUNDARIES-01 | in_progress | [任务](quality/records/APP-WORLD-COMPOSITION-01.json) |
| MAP-VIEW-BOUNDARY-01 | App最后两处旧地图展示查询归Stage | APP-WORLD-COMPOSITION-01 | in_progress | [任务](quality/records/MAP-VIEW-BOUNDARY-01.json) |
