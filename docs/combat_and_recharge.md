# 枪支、独立资源与补给

正式战斗/奖励规格以[伤害回退](damage_and_respawn.md)、[奖励构筑](rewards_and_builds.md)为准。当前仅玩家弹体/Damageable灰盒靶/射击补充/慢时原型已实现；玩家Health、敌人伤害与正式补给迁移未实现。

## 枪支与发射事务

CharacterDefinition持有基础属性/能力/初始WeaponDefinition。WeaponDefinition包含id/version、冷却/射速、弹体引用、damage、recoil策略/参数、spread策略、ActionCostPolicy与行为组件。未来不同枪/人物/流派通过定义组合，不在玩家控制器写武器ID分支；其他发射方式未定，当前仍按有效释放沿生成ShotRequest，缩短冷却不自动连射。

校验ACTIVE/方向/冷却/显式资源政策→原子消费→开始冷却→反冲→弹体→shot_fired；失败无副作用。射击不需命中就反冲，命中不再重复反冲。当前默认shot_burst 1100×.14秒位移154、无无敌/穿墙，legacy指数反冲保留；不因新经济/精力改变现有动作链。

弹体圆体积sweep，最近合法目标单次伤害、地形阻挡，阵营/owner过滤、寿命与所属token清理不变。现有shot_id/owner/session契约迁移为Run/Stage/Actor token时保留兼容适配和A31旧回归；当前speed1200/radius3/damage1/lifetime2仅原型参数，不是所有枪默认硬限制。

## 三类资源接口与配置

| 状态 | 定义字段 | 接口/边界 |
| --- | --- | --- |
| Health | resource_id/version、max、initial_current、合法范围 | apply_damage(DamageBatchResult)、heal(HealEffect)、set_max(MaxHealthEffect)、snapshot；零血终态，不知道地图/家园 |
| Stamina | resource_id/version、capacity、initial_current、regen_policy_id、consume_policy_ids、clock_domain | try_consume(request)、grant(request)、clamp、snapshot、changed；必须显式能力消费者，正式用途未定 |
| ActionResources | jump/shot资源ID、可配置上限、落地恢复与补充策略 | try_consume/grant/on_ground/snapshot；次数0/N、腾空账本不被精力误改 |

定义不保存当前状态，各Actor实例独立；接口请求携带合法token和transaction/event ID，失败不消费，增量钳制，重复事件不重复授予。Health的伤害批次来自DamagePolicy，不在UI消费；Stamina不接入移动/跳跃/射击默认消费。ActionResources当前射击账本已实现，跳跃目前由JumpAbility计数，P2适配其快照而不推倒动作实现。

当前AirFocus内部stamina/ground recovery与time budget为原型实验；P2先提取共享Stamina接口/配置，再由明确能力政策是否绑定。新正式精力用途待决策，原型候选100/45/30不锁定正式角色。新增Definition后一个stat只能有一个基础来源，当前config/player_tuning.json作为默认原型兼容入口，不能同时复制两份HP/武器默认参数。

## 补给与生命周期

射击补充、回血、加最大血量分别建Effect，不使用模糊的“加血”。HEAL_CURRENT不改max；INCREASE_MAX_HEALTH不隐式回血，组合须显式。普通射击补给仍只补动作次数，不默认补精力/HP、不重置射击冷却或弹跳。

正式候选ConsumptionPolicy每stage实例一次成功消费，资源满不消耗；段回退不重刷补给/奖励。刷新策略可扩展但需单独确认，不沿用旧“每生命一次、检查点全reset刷新”正式规则。已领取奖励、二选一组和商店库存归RunLedger/StageState，不随actor_epoch重新去重；未提交旧玩家请求取消，未领取offer可以新token重新申请。

动作链仍为跳跃→下射上升→补射击→冷却结束再射→落地恢复；怪物受击/环境回退不悄悄增加动作精力消耗。完整两类伤害/资源恢复和死亡优先按damage_and_respawn暂定策略实施，旧即时死亡仅显式测试。
