# P1 Boss 场地接线：四叶外部冻结候选

基线C8 `c8d39551bbe79b40895e96bdcdf8250c56939813`＋已冻结cancel三叶；本包只新增App/Generated/Plains/Thorn四叶差异。主树/引擎/远端未操作。**用candidate-relative-cancel.patch顺序叠加，不能覆盖App或Generated整个文件**：structure的damage候选也改这两叶。本包在外部有限镜像已实际检验 cancel→damage→boss 顺序apply/check，再逆序完整还原C8，最终栈SHA在candidate.json；不是仅凭不同行号推测不冲突。

原次序保持：App原Boss存在性、completion/伤害绑定 → generated.configure_boss_arena（原arena x+25/end-25，忽略原configure_arena返回；forest_floor y；has bind_duel时原manifest/四窄服务bind）→ connected的Plains.restore_boss_after_binding（empty no-op，原duel拒绝或position再Bell terminal restore/synchronize）→ fixed入口仍原890/1240 → generated且Windkeeper的modules循环+groundsupports绑定/ordinary restore → Pressure且terminal时原nonempty saved恢复+bridge恢复 → connected seal创建、状态隐藏、add_child/setup/restore、boss_enter add/可选activate → 原弹体信号、activate、contact策略、UI/reward等。App两条push_error/abandon_run/return保原错误内容与对应拒绝阶段。

Stage只接具体Encounter/player/controller/policy/lifetime/segment与显式connected，不接App/Director/RunSession。restored_boss既有数据仍归Plains；没有新复制、schema、默认字段、恢复引擎或条件guard。Generated只管它拥有的boss_arena/generated/assembler，不反向看Plains或Thorn。Plains封印隐藏hook只判Bell；Thorn override先super(Bell短路)，否则原layout==ForestTargetHosts.LAYOUT。Plains entry返回原x+70/y-18；Thorn override委托既有forest_boss_entry_position，旧函数及其现有spawn调用不动。避免base→derived新引用。没有移走App两阶段激活后restore、intro_seen政策、contact精确test、projectile信号或奖励职责。

类型检查：configure/restore/seal使用现有BossEncounter；其已有configure_arena/restore_region_position，Bell专属restore_combat_state在原Bell条件下显式as Bell。Windkeeper几何API仅Windkeeper类型，Pressure terminal helper仅Pressure类型；所有当前具体Boss继承原BossEncounter，无新增万能context/dictionary registry。configure_arena返回false原来忽略，本候选仍忽略，不把它升级成新的拒绝；仅原bind_duel false触发App原错误1，restore_bound_duel false触发原错误2。

证明范围：四文件逆变换整字节相同；App分支外前缀及projectile/contact/reward后缀完整相同；geometry loop仅owner限定符/缩进变换逐字同；原错误字串/abandon/return保留；原entry/geometry数值无修改。有效运行对象和原显式false拒绝合同由这些源对应证明，未声称未知损坏节点的GDScript异常堆栈位置不变。未运行native/parse，不把静态证明扩成full171结果。

root后续原R3/Boss/restore检查：实际App地图1 Bell、地图2 Pressure（普通geometry与terminal bridge两支）、森林实际duel初装和激活后restore、非generated fixed Boss。现有tests/forest_depth_restore_runner.gd已有invalid snapshot/位置/health拒绝，既有R3与Boss专项覆盖原接线。用户退役旧地图内部路线/golden不在本候选重引；原命令和预算由root现有注册选择，测试文件/profile/预算没有变化。
