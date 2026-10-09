# 敌人、战斗与 Boss 扩展

MVP 尚无敌人与 Boss；现在定义边界，不提前开发完整战斗系统。

Actor 由 Health、Hurtbox、Hitbox/Projectile、Faction、Motor、AbilitySet、Presentation 组合。敌人 AI（感知与决策）输出 ActorIntent，再由该 ActorController 执行；不得读屏幕输入或调用玩家控制器。每个 Actor 的 Motor 独占自身位移。机关致命策略可直接请求玩家死亡，不强行把精密跑酷变成扣血玩法。

DamageContext={session_id,event_id,source_actor_id,target_actor_id,attack_id,amount,damage_type,hit_direction}。Damageable 接收结果，统一检查阵营、无敌、死亡与事件去重；health_changed/damaged/died 驱动 UI 和表现。资源补充通过 RewardService，与受伤处理分离；同一个敌人可同时成为射击命中补充目标，但奖励策略必须明确。

EnemyDefinition：属性、感知范围、动作集、AI 配置、掉落引用。AI 状态机包含 idle/patrol/chase/attack/recover/dead；只在实际需要时添加状态。攻击前摇、有效帧和后摇由物理时钟驱动，动画订阅或同步时间轴；不能因美术动画被替换而改变伤害判定。

Boss 使用同一 Actor/伤害接口，额外 BossPhaseController 与 AttackPattern 配置。phase 条件可为生命阈值/事件；阶段切换取消旧攻击、弹体/机关按 encounter ownership 清理。ArenaController 管理开始、边界、胜利、失败与重置，不写入 PlayerController。攻击序列有独立 RNG/Seed 与节奏窗口，不能依赖全局随机流破坏地图复现。

死亡、重生、卸载和阶段切换都需 cancellation token/session epoch，延迟回调不得恢复已结束攻击。生成器仅要求能力/资源/战斗标签，不引用具体 Boss 脚本。

未来验收：敌人独立场景；两种 AI 复用同伤害组件；友伤过滤；同攻击去重；Boss 阶段边界；死亡后无伤害；重开恢复初始状态；替换动画不改命中窗口。敌人/Boss 引入前另补数值与难度规格。
