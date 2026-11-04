# MAPGEN-HOST-V2-01 非作者只读审查

基点 `30e36c9abe223f26e666ceaf796e3fe9cb58e10f`，当前7个新增GD/entry/test完整SHA见review.json。Provider/ellipse由items_refactor、FrozenSource/Stage/入口/test由root编写，本审均非作者。未运行engine/Chrome或测试，未修改源码；原生结果由root新冻结运行决定，不能以本审签物理通过。

## 当前结论与已修正问题

生产装配/几何/服务/生命周期结构限定可接受为**r2三模块受控加载切片**。发现的退出echo重入问题已由root修复并经源码复核；审查还发现并立即报告过一处真实test错误：`tests/runtime_map_v2_runner.gd` 的face分支把M16.R.face写为LEFT，而官方M16.R原来就是LEFT（其local_position=[0,64]，镜像来源的Port ID仍叫R）。因此这条case没有篡改数据，Provider应接受，原“必须拒绝”断言会失败。root现已改为RIGHT，保留拒绝断言，未换seed/模块；最新源码已复读核实。未执行该case，判断来自原JSON和分支逐字比较。

此前我曾报告`_connection_error if not matched`误缩进；用repr实际tabs复核后确认for-port和if-not-matched均两个tabs，检查在loop外，会正常返回诊断。该条是审查者展开文本误读，**已明确撤回，不是源缺陷**；root另加missing_port负例有效。

## 几何与原记录

- 主仓map.json与官方attempt-01全map逐字相同；M16/M18/M21三content逐字与selection-r2原件相同；三个完整instance结构与各原JSON相同；selection.json原件逐字相同。输入lock六条SHA全部与真实文件匹配。不是对挑选内容做过精简或重新生成。
- Provider只消费本次selected IDs，不调用旧generator，legacy_generated保持{}。定义先完成再进入原LevelRuntime；旧LevelPlan/Runtime/PlainsRegionAssembler/PlayerMotor/Controller/RunComposition已独立与HEAD比较全字节不变。没有PR123旧App wrapper复活。
- 原18块矩形＋M16/M18两个原seal各append一次→20 StaticBody；只有M16一台原AnimatableBody ellipse，无另造ground_supports。M16 one-way index3按原索引保留，seal追加不挤占原indices；seal与原边界可能有原设计重叠，属于两类原对象，不是第二套builder。v2几何port/route完整保存在实例metadata；content入口/出口被命名为authored_body_entry/exit并标注旧玩家body-center helper语义，不作为新增Route证明。
- 模块仅平移origin_blocks*128，当前adapter明确拒绝非128版本，不会悄然错误缩放。已物化platform/content/seal不再镜像或应用source_affine。M18/M21的source_affine y=-376只是来源metadata，未再次下移实体。新父节点scale1/rotation0，与本切片世界根identity合同一致。
- 原M16 ellipse：center[320,256]/radii[160,144]/period8/phase0/xsign-1。host保留原 `PI+TAU*fposmod`、Vector2分量舍入，再只翻offset.x；没有线性ping-pong/翻整模块。t0局部[480,256]，解析quarter turn为[320,112]/[160,256]/[320,400]。envelope仍[104,104,432,304]。center/radii/x_sign改为@export保证原两次Resource.duplicate(true)保留字段；是否原生真正承载、过缝与重复碰撞由root实跑验证。
- 三条内部C027/C030/C031按真实Port ID/边界face/INOUT/ROCK/world seam核对，不从R/L名字猜方向。cut edges与全部route没有改原map，切片不为缺失外部模块造新seal；不冒充整图封闭/路线物理认证。

## SHA信任与拒绝范围

FrozenSource固定res根和六个允许成员名，先用co-versioned input-lock校验实际字节再parse，不从content/source_scene_ref执行脚本或加载任意路径。这个入口的信任根是仓内锁本身；Provider的source_sha256参数只是**caller已核字节的断言**，它不重新序列化验证传入map/content，也不把content.source_sha256当物化内容哈希。因此本审认可这个固定资源入口，不把Provider描述成任意不可信外部JSON/全v2 Schema认证器。将来若换外来入口，必须在caller核实际完整来源字节，不能只传一个64字符字符串。

Provider对已构建selected几何的unknown instance/content/ellipse字段、非空未支持enemies/rewards/latches/hazards等、材质/连通性/port缺失/几何越界均有明确拒绝；它没有执行/校验完整graph、inputs、anchors、source_validation和required ability证明（保留metadata且无授予）。未选的全图实例/外边只保留记录，不代表宿主已支持。source seed已修为JSON safe-int范围内canonical decimal并同步plan.seed，避免930001.0误拒绝；不表示任意seed/算法已实测。

plan.map_hash是外来完整map raw SHA＋排序selected IDs，当前固定三content由同一可信lock保护；不是独立content-store digest或宿主spawn-binding hash。不得据此承诺更新content/外来store后仍能安全重放。当前同一冻结slice/受控spawn绑定的run-local恢复使用范围明确，不扩持久化schema。

## shared services、取消与恢复

- 一套RunSession/RunComposition真实player/controller/build/wallet/reward/shop，一个FrameDamagePolicy；没有在模块ready复制player/services。services持同一个lifetime对象；flow.start更新该对象epoch，不替换服务引用。selected content本来没有敌/奖/Boss/伤害源，所以required_services是原保留声明，不伪称这些消费者已受测。
- 初次host-bound spawn才调用原return_to_segment；过三个真实Port时不load_stage/不reset/不写玩家位置；ferry沿原AnimatableBody2D平台速度交给唯一Motor.step消费。三spawn只属slice，未改v2 player_spawn/Boss unresolved标记。标准request不额外grant grapple，本slice不证明完整能力路线。
- reload捕获module clocks/visited，验证run-local map state，清输入和弹丸、invalidate_actor后销毁旧Stage，再以相同plan/source重建并注入原policy；不更换player/wallet/policy、不重置HP。M16非bell-controlled轨迹由module clock驱动，所以恢复clock等于恢复其phase。测试目前walk后reload校核位置/服务/clock，不应说已经证明骑乘中reload无瞬态或完整机制状态恢复。
- exit先closed/禁输入/clear_projectiles/end lifetime，释放Stage并用原WorldAudioLifecycle总预算drain。原先按住ESC第二次handler可能提前quit的问题，当前入口已有not-closed/not-echo guard；close_slice并发调用也等待close_finished并返回同一close_result。_exit_tree另外end lifetime。普通直接free没有await drain的行为仍需调用者遵守既有close入口。
- admission测试反例/实际20body/每块世界offset/oneway/唯一player+policy/ellipse duplicate/过缝/同图恢复/旧token失效/退出弱引用释放/60帧真实ride trace均针对新消费者，非伪造ModuleScene替身。它们仍是计划/代码，原生未由本审执行。原01 seed解析失败按root消息保留；不删除失败，不把editor缓存问题当验证通过。

审查范围不含enemy/reward/Boss/projectile-to-latch/runtime生成/Web/设备或46实例整图。当前上述两问题均已在源码修正，没有剩余阻断发现；仍须以精确源原生通过及真实GUI/音画证据再决定交付。
