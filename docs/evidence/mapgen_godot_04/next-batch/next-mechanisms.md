# 下一批候选：先复用单钟门，不扩当前范围

本文件仅为下一批建议，实际完整内容和所有出现位置见 next-mechanisms.json。选择键是 module_id + content_version + role，再核实际连接；M 编号只标识本次 result，不是稳定模块身份。不换 seed、不 reroll，不删除模块中的困难机制来凑通过。

| 顺序 | 模块 / content_version（完整值在 JSON） | role / 本次位置 | 完整内容与判断 |
|---|---|---|---|
| 1 | game-plains-windchime-lesson / b2ee44df… | start；930001 M01、930007 M01 | 2个平台、1个 safe_lesson 钟门，open_seconds=0；无敌人、奖励、hook、伤害体、船、Boss。最小下一批。 |
| 2 | idea-plains-hq01-001 / 8c7d1809… | traversal；930001 M14、930007 M24 | 4个平台（其中1个单向）、2个 linear ferry P/Q、1个 group_motion 同步钟；无敌人、奖励、hook、伤害体、Boss。完整实现同步控制后才可接，不可只装两船忽略钟。 |
| 后置 | idea-interface-s11-001 / 69e52157… | traversal；930001 M24/M38/M39、930007 M29 | 6个平台（2个单向）、1个钟含 gate + paired_gate、initial_open=B、open_seconds=0 和返回/附加访问点；无敌人奖励hook。虽然原清单组名是 timed_gate，实际是双门合同，不能当普通计时门。 |

首选真实邻域：930001 的 M01.exit 经 C001 接 M02.R（idea-interface-s12-001），邻居包含敌人1、移动船2、HQ机制1；930007 的 M01.exit 经 C001 接 M02.L（idea-spec02-s12-001），邻居包含移动船2、HQ机制2。两图均保留原未连接 entry 封口，physical_validation=NOT_RUN。首选仅表示完整单模块最小；不授权把邻居也当已支持。若下一批要求跨缝，应单独纳入完整邻居及原封口/端口验证，不能删邻居敌人或重新挑图。

第二候选实际邻域：930001 M14.L 经 C012 接 M07.L（idea-spec02-s12-001），M14.R 经 C022 接 M15.L（idea-interface-s12-001，含敌人）；930007 M24.L 经 C028 接 M14.B（batch30-block-n04-0-2，含钟和奖励2），M24.R 经 C040 接 M33.entry_left（game-route-junction）。这说明“本模块无新敌人奖励”不等于整个相邻子图无新机制。其 route 记录 jump/shot_recoil，最低能力条件 status=partial，不需要据此授予 hook，也不能据此保证当前玩家整段可达。

原宿主可复用边界（来源 d4e17def，叶 SHA 见 JSON）：

- game/world/components/shot_latch.gd:67 的 setup 绑定真实 PlayerController、DemoLifetime、钟和门；133/137 是原射击/投射物接收，181 是原受 epoch/session 约束的提交，217/225 处理取消。单钟门应复用这些真实行为与正式表现，不新建伤害/钱包/弹药权威。
- game/world/components/generated_shot_latch_encounter.gd:7 已是正式生成房间消费者，但 setup 依赖现有 manifest/RandomStageAssembler，不能把 runtime-map Dictionary 硬塞成旧 Manifest。下一批需要窄装配映射，保原模块数据与生命周期；不修改随机规则、奖励或资源消耗。
- 当前 runtime_map_v2_provider.gd:10/289 明确拒绝非空 latches/approved_hq_cells，所以以上仍是待实现候选，绝非当前已支持。
- ShotLatch.bind_motion:408 现有接口只绑定一个 ModuleMovingPlatform；不能宣称已支持 group_motion 两目标。若选第二候选，先查原同步机制真实接口，保持两船相位/顺序/取消，不能复制一套通用船控制器或只用单目标代替。

下一批最小验收建议：以本次固定 result 指纹选唯一 start/safe_lesson 完整模块；保两平台、钟门和原封口；使用真实 Router 枪击观察门开放、重复命中幂等、取消/退出后不提交；验证 PlayerServices/钱包/伤害 owner 唯一、不授予 hook、不添加奖励。原 start.routes 为空，因此不能将模块存在当作路线资格证明；跨缝与整图仍另验。

13/14 个机制组少于旧0.3的17组，是两份真实0.4布局选出的完整模块组合改变，非删除字段：新分支已按原 ZIP compiled 根字段/数组长度及 exact content refs 检查结构，缺字段、清空船数组等实际负例均拒绝。默认图未选出旧 closed_polyline_loop/toggle_ferry/hazards/refresh_carried_enemies，gears 有 hazards，故分别13/14。新行始终 UNVERIFIED_CURRENT_HOST（未知）；已有12项有限宿主检查只证明选定 loading slice，不能签全图、所有机制、物理可达或奖励可领取。
