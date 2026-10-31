# Boss程序结构只读盘点

快照 `9b76f0044f0fe4d729f2bc894abf153a4f238564`，8场景/9Definition组合（默认Windkeeper与Storm同scene）。只写/tmp，未改源码/测试/配置/流程，未跑Godot，未宣称已统一。

现有共同点是节点骨架和资源事务：每场景都是Motor根CharacterBody2D、CollisionShape2D、Damageable、Encounter、Presentation；Health统一继承BossEncounter.health。和普通EnemyActor相比，共有Definition/Health/Damageable/accepted事件，但决策、运动、目标绑定和保存生命周期接口不同。

| Boss组合 | 控制/phase/运动 | 额外绑定与恢复 |
|---|---|---|
| Clockwork | BossEncounter；phases/pattern；水平BossMotor | configure_arena绑定Node2D目标；无统一combat snapshot/restore |
| Bellstrider | Bell→Wind→Boss；stage_phase+mode/clock；roll水平移动 | 继承BellCore/风桥绑定管线；扩父snapshot，stage逐字段恢复 |
| Windkeeper默认/Storm | 同Encounter；stage_phase三阶段+mode/clock；默认窗口与Storm连续可伤 | configure_arena加bind_stage_geometry/controller/policy/life/segment；断桥/风/符文专管线 |
| 旧Guardian/旧Queen | ThornForest→Boss；stage_phase+mode/clock；rooted本体+seed | session目标守门；旧restore清旧弹/锁点并回observe |
| Rootbell V2 | Rootbell→ThornForest→Boss；stage_phase+mode/clock；ForestBossMotor弹道sweep | bind_duel+controller/policy/life/geometry；独立Bell、flight token、同帧counter pending；严格专snapshot |
| Weave Queen | ThornQueenV2→ThornForest→Boss；网络stage_phase、路线route_phase、motion_mode/clock三轴；路径Motor | 3Knot/Band持续fields；schema13；支持重绑新玩家碰撞exception |
| Canopy Queen | Canopy→ThornForest→Boss；网场stage_phase、motion_mode/clock与section/leg；路径Motor | 2Knot/Band/真实锁岸；schema1；geometry重建比对后恢复 |

主要问题（均为静态结构事实/迁移风险，不冒称运行Bug）：

1. phase/state/clock多种表示并存。Clockwork用phases.phase，多个派生另写stage_phase；Rootbell/Bell/Wind没有按同一路径同步phases；Weave还有不能被合并的route_phase。
2. 复用继承带入不适用字段：Bell继承Windkeeper，Rootbell继承旧seed/弱侧，Canopy Definition继承旧Weave；父字段存在不能当行为存在。
3. 目标与上下文绑定分散：Node2D _target、多个controller、life/policy、arena/geometry/segment分开；Rootbell重绑要求同controller，Queens允许换玩家并管理collision exception。
4. restore被Stage/App/Encounter共同完成，旧restore回observe、现代保路径/fields，返回方式也不同。必须保schema/ready顺序与旧目标失效。
5. cancel_pending、cancel和menu pause语义不同：Weave pending仅epoch++，Canopy pending暂停field；Rootbell terminal有意保counter pending等同帧Policy结算。
6. Presentation读具体类和_bell/_weave_bound等私有字段，共享sampler按类型猜mode语义；接口共享不等于职责已解耦。
7. 原终态政策/leaf fade clock仍各自存在；共有health initialize处理不等于所有视觉clock和清理已统一。

另有初始化顺序差异：Boss先bind_health再订阅died，普通Actor先订阅再reset；bind_health会同步发出当前terminal状态。统一前须分别验证cold terminal、post-ready恢复、暂停恢复与新致死，不能只测一条路径。

最小统一方向：先做不改机制的adapter协议，统一只读identity+capabilities、CombatContext绑定结果、实际状态/phase轴/时钟域/锚点视图、accepted与initialize消息语义、带reason/scope的cancel/restore/detach；保现有各Encounter/存档validator/运动command。VFX或表现不得成为判定owner。App入场/shot资格/FrameDamagePolicy/奖励账本保持原唯一协调者。

不能把Boss硬并普通AI：EnemyActor默认身体加入grapple_target、普通accepted hurt附加stun/knockback、reset回出生点并重配health；这会把Boss身体错误变活锚、打断迁移/窗口、清掉持续fields或刷重置。Boss需要独立Bell/Knot/网场/断桥与多轴phase，普通brain+EnemyIntent不能原样替代。

完整逐scene节点路径、类链、真实调用/行号、13项不一致证据、最小协议与迁移风险见 `structure-boss.json`。本报告没有执行迁移或签署统一完成。
