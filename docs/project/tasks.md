# 活跃工作视图

本页是可继续工作的入口，不是历史流水账。本页保留13个当前议题，[归档](../evidence/tasks.md)保留369个旧任务；已完成工作从本页移出，由 Git／PR 追溯。待验收、待决定和待排期没有自动开工。表内状态只表达工作进度，验收结果与缺口留在各任务交接。

接续任务先读本行和下一动作，再读对应工作线和直接依赖；新内容审查按需读取质量卡；归档中的依赖用于追溯，不代表需要重跑旧架构。新增缺陷只建一个明确范围的任务，更新本页和自己的工作线。运行事实见 [当前状态](current_state.md)，跨会话规则见 [生产规则](cloud_production.md)。

## 本轮工作

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |

## 待验收

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |
| MAPGEN-HOST-WINDCHIME-041 | 修复纵向Port、地形小地图、二维重复度及生成等待并更新试玩 | MAPGEN-GODOT-04 | review | [交接](worklines/mapgen_host_windchime_041/scope.md) |
| DEATH-RUNTIME-01 | 复验已接入死亡优化的目标设备帧时间 | FIRST-USE-STUTTER-01 | blocked | [交接](worklines/death_runtime_01/scope.md) |
| MOBILE-WEB-FPS-04 | 普通 Web 真实大图帧时间与移动供音复验 | MOBILE-WEB-AUDIO-FIX-03 | blocked | [交接](worklines/mobile_web_fps_04/scope.md) |
| AUDIO-LAB-MATERIAL-01 | Lab 受伤 ABC 试听与七怪声音路由复核 | GAME-ARCH-CI-01 | in_progress | [交接](worklines/audio_lab_material_01/scope.md) |
| WINDKEEPER-PRESSURE-01 | 60HP牧风者六招三阶段主动追压与连续原声审核 | — | review | [交接](worklines/windkeeper_pressure_01/scope.md) |
| BELLSTRIDER-REWORK-01 | 鸣铃巡游机的唯一弱点、三招、回冲与奖励验收 | — | review | [交接](worklines/bellstrider_rework_01/scope.md) |
| ENEMY-ALL-02 | 全现存怪物同体动作与实机审核 | ENEMY-WORKFLOW-01 | review | [交接](worklines/enemy_all_02/scope.md) |
| PLAYER-PRESENTATION-01 | 主角连续动作代表样板 | CLOUD-EFFICIENCY-01 | in_progress | [交接](worklines/player_presentation_01/scope.md) |

- `MAPGEN-HOST-WINDCHIME-041`：试玩版本 `f78b51be4131` 已发布；复核三主路／六奖励、纵向跨缝、地形地图和实际等待，算法搜索反例交 map-gen #7。
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
| ITEM-V5-01 | 确认P17移动与G19精英资格，同步规范与实现 | RUN-GEAR-01 | blocked | [交接](worklines/item_v5_01/scope.md) |
| STORY-DESIGN-03 | 确认循环下的人物、日程和结局细案 | STORY-DESIGN-02 | blocked | [交接](worklines/story_design_03/scope.md) |
| FOREST-VARIETY-04 | 确认v18探索场所与时长目标的采用范围 | FOREST-VARIETY-03 | blocked | [交接](worklines/forest_variety_04/scope.md) |

- `ITEM-V5-01`：确认 P17 蓄力移动与 G19 精英资格，再调整正式规则与验证。
- `STORY-DESIGN-03`：确认森林现行 Boss 的叙事衔接、具体人物、日程与结局；叙事提案不替换已选战斗设计。
- `FOREST-VARIETY-04`：确认是否采用显式 v18 体验方案；当前默认仍为 v15，先验实际默认地图。

## 待排期

| 任务 | 目标 | 依赖 | 状态 | 入口 |
| --- | --- | --- | --- | --- |

| FOREST-BIBLE-V2-01 | 按圣经完成荆棘森林空间、完整美术与环境演出 | REGION-BIBLE-WORKFLOW-01 | in_progress | [交接](worklines/forest_bible_v2_01/scope.md) |
| PLAINS-BIBLE-V2-01 | 森林后按圣经优化风铃平原 | FOREST-BIBLE-V2-01 | planned | [交接](worklines/plains_bible_v2_01/scope.md) |

- `FOREST-BIBLE-V2-01`：依据选定圣经与当前 v15，先确认空间／环境演出差距；与候选 v18 分开验收。
- `PLAINS-BIBLE-V2-01`：森林方向收口后确认平原内容生产范围；不恢复已暂停黄金切片旧任务。
