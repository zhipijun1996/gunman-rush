# ENEMY-FEEDBACK-01 · M0 可恢复检查点

工作线 `feature/enemy-feedback-01`，System Engineering；生产基线为 PR103 merge `e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，实际审计/运行源为公共纯调度提交 `0ee0e79197f40e898283440d4af2d956f91f1c64`。本检查点仅增加任务文档与证据，运行代码未改；当前提交用 `git rev-parse HEAD` 读取，避免把提交后文档版本冒称新的运行结果。

采用 animation-vfx / game-quality-gate；没有新敌人或实质行为改动，不扩用 enemy-creator。任务仍 `in_progress`，本轮没有新反馈效果、录像、部署、独审、用户认可或真机结论。完整来源和原始回执见 [M0 原件](evidence/enemy_feedback_01/m0/README.md)。

## 已审计的真实消费者

| 消费者/源行 | 实际作用及边界 |
| --- | --- |
| `scenes/enemies/patrol_drone.tscn:6`；`scripts/demo/demo_stage.gd:54` | 原场景绑定 EnemyPresentation，固定 combat 实例直接保留。 |
| `scripts/demo/generated_demo_stage.gd:168–190` | 正式生成消费者从 PATROL 实例及实际 Definition 构建；diver 等保留 EnemyPresentation；root_bell 在178–185先替换为独立 RootBellPresentation。 |
| `scripts/demo/plains_region_stage.gd:150–151` | 普通平原最后依次执行 PixelFormalActors.install、UnderworldActors.install。 |
| `scripts/art_foundation/pixel_formal_style_installer.gd:7–21`；`scripts/underworld_plains/underworld_actor_installer.gd:6–19` | 删除并 queue_free 旧 Presentation，再安装 Pixel/Underworld。只改旧 EnemyPresentation 不会改到正式平原。 |
| `scripts/underworld_plains/underworld_enemy.gd:1–15`；`scripts/art_foundation/pixel_plains_enemy.gd:1–21`；`scripts/art_foundation/windchime_enemy_visual.gd:1–18` | Underworld→Pixel→Windchime 独立继承链；super ready 的匿名 hurt 订阅与 Underworld 自有 accepted hurt 订阅同时存在。Pixel 控制死亡0.65秒淡出和隐藏，保持只读。 |
| `scripts/presentation/forest_bible_actor_presentation.gd:29–51`；`scripts/demo/demo_app.gd:2320` | 森林 Bible 仅给 charger 装 Underworld，生态怪物有自己的原renderer，不属于这次推广。 |
| `scripts/demo/plains_environment_stage.gd:13–77`；`PlainsRegionStage` 的 regional_art_plan 分支 | 候选空间并非统一执行普通正式安装路径，不把普通平原验证外推到全部候选。 |

原 EnemyPresentation 从 HealthState.changed 触发0.14秒hurt，并根据 terminal 累计 death（`enemy_presentation.gd:14–33`）；Underworld 复用 `resources/damage/feedback.tres` 的hurt_seconds/flash_frequency（`underworld_enemy.gd:4–14,41–47`），现已有受伤变形。复用这些数据与事件，不另造伤害或音频总线。Underworld 自绘没有继承 Pixel 的死亡碎点，仍受父类 alpha/visible 控制；这只是源码观察，尚非画面改善结论。

## 两代表与可证伪样板

1. `resources/enemies/plains_root_bell.tres`：36×40、扎根不移动、0.85/0.16/1.2秒预警/脉冲/恢复；Underworld使用root_bell现有像素。命中做以脚底为锚的短铜壳压缩/回弹，受伤不推动根；致死只启动一次短收束，始终在既有0.65秒隐藏窗口内结束。
2. `resources/enemies/plains_diver.tres`：28×32、空中巡逻/俯冲、0.6/0.35/0.9秒预警/攻击/恢复；保留aerial现有双翼轮廓和flutter。命中做更轻的机身收缩/回弹，致死翅形收拢/短下沉，既有AI位移仍唯一权威。

新组件只维护已接受事件、epoch、hurt/death年龄与可配置的局部姿态参数；公共持续时间/频率从既有反馈Resource读取，不复制默认值。每个renderer自己画材质和轮廓。首先只在上述两个Underworld行为开启样板；旧EnemyPresentation的实际diver/巡逻消费者接同组件作兼容验证。第三套RootBellPresentation保持只读，不能称同两代表在所有旧renderer统一完成。

可观察目标：真实弹体击中后仅一次hurt/致死演出，短回弹后恢复原AI姿态；RootBell脚底稳定、diver双翼/俯冲节奏仍可辨识；死亡不改变掉落产生时刻。闪光不得遮住预警/落点。不满足任一项即REWORK，不能仅因计数通过签视觉。

## 已接受事件与生命周期边界

| 边界 | 已有真实合同 / M1必须证明 |
| --- | --- |
| 命中/落空/拒绝 | `Damageable.receive_damage:36–63` 校验event/actor/epoch/faction；`FrameDamagePolicy:53–69,79–129`批处理真实HP并在结算后发damaged。表现仅响应changed中的APPLIED、operation=damage、amount<0、当前health epoch；REPLAY accepted()不能当新命中。落空/接触拒绝无hurt。 |
| 受伤与致死 | `ActorResourceState:28–35,45–62`初始化发APPLIED initialize，不能演死亡；真实致死damage一次death，非致死一次hurt。致死优先，不能同时叠一次非致死hurt。 |
| 死亡/奖励幂等 | `Damageable:88–98` terminal信号带_death_emitted守门；`EnemyActor:74–81`负责停止/碰撞/defeated；`DemoApp:911–933`和`EnemyDropService:41–59`持有掉落幂等。组件绝不发defeated、结算掉落或改HP。须用原正式奖励消费者复验，M0未签两代表掉落。 |
| 暂停/慢时 | 正式Stage/Actor PAUSABLE，delta随原引擎时钟；组件在宿主_process推进，暂停不推进/排队补播；不调用time_scale。不用手动_process模拟正式暂停证据。 |
| 卸载/安装器替换 | 停止处理并清空组件、断开自有订阅；无孤立Tween/timer/音频/粒子或异步回调。旧renderer detach后不得对新节点演出。 |
| 旧epoch/重置 | Policy拒绝旧run/stage/actor，HealthState拒绝旧health/instance；组件看到initialize/epoch变化立即清hurt/death，不补播旧事件。不另改Policy。 |
| 恢复死体 | `EnemyActor.restore_instance_health:100–107`以initialize恢复，并压住重复enemy_defeat音；平原`plains_region_stage.gd:41–53`隐藏已死motor。组件初始terminal或initialize terminal只静态终态，不演新death，不清掉落收据、不把motor show回来。 |

## 实际验证及未验

`python3 tools/cloud_inputs.py --check underworld-damage-feedback --output build/enemy-feedback-01/m0-input-plan.json`：exit0、ready、0缺件，仅表示该原check输入可用。

获总控本地headless/import窗口后实际执行：`source /workspace/worklines/enemy-feedback-01-env.sh`，然后 `python3 tools/harness.py --check underworld-damage-feedback --release --jobs 1`。exit0，Godot4.7.2，317断言/0失败，check4.551秒、整轮6.048秒。原timeout180/inner120未改，原定义/断言未改；完成已释放租约。原件 `build/verification/harness/20261022T125012.811711Z/`，portable副本见证据目录。

此检查包含原Underworld巡逻怪的真实Router→Shoot→弹体→HP→hurt及重复拒绝；另含旧EnemyPresentation的地面sentry/空中diver真实弹体边缘案例。没有运行正式两张地图、两新代表的death、GPU画面、声音听审、用户手感、真机、完整CI。未进行影片；没有before，不能称已做同条件比较。原生baseline没有失败，源码静态gap不是已复现的运行失败。

质量元数据初版实际REJECT：criteria缺原schema要求的场景/方法/预期/失败/gate/dimension及creative_decision的basis；现按原schema修正，不改玩法。修后单卡`quality.py check` exit0、errors=[]、UNVERIFIED。另实际`python3 tools/check_quality.py` exit1：本线稀疏缺历史证据（1195行），原件`global-quality-sparse.log`保留；不扩取全历史或签全局通过。

## 冻结复现条件与下一命令

原baseline命令/运行源/完整输入指纹已冻结在回执；原生固定60FPS、Dummy音频，夹具坐标与初始Definition均以source-inventory绑定源码为准。这个headless原件不冒称录像。

M1先在**反馈实现之前**完成任务驱动、采baseline短片，再在同驱动/Seed/输入/镜头/分辨率/出生条件上改反馈。拟正常速度1280×720/60FPS，root Seed `enemy-feedback-01-m1`；Underworld root_bell/diver加旧链diver/巡逻分别单独片段；初始摆放明确fixture，之后仅真实Router/Input发射和物理弹体命中，AI持续运行，不传送、不注入资源、不直接调用反馈或receive_damage冒充战斗。等待真实ready/assembly；每次关联shot id→damage event/HP→姿态→death和录像frame/time。驱动具体输入序列/Manifest必须在首次baseline前冻结；目前未实现，不伪造精确tick或命中帧。正式stage消费者另跑原check，不把fixture称自然地图路线。

M0写集：本文件、`docs/quality/records/ENEMY-FEEDBACK-01.json`、`docs/evidence/enemy_feedback_01/m0/`。后继自有renderer为`enemy_presentation.gd`、`underworld_enemy.gd`及自身UID；总控已允许新增 `scripts/enemies/enemy_feedback_01_state.gd(+uid)`、`tests/enemy_feedback_01/`、`tools/run_enemy_feedback_01_tests.py`、`tools/capture_enemy_feedback_01.py`。不改Actor/Definition/ForestBibleActors/父类/共享音频材质/正式场景/Harness/config/中央状态。

现无共享接口请求；与主角线共用APPLIED damage/epoch与既有反馈Resource合同。若需要改变父类0.65隐藏、共享材质或新信号，先向总控给精确路径/签名/消费者影响。总控已明确允许两Underworld代表+旧链兼容范围，第三RootBell链保持不推广。

恢复：先 `git status --short`、`git rev-parse HEAD`、核本证据inventory；读本树最新AGENTS和这份检查点，source专属env。nextcmd（只计划、不运行引擎）：`python3 tools/production_plan.py --stage development --base origin/main`。下一动作是实现自有真实弹体采证驱动并向总控申请短GPU/录屏窗口；不创建PR、不跑完整CI、不合main、不部署。
