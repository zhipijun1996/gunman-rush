# 架构与接口

## 职责

| 系统 | 状态归属 | 接口与失败行为 |
| --- | --- | --- |
| InputRouter | 轴、动作队列、epoch | sample_axes; consume_actions(tick); clear(reason)。丢弃过期或旧 epoch |
| PlayerController | ACTIVE/DEAD/RESPAWNING、动作顺序 | physics_tick; die; respawn。非 ACTIVE 拒绝动作 |
| PlayerMotor | normal_velocity、recoil_velocity、接地 | step(intent, delta); apply_impulse; project_collisions。唯一位移入口 |
| JumpLogic | 缓冲、土狼时间、已用跳跃 | request_jump; try_jump; reset。耗尽拒绝 |
| ActionResources | 射击次数、上限、腾空账本 | try_consume_shot; grant_shot; on_landing; reset |
| Weapon | 冷却、shot_id | try_fire(direction)。失败不消耗、不生成弹体 |
| Projectile | owner_id、shot_id、类别、寿命 | hit(target)。同目标按命中策略只结算一次 |
| RechargeTarget | target_id、激活状态、刷新规则 | try_activate(context)。去重后请求资源授予 |
| LevelSession | 检查点、关卡实例与 session_id | load(definition); respawn_checkpoint; restart |
| Presentation | 动画、光效与声音 | 订阅 shot_fired/resource_granted/player_died/landed |

输入使用 Intent 与 ActionRequest 数据对象：type、sequence、epoch、timestamp、direction（仅射击）。不含 UI 坐标或触摸 ID。跨模块事件携带 session_id、player_id、event_id，防重生后的旧事件生效。

## 依赖与扩展

输入适配器 → Router → Controller → Motor/Jump/Weapon/Resources；关卡对象通过 context 请求交互，表现只接收结果。资源不依赖 UI、Weapon 不依赖某地图。先直接引用与 typed signal，不引入全局万能事件总线。

计划目录：scenes/{player,ui,test_levels,hazards,levels}；scripts/{input,player,combat,world}；data/；assets/；tests/。需要时才创建。后期 generation/rooms 接 LevelDefinition，固定与随机 LevelLoader 不更改玩家接口。

PlayerTuning Resource 集中参数；WeaponDefinition、AbilityDefinition、HazardDefinition 在实际引入第二种内容时建立。save_schema_version/content_version 为后期存档设计，当前无存档系统。

## 同帧事务

消费输入 → 更新时钟 → 应用上一帧合法交互奖励 → 跳跃 → 射击 → 重力衰减 → 一次移动 → 碰撞修正 → 致命判定 → 有效落地恢复 → 收集本帧交互供下一帧执行 → 表现。
死亡优先于尚未授予的奖励，取消旧 session 事件。命中奖励下帧可用，防止同帧自循环。

## 强制扩展契约

能力采用 [能力组件](ability_components.md)；世界对象采用 [地图组件](world_components.md)；敌人与 Boss 采用 [战斗架构](enemies_and_bosses.md)。这些契约现在约束实现，但未使用的完整系统延后开发。原文关于第二种内容才建立 Definition，不适用于跳跃/射击基础能力配置：M1 就必须支持 N 次数与能力启停。
