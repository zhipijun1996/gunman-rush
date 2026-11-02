# Flora 非作者静态审查

审查者：death_render_audit（本批Ground候选作者，不是Flora作者；本记录不审签Ground）。适用 gameplay-reviewer 只读及证据边界。被审源：外部 `flora-candidate/game/enemies/presentation/plains_revision_flora.gd`，SHA256 `a408e24800fb0e491b573e8e1b635f98d9224f9d4dbf0a5d5ce8b552714a56a9`。基线5d3303b78d4db374300d4a0266bde8eb1a6de5b2，原Flora SHA256 8ecb41f063aba37cc398a0b41d954c9f09c4b1056718619cd14f5d40719fdb47。前提：Pose仅新增 `flora_death_geometry: RefCounted`（另有Ground字段独立使用），prepare/live/Root cache保持。

结论：**限定静态范围 ACCEPT，未发现阻断问题**。数值位级等价、引擎解析、实际帧/原生性能、视觉、设备均 UNVERIFIED；本agent没有运行Godot/Chrome或修改生产。

逐项结果：

1. 同值hoist：Sentry窗口、center、parent_angle、body_target、sac_scale、nozzle/leaf/hip和角度复制原表达式。`_scale_part`调用展开仍为原helper同一 `point.lerp(center+(point-center)*factor,clampf(sac,0,1))`；center/factor保留原Vector2构造边界。Fan死态roots/angles、窗口、弱拍均用原表达式；关节操作次序、条件及最终落地blend保持。
2. float32边界：Geometry.float字段保存GDScript 64位scalar；原Vector2字段仍由原构造/向量操作产生。Fan `size.y*.17*roll` / `size.x*.10*roll` / `size.x*.07*sprawl` / `size.y*.075*sprawl`以及falling前缀保持左结合64位标量，没有提前pack Vector2。旋转仍由原 `.rotated(angle)`执行native real_t转换；没有GDScript double sin/cos替代。叶片和腿角乘窗口的结果存float字段不额外缩窄。
3. Fan key：仅未完成fan读取raw `pose.death_clock`作为key；窗口仍读取 `maxf(0.0,pose.death_clock)`。用raw而非clamped key只会保守重建。d>=1时key=0，且原d>=1 return仍在live与空中角读取之前。`not(d>=1)`保持NaN分支与原fallthrough一致，不用d<1错误跳过NaN。
4. raw_death：`deform_prepared`逐字未变，raw_death<.16的captured live混合、raw_death>0的floor clamp保持，并且每顶点依旧执行。Geometry仅依赖clamped death，因此raw_death未放key正确。air同理仅影响外层clamp，live分支仍逐点读pose.live。
5. Sentry UV/权重：原 `if uv.y<.23 / elif uv.x<.39 / default`按原顺序选择(.43,.23)/(.42,.32)/(.47,.31)及-1.58/-1.22/-1.48角；原 `front>.5`在三处选择(.61,.74)/(.34,.75)、对应moved hip和-1.12*[.25,.68]/1.18*[.34,.76]。没有改成UV x猜测front。
6. 失效：size/kind/death/有效时钟全部比较；同prepared pose改size/kind/death会重建。有限size guard逐字保留，NaN/Inf size在公共deform_prepared入口直接返回point；NaN death或未完成fan的NaN clock无法相等命中旧缓存。完成fan的clock不参与几何，忽略NaN clock符合原提前return。原来的raw/live可变字段仍由原未缓存调用层读取。
7. 生命周期：Geometry成员仅float/Vector2/StringName，没有Pose、RefCounted、Array或Dictionary引用；Pose→Geometry无回指。递归live使用独立pose.live，Geometry不会覆盖父dead pose。两个新增Pose字段相互独立，不改Root geometry。
8. 原公共/helper范围：独立脚本核验 `deform,deform_prepared,_pivot,_joint,_joint_at,_scale_part,_window,_root_bell,_prepare_root_geometry,_fold_elbow,_carry_stem`及Sentry/Fan live共13段逐字一致。外部临时树应用flora.patch所得精确字节与候选一致，候选/基线SHA已独立核。

建议root验证重点：原frozen byte oracle；同prepared pose size A→B→A、kind Sentry→Fan→Sentry、death .999→1→.1、fan raw clock负数/0/正数/NaN；Sentry uv .23/.39±epsilon及front .5±epsilon；raw_death独立于clamped death改变，air切换。不得用降低容差代替位级检查。Sentry预先计算全部有限hinge是固定额外工作，是否净省成本由原基准判定。
