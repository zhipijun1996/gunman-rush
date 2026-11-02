# CI registration 非作者窄审

审查对象：`ci-registration/candidate.patch`，SHA256 `cdce329cb27939e553e220782aa6772138bfb150e88cd70b285c8cd37873b5b2`；freeze四文件的当前candidate及Git30e36c9a基点SHA均已独立核对。**无阻断发现，接受这份CI注册候选。** 没有运行Godot/Chrome、planner测试或修改生产；只读比较JSON/AST并阅读作者原日志。

- 原219个check的完整定义逐一完全相同，命令/timeout/success_pattern/inputs/serial等均不改。只新增runtime-map-v2-host，180秒、固定60FPS、serial、非零assert/零失败严格marker及实际native.json artifact。新inputs逐路径包含真实20个source/UID/fixture及复用的原LevelRuntime/RunComposition/表现/工具链依赖，不设全仓兜底。
- 原full171与gameplay156是新数组精确有序前缀，各只尾加新check到172/157；其余profiles完全相同。当前full分lane为92 parallel＋80 serial；未删除旧项或扩大旧预算。四个Bible/direction保护check也完全不变，不刷新style34 SHA。
- impact policy只给原world domain的development/integration尾加真实新消费者，新增一个20条精确路径rule，其余旧rules原序及always_full逐字JSON值相同。Planner所有函数AST与原件完全相同，只有已有EXACT_EXPERIMENT_CONFIG表新增七条resources/levels固定文件，且每条绑定固定rule/domain。旧pilot例外和EXACT_MODULE_CONFIG全保。
- routing逻辑仍要求路径在硬编码表、rule.id、domain及rule.paths全部吻合才能优先于resources共享边界；unknown resource即便只在policy扩glob/加path仍forced full，unknown experiment/test无owner也full。共享DemoLifetime/工具配置也沿原规则full。game/world未知邻居仍是原来已有world ownership行为，不能把它误报成此次新增全仓例外。release路径依然交原deliver，不由plan签成功。
- 原48 planner方法名全部保留，其中47 AST逐字同；唯一历史lane方法只在原C59重建/hash/144..185断言之前断言新tail并投影去掉该tail，结尾恢复外层manifest。独立逆AST：移除新增三条顶层语句并把结尾恢复名还原current_manifest，完整方法AST与原件相同，故原循环、预算、断言均保留。新增第49方法另钉旧171/156完整有序canonical SHA、新172=92+80、20path digest/affected selection、shared/unknown full以及policy单独加unknown不能绕过。

已有执行证据：作者planner-tests-03.log为49 tests/OK、0.209秒，外层记录0.365秒/30秒cap且四主树前后hash相同；01 wrong-selection-label和02 runner-UID漏inputs导致的真实失败保留。最终Planner只额外解释注释，函数AST未改；本审没有重新执行这些测试。freeze中的new_native_status=not_run是CI作者预备阶段边界，不拿它覆盖root后来运行。

另已读取root提供`/tmp/mapgen-host-native-04.log`与当前`build/mapgen_host_v2_01/native.json`，两者一致报告受控slice150/0及三次音频released=true；未由本审运行。它不是已注册Harness check执行、full172、Web或设备通过。本附件只签上述四文件的注册/保守routing/历史断言保护，真实新CI同源运行由root收口。
