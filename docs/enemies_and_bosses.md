# 敌人、Actor与Boss契约

当前只有玩家攻击弹体与独立Damageable灰盒靶，没有敌人AI、玩家Health或Boss。P2实现一个固定灰盒敌人，P4实现一个最小Boss；不一次制作全部攻击/主题。正式怪物伤害与环境扣血回退由damage_and_respawn规定，旧“机关可直接致死”的正式规则废止。

Actor组合Health/Hurtbox/Hitbox或Projectile/Faction/Motor/AbilitySet/Presentation；每个Motor独占自身运动。EnemyAI感知/决策输出ActorIntent，不读玩家屏幕输入，不引用PlayerController控制流程。EnemyDefinition属性/感知/动作/攻击/掉落均可配置；最小patrol/attack/recover/dead按实际消费者实现，再增加追击/远程等。

接触、近战与敌弹产生MONSTER DamageRequest，攻击前摇/有效/后摇用游戏物理clock，不由替换动画决定伤害窗口。阵营/重复attack_id、怪物无敌与actor token统一过滤。环境回退保留敌人/机关相位与stage敌弹，但旧目标回调重新校验actor_epoch，出生保护独立；清理/重开只按明确scope。

## BossEncounter分层

BossPhaseController管理阶段/阈值与取消旧阶段攻击；AttackPattern管理前摇/弹幕/攻击seed；BossArena管理固定核心、必要躲避空间与兼容外围模板；BossEncounter管理开始/战斗结束、encounter_id/defeat_id；RewardService管理一个Guaranteed GOLD奖励；RunDirector统一裁定胜负与下个大关，不写Boss分支进PlayerController。

每大关正式第10小关固定Boss，开发3关测试第3为Boss。击败Boss必产一个金道具，只结算一次；领取方式待定。玩家/Boss同帧死亡暂定玩家失败优先、无Boss奖/无下一大关，先冻结帧资格收集伤害，再统一Health结果与RunEnd，不依赖signal先后。

首版Boss部分随机策略是暂定：核心战斗区/必要躲避空间固定；入口/装饰/已验证外围随机；影响战斗的平台/危险只能选适配攻击模式的模板。模板记录Boss/攻击版本、范围/遮挡/安全落点与capability约束；不保证任意随机布局都安全。

阶段切换、真正死亡/场景卸载按encounter ownership取消攻击/计时器/旧信号；段回退不默认重置Boss生命/阶段或刷奖励。重开新run/合法新encounter才按其策略初始化。Boss攻击RNG独立，不污染map/reward流。

验收：独立敌人组件、统一伤害/友伤/去重、动画替换不改命中、Boss阶段取消、同帧死亡两种回调顺序、必出金且一次、模板安全性、无空金池静默降级及旧run回调不发奖。攻击数值/阶段数量/具体Boss内容待其任务选择候选，不锁最终平衡。
