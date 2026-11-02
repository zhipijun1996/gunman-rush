# 死亡事件链只读审计（DEATH-RUNTIME-01）

审计源：`5d3303b7`。仅源与已有证据，未运行 Godot/Chrome，未改生产、配置、测试、绑定或动画。用户手机 Chrome 对 build 9dd 的改善反馈不在本审计中重新量测。

结论：当前大部分平原敌人的共享死亡路径没有 `get_image`、死亡 WAV 动态加载或金币 ArrayMesh 创建。最值得分段计时的是**死亡头几帧的625顶点变形/上传，加上同批新掉落 Sprite2D/ShaderMaterial 创建与首个 loot shader 绘制**。源码能证明这些工作会发生，不能证明其耗时解释手机停顿；旧测量也没有建立突出死亡帧。不要再重复 Foot/拓扑/静尸缓存或默认 canvas 首枪预热。

## 实际事件顺序

1. `game/combat/damage/damageable.gd:46` 验收事件/epoch，正式绑定时交 `damage_sink`；`game/combat/damage/frame_damage_policy.gd:47` 构造 DamageRequest，记录 on_damage_applied。
2. `frame_damage_policy.gd:203` 的 `_commit_selected` 调 HealthState.apply_damage；`game/combat/resources/state/actor_resource_state.gd:45` 写确定性 receipt 并同步 emit changed。Damageable `_state_changed`（:98）先 emit died → `game/enemies/enemy_actor.gd:77` 现有死亡音效、取消攻击、stop、关碰撞、停AI、emit defeated；死亡 sample（`enemy_feedback_01.gd:51`）记录 terminal/serial，生命周期订阅者读状态。
3. policy 在本帧致死/环境回退优先裁决后执行 on_damage_applied（:192）→ `Damageable.damaged.emit`。`enemy_feedback_01_particles.gd:29` 追加 burst；`enemy_feedback_01_remains.gd:229` 只认匹配 lethal receipt，capture、frame4、必要落地ray、显示尸体。它们不是 damage 决策方。on_committed 和 batch_resolved 随后发生（:195–200）。
4. `game/application/demo_app.gd:831` 的 `_damage_resolved` 在 batch_resolved 被调用，`:897` 扫 terminal actors，正式 connected map 使用**地图预生成 manifest.enemy_drops**；内存 duplicate、已有item kill bonus、safe_drop_position、PlainsLootMotion.units、snapshot、region_state/drop账本、RunManifest.record_output。正式击杀本身不重掷 drop RNG。
5. 下一 process `game/presentation/world/art/plains_stage_visual.gd:32` 同步新掉落 sprite/material；后续 physics 每帧推进掉落和保存内存 motion。每个 unit `ready_at = death_time + .30`。接近后 `demo_app.gd:2062` 才申请 pickup：coin 是局内 wallet；note 经 meta.grant_notes 事务写持久存储。

## 当前六种与旧路径

- `plains_revision_skin.gd:7,37`：patrol、charger、hopper、sentry、fan_sentry、root_bell 共六张 revision body；patrol_drone/graybox_patrol_drone是同一 patrol 类。正式宿主 `game/presentation/actors/underworld_plains/underworld_enemy.gd:20` 优先装 `PlainsRevisionVisual`；通用 `enemy_presentation.gd:29` 同样优先。
- `plains_revision_visual.gd:14` 在出生即装 live rig、particles、remains sibling。致死 `PlainsRevisionRemains._capture`（:31）复用原 `_rig`，`_set_frame`（:64）只报4–7及 foot=0，不调父 Frames/contact_bottom。不是新建 corpse mesh。
- `plains_diver` 不在 revision 六种；进入旧 frames_v8/EnemyFeedback01Remains。`enemy_feedback_01_frames.gd:58` contact cache冷key仍 get_image；`:71` visible_bounds也 get_image（后者在安装期）。旧接触缓存已经解决重复扫描，不能据此解释当前六种共同死亡停顿。Diver第一次distinct死亡frame可另计时，不能优先扩大此分支。

## 可验证的最小热点与优先级

| 优先级 | 已成立的源码事实 | 最小观测/改动候选与边界 |
| --- | --- | --- |
| 1 | `plains_revision_remains.gd:166` 每次动态尸体 draw 深拷 captured pose，`:180` 调原rig.draw_pose。`plains_revision_skin.gd:102` 未完成死亡每draw变形625点、打包5000字节vertices、surface_update_vertex_region和draw_mesh；GRID24=1152 triangles。`plains_revision_pose.gd:84` dead还构建live prepared pose。Flora `:17` sentry/root在raw_death<.16时每点递归计算live再lerp；Ground `:9` 先live/vitality再算dead。 | 单独计时 capture、prepare、625点kernel、to_byte_array、upload调用、draw提交及真正GL buffer/draw。保持当前1.1秒死亡及原几何，优化须原位级oracle覆盖起始death=0、.16前后、空中/落地。现有静尸缓存只在death=1生效，不能把它再次当新方案。死后早期额外成本与原alive对照即可定位。 |
| 2 | `plains_stage_visual.gd:42–54` 每个新unit创建Sprite2D，loot_motion另new ShaderMaterial并用 `shaders/plains_loot_02.gdshader`；coin零ArrayMesh。`plains_loot_motion.gd:8` 按5拆分：patrol1枚、charger/hopper2枚、sentry3枚、fan5→1枚、root7→3枚，另可有note/heart。sprite/material在每次死亡重复创建，shader首次可见仅首用冷成本。 | 记录新增unit数、_sync_pickups分配/节点通知/首次draw时间；比较首次掉落与第2同种击杀。若实测值得，可准备sprite/material pool；仅视觉节点，绝不提前创建/领取奖励账本或推进RNG。首loot shader准备只能解释冷首次，不能假称解释反复每杀。 |
| 3 | `plains_revision_remains.gd:46` 每actor首次death才new ShaderMaterial（同live `plains_revision_skin.gdshader`）；保持原rig/texture。 | 计时new/attach/首draw。可把同一私有remains material准备移到出生时，保参数和独立uniform；收益未测。无新death shader源码，不重复泛化首枪shader预热。 |
| 4 | `generated_demo_stage.gd:174` `_save_pickup_units` 每physics对全部pickup查source并对同源units循环match/merge(snapshot)，包括claimed；`plains_region_stage.gd:263` 每physics capture_state，`:337` 全敌region_snapshot；`:340` 在传参时先算support_identity，即使 transient remains的presentation_snapshot随后返回{}。 | 计时全组与随累计kills/units的增长。可精确索引record或避免不保存瞬时尸体的support扫描，但需保存/恢复快照字段与时点等价。它们是重复内存工作，无磁盘/localStorage I/O，首杀大停顿解释力弱。 |

`game/presentation/rendering/canvas_shader_preparation.gd:18` 当前 prepare_combat只默认 polygon/line及light mask 1/0，不含 loot 自定义shader或body mesh。它已完成的效果应保留；这不是重新做泛化warmup的理由。

## 粒子、音频、存储排除及条件路径

- particles节点出生已存在（`plains_revision_visual.gd:22`）；命中append小Dictionary并启process，死亡7细屑/3 contact rays（非scoped旧路径18/5），CPU draw polygon/line，无 GPUParticles、mesh/texture创建、get_image或load。
- 六种死亡音色由 `game/presentation/audio/plains_enemy_audio.gd:15,62` 预载shell/wing/plant streams，GameAudio `:247` 使用原12voice池、死亡cap3、已有优先级/替换、play，不动态load；落地另一个既有cue（root保LOW_BELL）。不能换音效以消卡。
- 与死亡同步的**武器accepted-hit音**是条件路径：`weapon_feel_v2.gd:60` → `weapon_feel.gd:63` → `weapon_audio.gd:11` → 非original profile时 `game_audio.gd:561` 同步load所选variant。这也是非致死hit共享；load可能cache命中，不能直接叫磁盘读。若测量，仅记录chosen path/cache状态/load/play，不预先随机抽音，不改director RNG、去重/interval/voice selection。初始selected validation加载过资源也不证明以后总有强引用。
- 死亡账本 `RunManifest.record_output:46` 仅deep copy内存，无JSON stringify/save。`plains_region_stage.capture_state` 也是内存字典；快照不是持久化I/O。
- `meta_save_service.gd:44` 的commit确有同步Web localStorage read/backup/write/readback（原生有flush/读回/rename），但本事件链只有note拾取（`demo_app.gd:2080`）才到达，最早晚于0.30秒，不是每怪死亡；coin不经MetaSaveService。不能改成异步保存绕开原提交事务。
- `feedback.tres:7` 现有kill hold=.033秒，只暂停尸体/细屑本地推进（remains :62 /particles :50），没有sleep/同步等待。观测应记录hold/time_scale与wall frame，保动画/手感规则。

## 已有证据的实际限度

旧 `/workspace/refactor-evidence/first-use-stutter-01/observations-01/source-index.json` 记录首hit frame225.030ms、terminal hit61.405ms且邻帧87.551/72.324ms；该旧样本未重现异常死亡峰。`first-enemy-gl-capture/summary.json` 首hit220.431ms期间已计时compile/link/texture/readPixels无≥2ms慢调用，draw/buffer当时仅计数；`docs/worklines/first_use_stutter_01/results.md:37` 也明确盲区。当前9dd正式4pulse/3hit/kill仍NOT_RUN，旧证据不能替当前手机签FPS/死亡根因。

建议下一个单次诊断只取原正式地图真实种类/episode/shot/HP receipt，对齐terminal提交帧及后续~1.5秒，覆盖首次与同会话第二只相同种类；保输入、伤害、奖励RNG、音色variant、声音选择及全部动画。先补 draw/buffer、dead kernel和新loot分配的计时，不继续无因改生产。
