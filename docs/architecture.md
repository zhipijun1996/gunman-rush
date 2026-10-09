# 架构与接口

## 职责

| 系统 | 状态归属 | 接口与失败行为 |
| --- | --- | --- |
| InputRouter | 轴、动作队列、epoch | sample_axes; consume_actions(tick); clear(reason)。丢弃过期或旧 epoch |
| Touch/KeyboardMouse/GamepadAdapter | 各设备捕获、瞄准与释放状态 | 归一化轴与动作意图；取消只清状态，不生成射击 |
| PlayerController | ACTIVE/DEAD/RESPAWNING、动作顺序 | physics_tick; die; respawn。非 ACTIVE 拒绝动作 |
| PlayerMotor | normal_velocity、recoil_velocity、接地 | step(intent, delta); apply_impulse / start_shot_burst / clear_recoil; project_collisions。唯一位移入口 |
| JumpLogic | 缓冲、土狼时间、已用跳跃 | request_jump; try_jump; reset。耗尽拒绝 |
| ActionResources | 射击次数、上限、腾空账本 | try_consume_shot; grant_shot; on_landing; reset |
| Weapon | 冷却、shot_id | try_fire(direction)。失败不消耗、不生成弹体 |
| Projectile | owner_id、shot_id、session_id、阵营、半径、寿命 | 圆形体积 sweep；阻挡/一次伤害/销毁，旧 session 无攻击 |
| Damageable | 生命、阵营、事件去重 | receive_damage(context)，独立于玩家控制、AI 和表现 |
| RechargeTarget | target_id、激活状态、刷新规则 | try_activate(context)。去重后请求资源授予 |
| LevelSession | 检查点、关卡实例与 session_id | load(definition); respawn_checkpoint; restart |
| Presentation | 动画、光效与声音 | 订阅 shot_fired/resource_granted/player_died/landed |

输入使用 Intent 与 ActionRequest 数据对象：type、sequence、epoch、timestamp、direction（仅射击）。不含 UI 坐标或触摸 ID。跨模块事件携带 session_id、player_id、event_id，防重生后的旧事件生效。

## Android 与 PC 共用边界

一套 PlayerController、能力、机关、敌人、Boss 和地图逻辑服务所有目标平台。Android 横屏优先交付；Windows 是未来正式平台，Steam 首发优先 Windows，Linux、macOS、Steam Deck 后续各自验证。继续使用 Godot Standard + GDScript。

TouchAdapter、KeyboardMouseAdapter、GamepadAdapter 分别处理设备事件，共同输出上述 Intent/ActionRequest。设备事件与 UI 不进入 Motor、能力或世界组件。详细释放、取消、死区与重新武装规则以 [输入契约](controls_contract.md) 为准；输入适配器只能提出动作，不能直接施加速度、改位置或消费资源。

DevicePresentation 根据最近有效输入更新提示，桌面隐藏触屏控件。InputProfile 保存可配置死区、灵敏度与按键映射；配置修改会取消相关旧手势，不能合成一次释放射击。PlayerTuning 仍是物理参数来源；不通过像素、屏幕尺寸、触屏布局、设备类别或渲染帧率调整玩法物理。瞄准在适配器内经过 Camera/Viewport 转为世界单位方向，物理固定 60 Hz。

## 存档与平台接入边界

所有平台共用 SaveData schema，包含 schema_version、content_version 和稳定对象 ID；平台文件路径、账号和 Steam 标识不进入玩法存档格式。SaveService 负责序列化、校验、版本迁移与存档策略；LocalSaveStorage 负责平台文件位置、原子写入和损坏恢复；未来 CloudSyncAdapter 负责传输、同步状态和冲突处理。云同步失败不破坏本地可用存档，具体冲突策略在接入前补规格。检查点仍是当前 LevelSession 重生状态，不冒充持久存档。MVP 保留接口边界，暂不实现磁盘或云存档。

PlatformServices 为成就、云同步等提供可选独立适配层。普通构建使用本地/空适配，SteamAdapter 的依赖与初始化集中在平台模块，玩家、能力、世界对象、敌人和 Boss 均不调用 Steam SDK。未安装 SDK、未运行 Steam 或初始化失败时，普通游戏仍能启动和完成固定挑战；平台服务可报告不可用，不能阻塞核心循环。现在不实现完整 Steamworks、不创建商店发布，也不要求 Steam 账号才能开发；实际接入时再依据 SDK 和授权条件细化。

Android 与 Windows 各有导出预设、构建日志和验收记录；一个平台通过不能推断另一个通过。ENV-01 准备对应引擎版本的 Android 工具链和 Windows Desktop 模板路径，实际预设和可运行导出在工程与版本门槛满足后实现。

## 依赖与扩展

输入适配器 → Router → Controller → Motor/Jump/Weapon/Resources；关卡对象通过 context 请求交互，表现只接收结果。资源不依赖 UI、Weapon 不依赖某地图。先直接引用与 typed signal，不引入全局万能事件总线。

计划目录：scenes/{player,ui,test_levels,hazards,levels}；scripts/{input,player,combat,world}；data/；assets/；tests/。需要时才创建。后期 generation/rooms 接 LevelDefinition，固定与随机 LevelLoader 不更改玩家接口。

PlayerTuning Resource 集中参数；WeaponDefinition、AbilityDefinition、HazardDefinition 在实际引入第二种内容时建立。save_schema_version/content_version 为后期存档设计，当前无存档系统。

## 同帧事务

消费输入 → 更新时钟 → 应用上一帧合法交互奖励 → 跳跃 → 射击 → 普通重力/指数衰减或短爆发窗口 → 一次移动 → 碰撞修正 → 致命判定 → 有效落地恢复 → 收集本帧交互供下一帧执行 → 表现。
死亡优先于尚未授予的奖励，取消旧 session 事件。命中奖励下帧可用，防止同帧自循环。

## 强制扩展契约

能力采用 [能力组件](ability_components.md)；世界对象采用 [地图组件](world_components.md)；敌人与 Boss 采用 [战斗架构](enemies_and_bosses.md)。这些契约现在约束实现，但未使用的完整系统延后开发。原文关于第二种内容才建立 Definition，不适用于跳跃/射击基础能力配置：M1 就必须支持 N 次数与能力启停。

## 可变跳高与网页迭代

InputRouter输出有序jump/jump_release边沿并聚合持有源；JumpAbility处理最短/最长维持和释放截断，Motor仍唯一位移出口。网页复用全部能力与输入适配器，Android和iPhone共享单线程Web试玩，不另写浏览器物理。构建为玩法PCK生成内容指纹、可见版本号和build-info.json；旧HTML检查当前版本并至多跳转一次，减少手机旧缓存干扰。正常推送验证物理、Windows导出和Web导出；仅指定试玩分支push部署Pages，不从PR发布。APK保留独立可选构建，Web不能证明原生Android性能。
