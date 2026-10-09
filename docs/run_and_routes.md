# 运行、路线与版本化内容契约

本文件是运行与路线权威规格，尚未实现。正式规则见[游戏设计](game_design.md)，暂定/待定项见[决策](decisions.md)。定义不得持有某局当前状态。

## 定义与状态

| 契约 | 必要字段/职责 |
| --- | --- |
| RunDefinition | id/version、正式stages_per_biome=10、boss_stage=10、主题序列策略；大关总数待定，不能硬编码终局次数 |
| BiomeDefinition | id/version、主题、地形/机关/敌人/Boss内容池、兼容标签与引用；主题不决定房间类型 |
| StageTypeDefinition | id/version、显示名/icon、完成规则组件、出口/奖励/商店策略引用；六类最小注册表，可增加定义与组件 |
| RunState | run_id/epoch/status、主题/小关索引、stage_epoch、RunCoin钱包、路线、BuildState、领取/交易账本、Manifest引用 |
| StageState | stable_stage_id、主题/类型、完成状态、两个ExitOffer、对象消耗/敌人/机关相位、奖励/商店状态 |
| ActorLifetime | actor_id/epoch；段回退只换actor_epoch，不换run/stage epoch |

正式至少注册combat/shop/coin_reward/health_reward/item_reward/boss；不存在的类型、图标、定义版本或兼容内容必须显式失败/使用已验证同类型保底，不默默换成另一类。完成条件由StageRule组合（如击败目标、抵达终点、完成交互），每类具体条件在其实现任务确定，不从类型名称推断。

RunDirector协调状态机：HOME → STARTING → IN_STAGE → TRANSITIONING → IN_STAGE；进入死亡终态ENDING_FAILURE后只能HOME，同帧零血优先。大关Boss胜利后进入NEXT_BIOME或ENDING_SUCCESS由RunDefinition决定；最后一关总数及终局展示待定。家园不是stage_index=0的地图房间。

## 两出口与唯一切换

ExitOffer={exit_id,source_stage_id,next_stage_index,next_stage_type_id,icon_id,label,route_version}。非终点推进关提供两项，可类型相同（例如暂定第9关的两项都是Boss）；不承诺候选地图/具体奖励已揭示。

选择命令SelectExit带run_id/run_epoch/stage_epoch/exit_id/selection_id。RoutePlanner先提供合法候选和节奏约束；RunDirector原子验证当前阶段已完成、玩家存活、命令属于当前offer，并IN_STAGE→TRANSITIONING锁定。相同selection_id重试返回原结果，另一个出口或旧stage回调拒绝；只有一条StageTransitionCommitted。已提交相同payload重试只读回原收据，不能再发切换事件；旧stage未提交请求仍拒绝。转场失败保留选定目标并有界重试/显式错误，不解锁成另一目标，不重复奖励；提交新场景后stage_epoch递增，旧事件失效。

正式1–8只能去下一索引，9只能去10/Boss，10不得出普通第11小关。第9关双Boss出口的呈现是暂定D027；Boss必达和第10关类型是已确认。Boss结束后的跨大关流转单独处理，不套两个普通出口绕过Boss。路线与地图均不在PlayerController实现。

## 可复现与独立随机流

RoutePlanner、LevelGenerator、RewardService、ShopService分别使用route/map/reward/shop随机流；Boss攻击另用boss_pattern流。每关流由规范化root_seed、namespace、主题/小关稳定ID与版本用稳定摘要派生，不用全局rand、字典遍历次序或未锁定引擎字符串hash。PRNG算法ID/版本、派生算法版本必须记录。奖励多抽一次不能改变地图/路线/商店；道具真正改变能力后合法改变地图筛选，必须记录capability_snapshot，不误称这种设计依赖为RNG串扰。

RunManifest包含schema_version、root_seed（持久化为字符串避免跨平台整数精度丢失）、rng_algorithm/version、stream_derivation_version、run_definition/profile版本、generator/route/reward/shop版本、内容manifest/hash、物理与资源配置hash、初始人物/武器/能力、每关能力快照、主题/类型/布局/对象稳定ID/机关相位、两个出口及选择记录、候选奖励/领取记录、商店报价/库存/成交记录、Boss模板/攻击seed、RunPolicy/DamagePolicy/SegmentReturnPolicy/BossOutcomePolicy版本。

Manifest记录实际结果，而不只记Seed。相同Seed、锁定版本与相同决策应重现候选内容；重放完整Manifest直接重建已选择路线和结果。用户选不同出口可产生不同路线。内容版本不可用或schema不支持时显式报告不兼容，不能承诺旧Seed在新版本仍复现；数据序列化顺序稳定，所有影响抽样的内容版本入hash。

## 分层实现

先用确定性固定场景验证RunDirector/路线，再引入生成器。开发专用RunProfile可设stages_per_biome=3、boss_stage=3、development_only=true，只用于集成测试；正式构建拒绝短关配置，始终10/10。缩短测试不能满足正式第10关验收。

局部类型化signal（RunStarted、StageExitSelected、StageTransitionCommitted、RunEnded）使用具体请求/结果Resource，附所属run/stage token；不引入万能事件总线。对象通过StageContext服务引用，不获取全局玩家或修改RunState字段。
