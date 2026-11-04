# 平原冲锋怪 · plains_charger

本页是 `plains_charger` 当前对象行为与表现规范。适用于正式平原及显式复用该定义的场景；参数与版本从当前资源解析。任务进度和历史验收属于 [ENEMY-ALL-02](../../tasks.md) 及对应质量记录，不在本页维护审计时间线。

## 设计归属与身份

- 上层约束：[整体战斗原则](../../game_design.md)、[平原 Bible](../../creative_direction/bibles/1-windchime_plains_region_bible_v2.md)、[Visual Bible](../../visual_bible.md)、[伤害与回退](../../damage_and_respawn.md)。
- stable_id 为 `plains_charger`，behavior_id 为 `charger`，阵营 enemy；地面近战压力，依靠可预读的定向冲锋迫使玩家改变高度或站位。
- 反制是观察预告后跳过、离开冲锋轴线、利用遮挡，或在安全位置射击／反冲并利用恢复窗。主路不能以尚未授予的 H/W/D 作为唯一解；有 H 时是否借怪过地形按实际授予和接触保护合同验证。
- [EnemyBehaviorRegistry](../../../game/enemies/enemy_behavior_registry.gd) 绑定策略、资源和场景；[EnemyFactory](../../../game/enemies/enemy_factory.gd) 创建独立实例配置。显式历史 revision 由注册表解析，不能把旧 charger_v2 当当前定义。

## 参数来源

数值唯一从下列机器来源读取；本页不维护一份人工数值表。世界长度为 wu，速度为 wu/s，时间使用游戏秒；实际慢时／暂停由调用时钟处理。

| 数据 | 唯一来源与字段 | 含义 |
| --- | --- | --- |
| 身份、体积与巡逻 | [plains_charger.tres](../../../resources/enemies/plains_charger.tres)：stable_id、definition_version、faction、collision_size、patrol_speed、patrol_half_width、initial_direction | 正式身份、碰撞尺寸、巡幅及初始朝向 |
| 生命 | 同资源 health_definition → [patrol_health.tres](../../../resources/enemies/patrol_health.tres)：max_health、initial_current | 创建时生命；运行中由实例 HealthState 持有，不能改资源模拟受伤 |
| 攻击时序和速度 | plains_charger.tres：telegraph_duration、attack_duration、recovery_duration、attack_speed | 预告、冲锋、恢复的时长和冲速 |
| 激活与安全点 | [EnemyDefinition](../../../scripts/enemies/enemy_definition.gd)：activation_range、protected_radius | 未被 .tres 覆写时采用导出字段默认；激活距离相对 home，安全点由场景提供 |
| 受伤运动 | [feedback.tres](../../../game/combat/damage/feedback.tres) 与 EnemyActor.damage_feedback | 普通接受命中的击退／停顿；技能另走自身 impact 参数 |
| 身体接触伤害 | [DemoContactEmitter](../../../game/combat/damage/demo_contact_emitter.gd) 与 DemoApp._contact 装配 | 与 FrameDamagePolicy 共用接触／无敌间隔政策，不从动画帧数推导伤害 |
| 初始攻控／并发策略 | [EnemyAttackBehavior](../../../game/enemies/behaviors/enemy_attack_behavior.gd)：cooldown、max_concurrent_attacks；实例装配可设并发 | 当前为实现默认值／实例政策，尚非独立配置字段；后续参数化时迁移真实来源，不在文档新增默认值 |
| 放置覆写 | EnemyFactory.INSTANCE_FIELDS 与实际 placement／Manifest | 只有允许字段可覆写；基准资源不代表每个放置的巡幅与方向 |

## 行为与状态

[EnemyActor](../../../game/enemies/enemy_actor.gd) 拥有生命和受伤暂停；[EnemyAttackBehavior](../../../game/enemies/behaviors/enemy_attack_behavior.gd) 拥有攻控时钟；[ChargerAttackStrategy](../../../game/enemies/behaviors/charger_attack_strategy.gd) 只规定冲锋运动；[EnemyMotor](../../../game/enemies/enemy_motor.gd) 执行碰撞与支撑探测。

| 状态／转换 | 条件和实际行为 |
| --- | --- |
| idle／巡逻 | 冷却递减；未进入攻击时交给原巡逻意图。目标须在相对 home 的激活范围、有视线、离开 protected_points，且满足实际并发上限 |
| idle → telegraph | 锁定目标方向并设置脑朝向，清相位时间，提交 warning 音义；不是每帧追踪玩家改方向 |
| telegraph → attack | 到预告时长且仍可接敌才冲锋；目标失效或被遮挡／进入安全区则转恢复 |
| attack | 沿已选左右方向向 `home.x ± patrol_half_width` 移动，单帧位移受 attack_speed 限制；使用 move_attack 的碰撞与地面支撑探测，不无视墙或冲离无支撑边缘；不发射弹体 |
| attack → recovery → idle | 攻击时长到期进入恢复并设置恢复债；恢复到期回到 idle。charger 不要求回到 home 后才能结束恢复 |
| 普通伤害反馈 | 只对接受伤害回执处理声音和击退。一般命中由 Actor 暂停动作推进并施加受约束击退，恢复后继续合法相位；反馈画面本身不另设伤害或 AI 中断 |
| 钩索／技能作用 | grapple 不叠加普通命中击退；技能走 apply_skill_impact 的中断／冷却／运动，取消当前攻击后恢复。未授予能力不因目标身份获得能力 |
| 取消／Actor epoch 改变 | 清旧攻击对象，转恢复并保留恢复债；没有有效玩家、世界失效或死亡时不继续攻击 |
| 死亡 | 终态停止攻控与运动、关闭身体碰撞并提交一次 defeated；同帧伤害顺序与玩家死亡优先服从共用合同 |

## 表现、声音与终态

正式平原通过 [UnderworldActorInstaller](../../../game/presentation/actors/underworld_plains/underworld_actor_installer.gd) → [EnemyPresentationBinding](../../../game/presentation/actors/presentation/enemy_presentation_binding.gd) 选择 Underworld 身体。场景基础 Presentation 是独立保留消费者，不能拿它的片段签正式替换后的身体。

| 范围 | 规范及真实入口 |
| --- | --- |
| 身体与移动 | [UnderworldEnemy](../../../game/presentation/actors/underworld_plains/underworld_enemy.gd) 消费实际 Actor、方向和运动状态；当前身体、预告和受伤须保持同一比例／脚锚／材质 |
| 预告／冲锋／恢复 | 蓄势、重心推进与收势对应攻控相位；警告标识辅助身体动作，不代替身体表达 |
| 受伤进入／退出 | 接受回执驱动当前帧资源和反馈组件；连续命中、攻击中受伤及回接活体均保持身份，不以 bbox 一致代签连续性 |
| 死亡／留尸 | 当前 Underworld 受伤／死亡资源由 `assets/enemy_feedback_01/frames_v8/manifest.json` 与实际消费者选择；尸体按 EnemyFeedback01Remains 的真实支撑、Stage 持有和清理规则处理 |
| 声音 | [PlainsEnemyAudio](../../../game/presentation/audio/plains_enemy_audio.gd) 的 shell 材质路由处理接受受伤／死亡；warning 来自攻控事件。音频去重、原图声／许可与混音沿现有服务，不额外复制音量参数 |

表现只消费已接受事件。死亡后重载恢复终态不等于新的击杀，不重播掉落／音效。掉落、任务与击杀奖励归现有 Stage／奖励服务，物种规范不另设保证金额或独立永久状态。

## 接入、保存与验证

正式入口是 [PlainsRegionStage](../../../game/world/levels/providers/plains_region_stage.gd) 的真实放置及 [DemoApp](../../../game/application/demo_app.gd) 的 encounter／接触装配。Lab／Studio 采用各自明确配方，属于开发消费者。不能从资源存在推定所有地图均生成该怪。

区域保存通过 EnemyActor.region_snapshot／restore_instance_health、攻控 restore_region_state 和 Stage 账本维持生命、位置、home、方向、相位时间、冷却与必要攻击字段；恢复不调用整怪 reset 刷新生命。留尸和支撑随原 Stage 表现账本恢复。暂停、卸载、重新进入和 actor epoch 的旧请求不得伤害新角色或重复奖励。

| 验证入口 | 对应要求 |
| --- | --- |
| `python3 tools/harness.py --check enemy-structure-native` | 当前 Registry → Factory → 场景／替换身体链，包括 charger 当前身份、实例隔离和非法覆写拒绝 |
| `python3 tools/harness.py --check enemy-region-state` | 当前对象状态保存／恢复与区域消费者 |
| `python3 tools/harness.py --check enemy-corpse-save --check enemy-corpse-snapshot` | 留尸、支撑及快照边界；按真实依赖运行 |
| 正式代表遭遇与正常速度音画 | 左右／高差、墙／边缘、遮挡／安全点、目标丢失、连续命中、攻击中受伤、死亡到留尸、暂停／卸载／重入 |

上表是验证方法，不是通过声明。全物种内容验收沿 [完成标准](../../quality/enemy_completion_standard.md) 和当前任务证据；未实际复验的视觉连续性、听感、正式遭遇、趣味和设备保持未验证。既有 CHR-VIS／CHR-COV 等发现先在当前身体消费者复现，再据新证据关闭。
