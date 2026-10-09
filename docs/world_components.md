# 独立地图组件

组件是可单独实例化和测试的 Godot 场景 + 定义 Resource + 局部运行状态。对象只依赖 WorldContext 的服务契约，不通过绝对 NodePath 查找玩家、HUD 或特定房间。

| 对象 | 组合职责 | 可配置扩展 |
| --- | --- | --- |
| 齿轮/锯轮 | Visual、Motion、HazardContact | 静止/旋转/轨道移动、周期、伤害策略 |
| 机关 | Trigger、Mechanism、Motion | 定时、开关、压力板、门、移动平台 |
| 怪物 | Actor、AI、Motor、Health、Attack | 巡逻/追击/远程、阵营与掉落 |
| 补给道具 | Trigger、Reward、RespawnPolicy | 射击/跳跃/生命、数量、冷却、拾取条件 |
| 检查点 | SafeSpawn、CheckpointActivation | 重生位置、局部重置策略 |
| 存储点 | Interaction、SaveServiceAdapter | 持久存档槽位与保存范围；后期实现 |

检查点与持久存储点不同：前者当前会话快速重生；后者写存档，需 schema_version、稳定对象 ID、原子写入、损坏恢复和迁移。MVP 不实现磁盘存档，但不能把检查点 API 当存档 API。

WorldContext={session_id,clock,actor_registry,damage_service,reward_service,checkpoint_service,optional_save_service}。对象 stable_id+definition_version，提供 activate/deactivate/reset(policy)/capture_state/restore_state（持久化时才实现后两项）。卸载必须断开订阅、清理碰撞与计时器。
Trigger 输出上下文事件；Mechanism 消费指定通道，关卡用导出的对象引用或稳定 ID 连接，不在玩家脚本加“某房间开门”分支。Motion 与伤害分离：换锯轮图片不改碰撞，换轨迹不改资源授予。

固定与随机关卡实例化相同场景；模块定义只描述摆放和连接。随机时记录初始相位与配置。场景验收：单独测试、复制两实例不共享运行状态、跨两张关卡复用无需改玩家、卸载重载无旧事件。
