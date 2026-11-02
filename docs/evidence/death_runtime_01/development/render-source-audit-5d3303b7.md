# 死亡渲染源码审计（只读）

审计源：`5d3303b78d4db374300d4a0266bde8eb1a6de5b2`，工作树起止 clean。角色：独立源审计；采用 `.agents/skills/gameplay-reviewer/SKILL.md` 的只读及证据边界。已读适用AGENTS、当前状态/交接最新段、直接消费者；未运行Godot/Chrome，未改生产、物理、掉落或时钟。以下是代码事实/候选，不是CPU根因或设备改善结论。

## 实际调用链

- `EnemyPresentation._process:91–105`、`UnderworldEnemy._advance_presentation:63–71`、`RootBellPresentation._process:66–68` → `PlainsRevisionVisual.refresh:59–88`。live `_draw:90` → `rig.draw_pose`。
- accepted damage → `EnemyFeedback01Remains._committed:229–265` → virtual `_capture` → `PlainsRevisionRemains._capture:29–67` → `visual.remains_view:35–41`，捕获同一rig引用和冻结pose，切换stage sibling。
- `PlainsRevisionRemains._physics_process:98–165` 保留kill hold、支撑/落地、1.1秒collapse、0.75秒hold、0.55秒fade（charger持久）。每tick queue_redraw；`_draw:167–180`复制captured pose并覆盖dead/death/air/death_clock/landing → `rig.draw_pose`。
- `Skin.draw_pose:96–127`：已有可见性剔除 → settled缓存 → `Pose.prepare` → 625次 `deform_prepared` → `surface_update_vertex_region(...vertices.to_byte_array())`（5000字节顶点数据） → 当前canvas四uniform → draw_mesh。
- `Ground.deform_prepared:9–28`总是先live和vitality，再按death算target并lerp；`Flora.deform_prepared:10–26`分物种并按早期死亡混合captured live。fan在`_fan:128–176`中再做live、空中loss及落地blend。

## 当前已做，不重复建议

Skin共享拓扑、按bounds的neutral points、按kind只读UV权重；每实例独立mutable mesh；Pose已有33个波形/quiet准备；Root已有draw-local geometry/IK准备；settled corpse已有排除death_clock的mesh缓存；body draw已有bounds.grow(64)可见性剔除。上一批宿主正常帧重复refresh已合并。

## 新候选，按优先级

1. **最小风险：Ground死亡每draw恒定量准备。** `ground:186–244`的death windows、stumble/knock、depth、neck，以及`246–292`中Hopper旧骨点/长度、body_shift、hip/foot/knee、front sqrt、三组segment angle_to，均与point/uv无关却当前每625点重复。依照现有Root geometry准备形式懒准备到Pose，按size复用/失效；保留原表达式顺序和Vector2中间量。Hopper的两次point→segment距离和shin_weight仍依赖point，不能误移为pose-only。无须改progress、采样密度、mesh数量或动画。
2. **Ground旋转。** `_joint_at:38–40`反复Vector2.rotated；死亡角仅少数pose值，live/vitality角也为pose-only。要缓存float旋转，须尊重Godot `Vector2::rotated(real_t)`先cast angle到float、float sin/cos、float乘减的顺序；GDScript `sin(angle)`为double，直接手写double标量矩阵不能预签位级等价。用独立frozen oracle拒绝细微漂移，不通过降低容差兜底。先做候选1可避此风险。
3. **Flora剩余死亡常量。** sentry `53–88`重复deflate/topple/leaf_drop、body_target、nozzle hinge、三个leaf hinge、两组hip/fold；fan `128–176`重复窗口/failed_beat/weak_beat和air角；Root geometry已经hoist但`_carry_stem:349–354`每点仍两rotated，叶片hinge只有有限类别。可按pose/size准备有限集合；Root不再重复提IK hoist。
4. **低优先：冻结子结果/相同有效几何。** Ground每个死亡draw都重做冻结live+vitality，即使death≥.14 blend=1；可缓存捕获live子顶点后保留原lerp。直接return target可能因Vector2.lerp浮点舍入改变位级输出。非fan空中death=0、landing=0时，local结果不读death_clock，当前仍重算/upload；有效pose缓存可能省这段，但须完整kind/bounds/texture/point/air/pose失效和shared-rig overwrite处理，复杂度高于候选1。

## mesh交接与cold路径

- `_capture`接收同一个rig，**没有创建第二mesh/texture**。Visual.refresh在terminal后visible=false并return（60–63），Visual._draw检查visible；父body `_draw`也在revision存在时return。正常持续死亡路径没有源证据支持live/corpse每帧双上传；只在不同canvas主动共享同rig且交错draw时会覆盖，已有缓存测试明确覆盖。仍可在真实场景按rig/frame记录draw/upload次数确认致死当帧。
- corpse首次`_capture:46–49`会创建skin ShaderMaterial（父初始化用flash_material）；这是首death资源创建事实，但不是已证实卡顿来源。mesh在live初始化创建，texture预加载，权重首draw准备；通常可见live早已走同skin shader。death改变uniform，不改变shader源码。现有CanvasShaderPreparation只准备default canvas polygon/line，不准备revision skin，但不能由此断言死亡重编译；应看真正program/link计数及draw/buffer时段。
- 每death draw仍有pose深复制、PackedVector2Array分配、to_byte_array和upload；无测量不把5000B量级宣称根因。每physics和_draw各_sync_material一次，亦仅候选低成本重复，需测量排序。

## oracle/验证建议（本审计未运行）

- 原 `tests/plains_revision_deform_equivalence_runner.gd` 直接对 `tests/fixtures/plains_revision_deform_2ce4ffa6/{skin,ground,flora}.gd` frozen oracle做PackedVector2Array字节比较；已有625格点、arbitrary UV、offset point、三种size、air、death阈值、raw/clamped/missing字段。原Harness：`plains-revision-deform-equivalence`，180s，Godot固定60。
- 追加更密death进度与全部新window边界±epsilon；同prepared pose交错size A→B→A（防lazy geometry误命中）；Hopper point offset/arbitrary UV必须保留，不能只测neutral grid。旧oracle不改。
- `tests/plains_motion_loot_02_motion.gd:280–419`已有实际CanvasItem draw计数、625/0变形、shared rig覆写、kind/bounds/texture/air失效、材质刷新与mesh实例独立检查；原`plains-motion-loot-02`保留。缓存优化需对实际新行为追加，不删旧检查。
- 实际同source/seed/input death timeline逐tick比对age/contact_age/progress/frame/position/support/face/alpha/active/visible/accepted_starts与音频一次事件；两宿主+Root、charger持久、fan空中落地、暂停/掉支撑/restore。动画轨迹和1.1/0.75/0.55时长不变。
- 几何计时和真正帧计时分开：交替A/B核对六物种death 0/.01/.1/.2/.5/.72/.99/1，冷首次和热重复；同时记录deform、PackedArray序列化、RenderingServer upload/draw与浏览器program/link、P95/P99。只有实测后判断用户卡顿是否改善。

结论：最小候选是Ground death pose/size-only参数与Hopper骨链准备；cold shader和持续双upload均未获现有源码支持。视觉、完整运行和设备性能均UNVERIFIED。
