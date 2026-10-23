# PLAYER-PRESENTATION-01 · 检查点 01

task_id: PLAYER-PRESENTATION-01；content_version: checkpoint-01；模式：System Engineering。

实施基线为 `origin/main@e9ab0e0743466b8983e34cc7de17bab1abf9d53a`，独立分支 `feature/player-presentation-01`。本检查点交付消费者审计、未修改正式消费者的真实基线、拟改接口和版本化影响分析。表现改进、全套动作、独立新 Preview 尚未交付，不能将本检查点称为完成。

采用 player-creator、animation-vfx、game-quality-gate；project-integration 用于分支／证据交接，另由独立代理只读审查源码与原生轨迹。中央 tasks/current_state/handoff、Harness、共享配置、DemoApp 和正式场景均未修改。实施任务保持中央索引的 planned；总控接收后负责同步状态。

已按用户追加要求完成[公开方法研究与本项目实验映射](methodology-01.md)：可读层次、武器节拍、快速响应与回稳、常用动作优先；方法只作提案，不签用户感受。

## 玩家体验与范围

最新用户要求覆盖全套动作、所有武器，并能在 home 切换角色，覆盖原调度合同的“不批量”限制；仍先完成一个正式主角黄金样板，再扩展动作与角色。本阶段只读既有 Motor／输入／物理／伤害／资源／授予／保存，不创造新可玩职业或新解锁。

已有三种是**会话外观**：原版信使、围巾旅人、修钟少女。home 已有选择器，不需要重造菜单；角色属性、能力或永久解锁不是当前已实现事实。正式 pixel 区域会隐藏选择器和选中的替代身体。家园选择能否延续到正式区域必须由总控协调 `AvatarPresentation`／DemoApp 所有权，不能在本线偷偷改入口。

## 实际消费者清单

| 实际入口／范围 | 身体与上身驱动 | 锚点／覆盖责任 |
| --- | --- | --- |
| 正式 PlainsRegionStage | DemoApp 的 pixel 分支实例化 UnderworldPlayer，节点名 PixelPlainsActor；Adapter 禁用、Courier 隐藏 | 真实主角，必须独立验证；不能拿 ActionStudio 代替 |
| 正式 Bible Forest | 同一 shared pixel 分支使用 UnderworldPlayer | 直接受影响消费者；重验与共享 style 由总控安排 |
| 正式 HomeScene | 自己实例化 UnderworldPlayer；Adapter 禁用、Courier 隐藏 | 家园三外观、移动、选择取消、离开与返回 |
| ForestExplorationPlaceLab | 显式实例化 UnderworldPlayer | 保留开发消费者，不能误称普通正式区域 |
| 非 pixel 正式与旧候选 | CourierVisual + PlayerVisualAdapter；可选 PaintedHero | 保留旧动作与素材，不能统一覆盖成一个身体 |
| ActionStudio / ModuleLab / Foundry / RandomStagePreview | player.tscn 的旧 Courier／Adapter 链 | 局部资源与武器测试；通过不外推正式 pixel 主角 |
| PixelPlainsRoom / WindchimeLab | PixelPlainsActor / WindchimeActorVisual | 父类旧消费者；本线不改父类 |
| WeaponActionRuntime 瞬闪残影 | 从隐藏 Courier.body.texture/global_transform 采样 | 外部绘制消费者，需协调，不能漏掉错误身体残影 |

关键代码：`scripts/demo/demo_app.gd:2269`、`:2272`、`:2289`；`scripts/demo/home_scene.gd:34`、`:53`；`scripts/demo/forest_exploration_place_lab.gd:65`；`scripts/art/avatar_presentation.gd:128`、`:160`、`:183`；`scripts/combat/weapon_action_runtime.gd:39`。

## 实测与最明显缺口

任务驱动 `tests/player_presentation_01/baseline_audit.gd` 从真实 DemoApp 创建 Home 或正式 Plains，保持原出生点／相机／地形／敌人／资源，移动与射击通过 Router。家园外观选择调用既有 `select_avatar()`，明确只是 API 选择 fixture，不能签鼠标／触屏菜单。驱动没有改位置、生命、装备、授予、弹体或伤害结果。

headless 基线：Home 720 样本、12 次 accepted shot；三外观均能选择。首次射击在 sample35，此后 685 样本的 Courier.state 持续为 recoil；旅人和少女各有 142 个实际移动样本全部仍为 recoil，而隐藏的 Underworld 身体为 run。Adapter 在 `_ready()` 已连接 shot 回调，禁用 `_process()` 后回调依然执行，却没有计时递减与恢复。这是**实际状态同步失败**，不是“没有素材”的推测。

正式 Plains 720 样本、8 次 accepted shot；真实 HP 自然从 5 降至 2，Underworld 状态有 run199 / hurt57 / fall457 / idle7；没有直接调用伤害或传送。仅证明此输入窗口的自然受伤与恢复，不证明整图、死亡流程、所有武器或用户手感。

Underworld 目前身体仅 idle/run/rise/fall/land/hurt/death；上身始终绘制同样的两条持枪线，不消费 mode/tier、beam、throw/catch、charge 或 weapon_in_hand。旧 Adapter 的分层仲裁与武器资源已存在，但正式 pixel 分支不会执行它的逐帧同步。**反证：ShootAbility.equip() 仍会写 Courier.weapon_mode/tier，因此不能宣称正式装备字段失效；本问题是绘制与动作消费缺口。** PaintedHero 的旅人／少女各只有九态，缺少的状态落回 idle，且独立枪图会覆盖按 mode 选择的枪图。以上源码覆盖缺口与真实连续画面审查须分别留证，不能按素材数量签动画质量。

## 全武器与动作覆盖

| 等级 | 实际装备 ID | mode |
| --- | --- | --- |
| Lv1 | pulse_gun / shadow_shuriken / recoil_bomb | 0 / 3 / 6 |
| Lv2 | triple_machine_gun / sustained_laser / fan_shuriken / remote_boomerang / magnetic_mine / collapse_singularity | 1 / 2 / 4 / 5 / 7 / 8 |
| Lv3 | machine_storm / laser_cannon / blade_bloom / moon_boomerang / magnetic_storm / star_collapse | 1 / 2 / 4 / 5 / 7 / 8 |

覆盖单位是十五装备、九 mode、六 Lv3 技能；Lv3 普攻维持 Lv2。每时刻一个 WeaponRuntime，飞刃／布置物不算第二武器。初始化装备的测试需单列 fixture，不冒称正式授予。

扩展矩阵：三外观 × 左右／上下／斜向瞄准 × idle/run/jump_start/rise/fall/land × 普攻／连射／beam／throw-out/return/catch／bomb/mine／singularity/charge/skill × H/W/D 衔接 × hurt 中断／恢复／death × pause／慢时／session/weapon_epoch 取消／卸载。逐分支记录没有 authored 资源的状态，不复用 recoil 冒称全套。先样板，后逐项扩产；本检查点这些新动作均未验。

## 拟改接口（提案，未接入生产）

1. 新建任务专属只读 `PlayerPresentationState` 与 `PlayerPresentationProfile`，避免第二套移动、伤害或事件总线。直接订阅现有 `shot_fired`、health.changed 的 APPLIED 结果、died、landed、segment_returned，以及 WeaponActionRuntime 已接受的 phase_changed/entity_transition；逐帧读取真实 Motor／runtime 状态。通过现有公开 `ShootAbility.runtime` 读取已存在实例，不调用会懒创建的 behavior()；过滤实体只遍历 runtime.entities，不调用会清理集合的 current_entities()。拒绝或过期请求不产生新反馈。每个 player 只有一个状态推进者，各身体／上身只读取；切外观不重播事件、不增加信号连接。
2. 身体层保留各角色资源与 Motor 朝向；上身层独立表达当前武器／技能，配置反冲位移、恢复时间、受伤覆盖与转向过渡。优先级为 death > hurt > accepted weapon phase > accepted shot > locomotion；hurt 清除旧视觉 recoil，恢复只读当前事实，不延迟重播旧枪。此顺序只仲裁表现，不拒绝窗口内合法射击。
3. `presentation_receipt()` 为纯读取，至少返回 body_state / upper_state / profile_id / weapon_id/mode/tier / session_id / weapon_epoch / accepted_event_ids / hand_world / authoritative_muzzle_world / visual_muzzle_world / remaining_times。读取不调用 setter、try_fire、资源 API 或 gameplay 回调；debug receipt 不驱动动画。
4. `UnderworldPlayer` 保留现有身体帧、脚底与 lifecycle，消费共享快照绘制上身；旧 `PlayerVisualAdapter` 继续保留非 pixel 消费者行为。`CourierVisual` 新增的纯表现接口不得改变现有玩法枪口、body/arm 变换或影响 `muzzle_position()` 的语义。
5. 复用 `assets/actor_actions/weapon_catalog.json` 与已有动作 catalog。正式上身按当前真实枪口反解纯绘制变换，不能为新枪姿移动 gameplay anchor。真正需要调整肩／枪口、瞬闪身体来源时，另交总控前置接口。
6. 家园复用现有 selector。旅人／少女应让其绘制消费者读取同一身体／上身快照，避免禁用 Adapter 后依赖陈旧 Courier.state；`AvatarPresentation`／`VisualLanguageSample.PaintedHero` 不在本线写集，先由总控分配。不能仅把 Adapter 开启或写 Courier.set_state 当无风险修复：这些会改真实 arm／枪口位置。

### 可证伪样板目标

在**真实正式 pixel 主角**上复现“左移并右上射击 → 自然或明确标注 fixture 的 accepted 非终结受伤 → 恢复移动 → accepted 终结伤害”。身体保持真实 locomotion 朝向；upper 只响应 accepted shot，hurt 中断旧视觉反冲，death 清除上身；伤后不补发旧反馈。

采用相同基线／Seed／输入脚本／相机／1280×720／60Hz／引擎与录制环境作 before/after。精确逐 tick 比较 Motor、HP、资源账本、弹体初始位置与 accepted ID/epoch，任何不同均失败；每帧上身可见 muzzle 与既有权威 muzzle 的误差 <= 0.5 world unit（本提案的绘制对齐预算，不是放宽 gameplay 判定）。hurt 后的旧 recoil 必须在下一次绘制清零；受伤窗口内新合法射击只作新事件消费；暂停冻结、拒绝射击、stale health epoch、session/weapon epoch 更新、death同tick、切外观与卸载均构造反例。

上述死亡若用真实 HealthState fixture 提交，明确只签 lifecycle，不冒称自然战斗死亡；真实正式死亡回家另验。轨迹一致不签视觉顺滑，AI审查不签用户手感／审美／实体设备。

独审追加反例：terminal HP 优先于同帧 shot/hurt/land，inactive 菜单不是死亡，active=true 不是复活依据；pause 的 router.clear 不应错误销毁仍被真实 runtime 保留的飞刃／地雷；beam 读取 accepted runtime.direction；配置开关／极值不能改变枪口，缺失／非法 Profile 回退明确的旧表现，重载后 owner／signal 连接数有界。旧 SVG fallback 也保留回归，不以“新增状态更多”代替旧消费者逐项覆盖。

## 共享影响与总控交接

共享 style v4 直接绑定 UnderworldPlayer 脚本与 animation_build.json/run_sheet.png/states_sheet.png。本检查点这四件及 UID 保持原字节；未改 PNG，未刷新任何旧 SHA／Bible。见同目录版本化 [impact-v1.json](impact-v1.json)。

提交给总控的具体决策：审查只读状态／配置接口；安排 shared-style/Bible 的独审与显式新版本重绑；分配替代外观绘制／残影接口（如确需）；登记任务驱动的 Development 映射；安排 Plains、Home、Bible Forest、旧 Courier 与替代角色完整受影响 Integration。平原线在共同基线只读比较，消费新主角前统一重验。

新任务 driver 在现有 production_plan 中属于未知路径，Development 保守升级 full；本线不改映射、不删检查、不把手动专项冒称 planner 已执行完成。已执行的基线／局部检查和待总控完整集成分别记录。PR 包括 draft 也会自动启动完整 Integration，本检查点先推可审查分支，待总控安排后建 PR，不隐式启动未排期的完整集成。

## 交付物、失败与未验

本检查点只交基线原件、实际消费者／接口提案、证据与可恢复命令。两段真实连续电影均为 729 帧／12.15 秒／1280×720／60FPS，完整源码采集守门 source_stable=true；见[证据索引](../../evidence/PLAYER-PRESENTATION-01/checkpoint-01/README.md)。已查看原尺寸 home9秒、plains1秒及每0.5秒抽帧，未完整播放或听音，不签连续性／音频观感。正式改进后的同条件短片及独立可操作 Preview 仍是下一里程碑交付；不得复用旧站链接冒充本轮成果。连续电影是软件 GPU 正常游戏速度输出，不是实体设备 FPS；有音轨不等于已听音。

共享资源与保护边界来自用户本轮明确指令及 `docs/demo_wave_01.md`，所以先交具体影响分析，等待总控独审／重绑后再改绑定生产文件。这里没有要求用户重新批准普通实现或为最终审美提前签字。

恢复命令（仓库根；唯一引擎租约、不得与导出并跑）：

```sh
presentation_recheck_id="recheck-$(date -u +%Y%m%dT%H%M%S%N)"
bash tools/godot.sh --headless --editor --path . --quit
bash tools/godot.sh --headless --fixed-fps 60 --audio-driver Dummy --path . --script tests/player_presentation_01/baseline_audit.gd -- --consumer=home "--output=res://build/player_presentation_01/${presentation_recheck_id}/home.json"
bash tools/godot.sh --headless --fixed-fps 60 --audio-driver Dummy --path . --script tests/player_presentation_01/baseline_audit.gd -- --consumer=plains "--output=res://build/player_presentation_01/${presentation_recheck_id}/plains.json"
python3 tools/production_plan.py --stage development --base origin/main
```

恢复命令生成唯一新目录名；本驱动未实现拒绝覆盖，重复调用者仍须使用新路径。运行前先核基线、当前主线与保护的四件 SHA；本驱动是可复现观察，未来源码变化后必须新目录重采，不覆盖本轮失败／原件。
