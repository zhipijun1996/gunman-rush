# /08 candidate02：艺术改善，底部碰撞阅读仍REWORK

实际全屏看 `build/painted_terrain/reuse08_candidate_02/video_frames/` 的120/180/300；没有完整播放/亲听。B主体、连续草海与完整薄土体现在同属一套语言，圆土下收代替硬裁也更自然；这是第二空间整体而非仅部件的改善。不因未制作新动画/UI阻塞本轮静态局部。

但**仍REWORK，不能展开余2seed**。180底缘透明起伏明显；root/worker核实固定source_bottom645使可见土边相对真实平直ceiling内收0–20world，而下方空气可通行。画出的空气可能仍会顶头，属于当前用途的公平性/空间阅读缺口，不以好看或常见让步。上方两岸去返不会覆盖下方碰撞。

建议各x最外可读土边锚实际bottom，圆收主要表达在内部明暗，不能靠透明挖去实心；边角从实体内取得厚度，不延长成假地基。修后需要真实PlayerMotor在最大内收凹口/低点各从下方上跳，记录头顶、碰撞与可见alpha边关系。如仅能以合法初始fixture置于下方，明确该碰撞反例范围，不冒正式路线已到达该处。

回执实际351tick route_target_reached、source_before==after真、errors空，root_seed `level-design-v2-baseline/08`、source_commit `df197eb773aa3d3d89078616d7523da1d3922724`、movie SHA `cab8f9d60fb05ff42d7018b73326b9529b5d75a1fee3a4f77fbefd31d7a68b53`。此处route是已声明的局部两岸往返观察，不是全图通关。未支持后段、首01 420budget红及首空间04范围继续保留。

只读时见当前工作树已有逐column bottom_profile新映射；那是candidate02之后的新候选，不用新源码追认旧图。等待新像素和真实Motor碰撞反例，不改被审源、不启动Godot。

## 后续真实Motor凹位反例05（不追认02）

实际查看 `build/painted_terrain/underside_head_05/head_768.png`、`head_896.png` 与receipt。新图中头部贴可见土体下缘，没有02的画出空气后再顶头距离。两点source_column768/896原固定采样不可见深度20/3.5714world，新profile校准0；原Motor正常调度记录head_contact_y170.036865对actual_ceiling_y170。receipt明确initial_spawn_only=true、manual_controller_step=false，这是已有正式几何下方的独立初始spawn碰撞fixture，不是普通路线到达证据。支持这两个测试位置的风险修复，不外推所有像素或Seed。新底线更平直但内部明暗仍圆收；不应为了追波纹重新透明挖掉实心。最终同语言艺术局部等03新实际图再判，旧02范围不变。
