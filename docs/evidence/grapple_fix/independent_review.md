# 钩索小修独立审查

审查者：独立子代理 `/root/independent_review`。生产代码与测试均只读；唯一写入本报告。采用 `.agents/skills/gameplay-reviewer/SKILL.md` 的小修轻量范围。基线 `origin/feature/production-capability-repair` / `9ffe8e7c7d299a2d9cf710287c6c07e8c04b8385`。

本轮审查输入为实现者提供的冻结候选，尚未作为 Git 提交审查：

| 文件 | SHA256 |
| --- | --- |
| `/workspace/scratch/traversal_ability.gd` | `d30033d4f07566c6a6917b8d82407f5cbef5e873415e59082ddf844880ddb4ea` |
| `/workspace/scratch/traversal.tres` | `c2ea9c7584668f1332eea60b14cdcfd36b0759c0813a5078db2b91b02af18390` |
| `/workspace/scratch/action_budget_runner.gd` | `38f61395c5ef84c236afda8f10e6a7b1d5976108ddacbb8cb1ddb643794ca2da` |
| `/workspace/scratch/actor_actions_runner.gd` | `4e5d10db6353ac390235c5f2dadd487f87cf2708c13e2ff2cd8a25a390532adf` |

## 当前结论

**ACCEPT（限定钩索runtime修复与新默认动作专项技术范围）**。已核验旧实现真实red、新实现动作预算及actor-actions真实green，未发现本轮新增生产缺陷。完整gameplay profile与历史森林严格退出仍不能签通过，历史森林发现继承基线泄漏，详见补记。没有实际玩过游戏、观看 GUI/连续录像、听音或使用实体设备，不签玩家手感、设备或视觉认可。审查者未自行执行Godot；独立性来自只读源码审查、原始日志/trace直接核验与基线源hash比对，不能冒称独立重跑。

## 已读与方法

从基线 Git 对象读取 `AGENTS.md`、reviewer skill、`docs/current_state.md`、`docs/handoff.md`、`docs/architecture.md`、`docs/acceptance_tests.md`、`docs/quality/review_method.md`、`docs/player_mechanics.md`、`docs/design/player_actions/README.md`。比较四份候选与原 ref，追踪 PlayerController 的 `advance → Motor.step → after_move`、Motor 的唯一 `move_and_slide`、kick 的分数末帧运动、取消/会话与接触保护消费者。查看真实 EnemyActor、PatrolDrone 使用与既有 360°、暂停、恢复链测试。通过 Git 搜索盘点 `hook_range`、`hook_kick`、`hook_launch_seconds` 与 `TraversalDefinition.new` 消费者。

## 生产变更判断

- 射程 231 = 默认空中反冲 1100 × 0.14 × 1.5，生效于正式加载的 `resources/player/traversal.tres`，引导与真实探测共用同一 Definition。没有修改 PlayerMotor 基础物理。
- kick 使用配置两轴构成的向量与长度调用原 Motor burst；240 × 0.10 = 每轴24世界像素，原600 × 0.20 = 每轴120。末帧按剩余时长缩放仍由 Motor 负责，来路侧45°语义保留。
- 将抵达提交移至本次 Motor 后，以本帧采样的 hook_tip 为参照，解决逃离目标在下一帧再次移开停止圈的追逐超时。hook_pull 每帧请求，抵达状态立即变为 hook_contact_kick，因此同一拉近不会反复提交伤害。
- 提交前再次检查目标实例/树/active；伤害 event_id、目标 actor_epoch、回能回调保持原逻辑。墙阻挡失败判据保留原 stop_distance + 2 容差。目标自身接触保护、其他来源拒绝继承、取消清除和会话检查均未改。
- 取消、死亡和暂停的既有覆盖保留；新增死亡与中途新墙反例是必要补充。未据静态源码宣称这些运行通过。

## 测试质量判断

新增测试使用真实 PatrolDrone 场景、EnemyActor/AI/Motor，每次 player Motor 后推进敌人，刻意构造逃离目标最坏相序；未用位置注入伪造目标移动。左右目标 × 左右方向 × 30/60/120Hz 可比较同样的朝向和逃离情况，检查完整 pull/contact/kick、真实恰好一次伤害和镜像接触位置。旧实现应在逃离目标上持续追逐至0.8秒失败，此结论尚待原代码负例日志确认。

静态锚点400→310与峰值350→260保留目标前停止圈的相对关系，符合新射程。`refill_contract` 的200→70并未删除真实子弹命中、恢复D/H、再次钩中、接触后恢复与去重断言：该链先向右射击令角色左反冲约154px，旧200距离目标会在反冲后超出新231射程，迁移目标是合理的fixture适配。建议实现者加注释说明此因果。没有发现删除或降低相关伤害、动作恢复断言。

## 消费者覆盖发现

**IR-HOOK-01：旧森林开发H切片与新默认调参不兼容（集成风险，待实现者处理）。** `scripts/demo/thorn_forest_h_slice.gd` 的SPAWN=(100,582)、ANCHOR_POINT=(380,470)，从入口发射原锚点距离约299px，超过新默认231；原120px kick还承担到405高枝的平台路线。`tests/forest_h_slice_runner.gd` 仍要求真实hook_pull/contact/kick、完整身体稳定落枝和连续返程。因此未处理的全量回归不能宣称通过。

此处是未开放森林的历史开发消费者，不建议为本次钩索反馈重做森林。可用明确标注的独立历史 Definition 冻结原460射程/600每轴速度/.20秒kick，保留原路线与全部断言，同时新增默认消费者继续验证新短钩索；或者记录其显式不兼容阻塞。不得删路线、返程或关键事件以换取绿色。该建议不代表已观察该fixture真实失败或准入任何新森林内容。

后续只读确认 `tools/run_forest_h_slice_tests.py` 使用真实headless正例、missing-anchor、no-hook三次进程，并调用严格 `validate_forest_h_slice`；source_files涵盖tests下新增.tres，无须改源指纹工具。最小注入点可在test runner的 `root.add_child(world)` 之后、第一physics前替换已创建controller的Definition并重新采 `world.initial_snapshot`，不必改开发切片布局或授予逻辑。应另记录实际历史Definition path/hash/数值与scope。当前通用snapshot把 `config_hashes.traversal` 写死为默认resource，即使实际已替换也仍显示默认；历史fixture采证必须纠正这项或明确另给实际Definition记录，不得冒称冻结了新默认路线。

**IR-HOOK-02：严格旧事件位置合同需要复核（静态时序兼容风险）。** `tools/level_design_contracts.py::_validate_forest_causality` 为所有state transition生成 `position=previous_position`，再与实际action_changed事件精确比较。旧hook_contact_kick在advance前移提交，新版在after_move后提交，因此该事件的真实坐标将是当前frame.position。仅冻结旧Definition未必足以通过旧因果验证器。应先保留真实失败；如扩展验收器，明确旧/新时序版本，使新contact事件约束到当前frame.position，其余仍按原前移语义，并保留全部旧原件、事件/帧/返程/坐标故意失败例。此处不能通过删除事件或放宽任意坐标接受来处理；也可明确该历史消费者不兼容而不虚报全量通过。

## 待补证据

1. 新候选真实action-budget、actor-actions（30/60/120Hz）日志、退出码与完成标记；严格退出诊断。
2. 同一新增移动目标判据对旧生产代码的故意失败例，保留完整失败日志。
3. 森林历史fixture适配的实际差异与真实原路线正负例，或明确阻塞说明。
4. 正式消费者/GUI与手感若未执行则持续unverified，不外推技术范围结论。

## 运行证据与实现复审补记

2026-10-16 已直接阅读 `/workspace/gunman-rush-fix/build/grapple_fix/old_runtime_negative.log`，真实Godot4.7.2旧生产运行完成 `MOVING HOOK PROBE: 855 assertions, 12 failures`，进程退出1（日志Python包装器保留该退出错误）。左右逃离目标 × 30/60/120Hz 共6场，每场完整pull/contact/kick与真实伤害各失败一次；迎面方向未见失败。该负例证明新增移动目标判据可以拒绝旧实现，符合静态根因。

已审真实Git diff中历史适配5文件，IR-HOOK-01/02的静态最小返工已落实：只派生测试Consumer，使用显式完整冻结历史Definition；首次physics前赋值并重采snapshot；实际Definition path/hash及前后值绑定；capture与工具summary明确不覆盖默认短钩索。生产森林布局及原路线、返程、资源、能力断言未改。验收器仅对新历史schema固定使用post_motor，只有contact事件坐标取当前帧，其余仍取前帧；旧原件缺省走原pre_motor。新增phase+坐标连贯回退、错坐标、错tick、缺绑定、伪默认覆盖和资源hash等反例。尚未收到真实历史路线与Python检查结果，两个发现保持待运行关闭。

复审hash：forest runner `3792ed8b56c4026c49147c7a8f101b0a3752cf52fe7763fbae3a372c7c4c027d`；历史.tres `351c574ae571cfb4309467b2127c6ca80620b249830d900cc0436d3081fd9ca2`；level_design_contracts `5e4bdc00762ed7123c289db578ff6e2904de7fef65950b9b762f70f1c9bbbfed`；Python反例 `00a677572bf02d0b65cf64be5efde6fc3846e637caff811051e4235f513017a1`；forest CLI `4c1ab518775352e8ecc58598e48a83e92cc22cb3910317339cf6f2eab51a1a9e`。上述四份正式生产/动作测试hash与初审scratch一致。

早期日志出现runtime_raw_export插件缺目录警告，独审已反馈。实现者确认是sparse列表漏包含latest新增addons，随后已补物化该目录，project.godot未改。该初始准备遗漏不冒称完整导出验证；早期完成的负例只支持native动作行为，后续最终harness与导出须在完整物化环境分别取证。

直接读过初次新实现 `build/grapple_fix/action_budget.log`：7410断言/3失败，三项均为超距未命中后应保持空中hook_used；其余移动目标、真实损伤和小跳断言没有失败。实现者定位为fixture在100高度等待1.1秒后已经合法落地恢复token。独审接受仅该case观察窗口改为0.6秒：仍完整约束不拉近、已收回free、空气钩已消耗；完成miss/retract但早于700地面落地。未删断言、未改生产语义，且旧代码red仅运行moving_hook_targets，不受该窗口变化。初次失败须保留；修订后尚待最终fresh运行。

历史fixture作者报告Python全文件 `python3 -m unittest tests/test_level_design_contracts.py` 31tests/77.374秒/OK/exit0（另3个针对性case/0.127秒/OK）。此条是作者提供结果而非独审自行执行，待日志原件绑定；我未运行会写临时文件的Python测试。另已读 `tools/harness/profiles.json` 单行success marker同步，仍精确匹配完整PASS句，明确default short hook not covered。

已直接核对隔离lane新鲜 `build/grapple_fix/targeted-isolated.log` 的 `ACTION BUDGET: 7305 assertions, 0 failures` 与 `PASS: action budgets and shared aim`，未见该已完成段的ERROR/泄漏/Traceback。实际trace `/workspace/scratch/grapple-targeted-lane/build/action_budget/native_trace.json` checks7305/failures0，6hop/12moving齐全。root与lane `traversal_ability.gd` / `traversal.tres` hash与初审相同，修正后action_budget hash两侧均 `3228a50c45108e712ac3f5490148f4b2e93a6cff977d47974f07a1a5d3ac4907`。据此关闭超距case观察窗待验；新默认动作预算/小跳/移动敌人专项技术证据成立，完整actor与历史路线、总profile仍待完成。

原日志完整性hash：旧red `195494dc5f7f3f7823ed47257b7544cd62c271f6e4645e69c3b03304438357ed`，初次新fixture失败 `b732e7b17d157169dff0f32b879c4f9c318ff91bd2bb6bc2f1eadacae452bd82`，新鲜隔离lane动作trace `0749452f7cbb51e2ddcc5c658bbc7164c0e67d7b854710084eef7e7f68f6f05e`。

已直接核对同一隔离lane日志 `ACTOR ACTIONS: 2871 assertions, 0 failures` 与 `PASS: actor actions runtime and input`，动作恢复、暂停取消、八向与接触保护相关原断言实际通过。没有把专项native行为等同GUI/设备。

历史森林首个候选正例 `.../build/forest_h_slice/20261016T093912_800e3268/positive/capture.log` 虽186/0，退出有105ObjectDB、63resources、PagedAllocator与7Texture RID ERROR，严格失败成立。初始怀疑inner HistoricalConsumer脚本引用环，后经实现者私有lane实际拆分独立Consumer、world.free/drain、载入顺序对照均未消除，实验均回滚，不把该猜想写成根因。

独审直接读取 `/workspace/scratch/grapple-targeted-lane/build/forest_h_slice_diagnosis/diagnostic_report.json`、`baseline_original/positive/capture.log` 和 `capture.invocation.json`，并与 `git show 9ffe8e7:<path> | sha256sum` 独立比对：原runner `65959a9f54356a762e23cf4afbcc0d888f24c7e978ef55d90fa049e14efc9e3f`、原ability `22cf09902d784739cfd506b634904f46fb1d5b05bd6025703f965f90bf6189a7`、原resource `6e44331517c7acdc2a1e9eb6e0f066a782192206aec9095419fd5fc0f6b706c5` 全部等于baseline invocation真实源记录。原185/0之后精确同量105ObjectDB/63resources/7RID。因此该严格森林失败是继承的基线缺陷，不是本次钩索回归；原Godot进程exit0但严格statusfailed/wrapper exit1，不混淆。Snapshot单独preload可复现77/58/2、Controller单独clean只缩小候选链，具体根因仍未知。

IR-HOOK-01/02已完成静态最小兼容处理，历史路线功能断言与固定post_motor事件合同在候选正例186/0成立，但严格整体仍 **BLOCKED（继承退出泄漏）**；missing-anchor/no-hook本次未完成则保持未验。禁止把186/0改签clean PASS，禁止删退出守门。完整profile结论必须保留该已知阻塞，不影响钩索runtime限定技术接受。
