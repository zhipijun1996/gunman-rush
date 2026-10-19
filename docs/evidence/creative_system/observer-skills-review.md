# Observer与Skills独立只读审查

审查者 `/root/pr_cost_audit`。未修改被审代码、测试或Skills。审查依据为本轮工作树diff与 `build/creative_system/observer/` 原件，不签美术、市场、实体设备、完整CI或发布。

## Skills：ACCEPT_SCOPED（可逆文本精简）

独立执行逐文件检查，16/16归档：

- SHA256与 `docs/archive/skill_history/manifest.json:/files/*/sha256` 完全一致。
- 归档字节与 `git show e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7:.agents/skills/<skill>/SKILL.md` 逐字相同。
- 原字节及当前字节均与manifest一致；机器结果 `scratch/creative-audit/skill-sha-verification.json`。
- 旧16份186700B→当前16份171877B；新增前置Skill3513B后175390B，净减11310B/6.06%。这是默认Skill源文本量，归档及公共入口另计，不能代表实际Agent已少读多少token、包体积或运行时间。

阅读全16份diff，删除主要是共同的输入列表、准入/返工和质量证据重复段，转交当前 `docs/creative_direction/README.md:33–41`；Boss的阶段学习/反冲/竞技场/完整战斗/死亡优先唯一奖励、enemy的真实行为和生态接入、challenge的动作链、art的素材接口及scene的合屏职责仍在对应Skill。归档历史章保留原件，当前提取必要通用规则，没有发现专属职责被整块误删。此结论限结构和内容审阅，不证明今后Agent会有效使用、实际执行成本已下降。

## Observer：候选1暂REWORK，候选2待冻结证据

已独立复算原物理负例 `baseline-negative.json` 对 `candidate1-negative.json`，不是只引用作者的comparison：两者5断言/2失败/native exit1不变；816帧、33事件、11资源收据、22policy观察、diagnostics、claimed=false、outcome=route_policy_failed、initial/final capability逐字段完全相等。state.done由false变true，原baseline stderr有20ObjectDB/7资源，候选无此终态。表明这一真实失败路径可协作退出且未删原物理失败。

四文件初版未改输入数值、HP、敌人配置、断言、严格错误matcher或生产物理；`formal_reward_entry`原`app.queue_free();await process_frame`不变；外层等待由`not state.done and not driver.terminated`改为`not state.done`，确保协作调用栈结束后再卸载。`finish`取消守门避免覆盖既有fatal结果。

独立审查发现初版仍有遗漏：

1. `plains_region_trace.tutorial()` 的await move_to即便取消false，仍调用traverse；`deep_trial`疏散段await tick后仍可能request drop_through/interact。
2. 祖先traverse/spatial_path及motion helper仍有未传播取消的边界。单一路径816帧等价不能证明所有终止后均不再产生动作。
3. `level_formal_trace.tick()` await prepare_threats后，若内部已fatal，应先取消return，防止safe=false覆盖原fatal outcome。

已向实现者发送并得到确认，候选2正在补最小guard；未代替实现者编辑。外部motion helper的tick callback取消责任还需明确限制。

## 原失败与正例证据边界

- `matrix-final.exit=1`、`formal-final.exit=1`保留；日志明确`source drift or native diagnostic`、`source snapshot changed during capture`/`source snapshot mismatch`，不将route_target_reached追签为capture通过。
- `matrix-stable`仍因source freshness失败，不用其中已完成单项宣称完整矩阵成功。
- `formal-stable/result.json` captured=true/errors=[]、2287frames/route_target_reached仅代表其冻结源。
- `native-final/result.json`的native/recovery/heart/note四进程exit0；`boundary.log`10tests passed；`budget-stop/result.json`30frames、frame_budget_exhausted、captured=true，均只接受对应范围。

候选2冻结矩阵及最终diff尚未收到，本审查不预签完整observer修复或完整CI通过。

## 候选2静态复审（等待最终执行）

已复读5文件171插入/9删除的新diff：新增 `plains_run_trace.gd` 的traverse/spatial_path入口及await后取消守门，`plains_region_trace.gd` tutorial、deep疏散、反向/井铃方法以及祖先random_stage traverse逐段增加guard；tick在prepare_threats后先取消return。初审指出的具体遗漏已修。新改动不改变物理、输入数值、HP、断言、原卸载调用。

当前 `/workspace/observer-validation/build/creative_system/observer/isolated-snapshot/diff-stat.txt` 为候选1的4文件75插入/9删除，与当前候选2五文件SHA不一致，故其中11正例及原负例结果仅属候选1；不得签成候选2最终fresh矩阵。作者已确认将保留候选1并对候选2新目录完整fresh矩阵及正式return/预算停止。

## 最终结论：Observer候选2 ACCEPT_SCOPED

此结论覆盖前文“待冻结”的暂态。已独立读取 `build/creative_system/observer/report.json`，并访问隔离原件 `/workspace/observer-validation/build/creative_system/observer/candidate2-matrix/` 和 `candidate2-other/`；没有执行被审代码的修改，也没有只依赖作者总报告。

独立核验：

- report绑定5个源SHA与共享工作树当前5文件逐字hash一致；冻结基线为 `e8ee34446aa82b4e64f5cdc414a22f5b6e2a6ca7` 加这5文件改动，不含并行美术/游戏改动。
- `candidate2-matrix/result.json`14runs：11正例exit0，3原物理负例exit1；每run source_before==source_after，原JSON和log SHA均重新计算一致。32个validator_refusals保留。
- 独立扫描14原运行日志，未见ERROR/SCRIPT ERROR、泄漏warning或resources仍占用；3个exit1保留原物理失败，不伪称物理通过。
- 对 `reward_original_conflict_kill.json` 与原baseline再次独立逐字段比较，816frames、33events、11resource_receipts、22policy_observations、diagnostics、claimed、outcome、initial/final capability完全一致；baseline20ObjectDB/7resources消失，state.done=true，原5assertions/2failures/native1保持。
- `candidate2-other/native-result.json`4个真实原生/恢复进程，报告106断言/0失败；formal-result捕获true、2287frames到原route目标；budget-stop-result捕获true、30frames、frame_budget_exhausted；candidate2边界10test通过。三个candidate2外层exit文件均0。
- 便携 `candidate2-evidence.zip`6823025B，SHA256 `bcedd0b2ebe9603df151e2bb2701fccbe82f0a53cd6aed415fdc3a76835c904f`与index一致，ZIP testzip通过、73成员。

可接受的声明：原encounter reward矩阵与受验预算停止路径的协程已协作退栈，保留真实失败/输入/资源/HP/卸载语义，并严格干净退出。取消后直接祖先方法不再继续发后续动作；外部静态motion helper内部所有callback的通用取消仍未全面覆盖，不能宣传“任意trace永久安全”。原完整run_plains_encounter_policy_tests专项、冻结历史对、并行美术集成后的完整fresh回归、完整CI和发布均未在本次冻结中跑完；需要在最终集成源继续验证。先前source drift拒绝和原始失败必须保留，不能因本次有限通过改写。
