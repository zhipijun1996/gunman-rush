# 当前实现

本页描述当前源码的默认行为；具体分支、提交与验证见任务交接。线上构建以试玩站 `build-info.json` 为准，源码合入与网站发布分别核实。

| 范围 | 当前行为与入口 |
| --- | --- |
| 正式流程 | 标题 → 家园 → 平原两张连通探索图 → H／钩索 → 森林两图 → 开发边界；`RunCampaignProgression` 负责能力权益和地区准入 |
| 角色资源 | 基础一跳、一发空中弹药；射击不耗时间能量，枪械／钩索空中瞄准慢时共用 AirFocus；实际命中、接地及已授予能力的恢复事件按 [资源合同](../bible/combat_and_recharge.md) |
| 武器与动作 | 家园可选三种 Lv.1 武器；完整武器／动作候选在开发练习中使用。正式授予与练习配置分开 |
| 背包与成长 | ItemCatalogV5、库存实例、装备容量与效果族；金币为局内货币，音符及家园升级／图鉴由永久保存事务管理 |
| 地图 | 家园按真实出发输入提前在线程生成平原，出发复用匹配结果或继续同一计算；RunSession 持有 PlainsMapGeneration，经 RuntimeMapV2Provider 转成 LevelPlan；森林默认 `forest-bible-world-v15`，生成器注册表仍支持显式版本选择 |
| mapgen | SDK 0.4.1、模块库 1.1.0、runtime-map/v2 接入家园正式出发；两图使用现有敌人、奖励、Boss、地图和正式平原表现，随后沿既有流程选H并进入森林。配置见 config/plains_mapgen.json；开发切片复用同一底层生成作业与SDK |
| 表现 | 共用细粒度像素风格、1wu 世界采样与 nearest；当前技术绑定通过 [Bible注册表](../data/creative_direction/bibles/registry.json) 解析 |
| CI与交付 | 日常固定project／import／smoke／contracts四项，开发显式选手动专项；发布和试玩部署独立手动执行 |
| 工程 | 正式代码位于 `game/`；`scripts/`、`scenes/`、`resources/` 中仍有当前 Definition、Boss场景与森林布局实现 |

## 当前缺口

- 完整16地区与六阶段路线尚未实现；实际开放范围由运行入口和能力授予决定。
- map-gen 正式内容覆盖模块包内全部106个平原模块，按出发角色的真实能力和动作容量筛选；两图均要求三主通路、六处奖励。纵向接缝、成对门、组运动、挂载／泊位、炮台、伸缩危险和奖励联动使用原生组件。完整地图的搜索重试成本与逐路线物理覆盖仍需优化，实际证据见 [工作线](worklines/mapgen_host_windchime_041/scope.md)。
- 剧情设计具体人物、日程和结局仍有提案，未整体接入游戏；从 [剧情入口](../bible/story.md) 加载。
- 实体手机／手柄、目标性能、平衡、听感、审美与完整探索趣味按任务证据分别验收。

当前工作从 [任务索引](tasks.md) 定位，修改入口、设计和检查见 [模块导航](module_map.md)。
