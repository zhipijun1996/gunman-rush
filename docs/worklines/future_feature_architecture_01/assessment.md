# 后续玩法扩展的实际架构边界

核查时间：2026-11-01。游戏基线：`8dfaf7f325907e4b60853d6e49965fd359e869d4`，开始核查时工作树干净。只读源码与小型 GitHub API 文本；未运行游戏、浏览器、测试或生成器，未修改生产文件。下文行号均对应此提交，不代表新增功能已验收。

## 判断

四项都可以在现架构上继续做，**不需要重新搭一套玩家、钱包、装备、奖励或地图运行时**。但成熟程度不同：永久成长已有真正的保存、交易、下局应用链；家园和两区域能力推进已有实际消费者；教程/剧情只有帮助页与局部阅读互动；新 map-gen 尚未接入，更不是已经支持任意区域模块包的通用运行时。

当前主调用链：

```text
DemoMenu / HomeScene -> DemoApp（用户意图与装配）
  -> RunSession -> DemoRunDirector / Lifetime（本局状态与失效 token）
                -> RunCampaignProgression（本局能力/区域推进）
                -> Wallet / Build / RewardService / ItemRuntime
  -> RunComposition（创建真实 PlayerController，设置已有能力）
  -> LevelRequest -> PlainsLevelProvider / ForestLevelProvider
       -> 现有 Generator -> LegacyRegionPlanAdapter
       -> LevelPlan + 原 Manifest 兼容数据
       -> 现有 Stage -> LevelRuntime -> 现有两区 Assembler / Actor / Boss
  -> MetaProgression -> MetaSaveService（局外状态与保存提交）
```

这里的 Provider 是已有两类实现和统一数据合同，并非已经存在的全区域动态 Provider 注册表。`RunComposition` 也不是剧情、生成或进度服务。

## 1. 新手教程与剧情短片

**已有真实接口。** `game/presentation/ui/demo_menu.gd:537–555` 的“新手教程”是说明页；`:544` 的练习按钮仍走新冒险入口。`game/application/run_composition.gd:6` 创建正式玩家，`:21` 配置现有能力，`:26` 装配瞄准提示。`game/application/run_session.gd:6–22` 已有统一 flow/lifetime/player/services；`game/application/demo_app.gd:1069` 的菜单暂停、`:2551–2558` 的能力选择暂停已真实使用输入清理与暂停。

**缺口。** 目前没有从该教程按钮进入的步骤目标、完成条件、教程完成记录或短片播放/跳过/恢复链。`game/application/demo_run_director.gd:7` 状态仅 HOME/IN_STAGE/各类结束，不包含剧情播放；不能把“说明页+普通新局”当作交互教程。全树暂停与输入恢复仍由具体 UI 接线控制，多个插入内容叠加时需明确唯一结束/取消与暂停恢复责任。

**推荐归属。** 教程/叙事进程属于 application 层的本局流程；具体提示/字幕/短片属于 presentation；触发点由关卡内容提供；玩家动作与伤害仍调用原 Controller/资源所有者。`RunComposition` 只负责连接对象，不能成为步骤解释器。是否暂停整个世界、保留何种输入是每种演出明确的策略，不能把所有演出强行等同菜单暂停。

**最小下一批。** 先接一个真实入口，完成“展示一条提示→观察一个既有玩家动作→关闭/跳过→恢复输入”的垂直功能；先不搭通用剧情 DSL。覆盖切地图/死亡/Home/重复回调/跳过时 token 失效，且正常路线动作、奖励、RNG不变。需要“首次教程完成”跨局记忆时，才单独设计 Meta 字段及迁移，不能偷偷塞进现存档。可从现 `tests/run_session_runner.gd`、`tests/home_app_runner.gd` 对应真实消费者扩展。

## 2. map-gen、模块包运行时生成、多区域、能力与区域选择

**现成接入面。**

- `game/world/levels/level_request.gd:3–10` 已明确只收值输入，含 seed/region/map/tuning/expected_hash/capabilities，不接 App、玩家或钱包。
- `game/world/levels/level_plan.gd:5–25` 有来源版本、map hash、模块、连接、怪物、Boss和奖励位置；`:27` 校验合法性，`:76` 校验地形归属。`level_module_placement.gd:4–9` 绑定真实 `PlatformingModuleDefinition`。
- `game/world/levels/content/level_module_catalog.gd:3–15,30` 是已有模块准入与 definition/scene 权威；新导入必须沿它扩展版本与验证，不能另放一套绕过准入的路径字典。
- `game/world/levels/providers/plains_level_provider.gd:4`、`forest_level_provider.gd:4` 已保留 expected_hash 的历史重放匹配；`level_build_result.gd:3–10` 仍携带 legacy_generated，表明旧 Manifest 适配还在。
- `game/application/run_campaign_progression.gd:12,28,41` 有真实能力奖励/幂等 token/区域进入；`game/player/actions/traversal_ability.gd:45–61` 已执行 grapple/wall_climb/double_jump。`demo_app.gd:2551–2588` 已串起奖励、授予、manifest记录与转区。

**尚硬编码。**

- `demo_app.gd:456–480` 同步选森林或平原 Provider、选两种 Stage，并读 legacy manifest；其它 region 默认落平原分支，不是未知区域拒绝合同。
- `level_runtime.gd:4,10` 仍接受 `PlainsRegionState`，以 `plan.forest != null` 二分两种 Assembler。新增 region 不能只加一个 JSON 就宣称可运行。
- `run_campaign_progression.gd:19–25,38–44` 平原只开放 grapple，然后只准 thorn_forest；森林奖励后到 BOUNDARY。`demo_run_director.gd:125–135` 再明确限制 formal_plains_region/map2/plains→thorn_forest。`region_progression_modal.gd:29–40` 的地区列表与文案也固定森林；`plains_region_campaign.gd:5` 固定每区两图。
- `RunSession.region_states` 是本区域按 map_index 的状态集合，`demo_app.gd:2578` 转区重置。若未来要回访多区域，需要先定义 region+map 身份/保留政策，不能误用同一个 map_index 来覆盖前区状态。
- `docs/world_regions.json:3` 自称 `design_catalog_not_runtime_configuration`；六层十六区域及剧情投放是设计，不是实际运行注册表（其中 runtime_available/status 也不能用来反推现平原/森林是否已实现）。

**map-gen 已核实的实际状态。** 本地 `/workspace` 未发现对应 checkout；随后仅用 GitHub API 查询 owner 下的实际仓库，确认 [zhipijun1996/map-gen](https://github.com/zhipijun1996/map-gen) 的 main 为 `c2ac2c3625f659364b187592c836c5ff2bceb892`。未 clone、未下载模块包、未执行。以下是该提交的源/README证据，不是本轮复测：

- [README](https://github.com/zhipijun1996/map-gen/blob/c2ac2c3625f659364b187592c836c5ff2bceb892/README.md)：核心是 Python 3.10+ 标准库原型；浏览器 HTML 是结果检查器，不能据此认为算法已在浏览器本地生成或有远程服务。真实 Module 来自 map-edit，正式格式导入尚未实施。
- [prototype/generate.py:269–289](https://github.com/zhipijun1996/map-gen/blob/c2ac2c3625f659364b187592c836c5ff2bceb892/prototype/generate.py#L269)：输出 `map-port-prototype/2`、`block_pixels=128`、`library_version=offset-block-port-fixtures-v2`、instances/connections/closures，显式 `certified_for_game=False`；CLI只 `--seed/--out`，生成 map.json/module_library.json。
- [prototype/model.py:4,11–26](https://github.com/zhipijun1996/map-gen/blob/c2ac2c3625f659364b187592c836c5ff2bceb892/prototype/model.py#L4)：能力全集固定 jump/double_jump/recoil/grapple，模块和 route 标记未物理认证；不是游戏当前实际能力集合的准入证明。
- README记录 20 个固定 seed 首次16通过、4拒绝，仍用52占位模板；这些是仓库既有静态结果，不是正式游戏碰撞/跳跃/资源消耗/镜像/封口验证，也不是本轮性能结论。

**最小下一批与两种部署方式。** 先冻结一版真实模块格式与版本/hash，把一个小模块包的 port/route/镜像/封口/能力条件映射到现 Catalog/Definition/LevelPlan；针对少量固定 seed 做真实碰撞、到达、回程、奖励可领取和旧hash重放验证。新 provider 负责转换数据，Stage/Runtime 继续复用服务。不要先把全部旧地图算法重写。

| 执行位置 | 可沿用的共同边界 | 还必须新增的明确责任 |
|---|---|---|
| 浏览器本地 | 同样的 LevelRequest→受校验的 LevelPlan；确定算法与模块版本、seed/hash | 选择GDScript/JS/WASM等可交付实现或移植方案；不能原样假定Python在Godot Web运行。异步/分帧与取消归application/platform，不能每战斗帧生成。 |
| 远程生成服务 | 返回同样的受校验内容；本地Catalog只允许已准入资源，不信任任意远端脚本/路径 | platform承接请求/响应与超时、失败、取消；application按当前run token接收，旧响应不得装进新局；来源/版本/hash可记录重放，离线与拒绝种子的处理先明确。当前未核到现成服务协议。 |

先通过适配器保留两种执行位置的选择，不必因此阻塞询问。第一批无需同时实现本地和远程。区域扩充另为紧随批次：将已有 campaign/director 的准入权威收敛为一个实际政策，UI消费其合法 offers，App只装配；首批仍保持平原→森林及旧奖励行为，随后再正式加入新区域，避免UI、Director、Campaign各维护一份可达规则。

## 3. 剧情插入、对话、NPC、家园

**已有真实消费者。** 家园并非空菜单：`game/progression/home/home_scene.gd:4–10` 定义交互/导航信号和服务名称；`:153–166` 按实际楼层/距离选交互对象，`:199` 执行交互，`:204` 阻断输入。`demo_app.gd:1365–1386` 装配家园玩家；`:1396–1408` 路由图鉴/角色等面板；`:1456,1465` 调用已有局外解锁/选择事务。

森林也已有叙事阅读的真实切片：`game/world/components/forest_bible_discovery_catalog.gd:4–5` 内容定义；`forest_bible_discoveries.gd:32,61,87,191,239` 配置、交互、作用域验证、确认提交与关闭；`demo_app.gd:2691–2731` 连接暂停/恢复、队列提交、Manifest记录和奖励后捷径。这是可复用的既有生命周期与奖励消费者，不应另造“剧情钱包”。

**缺口。** 当前是有限服务槽位与森林发现页，未形成通用的NPC多轮对话/条件分支/剧情事件编排/全局故事标记。现 `LevelPlan` 没有通用 story trigger/NPC placement 字段；不要把这些混入敌人 actor 的专属行为定义。家园服务展示不等于所有名称对应完整成长、成就或剧情玩法。

**推荐与最小批次。** 从一个家园NPC或者一个森林阅读对象做“进入→一轮对话→关闭/一次奖励”的真实功能；presentation负责文字/选项，application负责插入与取消，world负责空间触发，progression负责确需持久的故事结果。优先把当前阅读页的作用域/暂停恢复/一次确认边界复用或抽到实际共同消费者，而不是先把森林所有特殊奖励策略泛化。检查死亡先于确认、离场后回调、重复打开、重载后是否重复领奖。扩展现 `tests/forest_bible_discoveries_tests.gd`、`tests/forest_bible_app_discoveries_runner.gd` 与家园消费者，原功能保留。

## 4. 永久升级

**已经有完整但有限的实际链。** `game/progression/meta_progression.gd:23–27` 加载唯一 `config/meta_upgrades.json`；`:63` purchase_upgrade；`:105` quote；`:135–182` 校验请求、receipt幂等/冲突、余额、候选提交；`:222–228` 保存成功才恢复内存状态。`game/platform/persistence/meta_save_service.gd:4–8` 当前 schema3/稳定Web键；`:22–41` 主档/备份恢复和未来版本拒绝，`:44–82` 有校验和、本地临时写入/备份或Web localStorage写回验证。不是云同步存档。

`demo_app.gd:2096–2107` 的家园购买是真实消费者；`:344` 在新局应用 `meta.fresh_health_definition`，`:1378` 家园装配也使用该函数。`meta_progression.gd:113–124` 复制原健康定义再加永久生命，避免修改共享 Resource。已有图鉴发现/家园道具解锁/带出选择（`:68–75`）也复用同一局外账本。

**限制。** `config/meta_upgrades.json:3–5` 标 `fixture_only:true`，实际只有 vitality，+1HP/级、最多3级、价格5/10/15；它虽然是实际加载的配置，不能冒称正式全面成长平衡已完成。`demo_app.gd:2100` 与 `demo_menu.gd:321–326` 购买/展示仍硬编码 vitality；效果应用仅识别 max_health。新攻击/能量/移动类属性不会仅加JSON就自动生效。本局能力账本与永久升级是不同所有者，不能把通关授予的钩索无意变成永久能力。

**最小下一批。** 保原事务与价格/数值，先让已有家园升级UI消费现有升级definition/quote，实际购买传upgrade_id；新效果只在明确的玩家构建边界应用一次，并给合法stat有限验证，不另建升级余额或保存服务。先用原vitality证明旧存档/重复提交/存储拒绝/换档/下局重建均等价，再另批设计第二种永久升级及数值。新增永久剧情/教程字段时明确schema迁移；本轮不改现存档。沿用 `tests/meta_notes_save_tests.gd`、`tests/home_app_runner.gd`、`tests/run_session_runner.gd`。

## 建议排期与验收边界

1. 性能问题继续独立诊断/优化；不要把新生成器或剧情系统混进当前战斗卡顿修复，当前审计不提供新性能因果。
2. 先做一个教程/叙事垂直切片，验证正式玩家、输入、取消、存档边界，不改变基础玩法。
3. map-gen先格式/模块资格与一个小包的Provider接入，再多区域政策；这是最大风险项，静态图通过不等于可玩。
4. 永久升级UI去单项硬编码与家园NPC可以小批推进；各自复用现有所有者，新增玩法数值另行验收。

以上为源码可行性与最小实施建议，不签新功能/native/Web/设备体验通过。本轮没有改代码、资源、配置、存档或生产文档。
