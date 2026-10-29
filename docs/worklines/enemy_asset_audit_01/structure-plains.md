# 平原7种程序结构盘点与最小统一边界

当前HEAD `9b76f0044f0fe4d729f2bc894abf153a4f238564`。只读事实/方案，未改仓库、未跑Godot；保留“先不要批量做，先发现问题”。底层共用不代表视觉同质，也不代表成品质量已接受。

## 实际共通主干

正式调用：`PlainsRegionGenerator manifest → GeneratedDemoStage._spawn_enemies_from_plan → patrol_drone场景 → 复制Definition/运行覆盖 → Actor ready(Health/Motor/AI) → root可先换专用Presentation → PlainsRegionStage保存health/位置恢复 → Pixel/Underworld表现再次安装 → 尸体support恢复 → DemoApp绑定DamagePolicy/Behavior/接触Emitter与保存行为phase`。

共享Actor/Health/Damageable/Motor已存在；主要结构不一致在**装配、外观分派、反馈和恢复所有权**，不需要重写所有怪物AI或建立巨型实体框架。

| 物种 | Actor/AI/Motor/Health/Damageable | Behavior | 表现/反馈差异 |
| --- | --- | --- | --- |
| patrol_drone | 共用同一场景组件 | 无主动Behavior，PatrolAI直接输出 | scene/underworld；HitTemplate owner+宿主原终态 |
| plains_charger | 共用同一场景组件 | enemy_attack_behavior | scene/underworld；专有sample+Frames/Body/粒子+stage兄弟Remains |
| plains_diver | 共用同一场景组件 | enemy_attack_behavior | scene/underworld；专有sample+Frames/Body/粒子+stage兄弟Remains |
| plains_hopper | 共用同一场景组件 | enemy_attack_behavior | scene/underworld；HitTemplate owner+宿主原终态 |
| plains_sentry | 共用同一场景组件 | enemy_attack_behavior | scene/underworld；HitTemplate owner+宿主原终态 |
| plains_fan_sentry | 共用同一场景组件 | enemy_attack_behavior | scene/underworld；HitTemplate owner+宿主原终态 |
| plains_root_bell | 共用同一场景组件 | root_bell_behavior | scene_raw_fallback/underworld/root_bell_independent；HitTemplate owner+宿主原终态 |

运行覆盖：资源不是实例全部真相。工厂复制Definition后写`patrol_half_width=data.patrol_radius`、`aerial=data.aerial`、可选`dive_depth`；App再恢复state/state_time/cooldown/serial/home/方向/目标并设置并发上限。patrol仍为历史灰盒/接触fixture，不能因计入库存就当正式主动池新增物种。

## 已证实的问题

- **PS01 运动flag泄漏成外观分派**：aerial用于Motor的_ground_actor、Actor击退平面；两个presenter又优先拿它选sprite/aerial分支，fan因此画飞行机并绕过mesh。 出处`scripts/enemies/enemy_motor.gd:15`。影响：改运动参数可意外换身体/失去动画；反过来为换图改aerial会改击退与支撑策略。
- **PS02 实例装配和最终表现选择分散**：GeneratedDemoStage先root专门换Presentation，PlainsRegionStage后来装PixelFormalActors与UnderworldActors，installer整节点替换；rawscene/diagnostic/formal最后使用者不同。 出处`scripts/demo/generated_demo_stage.gd:182`。影响：临时表现已ready/订阅后再销毁；某链验证通过不能推出另链相同；名字同Presentation不足以确认身体。
- **PS03 Definition源、实例覆盖和App恢复未成单一可读合同**：基础tres复制后覆盖aerial/patrol范围/dive_depth，App再恢复Behavior多个字段和并发上限。基础Definition不是最终实例全貌。 出处`scripts/demo/generated_demo_stage.gd:175`。影响：制作卡/测试容易只看资源默认值；保存/重载或改工厂顺序可能还原错home/phase。
- **PS04 专有与通用反馈有两套装配所有权**：charger/diver presenter直接new/advance/dispose EnemyFeedback01及Frames/Remains；其它由HitTemplate child封装同sample。这一能力由stable_id映射决定。 出处`scripts/enemies/enemy_feedback_01.gd:28`。影响：新物种容易漏接/双接或误借两种死帧；事件顺序和epoch恢复每个分支重复维护。
- **PS05 非专有Underworld重复hurt缓存**：父Windchime._ready匿名health监听、Underworld自己的_accepted_damage与HitTemplate.sample同时接入；_hurt/.12/.hurt_seconds与sample时钟并行。 出处`scripts/art_foundation/windchime_enemy_visual.gd:9`。影响：维护者误认唯一反馈；恢复/过滤条件不一致，但不能据此断言三次伤害或当前泄漏。
- **PS06 表现时钟和状态缓存有未消费计算**：EnemyPresentation仍_update_frame_weights，但body live固定idle_a；RootBell计算_pose/_transition_time而_draw_pose固定idle/death。各宿主还保留_clock/_hurt/_death，另有body_motion.clock。 出处`scripts/enemies/enemy_presentation.gd:90`。影响：文档把存在的pose/state误当画面；清理若直接删缓存可能影响备用_remains_view/aerial分支。
- **PS07 epoch/initialize同步重复散在多宿主**：EnemyFeedback01._synchronize、HitTemplate._health_changed、两个presenter初始化、PlainsMotion02.advance/draw_body自检查及Remains._initialized都处理epoch。 出处`scripts/enemies/enemy_feedback_01.gd:40`。影响：paused initialize必须立即生效，移动delta=0同步不能吞位移；某个分支单独修改易残旧状态。
- **PS08 Stage保存直接识别renderer类且恢复有顺序依赖**：Stage._enemy_remains用UnderworldEnemy/EnemyPresentation type检查取feedback_remains；health/位置先恢复，表现安装后再恢复corpse support；App手写Behavior字段。 出处`scripts/demo/plains_region_stage.gd:157`。影响：换renderer可能丢尸体/重播死亡；先后顺序动错会基于旧位置采样。
- **PS09 终态政策分散且不应一刀切**：Underworld父.65s fade、legacy普通单death/同图且alpha下限.18、RootBell独立.8s fade、charger/diver stage-sibling持久尸体，均由不同owner决定。 出处`scripts/art_foundation/pixel_plains_enemy.gd:15`。影响：结构统一容易误清持尸或强加全部留尸，改变保存/奖励/预算。
- **PS10 恢复health不是完整复活接口**：restore_instance_health仅health.configure复制的HealthDefinition；_on_death另关Motor碰撞和Actor physics。正式重载使用新实例，不能把health方法当通用同实例复活。 出处`scripts/enemies/enemy_actor.gd:100`。影响：未来统一reset时误认为恢复HP自动恢复碰撞/AI；未在本审计证明当前正式重载失败。

不是所有“重复”都应合并：Damageable/Policy/Health的去重分别保护不同边界；Behavior物理state_time、表现局部clock、尸体physics时钟也不是一回事。匿名Node信号缺显式disconnect并不自动证明当前泄漏，本次没有运行验证。

## 建议一起确认的最小统一边界

1. **本轮先共同确认物种/结构差异与问题清单**：7物种组件表+实际factory/override/renderer/feedback/death policy合同；保留用户对成品质量的拒绝，不继续批量制作。
2. **选择一个代表物种作装配边界样板**：建议先fan或charger其一：fan揭示aerial视觉耦合；charger揭示两skin和尸体生命周期。由用户一起选，不先两者都重构。
3. **收敛现有factory的创建顺序和显式presentation profile**：baseDefinition + manifest runtime overlay → actor components ready → encounter binding → selected presentation → saved visual restore；只一最终renderer安装。
4. **统一accepted-feedback与表现生命周期契约**：一sample owner、bind/sync_epoch/advance/dispose窄接口、body/warnings/HP separation；可选Frames/Remains policy；消除已证无消费者缓存。
5. **样板完成后再决定是否迁移第二物种**：同构规范只约束所有权和输入输出；每物种艺术母版/动画方法/机制/终态保持独立。实际合屏和用户质量判断必须先于批量迁移。

可共通：一个明确实例工厂、显式runtime overlay和最终presentation选择、一处accepted-feedback owner、统一bind/sync_epoch/advance/dispose语义，以及窄的visual snapshot能力。应保留：每物种策略/运动、专属身体与动画制作方式、各skin、root固定锚和中断规则、不同终态/尸体政策。

迁移时优先保护：Godot_ready/信号顺序；paused initialize即时清状态；health_epoch与target actor_epoch各自取消语义；死档零重播；保存位置后装视觉/支撑；FrameDamagePolicy/奖励幂等；Stage sibling尸体不随Motor隐藏消失；旧trace/tests/Stage对Presentation具体类型和字段的依赖。

**本轮只交问题和边界，不实施批量重构。** 先与用户确认代表物种和验收观察，再选择一次最小迁移；不能用架构整齐或测试数量代替美术/动作实际审核。完整逐怪路径、运行覆盖、问题证据行号与源码SHA见同名JSON。
