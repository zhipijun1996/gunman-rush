# ENEMY-FEEDBACK-01 · System Engineering

## 检查点 1：复用与代表对象

基线 `origin/main e9ab0e0743466b8983e34cc7de17bab1abf9d53a`（PR103实际合并），独立分支 `feature/enemy-feedback-01`，工作区 `/workspace/gunman-rush-work`。任务类型 animation；采用 animation-vfx、game-quality-gate，未扩展行为，因此不触发 enemy-creator。

选择 `resources/enemies/plains_charger.tres`（plains_charger，地面冲锋）与 `resources/enemies/plains_diver.tres`（plains_diver，空中俯冲）。两者现有碰撞均28×32；选择依据是不同支撑/运动方式和现有身体轮廓，不冒称尺寸差异，不改Definition。地面保持脚底锚与冲锋节拍，空中保留flutter/lean与俯冲预告；分别用较宽的压缩和较轻的纵向反应。

| 已有系统 | 复用结论 |
| --- | --- |
| PlayerProjectile → Damageable → FrameDamagePolicy → HealthState.changed | 正式命中入口；仅APPLIED、damage、负增量、当前health epoch与唯一event_id驱动样板。接触火花不能作为HP已接受证明。无需新信号。 |
| EnemyPresentation | 旧消费者保留；选中两种接共享状态，其他继续原反馈；已有动作帧/材质/预告保留。 |
| UnderworldActorInstaller → UnderworldEnemy → PixelPlainsEnemy → WindchimeEnemyVisual | 正式安装器移除旧Presentation，因此必须独立接入；选中实例不再安装Windchime匿名受伤监听，避免两套计时并行。 |
| ForestBibleActors.install | 森林保留的plains_charger也会经UnderworldEnemy消费同组件；没有新增第三物种，仍须在完整Integration覆盖森林该消费者，不能只看平原。 |
| PixelPlainsEnemy._death / visible / modulate.a | 父类独占、只读；不重置或改写。新死亡姿态在原0.65s淡出内结束。 |
| EnemyActor / Damageable.died / GameAudio | 原死亡/击伤声音和击退保持；组件不发声、不发defeated、不驱动AI或伤害。 |
| DemoApp._settle_enemy_drops / EnemyDropService | 原奖励所有者继续结算；组件不创建掉落。验证幂等，不改奖励。 |
| HealthState initialize / restore_instance_health | 清空短时表现；terminal初始化为恢复死体，不演出新死亡。已死亡身体恢复时不绘制短时粒子/动作。 |

修订：检查点初选的graybox_patrol_drone仅在旧场景，不在默认正式生成池。正式池审计后改为plains_charger，确保两个对象都具备默认地图消费者。旧巡逻组合154断言0失败只保留为历史定位证据，不移签最终组合。

## 写集与所有权

仅修改 enemy_presentation.gd / underworld_enemy.gd（现有UID保持），新增 enemy_feedback_01.gd 及其UID、任务专属测试/录屏驱动、本文、docs/evidence/enemy_feedback_01 与本任务质量记录。EnemyActor、Definition、ForestBibleActors、共享材质、音频、父类、正式场景、Harness、中央任务/状态/交接均归总控只读。本文件兼任务交接，不并改中央文件。

## 状态、锚点与时间轴

- 正式非致死命中：组件在health提交信号当帧设置hurt_remaining；持续时间直接读既有feedback.tres。ground压缩与aerial拉伸经平方衰减归一，保留原AI动作层。没有额外stagger/force。
- 致死命中优先：停止hurt，死亡计数仅一次；地面压扁、空中收拢及轻倾。旧表现短时mote沿原绘制；正式表现沿父类下沉/0.65s淡出。组件0.5s后结束，不生成节点/粒子/Timer/Tween。
- 暂停不推进；慢时消费现有delta，不改time_scale。initialize清除hurt/death和当前epoch去重集，恢复死体不产生新事件。
- uninstall/_exit_tree显式disconnect并dispose，移除旧表现后不留signal持有RefCounted；无异步回调跨场景。
- 父类已有同实例死后reset活体仍隐藏的限制不在本线改动范围；若要求该路径，先由总控分配父类可见性/计时接口，不能偷偷重置。

## 可证伪验收与阶段

| 场景 | 方法 | 失败条件 |
| --- | --- | --- |
| 两对象×两继承链正式受击/死亡 | 原Router发射真实弹体、原碰撞/帧伤害提交，记录HP/事件/表现 | 无HP提交却反馈，漏一继承链，非致死和致死重复计数 |
| 重播/无效/旧epoch | 将真实命中context重试、失效target epoch与旧stage token反例 | 新hurt/death/audio/drop或HP变化 |
| 暂停/恢复/慢时 | 中断hurt/death并观察时钟、恢复自然消退 | 暂停推进、恢复重复开始 |
| 恢复死体/卸载/重装 | 正式恢复接口、安装器替换和weakref释放 | 新死亡演出、旧signal残留、掉落重结算 |
| 非样板消费者 | 原underworld反馈专项与正式消费者回归 | 不相关物种变化或shared母版漂移 |

先Development专项定位；新组件/driver不在影响映射中会按原planner升级full，保留该计划，不自行缩减或改配置。合入前完整Integration由总控安排；本线不合main。G2交真实正常速度、真实音轨、同输入/镜头/分辨率before/after MP4，定位fixture明确标注，不冒称自然路线。当前只是可观察反馈，不新增可操作机制，按用户交付条件优先短片；用户要求操作后补独立Preview。AI审查、用户视觉/手感认可和真机分别记录。

## 当前恢复点

任务版本 candidate-v1；已完成复用盘点与选择。实现、原生验证、媒体和独审仍进行中。质量记录 `docs/quality/records/ENEMY-FEEDBACK-01.json`；原失败与证据放 `build/enemy-feedback-01/`，精选归档到任务证据目录。工具链初始系统Godot4.6.3不符，已用仓库setup安装锁定4.7.2，未放宽检查。
