# 当前实现

源码基线：`main@7d73389feab22224d0f8bd7c09325420a7605980`。线上构建以试玩站 `build-info.json` 为准，当前实施分支feat/mv-first-loop；源码合入与网站发布分别核实。

| 范围 | 当前行为与入口 |
| --- | --- |
| 正常游戏入口 | project.godot → FixedWorldApp；标题新游戏/继续，五房环路、共用玩家、真实门、显式休息/死亡恢复、牧风者胜利/H唯一领取；旧DemoApp保留为显式回归入口 |
| 新世界状态/保存 | FixedWorldState按永久/周期/尝试职责提交，新schema及独立原生槽/Web key；WorldSaveService复用MetaSaveService可靠IO。基础枪首档试制5伤害；Q只在明确授予的专项夹具验收，正式首批不授予 |
| 旧原型运行流程 | 标题 → 家园 → 平原两张连通探索图 → H／钩索 → 森林两图 → 开发边界；`RunCampaignProgression` 负责能力权益和地区准入 |
| 角色资源 | 基础一跳、一发空中弹药；射击不耗时间能量，枪械／钩索空中瞄准慢时共用 AirFocus；实际命中、接地及已授予能力的恢复事件按 [资源合同](../bible/combat_and_recharge.md) |
| 武器与动作 | 新世界使用基础枪与胜利后H；旧原型家园三种Lv.1武器和完整动作候选仍由显式开发入口回归 |
| 背包与成长 | ItemCatalogV5、库存、装备容量与效果族已有旧原型消费者；新世界尚未接入完整库存、NPC成长与经济，不能沿用旧局内清空规则 |
| NPC／任务／修钟 | 家园服务面板和森林发现/阅读已有局部消费者；固定世界NPC身份、任务快照、迁居、修钟及结局事实链尚未接入 |
| 设置与文本 | InputProfile和面板布局/字体已有实现；输入偏好仍由App会话值维护，独立设置持久化与统一文本入口尚未接入 |
| 地图 | FixedWorldProvider提供首批五房；地图列表只显示实际到达。旧平原/森林Provider及版本注册保留显式开发回归 |
| mapgen | SDK 0.4.1、模块库 1.1.0、runtime-map/v2 已接入开发入口；真实生成、M35／gears／完整起点风铃为有限切片，普通新游戏使用固定五房，不调用mapgen |
| 表现 | 共用细粒度像素风格、1wu 世界采样与 nearest；当前技术绑定通过 [Bible注册表](../data/creative_direction/bibles/registry.json) 解析 |
| CI与交付 | 日常固定project／import／smoke／contracts四项，开发显式选手动专项；森林H控制器回归绑定独立测试夹具，旧随机地区路由拒绝执行；发布和试玩部署独立手动执行 |
| 工程 | 正式代码位于 `game/`；`scripts/`、`scenes/`、`resources/` 中仍有当前 Definition、Boss场景与森林布局实现 |

目标是固定世界类银河恶魔城；首批五房运行闭环已接通，其余211房和完整内容系统尚未施工。2026-11-06[线上试玩](https://zhipijun1996.github.io/gunman-rush/) build `43525971ba6d` 对应源码 `25edf7cf4ed70ce4ac36ccf678c69ccd8d5b4ae9`（PR140），不同于main；公开元数据、HTML与完整PCK下载校验通过；公网浏览器实测新游戏、移动跳跃、暂停、保存及刷新后继续通过。

## 当前缺口

- 首批之外的房间、房内分区探索、NPC/库存/任务/修钟与完整设置尚未接入；不把首批按房探索列表当完整世界地图。Q运行机制已接入并由明确授予夹具覆盖，K-R10正式获取路线待后续施工。
- mapgen旧正式量产目标停止，保留当前开发消费者用于回归；其余旧PR独有成果已放弃，见 [迁移交接](worklines/mv_migration/scope.md)。
- 剧情设计具体人物、日程和结局仍有提案，未整体接入游戏；从 [剧情入口](../bible/story.md) 加载。
- 实体手机／手柄、目标性能、平衡、听感、审美与完整探索趣味按任务证据分别验收。

系统职责与复用/适配/新增缺口见 [架构](architecture.md)；PR138清理已在main，不再作为开发前置。MV-RUNTIME-01B—01F推进到五房闭环；后续NPC服务、装备、任务/修钟及代表房扩展尚未接入。

当前工作从 [任务索引](tasks.md) 定位，修改入口、设计和检查见 [模块导航](module_map.md)。
