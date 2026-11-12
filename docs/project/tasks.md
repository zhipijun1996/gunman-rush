# 活跃工作视图

唯一开发基线为最新main，已包含PR139架构约定及PR138主线收敛成果；已放弃的旧PR不审计或择取。基线已有实现按实际消费者复用。已结束工作从本页移出，由Git／PR追溯。待验收、待决定和待排期没有自动开工。表内状态只表达工作进度，验收结果与缺口留在各任务交接。

接续任务先读本行和下一动作，再读对应工作线和直接依赖；新内容审查按需读取质量卡；依赖只列当前任务，已完成的实现直接以main代码为准。新增缺陷只建一个明确范围的任务，更新本页和自己的工作线。运行事实见 [当前状态](current_state.md)，跨会话规则见 [生产规则](cloud_production.md)。

## 制作与返工

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| PLAINS-BIBLE-V2-01 | P21空中反冲提示与牧风者左右换边追压 | — | in_progress | [交接](worklines/plains_bible_v2_01/scope.md) |
| MOBILE-LEVEL-WORKBENCH-01 | Site V18 / r68：双点出口跳房、37房隔离预览与钟心室内分层；整区审核含森林24房规划 | — | review | [交接](worklines/mobile_level_workbench_01/scope.md) |


## 待验收

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| DEATH-RUNTIME-01 | 复验已接入死亡优化的目标设备帧时间 | — | blocked | [交接](worklines/death_runtime_01/scope.md) |
| MOBILE-WEB-FPS-04 | 普通 Web 真实大图帧时间与移动供音复验 | — | blocked | [交接](worklines/mobile_web_fps_04/scope.md) |
| AUDIO-LAB-MATERIAL-01 | Lab 受伤 ABC 试听与七怪声音路由复核 | — | in_progress | [交接](worklines/audio_lab_material_01/scope.md) |
| WINDKEEPER-PRESSURE-01 | 牧风者招式成果与新攻击档位适配审核 | — | review | [交接](worklines/windkeeper_pressure_01/scope.md) |
| BELLSTRIDER-REWORK-01 | 鸣铃巡游机的唯一弱点、三招、回冲与奖励验收 | — | review | [交接](worklines/bellstrider_rework_01/scope.md) |
| ENEMY-ALL-02 | 全现存怪物同体动作与实机审核 | — | review | [交接](worklines/enemy_all_02/scope.md) |
| PLAYER-PRESENTATION-01 | 共鸣蓄力独立集气／释放补帧、声音与特效，按保存结果和取消生命周期接入 | — | review | [交接](worklines/player_presentation_01/scope.md) |

- `DEATH-RUNTIME-01`：聚合首用／战斗／死亡性能链，在同版真实设备复验；技术合入不代签帧时间。
- `MOBILE-WEB-FPS-04`：实体手机复验普通 Web 帧时间、供音与大图；承接 MOBILE-WEB-PERF/AUDIO 系列。
- `AUDIO-LAB-MATERIAL-01`：按实际 Lab 入口复核 enemy_hurt ABC 与七怪材质路由，先确认当前缺陷是否仍可复现。
- `WINDKEEPER-PRESSURE-01`：以现行510HP三阶段实现审核主动追压、六招三阶段与连续原声实战。
- `BELLSTRIDER-REWORK-01`：按现行Definition和最新分体动作审核唯一上端弱点、回冲／失效／奖励与连续原声实战。
- `ENEMY-ALL-02`：按物种卡逐一核真实同体动作、声音和遭遇；不从公共技术检查推定内容完成。
- `PLAYER-PRESENTATION-01`：在当前共享人物消费者检查连续动作和画面；旧快照不代表当前外观已认可。

## 待决定

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| ITEM-V5-01 | 筛选永久装备并逐件迁移NPC升级/休息周期效果 | — | blocked | [交接](worklines/item_v5_01/scope.md) |
| STORY-DESIGN-03 | 固定世界NPC任务、修钟与结局叙事 | — | blocked | [交接](worklines/story_design_03/scope.md) |

- `ITEM-V5-01`：先从旧候选选48件，逐件定义永久ID、NPC升级与周期额度；P17/G19仅在选中时解决。
- `STORY-DESIGN-03`：以固定世界任务、修钟及结局条件重整人物与对白，不继承多Run前提。

## 待排期

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| FOREST-BIBLE-V2-01 | 24房整区坐标、连接与初版玩法方案；手机审核后进入相连灰盒 | — | review | [交接](worklines/forest_bible_v2_01/scope.md) |

- `FOREST-BIBLE-V2-01`：整区候选先审房形、主支路与收集回程，再选03/04/19/20相连灰盒；保留现有H/W/生态资产。

## 固定世界迁移

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| MV-RUNTIME-01 | 全项目架构约定、共用状态与代表样房真实闭环；子任务01A—01J | — | in_progress | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01B | 提取人工施工与独立路线输入，证明生成等价 | — | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01C | 切换config/world权威、运行导出及PCK消费者 | MV-RUNTIME-01B | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01D | 固定房间装载、真实入口/镜头与控制权/卸载 | MV-RUNTIME-01C | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01E | 四种寿命、统一事实/提交、新槽保存与恢复 | MV-RUNTIME-01D | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01F | 首批P房真实闭环，含必要连接P-R08 | MV-RUNTIME-01E | review | [交接](worklines/mv_migration/scope.md) |
| MV-DEMO-02 | 首环路体验整改、正式表现/UI/地图及NPC试制服务地基 | MV-RUNTIME-01F | review | [交接](worklines/mv_migration/scope.md) |
| MV-DEMO-03 | 首环路敌人周期、门台地图、Boss内场、装备页与共鸣回复 | MV-DEMO-02 | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01G | 正式48件与NPC库存/装配成长内容适配 | MV-RUNTIME-01F, ITEM-V5-01 | planned | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01H | 正式人物任务、迁居、主线修钟/演出与结局 | MV-RUNTIME-01F, STORY-DESIGN-03 | planned | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01I | 完整文本/多设备UI、视听与目标平台验收 | MV-RUNTIME-01F | planned | [交接](worklines/mv_migration/scope.md) |
| MV-DEMO-04 | 统一镜头/入场动作、向上交互、机器人充电站与危险收集物可读性 | MV-DEMO-03 | review | [交接](worklines/mv_migration/scope.md) |
| MV-DEMO-05 | 修复道具纹理卡顿、竖门实体落点、既有金币掉落接入、对话与分区镜头 | MV-DEMO-04 | review | [交接](worklines/mv_migration/scope.md) |
| MV-RUNTIME-01J | 不同机制代表房、剩余基础流程与量产准入验收 | MV-DEMO-05 | planned | [交接](worklines/mv_migration/scope.md) |
| MV-WORLD-GRAYBOX-01 | 309房结构与真实运行路线，按消费者退役旧链 | MV-RUNTIME-01J | planned | [交接](worklines/mv_migration/scope.md) |
