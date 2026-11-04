# CI完整输入计划排序修复：独立复核

结论：限定ACCEPT两文件修复，无阻断。审阅者`/root/review_ci_contract_repair`不是实现者，未修改被审源码、index、ref或PR，未启动Godot或浏览器。

原run41714871138/d5cbdb9的失败保留原身份：原计划包含179个完整唯一检查，但现有production.make_plan把便携/docs检查提前，顺序与full profile不同。旧exporter把这两种职责混为同一列表等值而拒绝；尚未执行179正式lane，不是算法或测试失败。

仅bundle_contract的完整覆盖授权从同序full列表比较改为长度与集合相等。原计划source/HEAD、full_lanes路线、plan.checks与CLI选择逐序相同、原计划原字节SHA继续保留。全部HEAD/index结构、path/mode/blob/SHA、原receipt原字节、same-run、tar安全、无覆盖、预检与磁盘检查实现AST未变。执行lane继续使用原profile顺序，全部179检查定义、argv/预算/marker与profile文件原字节未变。

独立核验88项全部通过；原45个测试方法的body与参数AST全部保持，新增5项。独立实跑50项纯测试，8.909秒/0失败，包含真实planner便携前置排序正例、真实小稀疏Git工件导出恢复、缺漏/额外/重复/CLI顺序和原计划重新编码SHA负例。

独立读取原CI原始pre-execution-plan，SHA8388ff904b4afb4016f5d9e4793c6ab88522965a5a5c17b658a0812356828b5a不变；用现有production.make_plan原changed_paths重算得到逐序相同的179项，并在实际仓库相同Git HEAD/index运行修复后metadata contract，返回原179顺序和原计划SHA。缺漏或反序CLI仍被拒绝。

限制：该probe是WIP修复的真实输入契约复现，不是新head完整CI或4.43GB打包证明。旧run未重跑、旧失败不改绿。下一候选仍必须实际完成输入工件导出/上传/两lane恢复、完整179+affected验收，不代签原生/Web、设备或整图。
