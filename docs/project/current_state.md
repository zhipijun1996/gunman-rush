# 当前实现

源码基线：`main@7d73389feab22224d0f8bd7c09325420a7605980`。线上构建以试玩站 `build-info.json` 为准，当前实施分支feat/mv-first-loop；源码合入与网站发布分别核实。

| 范围 | 当前行为与入口 |
| --- | --- |
| 正常游戏入口 | project.godot → FixedWorldApp；原标题展示/正式人物/HUD，标题新游戏/继续，五房环路、共用玩家、真实墙面缺口、可见步入/侧跳/下落、统一缓冲镜头、尸体/敌人周期、充电不原地刷怪及死亡恢复、牧风者胜利/H唯一领取；旧DemoApp保留为显式回归入口 |
| 新世界状态/保存 | FixedWorldState按永久/周期/尝试职责提交，新schema及独立原生槽/Web key；WorldSaveService复用MetaSaveService可靠IO。基础枪首档试制5伤害；Q只在明确授予的专项夹具验收，正式首批不授予 |
| 旧原型运行流程 | 标题 → 家园 → 平原两张连通探索图 → H／钩索 → 森林两图 → 开发边界；`RunCampaignProgression` 负责能力权益和地区准入 |
| 角色资源 | 基础一跳、一发空中弹药；射击不耗时间能量，枪械／钩索共用AirFocus；共鸣蓄力回复复用HealthState/CombatEnergyState，数值与恢复/取消规则见 [资源合同](../bible/combat_and_recharge.md) |
| 武器与动作 | 新世界使用基础枪与胜利后H；旧原型家园三种Lv.1武器和完整动作候选仍由显式开发入口回归 |
| 背包与成长 | 原DemoMenu装备网格/负荷槽/详情已接回新世界；WorldServices拥有试制永久所有权/等级/破损、周期装配锁、购买/升级/维修及周期使用；统计复用ItemCatalog/BuildState。正式48件/价格待确认 |
| NPC／任务／修钟 | 小站两位NPC的场景身份、向上交互/先回应对话、试制服务/委托及持久结果已接入；完整迁居/正式修钟与结局待叙事内容确认 |
| 设置与文本 | 复用InputProfile/正式面板与触屏适配；设置独立保存，新增UI文本集中提取，内容文本归各对象定义 |
| 地图 | 首批五房按实际尺寸/成对门同尺度拼接，大小地图共用接缝和玩家位置，支持触控拖动/缩放；只显示实际到达。旧Provider保留显式回归 |
| mapgen | SDK 0.4.1、模块库 1.1.0、runtime-map/v2 已接入开发入口；真实生成、M35／gears／完整起点风铃为有限切片，普通新游戏使用固定五房，不调用mapgen |
| 表现 | 共用细粒度像素风格、1wu 世界采样与 nearest；当前技术绑定通过 [Bible注册表](../data/creative_direction/bibles/registry.json) 解析 |
| CI与交付 | 日常固定project／import／smoke／contracts四项，开发显式选手动专项；森林H控制器回归绑定独立测试夹具，旧随机地区路由拒绝执行；发布和试玩部署独立手动执行 |
| 工程 | 正式代码位于 `game/`；`scripts/`、`scenes/`、`resources/` 中仍有当前 Definition、Boss场景与森林布局实现 |

目标是固定世界类银河恶魔城；当前交付五房和试制服务闭环，实施分支正在验证统一镜头/可见入场、告示牌/向上交互与机器人充电站，其余211房与正式内容尚未施工。[线上试玩](https://zhipijun1996.github.io/gunman-rush/) build `f9052b52961b` 对应源码 `48f98147a8cc2da379e13366b0538c55b9133b20`（PR140，尚未合入main）。同源发布、公开完整PCK与浏览器检查通过；验证和设备边界见 [当前交接](worklines/mv_migration/scope.md)，[验收产物](https://zhipijun1996.github.io/gunman-rush/verification/report.json)随该构建发布。

## 当前缺口

- 五房仍是结构样板，场地节奏与窄屏地图排布待打磨。首批之外的房间、房内分区探索、正式装备/经济/剧情修钟及发布平台完整验收尚未完成；当前地图只覆盖已施工且实际到达的房形。Q运行机制已接入并由明确授予夹具覆盖，K-R10正式获取路线待后续施工。
- mapgen旧正式量产目标停止，保留当前开发消费者用于回归；其余旧PR独有成果已放弃，见 [迁移交接](worklines/mv_migration/scope.md)。
- 剧情设计具体人物、日程和结局仍有提案，未整体接入游戏；从 [剧情入口](../bible/story.md) 加载。
- 实体手机／手柄、目标性能、平衡、听感、审美与完整探索趣味按任务证据分别验收。

系统职责与复用/适配/新增缺口见 [架构](architecture.md)；PR138清理已在main，不再作为开发前置。MV-RUNTIME-01B—01F推进到五房闭环；当前在首环路验收试制NPC/装备/委托及正式表现/UI；正式内容与其他机制代表房仍需各自验收。

当前工作从 [任务索引](tasks.md) 定位，修改入口、设计和检查见 [模块导航](module_map.md)。
