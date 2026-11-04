# 活跃工作视图

本页是可继续工作的入口，不是历史流水账。383 个任务 ID 分为本页 14 个当前议题和 [归档](archive/tasks.md) 369 个旧任务。本轮工作处于 PR134 待审；待验收、待决定和待排期没有自动开工。表内状态保留原验收口径，分组和“下一动作”说明现在如何处理。

接续任务先读本行和下一动作，再读对应工作线／质量卡及直接依赖；归档中的依赖用于追溯，不代表需要重跑旧架构。新增缺陷只建一个明确范围的任务，更新本页和自己的工作线。运行事实见 [当前状态](current_state.md)，跨会话规则见 [生产规则](cloud_production.md)。

## 本轮工作

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| CODEX-CONTEXT-01 | PR134 创作兼容、任务收口与文档权威整理 | — | review | [结果](worklines/codex_context_01/results.md) |

- `CODEX-CONTEXT-01`：收口 PR134 创作工具、活跃任务与文档权威；本工作线记录验证和交接。

## 待验收

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| DEATH-RUNTIME-01 | 保持死亡动画，优化死亡运行成本 | FIRST-USE-STUTTER-01 | review | [任务](worklines/death_runtime_01/scope.md) |
| MOBILE-WEB-FPS-04 | 正式Web帧时间、真实大地图空中攻击A/B/A及前景无损优化；PR12… | MOBILE-WEB-AUDIO-FIX-03 | awaiting-device | [任务](quality/records/MOBILE-WEB-FPS-04.json) |
| AUDIO-LAB-MATERIAL-01 | 显式 Lab enemy_hurt ABC 试听与七怪材质路由兼容缺陷… | GAME-ARCH-CI-01 | in_progress | [任务](quality/records/AUDIO-LAB-MATERIAL-01.json) |
| WINDKEEPER-PRESSURE-01 | 60HP牧风者六招三阶段主动追压与连续原声审核 | — | review | [任务](worklines/windkeeper_pressure_01/spec.md) |
| BELLSTRIDER-REWORK-01 | 40HP上端唯一弱点、三招与回冲、机械失效/实体奖励、正式原声实战与工… | — | review | [任务](worklines/bellstrider_rework_01/spec.md) |
| ENEMY-ALL-02 | 全现存怪物同体动作与实机审核 | ENEMY-WORKFLOW-01 | review | [任务](worklines/enemy_asset_audit_01/README.md) |
| PLAYER-PRESENTATION-01 | 主角连续动作代表样板 | CLOUD-EFFICIENCY-01 | in_progress | [任务](quality/records/PLAYER-PRESENTATION-01.json) |

- `DEATH-RUNTIME-01`：聚合首用／战斗／死亡性能链，在同版真实设备复验；技术合入不代签帧时间。
- `MOBILE-WEB-FPS-04`：实体手机复验普通 Web 帧时间、供音与大图；承接 MOBILE-WEB-PERF/AUDIO 系列。
- `AUDIO-LAB-MATERIAL-01`：按实际 Lab 入口复核 enemy_hurt ABC 与七怪材质路由，先确认当前缺陷是否仍可复现。
- `WINDKEEPER-PRESSURE-01`：按当前 60HP 规范审核主动追压、六招三阶段与连续原声实战。
- `BELLSTRIDER-REWORK-01`：按当前 40HP 规范审核唯一上端弱点、回冲／失效／奖励与连续原声实战。
- `ENEMY-ALL-02`：按物种卡逐一核真实同体动作、声音和遭遇；不从公共技术检查推定内容完成。
- `PLAYER-PRESENTATION-01`：在当前共享人物消费者检查连续动作和画面；旧快照不代表当前外观已认可。

## 待决定

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| ITEM-V5-01 | 实现道具V5的72件、16成长与9有效联动 | RUN-GEAR-01 | review | [任务](worklines/item_v5_01/scope.md) |
| STORY-DESIGN-03 | 统一最后一天循环、家园逻辑与多通细案 | STORY-DESIGN-02 | review | [记录](quality/records/STORY-DESIGN-03.json) |
| FOREST-VARIETY-04 | 六类探索场所、两图真实网络与每图8–12/15–20分钟初步体验目标 | FOREST-VARIETY-03 | in_progress | [任务](design/forest_exploration_v18.md) |

- `ITEM-V5-01`：确认 P17 满速充能与 40/55/70% 阶梯的取舍，再调整正式规则与验证。
- `STORY-DESIGN-03`：按最后一天循环审阅具体人物、日程和结局提案；不把提案当已接入剧情。
- `FOREST-VARIETY-04`：确认是否采用显式 v18 体验方案；当前默认仍为 v15，先验实际默认地图。

## 待排期

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| MAPGEN-HOST-WINDCHIME-041 | 0.4.1真实生成/多端口准入/完整起点钟门与最终集成 | MAPGEN-GODOT-04 | review | [结果](worklines/mapgen_041_windchime/results.md) |
| FOREST-BIBLE-V2-01 | 按圣经完成荆棘森林空间、完整美术与环境演出 | REGION-BIBLE-WORKFLOW-01 | in_progress | [任务](quality/records/FOREST-BIBLE-V2-01.json) |
| PLAINS-BIBLE-V2-01 | 森林后按圣经优化风铃平原 | FOREST-BIBLE-V2-01 | planned | [任务](quality/records/PLAINS-BIBLE-V2-01.json) |

- `MAPGEN-HOST-WINDCHIME-041`：按 upstream_requirements 处理整图、邻模块与真实敌人／奖励消费者；0.4.1 切片已经集成。
- `FOREST-BIBLE-V2-01`：依据选定圣经与当前 v15，先确认空间／环境演出差距；与候选 v18 分开验收。
- `PLAINS-BIBLE-V2-01`：森林方向收口后确认平原内容生产范围；不恢复已暂停黄金切片旧任务。
