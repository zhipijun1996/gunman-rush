# 森林7种＋2候选程序结构审计

只读版本 `9b76f0044f0fe4d729f2bc894abf153a4f238564`。未改仓库/skills，未运行Godot。H/D在本文指受伤/死亡；不同结构不自动等于缺陷。

| 对象 | 真实Definition / Behavior | Presentation继承 | 专有bind/cancel/终态 |
|---|---|---|---|
| forest_lantern | EnemyDefinition / ForestLanternBehavior→EnemyAttackBehavior | ForestEnemyPresentation→Node2D | retained same-body dark terminal in local presenter |
| forest_seed_sentry | EnemyDefinition / ForestSeedSentryBehavior→EnemyAttackBehavior | ForestEnemyPresentation→Node2D | retained same-body dark terminal in local presenter |
| forest_bark_beetle | ForestEnemyDefinition / ForestBarkBeetleBehavior→EnemyAttackBehavior | unnamed Node2D script→Node2D | 0.38s procedural settle then presenter stops drawing |
| forest_swing_pod | ForestEnemyDefinition / ForestSwingPodBehavior→EnemyAttackBehavior | unnamed Node2D script→Node2D | 0.38s procedural settle then presenter stops drawing |
| forest_crossbranch | ForestEnemyDefinition / ForestCrossbranchBehavior→EnemyAttackBehavior | unnamed Node2D script→Node2D | 0.38s procedural settle then presenter stops drawing |
| forest_thread_spider | ForestEnemyDefinition / ForestThreadSpiderBehavior→EnemyAttackBehavior | ForestDepthEnemyPresentation→Node2D | retained same-body dark terminal in local presenter |
| forest_bible_weaver | ForestBibleWeaverDefinition / ForestBibleWeaverBehavior→ForestThreadSpiderBehavior | ForestDepthEnemyPresentation→Node2D | retained same-body dark terminal in local presenter |
| candidate_lure_guard | runtime duplicate of EnemyDefinition/plains_charger / EnemyAttackBehavior→Node | PrototypeEnemyPresentation→EnemyPresentation | same canonical crop joint death then .6s fade; no dedicated remains component for this ID |
| candidate_crosswind_moth | runtime duplicate of EnemyDefinition/plains_sentry / PrototypeMothBehavior→EnemyAttackBehavior | PrototypeEnemyPresentation→EnemyPresentation | same canonical crop joint death then .6s fade; no dedicated remains component for this ID |

共同底层确实已存在：九者使用EnemyActor、EnemyMotor、HealthState及Damageable接受事件；七森林的Behavior均沿实际EnemyAttackBehavior家族，双入口蛛再继承有限线蛛。四森林Presentation直接继承Node2D，两候选继承EnemyPresentation，不能把它们写成同一个现成表现基类。

优先发现的具体问题：

1. **候选factory实际配置漂移**：ModuleLab的moth速度45、半宽120；Studio复制速度0的plains_sentry且未覆写速度，半宽100。同stable_id的运动输入已不同（JSON F01列源码行）。
2. **生命周期重复与无效父层工作**：四森林脚本复制install/initialize/paused advance/disconnect；Prototype同时执行父类PlainsMotion02、重心/姿态权重计算和自己的网格采样，子类绘制不使用父类这些计算。父子还各自处理health初始化和死亡时钟。
3. **恢复事务分散**：Stage先发health.initialize，再写saved position；App后续才写saved behavior/facing，而ForestMotion的即时epoch同步已采过位置/方向。这里是有源码顺序依据的暂停/首帧风险，本次没有运行复现，不把风险写成已证实画面故障。
4. **隐式meta和耦合**：祖先forest_bible_actor_art＋layout版本及身份/碰撞白名单决定PNG还是几何fallback；Body/Motion/HitTemplate间再用meta寻址；荚柄另持host/actor实例字典。Prototype.moth由factory索引布尔值选择图和动作，不由Definition声明。
5. **死亡所有权不止一层**：HealthState判HP终态，Actor停行为/碰撞并发defeated；Presentation持.38/.6秒或暗体；Stage保存行为并在terminal恢复时hide Motor。局部暗体保留不等于重入可见留尸。
6. **状态名不是统一语义**：swing/turn是接锚相位，hold才是蛛线伤害期，crossbranch保留多种真实跌落恢复。现在表现用原始StringName分组采样，不能强制全部套idle/telegraph/attack/recovery。
7. **接口顺序与重复登记**：Definition三层各有行为白名单，Actor match、Stage scene map、Body map均需维护；Actor已有behavior就拒绝bind，而候选手建behavior。表现没有显式bind/unbind协议，现依赖_ready/_exit_tree和单次组装假设。
8. **拒绝事件协议也不同**：候选盾在基础epoch/event验证前播放armour并return；森林盾先有身份/epoch/guarded-event处理后发shield_contact。共享反馈不能抹平accepted、有效blocked、invalid/stale的区别。

应保留的专有部分：两岸飞行与真实支撑恢复、悬荚连续摆相及挂点、有限蛛线/双入口时序、甲虫方向盾和真实脚探测、棘籽弹体/落区、蛾的双轮锁线，以及各自终态政策。特别是Swing.cancel保相、Cross.cancel保真实跌落、Spider.cancel清线token，不能直接替换成基类统一recovery。

最小统一建议只是待讨论契约：先统一构建输入和单一候选参数来源；明确bind(context)／暂停也立即on_initialize／每帧一次advance(read-only snapshot)／幂等unbind；快照保raw_phase、elapsed和可选progress、真实运动/朝向/承诺方向、接受回执、typed锚与epoch；明确完整restore完成边界；把终态及保存/清理所有者登记清楚。各现有类可适配这个契约，无需先改变真实继承或重写所有AI。draw可更新渲染cache，但不能推进玩法或时间；离屏只裁网格，不裁接受事件/相位。结构统一本身不签美术质量。

逐怪bind/initialize/pause/advance/unbind/terminal和12项问题的真实文件/行号、分类与风险见 `structure-forest.json`。
