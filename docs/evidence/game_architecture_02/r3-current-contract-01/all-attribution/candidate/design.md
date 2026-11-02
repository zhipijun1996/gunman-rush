# 同一平台流程覆盖真实冲锋组／回冲腿

范围：仅既有 Bell legal_input_pilot 与实际 R3 capture 的外部诊断候选；不生产、不引擎、不主树写入。已读 e564 主树：两原工具 SHA 与此前原件一致。前一次首组候选的真实证明只限 group1/tick219..397/HP5/Platform1/两次1伤；全场1811帧死亡、3fail未消除，不覆盖旧记录。

设计已经 structure 因果审认可准备候选；代码仍须独审。

- 唯一 group key 为实际 groups_started；同一个 leg 子流程的 key 为 (group, group_plan.roll_index)。first/all 只改变准入集合，没有两套导航。index0必须原roll_warning；index1必须冻结return_roll为真、真实combo_warning且上一腿已实际落地。回冲方向读当前encounter.direction，绝不用不会反转的plan.direction。
- 每腿使用同一既存低台选择／支撑核验／rig前缘事件／普通跳流程。新组选择当前最低层实际台中最近者；返回腿沿同一已验证目标，不扫描新目标。若已有同台真实grounded，直接supported，无无意义登台跳。只有真实支撑才请求新跳，JumpAbility.maximum_jumps()==1且hook未授权，绝不修改 used_jumps。
- 上腿真实落地后，在仍属冲锋或combo_brake/turn/warning期间保持零水平输入和真实平台支撑，直到新的实际warning准入；neck/recovery仍由原两枪代码管理。各腿独立记录真实ground→air→换边→land、当前起始side及support ID。无法在本腿原warning内实际支撑则诊断失败，不延时／补平台／补跳。
- 新平台动作先于原wave_jump优先块；遇实际wave优先时不提交或宣称平台evade动作。原波浪输入仍执行，无法继续证明支撑／腿链则明确失败；不吞原波浪避让。ring/lob和原两枪恢复块逐字保留。一次诊断无参数或目标重试；策略失败会锁存，旧完整战斗的后续失败继续保留。
- 组窗口从首warning直到最后neck结束使groups_completed增加，含两腿、中间等待和恢复，HP及实际player结算均需无损。真实terminal可结束最后组，但收口必须同时有原真实HealthState terminal/0、原defeated信号、真实death事件和该组两次提交／两次实际1伤。缺件／invalid不是胜利；若第1枪就致死，不额外补射，将额外两枪诊断前提失败单列。
- 原metrics.events仅保256行，完整战斗可能丢首组；capture只读现有presentation_event，保存group／bell_hit／death真实事件，不更改生产容量。正常与released两收据共用一个只读validator。
- 避免O(n²)：每帧只写当前group/leg的标量、原生支撑、HP和输入；完整组/腿ledger与信号流只在最终receipt写一次，不每帧duplicate所有历史。

保原seed／HP／弹药／两枪上限／7200／180／25失败谓词及其他输入与收尾预算。无H、无碰撞／物理／随机变更。首组方案与新all方案各有准确source绑定，不追签前次失败。
