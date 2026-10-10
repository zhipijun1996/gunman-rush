# 敌人、Actor与Boss契约

当前D062见[分岔挑战修订](plains_branch_revision.md)：普通房不清怪也可出门；两条分支终点分别单门；击杀独立抽样金币/音符/爱心，接触爱心恢复当前HP。旧开发记录不覆盖现行规则。
HEALTH-01独立玩家Health/Stamina与ENEMY-01一个固定灰盒巡逻敌人已接入；Boss和玩家受伤流程仍未实现。P4实现一个最小Boss；不一次制作全部攻击/主题。正式怪物伤害与环境扣血回退由damage_and_respawn规定，旧“机关可直接致死”的正式规则废止。

Actor组合Health/Hurtbox/Hitbox或Projectile/Faction/Motor/AbilitySet/Presentation；每个Motor独占自身运动。EnemyAI感知/决策输出ActorIntent，不读玩家屏幕输入，不引用PlayerController控制流程。EnemyDefinition属性/感知/动作/攻击/掉落均可配置；最小patrol/attack/recover/dead按实际消费者实现，再增加追击/远程等。

接触、近战与敌弹产生MONSTER DamageRequest，攻击前摇/有效/后摇用游戏物理clock，不由替换动画决定伤害窗口。阵营/重复attack_id、怪物无敌与actor token统一过滤。环境回退保留敌人/机关相位与stage敌弹，但旧目标回调重新校验actor_epoch，出生保护独立；清理/重开只按明确scope。

## BossEncounter分层

BossPhaseController管理阶段/阈值与取消旧阶段攻击；AttackPattern管理前摇/弹幕/攻击seed；BossArena管理固定核心、必要躲避空间与兼容外围模板；BossEncounter管理开始/战斗结束、encounter_id/defeat_id；RewardService管理一个Guaranteed GOLD奖励；RunDirector统一裁定胜负与下个大关，不写Boss分支进PlayerController。

每大关正式第10小关固定Boss，开发3关测试第3为Boss。击败Boss必产一个金道具，只结算一次；领取方式待定。玩家/Boss同帧死亡暂定玩家失败优先、无Boss奖/无下一大关，先冻结帧资格收集伤害，再统一Health结果与RunEnd，不依赖signal先后。

首版Boss部分随机策略是暂定：核心战斗区/必要躲避空间固定；入口/装饰/已验证外围随机；影响战斗的平台/危险只能选适配攻击模式的模板。模板记录Boss/攻击版本、范围/遮挡/安全落点与capability约束；不保证任意随机布局都安全。

阶段切换、真正死亡/场景卸载按encounter ownership取消攻击/计时器/旧信号；段回退不默认重置Boss生命/阶段或刷奖励。重开新run/合法新encounter才按其策略初始化。Boss攻击RNG独立，不污染map/reward流。

验收：独立敌人组件、统一伤害/友伤/去重、动画替换不改命中、Boss阶段取消、同帧死亡两种回调顺序、必出金且一次、模板安全性、无空金池静默降级及旧run回调不发奖。攻击数值/阶段数量/具体Boss内容待其任务选择候选，不锁最终平衡。

## ENEMY-01首个实际消费者

scenes/enemies/patrol_drone.tscn组合EnemyDefinition/HealthDefinition、EnemyActor、EnemyPatrolAI、EnemyIntent、EnemyMotor、Damageable和EnemyPresentation。首个敌人是固定高度悬浮巡逻fixture；90速度、±100范围、3HP、28×32碰撞体只在resources/enemies定义，不锁定正式平衡/未来地面或追击AI。实例化时复制运行所需配置与独立Health/AI状态，定义不持有当前生命/巡逻方向。

AI输出轴与本步最大旅行距离，Motor用一次move_and_collide做实际扫掠与墙阻挡，遇墙下一意图反向；不读InputRouter/PlayerController，不增加第二个move_and_slide入口。Actor协调组件和败亡；表现只画原创几何占位形状/HP点，不决定受击或速度。暂停与全场慢时使用游戏clock，死亡停止AI/运动、清碰撞，不发奖励/不结束玩家本局。

现有PlayerProjectile→Damageable字典入口暂作兼容适配：给伤害附target_actor_id与target_epoch；Health绑定目标必须校验两项、友伤/自身/非法量/重复，才创建ActorResourceRequest提交唯一HealthState。新敌人不维护第二份HP，旧CombatTarget继续旧计数兼容。未来DAMAGE-01引入类型化DamageRequest/批次时迁移此桥，不将兼容字典升级为万能事件总线。

正式环境段回退仍须保留敌人生命与AI；目前只在显式旧灰盒重启/新关初始化时调用EnemyActor.reset。玩家接触怪物扣血、怪物受击无敌、环境回退/真正死亡均未接入，不因为可击败敌人宣称A33通过。A20的第二种AI/敌人主动攻击留后续，当前只验证其最小独立AI/受击/友伤/败亡部分。


## 时钟世界中的战斗定位

以[世界锚点](world_and_story.md)为背景：敌人用于路径压力与可读互动，Boss重在位移、落点和机关节奏。当前攻击弹体/伤害消费者仍保留，正式每房完成条件由StageRule配置，不因combat名称或灰盒“击杀无人机”fixture强迫所有小关站定清怪。Boss核心区域/必要站位固定，只从适配攻击模式的已验证有限布局变体选择；最终“最后的守钟人”为工作名和后续候选，不替换现有demo Boss或确定其身份。路线机制回响只使用本局已学并验证的模式，限制同时激活危险。金奖必出/一次结算与同帧死亡优先策略保留。
