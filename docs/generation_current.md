# 当前正式关卡随机算法

源码基线：`feature/plains-cohesion-and-pressure@53f88e5`，2026-10-12。正式消费者是 `DemoApp.start_plains` → `PlainsRegionGenerator`，不是保留在开发入口的八关 `PlainsStageGenerator` 或 `RandomStagePreview`。最新生成版本 `plains-region-v8`；随机派生版本保持 `plains-region-v4`。

## 从种子到可玩的世界

```mermaid
flowchart LR
    A[新局种子与地图号] --> B[抽空间骨架与格子占地]
    B --> C[构建邻接与删边 保持连通和环路]
    C --> D[加入捷径 教学 Boss与深层挑战]
    D --> E[填入水平动作配方和竖井配方]
    E --> F[布置奖励 敌人 机关相位]
    F --> G[能力与结构校验 确定性重建]
    G --> H[Manifest与正式装配器]
```

1. **种子分离**。`PlainsRegionCampaign.seed_for` 第一图用 root seed，第二图用 `root_seed + "/plains/map_2"`；第一图 `intro`，第二图 `advanced`。菜单空种子产生新局种子，显式种子可复现。`RunRandomStream` 将种子、流名、稳定身份、版本、计数器组成输入，SHA256 前13个十六进制字符转为52位整数，再对候选数取模。是确定性伪随机，不是 AI 临场造地图。
2. **骨架和占地**。`PlainsExplorationTopology.make` 从格子矩形删除格子，保护教学入口及高难支路入口，要求格子连通、至少7个独立环和合法远端Boss接近格。第一图目标15格，第二图15或18格；横距1400、层距700世界单位。`woven_layers` 偏交错庭院，`linked_rings` 偏井环，`crossroads` 偏枢纽卫星。删格最多240次；不足时换确定性完整格子占地，记录 `footprint_fallback`。
3. **图连接**。相邻格子连水平通道或竖井；选择远端、至少两条连接的Boss整备区。随机尝试切断连续水平长廊及最多4条水平边，只有保持正反可达、至少5个独立环、整备区至少两连接时才保留删除。再安排两处上侧开启的反侧捷径；井环骨架尝试加入两条单向下降，必须保留其他返回路线。
4. **特殊位置**。加入独立短教学前缀、固定Boss核心和两条高处深层奖励路线；深层挑战由三种组合变体抽取，有不同节点的单向下降撤离。正式第一图通常20区域节点，第二图20或23，包括教学、Boss和深层节点；这不是20/23个屏幕或20/23个动作模块。
5. **局部动作配方**。水平通道从 `PlainsRouteRecipes.RECIPES` 的16个配方条目选取：如安全格落点、刺墙越顶、低顶短跳、反冲横渡、读齿轮相位、远端双铃和控制渡台。`choose` 优先本图使用最少的配方，尽量避免相邻同配方；一定数量之后补齐齿轮/荆棘压力覆盖，intro排除部分组合。竖向通道抽升降台、交错阶梯或反冲竖井，骨架影响权重。**16个条目存在模块复用，不等于16种完全独立机制**。
6. **内容投放**。拓扑、内容、奖励分别使用 `region_topology`、`region_content`、`region_reward` 流，机关相位按模块稳定ID使用 `region_phases`，相位从0/0.25/0.5/0.75选择。水平配方、商人、地标、敌人等仍共用content流，新增content抽样可能改变其他content结果；独立流不等于每个内容系统彼此完全隔离。每张图的普通金币/位置道具箱/补给预算固定，不因地图更大无限增长；敌人在渡台、铃、齿轮或落点窗口布置，不强制全清。
7. **失败与记录**。外层最多4次候选尝试，失败用 `verified_exploration_region` 同难度完整探索保底，不退化为直线。它用固定保底种子生成，再把原请求seed写回Manifest，重放验证按保底身份恢复。格子占地保底与整图保底是两种不同统计。Manifest记录实际格子、连接、节点几何/定义指纹、动作配方、相位、预算、内容、参数hash与尝试号。装配器消费此布局；段回退保留世界实例、机关与领取账本，不重新抽图。

## 校验实际能证明什么

`PlainsRegionGenerator.validate` 校验版本/hash、开放图正反连通、最低环数/分岔/捷径、节点数量、模块 `supports(tuning)`、风铃计划，并从种子/骨架/难度/尝试号重新构建候选比对hash，拒绝重新签名的假连接或删改奖励。

它**没有在每次生成时执行完整Motor轨迹搜索**；`supports` 使用作者定义的能力需求和移动包络筛选，碰撞自由包络不证明危险相位下可通关。真正的身体扫掠、双向输入、反冲、渡台和撤离在地区/模块专项测试中验证。专项固定样本通过不能推广为所有seed、所有装备、所有精力状态均可过。连通图也不证明玩家找得到路、操作舒服或觉得有趣。

当前入口只接受至少一跳/一空中射击的构筑，不能宣称支持任意零能力构筑。没有按玩家疲劳、受伤情况或学习进度实时调整布局；单图 `recipe_history` 不是跨局持久去重。基础1400×700格子间距和大部分局部模块几何固定；随机主要发生在占地、连接、配方、组合、位置和相位。

## 已有测量与下一步

基线已提交 [两图100样本统计](evidence/plains_cohesion/corpus.json)：50seed×2图，第一图45种连接签名、第二图49种；两图样本最低5环/5分岔，整图保底0。另 [操作统计](evidence/plains_cohesion/operation_corpus.json) 记录最大同配方占比0.125及动作/压力覆盖。这些是历史样本统计，本次没有重跑；0整图保底不自动表示0格子占地保底，也不证明无限seed无死局。

后续应分开测：连接图差异、实际动作签名差异、连续高压/恢复间隔、重复空走距离、首遇机制教学、到Boss/成长/深层回程的真人行程。需要时把资源状态和学习前置加入编排约束，先固定样板，再真实路线，再批量生成；不要仅增加模块数或hash差异来验收多样性。详见 [质量流程](development_quality.md)。

源码导航：[正式生成器](../scripts/generation/plains_region_generator.gd)、[格子骨架](../scripts/generation/plains_exploration_topology.gd)、[动作配方](../scripts/generation/plains_route_recipes.gd)、[两图种子](../scripts/run/plains_region_campaign.gd)、[随机流](../scripts/run/run_random_stream.gd)、[装配器](../scripts/generation/plains_region_assembler.gd)。
