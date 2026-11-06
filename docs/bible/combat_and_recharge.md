# 攻击与独立资源

## 当前资源

| 资源 | 所有者与行为 |
| --- | --- |
| Health | HealthState／Definition；零血进入终态，恢复当前HP与提高上限分别处理 |
| 动作次数 | ActionResources；基础空中弹药一发，跳跃次数按当前能力；接地／真实命中及已授予能力恢复事件分别处理 |
| 时间能量 | AirFocus与ShotEnergyPolicy；枪械／钩索共用，只有实际空中瞄准慢时消费，接地按真实秒渐回 |
| 共鸣 | CombatEnergyState；合法敌人伤害产能，主动技与道具消费者共用其提交政策 |

基础射击本身不消费或返还时间能量；[道具](../data/items.md)可以在满足自身条件时返还，不能延长同次腾空的慢时预算。默认资源Definition是`game/player/resources/demo_ui_01/time_energy_v2.tres`。成功命中按会话、攻击包、目标和动作收据去重；空中实际伤害可补弹，并恢复已授予的H／D资格。

## 发射事务

校验活动状态、方向、冷却、动作次数和明确资源政策 → 原子消费 → 冷却 → 反冲 → 弹体 → 接受事件。请求失败不改变状态。射击发出即产生反冲，命中不重复施加同次反冲。

当前武器来自WeaponDefinition及运动Definition；同一时刻只有一个装备家族，其多弹体仍属于同一WeaponRuntime。伤害统一提交 [帧伤害策略](damage_and_respawn.md)，同帧死亡优先于奖励。

## 恢复与取消

补射击次数、恢复HP、提高HP上限和补共鸣是不同效果。提高上限不隐式回血，卸下来源只钳制当前值，零血不复活。接地恢复不重置射击冷却。

当前实现以Run／Stage／Actor epoch及武器epoch限制弹体、持续攻击和延迟回调。暂停、菜单、失焦、死亡和切换取消旧射击及慢时。新世界的永久、休息周期、挑战尝试与动作瞬态边界见 [保存与休息](home_and_save.md)。

武器各分支设计从 [动作入口](../data/player_actions.md) 按需读取；实际数值以配置、Definition与Runtime为准。代码与验证见 [模块导航](../project/module_map.md)。
