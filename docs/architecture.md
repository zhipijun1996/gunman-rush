# 架构与接口

正式设计以[游戏设计](game_design.md)为准；运行、奖励、伤害、家园分别由[运行路线](run_and_routes.md)、[奖励构筑](rewards_and_builds.md)、[伤害回退](damage_and_respawn.md)、[家园存档](home_and_save.md)细化。下表是职责契约，不代表系统已实现；实现状态在[任务](tasks.md)。

当前模块导航及已接入资源框架见[模块分类](module_map.md)。

## 角色、输入与局部世界

| 系统 | 状态归属与边界 |
| --- | --- |
| InputAdapters / InputRouter | 归一化轴、jump/jump_release/shoot_release有序请求、aim_engaged与epoch；取消不射击，不消费资源/改位置 |
| PlayerController | 协调能力与动作顺序，ACTIVE/ROLLING_BACK/INACTIVE；接收通用伤害结果，不管理Boss/路线/道具ID |
| PlayerMotor | normal/recoil速度、接地/碰撞、唯一运动与安全定位出口，每tick最多一次move_and_slide |
| Jump / Shoot / Recoil / AirFocusAbility | 各自动作规则、冷却与持续状态；启停/次数配置，慢时与金黄遮罩保留原型实验 |
| Health / Stamina / ActionResources | 三份独立状态/配置/变更事件；精力用途未定，动作不默认消耗精力 |
| Actor / Damageable / AI | Actor组合Health/Hurtbox/Faction/Motor/能力；AI输出ActorIntent，不读取玩家输入 |
| StageContext（演进自WorldContext） | 显式局部服务引用、run/stage token、游戏clock、对象注册/状态；段回退不能reset全世界 |
| Presentation | 订阅具体结果，控制动画/光效/声音/遮罩；不决定玩法或时间倍率 |

现有WorldContext.respawn的全对象reset、PlayerController.die快速检查点复活只属于尚待隔离的旧灰盒。阶段2将环境碰撞从直接die迁移到DamagePolicy；显式LEGACY_INSTANT_DEATH只能测试，正式健康/死亡不复用旧全场景reset。

## 运行与内容服务

| 职责 | 所有权与输入输出 |
| --- | --- |
| RunDirector | RunLifetime/RunState、一局与主题/小关、唯一转场、胜负；SelectExit→StageTransitionCommitted，RunEnd→Home |
| BiomeDefinition | 主题与内容池，不拥有运行状态，不等于StageType |
| StageTypeDefinition + StageRule | 类型、图标、完成条件/奖励/出口策略；注册新规则组件，Loader不堆类型switch |
| RoutePlanner | 两个ExitOffer、节奏、Boss必达；独立route随机流 |
| LevelGenerator | Biome+Type+能力快照+seed→LevelDefinition与StageManifest；独立map流，有界失败与验证保底 |
| RewardService | RewardOffer/领取组/稀有度与幂等收据；独立reward流与RunLedger |
| ShopService | 报价/币种/库存/购买与收据；独立shop流，原子扣币/效果/库存 |
| BuildState + ModifierResolver | 本局道具/技能/武器及来源修正；从基础重算，可撤销，不修改玩家脚本 |
| DamagePolicy | 按物理tick收集/排序/去重与两类伤害/终局优先级；Health只数值结算 |
| SegmentRespawn | 挑战段安全锚点、输入/运动清理及actor_epoch；不拥有场景整体reset |
| BossEncounter | 战斗开关/阶段/攻击/BossArena与defeat_id；奖励交RewardService，胜负交RunDirector |
| MetaProgression + RunPolicy | 永久升级/解锁/剧情与本局结算边界；未决定经济不自动转币 |
| SaveService / StorageAdapter | Profile版本/迁移/幂等提交与原子存储；云/Steam适配独立、可缺省 |

## 类型化数据与事件

请求与结果采用具体Resource/RefCounted类型，不用无边界Dictionary事件总线。RunToken={run_id,run_epoch}；StageToken另加stage_id/stage_epoch；ActorToken再加actor_id/actor_epoch。奖励账本属于run/stage，不随actor_epoch重置；持久事务用profile_id/revision/transaction_id，不能误用临时token。

局部typed signal例：DamagePolicy.damage_resolved(result:DamageResult)、SegmentRespawn.actor_returned(result:SegmentReturnResult)、RewardService.reward_claimed(receipt:RewardReceipt)、ShopService.purchase_committed(receipt:PurchaseReceipt)、BossEncounter.boss_defeated(result:BossResult)、RunDirector.run_ended(result:RunEndResult)、SaveService.save_committed(receipt:SaveReceipt)。对象只引用所需StageContext服务；表现/AI不凭同名全局signal串关。

## 帧级提交顺序

输入意图→动作时钟/合法已提交资源→有序跳跃→释放射击→一次Motor移动/碰撞→收集所有Actor合法DamageRequest→确定性去重/批次Health结算→玩家零血终局→非致命环境段回退/怪物无敌→Boss胜利与StageRule完成→奖励/购买/出口逻辑提交→表现。死亡优先于未提交奖励/转场；双方同帧死亡暂定失败且无金奖励。具体批策略见damage_and_respawn，不由回调顺序决定。

## 时间、随机与存储域

普通物理/机关/攻击/冷却按60Hz游戏clock，现有慢时原型统一缩放Engine.time_scale，精力与慢时预算按真实秒。视觉淡入/淡出与输入保持实时响应；多慢时来源引入前建立统一所有权，不能Boss与能力互相覆盖。独立Stamina正式消费时钟由策略配置，用途待定。HEALTH-01已将AirFocus计量提取为独立StaminaState，由显式原型政策消费/恢复；移动/跳跃/射击不绑定消费。

map/route/reward/shop及Boss攻击独立随机流；Seed和所有算法/内容/配置版本、实际路线/布局/候选/库存结果写完整RunManifest。内容复现与运行快照不同，版本缺失显式不兼容。局内与Meta存档数据共用schema、文件适配与云同步分层。

## 跨平台与渐进迁移

Godot Standard + 类型化GDScript不变。Android横屏当前优先，Windows为正式目标、Steam首发Windows，Linux/macOS/Steam Deck分别验证。三适配器只产统一意图，物理不依赖屏幕/设备，提示/死区/敏感度/映射独立；详见controls_contract。Web用于Android/iPhone快速迭代，不能证明Safari真机、APK性能或Windows实机通过。

PlatformServices提供可选SteamAdapter，本地/空适配可运行；玩家/地图/AI不调用Steam SDK。不实现完整Steamworks/商店发布，不要求Steam账号/SDK。SaveService不包含Steam标识，未来CloudSyncAdapter独立处理失败/冲突。

先保留已通过原型，P2实际引入Health/Stamina/DamagePolicy/SegmentRespawn与最小敌人，P3实际消费者才引入最小Modifier/Reward/Shop，P4固定3关集成RunDirector/路线/Boss/Home，P5正式10关/生成，P6永久存档/内容。不一次创建全部空框架。已接入scripts/resources/{definitions,state,contracts}、scripts/actors与资源HUD，以及scripts/enemies的Actor/AI/Intent/Motor/表现组合；Damageable兼容桥委托HealthState；scripts/{run,rewards,builds,damage,meta}已由固定demo消费，Meta仅内存摘要；save/generation仍按对应任务引入。


## 随机地图空间与难度（设计接入）

详见[生成权威](procedural_generation.md)、[8模块蓝图](platforming_modules.md)与[候选难度](difficulty_profiles.md)。LevelGenerator以GenerationRequest快照调用LayoutPlanner/ModuleAssembler/LevelValidator，输出LevelDefinition与StageManifest；布局图/端口速度资源/危险相位、world_bounds和CameraProfile必须明确。主题、类型、横纵/方形拓扑、P/C/T/R预算分别组合。StageFactory只实例化验证结果，共用现有伤害/段回退/奖励/交易/Boss服务；Controller和Motor不认识生成器。

CameraRig负责世界边界与预告视野，不改物理和输入意图；非单屏布局须先验证鼠标世界转换/触屏瞄准与顶底边界。随机关卡生成时固定参数快照，不让不同手机分辨率改变世界碰撞。各接口按任务实际消费者创建，本轮只交付文档与原创示意，未创建运行时空框架。
