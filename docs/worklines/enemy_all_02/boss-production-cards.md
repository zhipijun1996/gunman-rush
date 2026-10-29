# ENEMY-ALL-02：现有 Boss 连续性制作卡

状态：首版表现已实现，等待当前源码的 Godot 编译、真实场景连续采证和导演复核。本文不签署 G5、美术通过、设备通过或用户认可。基线 `20e67867b272a7e461eddce169a0cdb83353f4b6`，本轮工作分支 `feature/enemy-completion-02`；最终录制应绑定 root 冻结后的提交与源合同。

## 完成标准与本轮边界

每个实际场景需连续展示观察／移动、真实预警、攻击承诺、受伤、恢复当前状态、死亡及原终态。动作必须可在正常速度辨认，原身体、纹理和关节连续，死亡优先于受伤；真实弱点、HP、警示、投射物、运动路径均由原逻辑拥有。完整战斗及原机制守门与导演录像是不同证据，不能用局部姿势截图替代。

本轮只改 Boss presentation 叶并新增纯表现 `BossMotionPresentation`。它读取实际模式、剩余时间、阶段、Motor 位移，监听 `HealthState.changed` 的同 epoch `damage/APPLIED` 与真实 `projectile_created`；不写 Actor、AI、Definition、判定、HP、奖励、存档或生成。受伤形变是身体反应，不新增硬直。终态不统一改为普通怪留尸政策。

精细身体沿用原图，使用共享顶点 UV 网格驱动头冠、左右肩肘、腿链／悬挂。单身体使用一个缓存 `ArrayMesh` 和一次 `draw_mesh`；UV 与 indices 缓存，当前顶点更新后重建同一 surface，并明确nearest采样。默认姿态不换图、不裁掉身体，不以每格独立变换制造接缝。外部 weakpoint、HP、轨迹与标记继续在原位置绘制；胸心区域另有局部形变锁定。

R2发现三个旧Boss仍为灰盒，E03不足，故v3将旧Guardian、旧Queen与Weave复用森林既有fine32身份母版，原PNG字节不改。Guardian1×固定脚48；旧Queen2×统一整数比例固定脚48，原画心低亮覆盖，真实弱侧仍由原唯一UI提示；Weave1×保持与Canopy同族悬浮基准。判定与预警不跟身体图像伸缩。旧灰盒影片保留为失败，v3必须新录，不能用首轮动作通过补签美术。

## 场景制作卡

| 场景／身体 | 真实输入与连续动作 | 恢复与原终态 | 必须采证 |
| --- | --- | --- | --- |
| `clockwork_guardian.tscn`／原 `boss_phase_1/2` 画页 | `pattern.telegraphing/warning_progress` 驱动肩臂蓄势；真实 `projectile_created` 驱动发射发力，Motor 实际移动驱动腿部；既有阶段画页保留；accepted damage 触发短促反向身体反应 | 发射后的身体收回是表现尾随，不能称新增战斗冷却；终态保留原 `boss_dead` 画页及原至少 `.18` alpha 的保留表现 | 预警中受伤→仍完成实际发射；移动中受伤；阶段 1／2 真投射物；死亡原终态 |
| `windkeeper.tscn`／正式 Underworld 精细机械体；原绘制分支仍保留 | 正式安装器通常绑定 `windkeeper_storm.tres`，默认场景资源与正式 profile 分别记录。`stomp/charge/blade/pier` 的实际 warning 与原剩余时间驱动蓄势；真实移动驱动腿链；实际攻击模式、真实弹体驱动发力；转子仍在原 hub，`blade_angle` 仍属 encounter | `neck/back/pier_open/final_hold` 驱动肩臂收回；受伤退出跟随当时真实模式；Underworld 终态为局部收拢和材质暗化，原父级卸载／奖励逻辑保留；原 painted／pixel 的已有终态策略不重写 | 正式 profile 的各攻击、恢复、阶段差异；默认 profile 的合法窗口另列；冲锋中受伤；转子与实际伤害范围；终态尾段 |
| `bellstrider.tscn`／正式 Underworld 精细轮式机械体 | `roll_warning/ring_warning/lob_warning` 的实际 clock 驱动悬挂压载和冠架蓄势；车轮 spoke 仍由实际位移计算；`roll/rings/lob` 与每次真实投射物驱动回弹，第二轮真实 volley 同样触发；核心由原 `core_offset()` 单独绘制 | `neck` 散热收势；accepted damage 反作用退出回实际 roll／neck；保留原 `.45s` 整个 presentation 淡出，不新增尸体 | 三种攻击完整循环；phase 2 第二波／第二铃；滚动中受伤→继续滚动；停机受伤→仍处停机；死亡淡出 |
| `thorn_guardian.tscn`／fine32 Guardian 1×根臂身体 | `branch_warning` 真实预警进度驱动树冠、肩肘蓄势；`seed_flight`／真实 seed 创建驱动枝臂甩出；心脏继续在原弱侧坐标单独绘制；根脚不移动 | `heart_open` 枝臂收势与原窗口同步，受伤不决定窗口；死亡保留原 rooted body，枝冠折落、树干暗化，不改变死亡协调 | 必须让真实玩家站在真实地面以锁 `attack_goal`；两阶段、左右真实弱侧、攻击中受伤、终态观察 |
| `thorn_queen.tscn`／fine32 Queen 2×枝冠身体 | 沿用 Guardian 的真实 seed 链；枝冠与肩肘分别动作，原 queen 三阶段与真实弱侧完整保留 | accepted damage 后回到当前实际 branch／flight／heart 状态；死亡原 rooted body 保留、枝冠收垂 | 三阶段；阶段 2 换侧与阶段 3 真弱侧；转阶段清攻击；真实 seed → patch → heart_open 的整段 |
| `rootbell_guardian_v2.tscn`／ForestBible 精细根臂身体 | 祖先 `forest_bible_actor_art=true` 才为正式精细分支；原精细身体 UV 关节动作接 `bell_warning` 与 `pursuit_warning`；`pursuit_flight` 用实际飞行位移，投铃与本体动作不改变真实 Bell Node | `landing_recovery/bell_stagger` 对应肩肘收回；原反击真实 Policy 事件图层保留；阶段 2 原双边框与并行动作保留；终态为原身体暗化与局部折落，无新尸体实体 | 合法 `bind_duel` 与真 arena；一次真实投铃完整往返；真实扑落→landing_recovery；phase 2 Bell + Body；accepted damage、真实铃反击单独列 |
| `thorn_queen_v2.tscn`／fine32 Queen 1×织网身体 | `motion_mode/motion_clock` 的 `migration_preview/phase_preview` 驱动冠尖和侧瓣收束，真实 `flight/phase_flight` 驱动伸展；同体枝臂保留中央身体与真实心位；原迁移路径和 knot/band 单独拥有 | `perched` 收势回实际停驻；受伤后回当时实际 preview／flight；原场域停止策略不改；终态保留原身体、冠臂收垂与暗化 | 合法 geometry + bind_duel；真实三阶段迁移；flight 中受伤后续同一路径；结点与网线继续原碰撞／生命；终态场域停止 |
| `thorn_queen_canopy.tscn`／ForestBible 精细枝冠女王 | 精细分支要求原 `thorn_queen_canopy_v3`、48×54 判定及祖先 metadata；共享 UV 网格驱动冠、左右枝臂；真实 `migration_preview/motion_clock` 收束，`flight` 展开；原连续路径与实际 knot 计数标签不随身体变形 | 路径抵达后的下一真实 preview 重新蓄势；没有伪造 encounter 不存在的 perched／冷却状态；accepted damage 回当前实际 flight／preview；保留原身体终态并暗化收枝 | 合法 build_geometry + bind_duel；phase 1／2／3 实际场域与 locked_receiver；flight 中受伤；两 knot 真实计数与切断；终态尾段 |

## 实际绑定与不变接口

修改的现有脚本：`boss_presentation.gd`、`windkeeper_presentation.gd`、`bellstrider_presentation.gd`、`thorn_forest_presentation.gd`、`forest_boss_duel_presentation_v2.gd`、`thorn_queen_weave_presentation.gd`、`thorn_queen_canopy_presentation.gd`，均在 `scripts/bosses/`。

新增：`scripts/bosses/boss_motion_presentation.gd`。`BossArrivalPresentation`、场景、Definition 资源、Encounter、Motor、damageable、奖励和保存脚本均未由本任务改写。`ForestBibleActors` 和 `UnderworldActors` 的公共 helper 未改写；Boss presentation 在原实际纹理分支中委托新叶，保留原正式 metadata 与稳定 ID／碰撞尺寸检查。

沿用 `assets/underworld_plains/actors/windkeeper.png`、`bellstrider.png`，`assets/forest_bible_v2/native/fine_32/guardian.png`、`queen.png` 及原 Clockwork atlas。没有生成或改写 PNG，也没有把旧图片重新登记为本轮新生成。

## 静态核对与待验证

本代理没有运行 Godot，单引擎租约由 root 持有。`gdtoolkit` 语法解析覆盖新 helper 与上述所有 presentation，`git diff --check` 已通过。纯数学网格包络审计用于找出局部三角形反转，发现过大的终态腿部／女王肩臂幅度后已收敛；它不是实机姿势或画风通过证据。

root 仍需在源码冻结后完成：Godot 4.7.2 import／类型检查；真实 AI 与 InputRouter／真实发射物连续战斗；正常速度的关节与脚底接触复核；weakpoint 视觉／实际命中同步；所有覆盖分支与阶段；终态、暂停、epoch 重建与退出信号清理；原机制／预算守门。任何失败原件保留，修正后重新采受影响片段。实机视频、trace、时长／fps／帧数与最终源合同在独立证据收据中填写，不用本制作卡预填通过。
