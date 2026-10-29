# Forest cache／early body cull／Actor readonly候选源审

2026-10-29，/root/enemy_review。只读候选生产源码；新长期测试仅准备/tmp，没有写root测试／生产或启动Godot。本结论为**可进入有界实测，未宣称性能缺陷关闭**。此前CI52/80超时与未跑原件继续保留，原80、argv、断言和90/240/600预算不得变。

候选：`/tmp/forest_joint_cache_5b/forest_motion_02.cache-and-early-cull.gd`及`/tmp/enemy_actor_presentation_fast_candidate.gd`，对Git5b精确源审查。未发现阻断源问题，边界如下。

1. 影响缓存按实际region/margin/pivot布局、kind和foot_y缓存，mesh纹理／bounds重建先invalidate；不是仅按species猜缓存。每次_prepare_influences在判命中前刷新所有动态angles。脚底clamp、种类mask及零／空权重可分别失效。没有遗漏需要由epoch单独失效的静态几何；重入按当前layout/angles采样，时钟继续由原advance拥有。
2. 权重／total用PackedFloat64Array，pivot保持Vector2；非零joint保原遍历顺序、Vector2.rotated及乘／加／归一化顺序，total仍按原全项累积。只跳过精确零项，故必须保严格byte对照检验有符号零／抵消边界，不能改成容差或矩阵替代。原_deform_connected逐字保持；_prepare_mesh除了新invalidate行，原拓扑／UV计算与5b相同。dispose清缓存数组及纹理／mesh引用。
3. 新earlycull只将既有body_mesh_visible谓词提前到_last_body_pose更新后、关节调度前；旧latecull仍在。返回前恢复identity draw transform，host后的HP／预警／线／荚柄等不随此return退出。没有改_process／advance／AI、已接受反馈、epoch或终态策略。_joints在离屏时不再生成，但检索当前生产／采证无外部消费者；原culling测试直接设置该私有数据不受影响。此层未被纯math微基准覆盖，须用实际GL边缘／重入及其后marker位置对照，不能借math字节相同签屏内画面等价。
4. Actor默认快照shell及三float duration字典每次新建后直接readonly，字段均为scalar/StringName/Vector2值；允许的Behavior hook四字段仍逐值调用原递归freeze，source_phase另隔离。原helper逐字保留，不增加跨帧缓存、同帧采样延迟或可写借用容器。invalid分支同为fresh readonly。未把原helper不隔离Object/Resource的既有边界扩大。

root提供的756case／218484vertices严格byte相同、300iteration46.7ms对302.7ms仅为纯math实测；本代理没有执行该引擎。0.154x不能当整route提速。实际profile mesh约7.97/43.77秒、snapshot约1.689/43.77秒，全部归零的理论部分也仅约22%wall；earlycull另省关节调度，但效益须实际route测量。不能预签原CI600秒恢复。

## 长期最小接入（仅/tmp准备）

`/tmp/enemy_structure_cache_test_candidate/`有3个可审文件与manifest/README：新`tests/enemy_forest_cache_contract.gd`、既有runner/wrapper候选。原39case函数体不改，run只追加1cache case，wrapper精确要求40；import90/native180不动。enemy-structure-native有限inputs只需追加新helper1路径，无新profile／检查体系。

新helper先锁Git5b原_deform_connected canonical方法SHA `4d71240973cbf4458c79e5e64724a490118f9b7e812abfc2fb48ad3a78e7258d`及去新invalidate行后的_prepare_mesh SHA `abd088dfddbca8ab11e2456dc5bcc4e188ba80d24a6809177f0a9213e7502631`，防两边一起错误漂移；再以保留原函数作reference，对缓存生产路径严格比较Vector2Array bytes。保原756有限组合，另加kind-only、精确脚底边界与dispose重建，共767比较／221663顶点。新runner还独立要求至少756／218484，helper失败传回原failures。

此测试由本代理准备，不能作为对自己测试设计充分性的独立签字；须root／另审者核设计和实际运行。这里只做Python编译和源码比较，未引擎parse。原730、708、GL44／命中12、真实route、原80／600及最终完整CI均需在新精确源按影响复验，旧结果不改源。美术／动作拒绝与G5仍保持。
