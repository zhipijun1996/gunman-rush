# 地图生成

## 公共协议

`LevelRequest → Provider → LevelPlan → LevelRuntime → Stage／实体工厂`。Request描述地区、地图索引、Seed、实际身体／能力与版本；Provider选择和验证来源，Plan承载已解析内容，Runtime装配真实实例。Stage及区域状态拥有运行节点与恢复账本。

生成不改基础Motor、武器、资源和保存规则。地图、奖励、商店及Boss各用独立随机流。版本化Manifest记录实际选择与能力快照；同版本重建保持实例身份、奖励收据与机关相位。

## 正式来源

| 来源 | 实现与当前选择 |
| --- | --- |
| 平原 | `PlainsLevelProvider` → `PlainsRegionGenerator` → `LegacyRegionPlanAdapter`；每地区两张连通探索图 |
| 森林 | `ForestLevelProvider` → `ThornForestRegionGenerator`；默认 `forest-bible-world-v15`，显式版本由生成器注册表选择 |
| 开发工坊 | `experiments/generation/` 的Foundry入口；验证模块组合、能力profile和输入回放 |
| mapgen开发切片 | SDK 0.4.1、模块包1.1.0、runtime-map/v2；生成job → `RuntimeMapV2Provider` → Plan → `RuntimeMapSliceStage`／公共Runtime |

正式普通出发使用平原／森林来源。mapgen开发入口支持三模块、M35、gears和完整起点风铃；当前起点风铃只覆盖模块到本侧岸，不包含邻模块或完整地区流程。SDK固定版本与校验值来自`config/mapgen_candidate.json`。

## 设计与准入

目标地区的主题及能力锁分别从 [创作入口](creative_direction/README.md) 和 [地区设计](design/player_actions/regions_v0.3.md) 选取相关章节。按主路、可选奖励、隐藏挑战、汇合营地、Boss接近和返回定义路线意图。

模块端口、镜像、坐标与封口先验证身体包络和支撑，再验证真实Motor的速度、冷却、资源与机关相位。主路依赖已经合法授予的能力；敌人死亡或移开后仍须有符合合同的通行／返回方案。

空间、动作、机制、探索决策和视觉变化分别比较。先验证一个完整黄金场所，再扩模块与Seed；保留最差样本，检查正常探索与返程的节奏。

## 验证与失败处理

生成有界重试并记录attempt和拒绝原因；已提交地图回退不重抽。缺版本、身份、输入或安全出生时明确失败，保底只采用已经验证且语义相同的内容。

验证依次覆盖合同／结构、真实模块Motor、连接／相位、正式消费者、Manifest JSON往返、回退／取消、Web与合屏。几何可达与统计仅用于诊断。检查入口见 [模块导航](module_map.md)，内容诊断工具为 `tools/level_design.py`。
