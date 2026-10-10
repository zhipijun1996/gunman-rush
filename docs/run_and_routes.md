# 运行、路线与版本化内容契约

本文件是运行与路线权威规格。P4三关开发链与RUN-TEN固定十关试炼已接入局部运行服务；地图生成和正式跨大关流转尚未交付。正式规则见[游戏设计](game_design.md)，暂定/待定项见[决策](decisions.md)。定义不得持有某局当前状态。

## 定义与状态

| 契约 | 必要字段/职责 |
| --- | --- |
| RunDefinition | id/version、正式stages_per_biome=10、boss_stage=10、主题序列策略；第一大关平原，六层路线为暂定建议，大关总数不硬编码 |
| BiomeDefinition | id/version、主题、地形/机关/敌人/Boss内容池、兼容标签与引用；主题不决定房间类型 |
| StageTypeDefinition | id/version、显示名/icon、完成规则组件、出口/奖励/商店策略引用；六类最小注册表，可增加定义与组件 |
| RunState | run_id/epoch/status、主题/小关索引、stage_epoch、RunCoin钱包、路线、BuildState、领取/交易账本、Manifest引用 |
| StageState | stable_stage_id、主题/类型、完成状态、ExitOffer数组（默认两个）、对象消耗/敌人/机关相位、奖励/商店状态 |
| ActorLifetime | actor_id/epoch；段回退只换actor_epoch，不换run/stage epoch |

正式至少注册combat/shop/coin_reward/health_reward/item_reward/boss；不存在的类型、图标、定义版本或兼容内容必须显式失败/使用已验证同类型保底，不默默换成另一类。完成条件由StageRule组合（如击败目标、抵达终点、完成交互），每类具体条件在其实现任务确定，不从类型名称推断。

RunDirector协调状态机：HOME → STARTING → IN_STAGE → TRANSITIONING → IN_STAGE；进入死亡终态ENDING_FAILURE后只能HOME，同帧零血优先。大关Boss胜利后进入NEXT_BIOME或ENDING_SUCCESS由RunDefinition决定；最后一关总数及终局展示待定。家园不是stage_index=0的地图房间。

## 可配置出口与唯一切换

ExitOffer={exit_id,source_stage_id,next_stage_index,next_stage_type_id,icon_id,label,route_version}。非终点推进关提供配置数量的选项，当前默认两项；可以类型相同（例如暂定第9关的两项都是Boss）；不承诺候选地图/具体奖励已揭示。

选择命令SelectExit带run_id/run_epoch/stage_epoch/exit_id/selection_id。RoutePlanner先提供合法候选和节奏约束；RunDirector原子验证当前阶段已完成、玩家存活、命令属于当前offer，并IN_STAGE→TRANSITIONING锁定。相同selection_id重试返回原结果，另一个出口或旧stage回调拒绝；只有一条StageTransitionCommitted。已提交相同payload重试只读回原收据，不能再发切换事件；旧stage未提交请求仍拒绝。转场失败保留选定目标并有界重试/显式错误，不解锁成另一目标，不重复奖励；提交新场景后stage_epoch递增，旧事件失效。

正式1–8只能去下一索引，9只能去10/Boss，10不得出普通第11小关。第9关双Boss出口的呈现是暂定D027；Boss必达和第10关类型是已确认。Boss结束后的跨大关流转单独处理，不套两个普通出口绕过Boss。路线与地图均不在PlayerController实现。

## 大关路线与小关路线分层

[世界目录](world_regions.json)包含候选16地区、6层及29条连接白名单，严格design-only，不能直接当已开放BiomeDefinition注册表。小关StageExitOffer选类型、大关BiomeExitOffer选地区；后者仅在Boss合法胜利/金奖结算后生成，玩家同帧死亡时不开放。常规大关候选建议两个不同有效目的地，唯一终点允许一个；过滤完成状态、解锁与从剩余内容到终点的可达性，缺内容时显式固定开发路线/错误，不连空场景。第9小关单Boss出口为附件建议，当前双Boss实现不改。未来每层区域访问计数与小关1–10索引分离，普通路线层级递增，隐藏跳层单独策略后置。

大关候选/选择另用region_route流和版本化记录{world_graph_version,source_biome,layer,offered_biomes,selected_biome,unlock_snapshot,availability_snapshot}；不得因为新增奖励抽样改变大关选项，也不改既有route/map/reward/shop算法版本。当前运行没有region_route消费者或跨大关状态，附件网络不自动写进当前demo Manifest。

## 可复现与独立随机流

RoutePlanner、LevelGenerator、RewardService、ShopService分别使用route/map/reward/shop随机流；Boss攻击另用boss_pattern流。每关流由规范化root_seed、namespace、主题/小关稳定ID与版本用稳定摘要派生，不用全局rand、字典遍历次序或未锁定引擎字符串hash。PRNG算法ID/版本、派生算法版本必须记录。奖励多抽一次不能改变地图/路线/商店；道具真正改变能力后合法改变地图筛选，必须记录capability_snapshot，不误称这种设计依赖为RNG串扰。

RunManifest包含schema_version、root_seed（持久化为字符串避免跨平台整数精度丢失）、rng_algorithm/version、stream_derivation_version、run_definition/profile版本、generator/route/reward/shop版本、内容manifest/hash、物理与资源配置hash、初始人物/武器/能力、每关能力快照、主题/类型/布局/对象稳定ID/机关相位、所有出口及选择记录、候选奖励/领取记录、商店报价/库存/成交记录、Boss模板/攻击seed、RunPolicy/DamagePolicy/SegmentReturnPolicy/BossOutcomePolicy版本。

Manifest记录实际结果，而不只记Seed。相同Seed、锁定版本与相同决策应重现候选内容；重放完整Manifest直接重建已选择路线和结果。用户选不同出口可产生不同路线。内容版本不可用或schema不支持时显式报告不兼容，不能承诺旧Seed在新版本仍复现；数据序列化顺序稳定，所有影响抽样的内容版本入hash。

## 分层实现

先用确定性固定场景验证RunDirector/路线，再引入生成器。开发专用RunProfile可设stages_per_biome=3、boss_stage=3、development_only=true，只用于集成测试；正式构建拒绝短关配置，始终10/10。缩短测试不能满足正式第10关验收。

局部类型化signal（RunStarted、StageExitSelected、StageTransitionCommitted、RunEnded）使用具体请求/结果Resource，附所属run/stage token；不引入万能事件总线。对象通过StageContext服务引用，不获取全局玩家或修改RunState字段。

## 当前固定 demo 接入

`scripts/run/demo_run_director.gd`、`route_planner.gd`、`run_profile.gd`与`run_manifest.gd`由`scenes/demo/demo.tscn`消费。主菜单可选择三关快试或十关试炼。三关快试从独立HOME进入战斗关，击败巡逻敌人后选择SHOP或ITEM房间；第二关两个出口均进入第三关Boss。商店允许不买直接推进；道具房必须二选一领取后推进。这些是开发fixture的完成规则，不锁定Q013正式类型完成条件。正式`formal_ten.tres`为10/Boss10，开发`development_three.tres`显式标记development_only；普通正式构建校验拒绝开发短配置。固定demo终局不替代未确定的大关总数/跨大关流转。

切关服务同步原子提交索引/类型及stage/actor epoch，先存脱离收据再发`stage_entered(DemoRunResult)`，表现层随后延迟装载固定地图并暂停旧输入。相同选择ID/相同payload只读返回REPLAY；不同payload或旧阶段未提交请求拒绝。异步资源下载和失败重试不是当前同步固定场景服务已实现能力。

随机流实现是SHA256 counter-mode 52位整数抽样v1，规范化字符串seed、namespace、stable_stage_id、内容版本与派生版本组成key；map/route/reward/shop各自实例。当前地图固定；十关路线选项和合法道具候选使用独立随机流，不能把随机候选等同随机生成地图。Manifest记录实际输出及内容/配置hash、候选与选择，支持版本校验后导入脱离快照；不支持未来schema/算法/不合法末关Boss配置。它是内容复现记录，不是中途存档恢复系统。实际集成输出与验证证据以[交接](handoff.md)为准。


## RUN-TEN 固定十关试炼接入（本轮范围）

正式10/10 Profile使用固定地图消费者支持全部六房间类型，1–9推进、9两个出口必达10/Boss；金币/血量房间分别使用RUN_COIN与HEAL_CURRENT演示定义，不将加最大HP等同回血。多次道具房只从合法池取两种不同定义，重复/上限与互斥仍由BuildState验证。地图固定，不实现GEN，也不修改LEVEL-02真机门槛。

大关总数Q001未定。十关试炼击败Boss并兑现金道具进入显式ENDING_BIOME/biome_complete，由演示宿主返回家园；只表示一个大关完成，不调用三关ENDING_SUCCESS或假定正式整局只有一个大关。家园内存统计区分demo成功、失败与大关完成。后续正式跨大关策略另实现，Manifest记录实际边界；同帧零血仍优先，无金奖励。

本轮reward算法版本升为2，schema仍为1：新合法候选池改变奖励序列，旧reward=1的Manifest显式不兼容；不静默用新池重放旧Seed。实际初始InputProfile值及局内设置修改也记录，配置文件SHA不能替代会话实际输入参数。

生成设计轮扩展：路线类型选择与地图LayoutProfile独立；每关记录实际空间拓扑、模块图/变换/相位、难度预算/版本、镜头配置、验证版本/attempt/fallback。RouteRhythmPolicy只能筛选未来候选、放宽已声明软偏好并记录原因，不能改已选出口/正式10关/Boss必达。候选预算详见[difficulty_profiles](difficulty_profiles.md)，本轮不改现有RoutePlanner运行算法版本。


D046更新：出口数量属于路线配置，默认仍为两选项，允许后续多出口；固定3/10关当前消费者继续使用默认两出口。模块内多入口/多出口与小关末端下一关选择是不同数据域；生成试玩多终点只结束练习，不假装已改正式RoutePlanner奖励/类型消费者。选定任一出口仍只切换一次，Boss必达/第10Boss/死亡优先不改变。
