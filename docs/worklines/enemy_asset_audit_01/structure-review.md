# 全怪物程序结构独立盘点与最小统一方案（讨论稿）

2026-10-29；只读审查 `/root/enemy_review`。读取时HEAD：`9b76f0044f0fe4d729f2bc894abf153a4f238564`。没有修改源码／skills，没有运行Godot，没有签新视觉／行为通过。本报告响应“所有怪物整理并统一程序结构”，同时保留“先不要批量做，先发现问题”；方案尚未冻结。

## 结论

现有工程已经统一了伤害资源和一部分实体／行为基础，但**没有统一从真实行为到最终身体表现的明确边界**。目前最需要统一的是身份绑定、可读表现状态、安装与生命周期的接口，而非把所有怪物合进一个基类或强制相同动作。程序结构统一不能解决本轮已被用户拒绝的美术／动作质量，也不构成继续批量扩产的依据。

实际Boss库存须说准：8个Boss场景对应7个不同Encounter脚本（含`BossEncounter`基类）；`extends`链中有6个派生类。旧guardian与旧queen共用`ThornForestEncounter`，不是两个独立子类。7个Boss表现脚本与7个Encounter脚本也不是逐个同名对应。

## 现在已统一、还未统一、必须保留什么

| 层 | 现在已统一 | 还未统一 | 必须保留的差异 |
|---|---|---|---|
| 伤害与生命 | 普通/Boss使用`HealthState`、`Damageable`、实际资源结果；`EnemyHitTemplate.install/install_boss`共用接受反馈 | 各表现层另接health、局部hurt/death时钟；恢复／取消语义分散 | 护甲、弱侧、普通躯体、反铃与技能结果仍由真实Policy／Damageable决定 |
| 普通实体 | `EnemyActor`持definition/motor/brain/health，统一reset、死亡停机、绑定与恢复入口 | 基类attack中混有多物种算法；行为选择散在Actor、Definition与表现里 | 地面承重、悬挂、轨道、飞行、绕过／接触巡逻不同；不可统一为同一移动／攻击周期 |
| Boss实体 | `BossEncounter`提供health、arena、activate/cancel/defeated/projectile/phase信号；子类共享部分场地及伤害管线 | 各代状态名、计时、目标与阶段字段、双实体／网场所有权、保存schema不同 | 真实阶段、Bell与Body并行、活结／网带持有、弱点、碰撞、原奖励与终态政策 |
| 表现 | 大多保持表现只读玩法；已有Plains/Forest/Boss motion helper及公共hit模板 | 资源／外观选择、clock接口、renderer安装、最终可见分支与能力查询不一致 | 逐帧、骨骼、单图形变、刚性机械件可并存；不同物种动作设计与素材不可统一成一套摆动 |
| 世界接入 | 现有installer与Manifest可指向具体原实例 | style靠祖先metadata，普通换节点、Boss切分支、森林按精确尺寸／stable_id选择 | 地区皮肤、旧scene/正式profile、合法保存及当前历史准入须显式保留 |

## 五个优先问题：证据与最小责任切分

### S1 高：外观身份由运动字段及祖先环境隐式推断

证据：`EnemyDefinition.aerial`既参与Motor／击退语义，又参与选图。`resources/enemies/plains_fan_sentry.tres:20`为true；`enemy_presentation.gd:142–146`直接画actors.png区域，绕过`:149–150`动作分支；`underworld_enemy.gd:143`同一物种优先选aerial.png。旧卡写同sentry母版却不成立。`ForestBibleActors.active`（`scripts/presentation/forest_bible_actor_presentation.gd:88`）又沿祖先meta决定皮肤；`draw_enemy_body`在stable_id和collision_size精确匹配后才画fine身体，否则fallback。

影响：物理属性、安装环境、资源选择和动作路径纠缠；仅看species或helper无法知道最终身体，未来改aerial或尺寸可能意外换皮／绕开动作。它已经造成资料事实错误，不只是命名问题。

最小切分：让实际安装上下文明确解析“species/definition版本＋presentation profile＋renderer资源＋动作方案＋锚/尺寸＋适用能力”，输出一份最终绑定。`aerial`继续归运动，不再作为唯一美术ID。不要为选中想要的图改aerial或collision_size；尺寸/身份guard不能直接删除，应改成绑定一致性校验及明确失败原因。fallback的保留／拒绝需显式决定，不静默掉回另一身体。

### S2 高：共享motion helper正在承担跨物种状态翻译，缺只读表现协议

证据：`PlainsMotion02.advance:49–53`读取behavior.state/state_time及Definition通用时长，state_time向上累计；`ForestMotion02.advance:81–85`另列hold/turn/extend/travel/swing/flight等字符串集合。`BossMotionPresentation.sample:73–99`按Windkeeper、ThornForest、QueenV2、Canopy具体类型逐层特判，读取clock/motion_clock并各取不同duration，`:104`还以字符串后缀warning/preview识别预警。Boss实际clock多为递减；普通state_time递增，不能只统一字段名。

基类`BossEncounter.phases.phase`与派生`stage_phase`并非处处同一权威：`bellstrider_encounter.gd:33`直接写stage_phase，`rootbell_guardian_v2.gd:55–59`也写stage_phase并发信号；原helper靠特判读取才得到实际阶段。这说明消费者不能盲读基类字段，不能据此直接判玩法BUG或补写phase来迎合美术。

最小切分：在行为与表现之间增加有版本、只读、可核对的“表现状态快照”适配。保留raw state/真实阶段/实际模式序号；明确相位进度、warning/commit/recovery是否有效、position/facing及epoch。特殊并行轨道和附件通过独立能力字段或小接口提供。由各实际算法/适配器解释自己的clock，helper只消费快照，不再扩张类型switch。不能用一个0..1进度抹掉Rootbell并行铃与身体，也不能伪造原玩法不存在的恢复态。

### S3 高：renderer直接读取Encounter内部实现字段，正式提示与私有节点绑死

证据：`thorn_queen_weave_presentation.gd:25`读`_weave_bound`；`forest_boss_duel_presentation_v2.gd:55–56/120–122`读`_bell`实例和位置；`windkeeper_presentation.gd:162–163`读`_platform_piers/_floor_y`，`:212`读`_locked_aim`。相同Boss公共接口已存在`core_offset()`、`body_contact_enabled()`等，说明并非完全无接口，只是覆盖不完整。

影响：行为内存布局／内部所有者调整会直接破坏实际预警或附件；看似仅重构名字也可能改画面。renderer知道节点寿命，易把不存在／旧epoch附件当当前状态。这里是已证实的耦合，尚未宣称当前每处都发生错误。

最小切分：为真实需要暴露的提示提供窄只读查询，如当前锁定点（带valid）、真实铃的展示快照（位置/状态/所有者epoch）、迁移路径及可用性。表现不持有可写Boss节点，不访问私有字段；各能力可不适用。预警几何仍来自真实Encounter，不能把绘图bbox／视觉骨架当伤害权威，也不要把所有特殊字段塞进巨型公共字典。

### S4 中高：表现生命周期与多套时钟重复，当前接线合同不一致

证据：`enemy_presentation.gd:25–51`charger/diver独立创建Feedback01/Body/Particles/Remains，其他怪走HitTemplate；`:66–90`又管理host _clock、_death_time、body_motion及sample；`ForestMotion02`经canvas metadata安装和静态draw找实例（`:30–35/87–90`），initialize靠各host接health（如`forest_feedback_enemy_presentation.gd:7–21`）。`BossMotionPresentation`自己bind/dispose health与projectile（`:23–57`）；prototype又另写epoch、stride、hurt及终态同步（`prototype_enemy_presentation.gd:67–95`）。三helper各自缓存网格、计算位移与保守裁剪。

影响：同一种暂停初始化／恢复为终态需求散在多处，之前R1已因此返工；统一接口前不该直接复制第四套。多时钟本身未必错误，但谁推进、谁重置、谁释放必须明确。

最小切分：统一窄生命周期入口（bind、sample/sync、reset-for-epoch、dispose）和所有权说明；一个宿主只推进它拥有的表现时钟一次。公共数学/可见性/mesh上传可在真正相同时抽小工具；各物种pose生成和死亡政策仍独立。尸体在Stage兄弟持有是合理差异，不能为统一让它随Motor隐藏或统一淡出。公共hurt模板与具体身体响应须分层，防止双重advance／重复信号。

### S5 中：行为创建、算法与配置验证多点登记，基类同时扮演具体策略

证据：`EnemyActor.bind_encounter:85–94`按behavior_id工厂match；`EnemyAttackBehavior.advance:45–88`内部还包含diver环绕、charger冲刺、hopper抛物线、sentry/fan三弹和回巢算法；`EnemyDefinition.is_valid:29–33`含基础行为白名单；`ForestEnemyDefinition.is_valid:25–40`又不调用super，重做共有字段检查并增加专属白名单。`EnemyAttackBehavior._can_engage:96–104`还依赖父节点遍历、节点名Actor和同伴私有`_active()`来算并发。

影响：新增一个行为要同时理解多处分发、验证及调用约定；公共校验易漂移，世界树形状影响并发。该结构有真实历史兼容原因，不能因“不够统一”现在批量拆AI。

最小切分：先登记单一有限的behavior→配置类型→创建者映射及实际消费者；拆共有配置验证与专属验证的函数职责。随后若确需重构，可让基类保有配置／取消／生命周期合同，各运动算法为具体策略；并发由场地拥有的已注册参与者查询。不要先引入通用行为树、全局怪物服务或反射动态插件系统。现有精确AI时序与合法策略必须在单怪迁移时逐项对照，而非靠更多新测试数量替代。

## 两个可选结构方案（供讨论）

### A：先统一边界，保留现有实体与算法（较小范围）

`原EnemyActor/BossEncounter/具体行为 → 小型只读适配器 → 表现状态快照 → 物种renderer/动作实现`

另由现有stage安装入口解析明确的presentation绑定，校验唯一宿主、实际profile与资源路径。生命周期按同一约定接入，但不立即更换内部类继承；特殊提示/附件是窄能力，普通未拥有的能力不可伪造默认有效值。

优点：可先拿fan_sentry两条实际链或另一只黄金怪验证“绑定事实可追踪”；对原AI、伤害、存档与场地侵入最小。风险：适配器若只是把当前大switch搬家，仍会成为新的God类；需按具体家族/行为隔离，输出范围有限。快照采样必须注明physics/process/postdraw相位，否则会创造一帧延迟。readonly需实际阻断写回，不能只靠注释。统一快照不是动作素材，不解决质量拒绝。

### B：在A验证后，再收敛组件结构（范围较大）

普通与Boss各保留自己的协调器，把公共生命/生命周期合同与具体行为策略、运动、场地特殊对象、表现拆为组合；例如Bellstrider从Windkeeper继承只为共用管线（源码第3行已明示）可在未来用组合表达。但不要求所有Boss立刻平铺，普通怪也不强制与Boss共用Actor。

优点：长期可减少具体算法被继承进无关怪、降低基类分支。风险：改变ready/bind/信号顺序、取消与保存schema、场地节点、contact/weakpoint权威；回归成本高且容易顺便改玩法。现阶段不建议全体迁移；必须先完成库存和A的一个小样，用户共同确定价值后再选范围。

## 这轮应交付的结构盘点字段与复核要点

每条实际链至少列：稳定ID、Definition/profile、Motor/Actor/Behavior或Encounter具体类型、安装者与最终renderer分支、身体源/动作方法、hurt与terminal所有者、时钟／epoch推进者、特殊对象／预警数据来源、保存与卸载所有者、正式/候选/历史准入。普通物种库存不能吞并不同渲染链，Boss场景也不能吞并不同Definition。

先使这份事实表与代码相符，暴露缺字段和隐式分支，再共同决定统一边界。以后若实施单怪样板，复核至少包括：最终画的是声明的renderer与资源；接受事件不重播；暂停restore终态不重演；特殊提示仍读真实机制；卸载无悬挂引用；原AI轨迹/HP/攻击时序/奖励/存档未因画面而变。正常速度成品质量另审，结构清洁与测试通过不代签美术／动画。此处是方案验收方向，不是已经执行或已经冻结的新检查集合。
