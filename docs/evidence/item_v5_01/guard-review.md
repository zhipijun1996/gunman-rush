> 阶段说明：下文保留首次新增14项阶段的独立审查。后续新增pause-escape／random-context两项的窄增量审查另见[增量报告](guard-review/addendum.md)。源码与绑定以后续实际版本为准，本审查不代签后续生产改动。

# ITEM-V5-01：守门、版本与测试迁移独立审查

审查者 `/root/ci_audit`；基线 `879b39eaa869be70cb799dedd1bb6ffc35e0b92f`，分支 `feature/item-v5-catalog`，工作区未提交版本。采用 `gameplay-reviewer`、`project-integration`。**ACCEPT：仅接受本报告所列守门／版本／fixture迁移及追加 Harness 合同；72件实际效果、完整CI、画面、设备与G5保持 UNVERIFIED。**

[机器报告及逐文件SHA](guard-review/review.json)记录本轮精确读取源；最终 Harness Manifest SHA256 为 `492d3f780a443f29307239ad5dd2faae7e467c41b35155b22e46560e683e595d`。审查者未修改被审的生产、测试、工具、配置或权威绑定；发现由 `bible_guard_review` 与 root 修复后复审。本审查没有启动 Godot。

## 保留与实际执行

- 原176个check全部保留；旧check的命令、成功标记、超时、serial/cache设置未改。仅region-bible输入由139项原序前缀追加48项至187；creative检查在修复后整个对象与基线完全相同，恢复默认全源摘要。新增14个V5检查，原gameplay/full顺序保留，full由144追加至158。
- 原Bible32和方向10个测试方法均未删除。style-v14原件完整保留；新v15保原36项顺序，仅DemoApp SHA变化，另外35项完全相同，再追加18项，共54个实际字节匹配引用。creative-v17两方向与registry归档逐字等于基线，旧版本拒绝、G2/content及未正式开放边界仍在。
- 06表B23:B25实际为35／55／80，与容量配置8→10→12→14一致。UI显式收入fixture改读配置总价，仍点击原购买入口、检查实际quote扣款及容量；原库存专项的余额不足、同ID重放、冲突、过期、回滚和14上限断言保持。真实V5宝箱领取断言保留，分数生命检查改用独立来源的旧道具fixture，未改宝箱道具。`% creation`→`% [creation]`只修GDScript格式操作数。
- 两gear wrapper只增加通用`ERROR:`拒绝；原`run_tests.run_engine`逐字未变，非零退出、脚本／shader错误、泄漏、超时仍失败。新V5 wrapper每家族要求唯一完整标记、最小实际断言数和0失败；固定import90s／native120s，外层240s。
- 新13个native检查保留`assets`实际摘要目录，并追加原preflight识别所需`assets/**`与真实import哨兵`docs/.gdignore`、`build/.gdignore`。未改全局preflight或旧检查。

独立实际运行原入口：Bible **32/0**、方向 **10/0**、数据 **27/0**，原30／60／60秒预算未变。仅六个声明文件的隔离数据入口也27/0；region187个声明文件加原Harness入口／SKILL存在性bootstrap，隔离原32/0。不是“只凭187文件独立运行”，也不把availability探测称完整运行闭包。

[wrapper反证](guard-review/wrapper-controls.json)：43项synthetic parser／命令正反例和7项真实小Python子进程守门全部符合预期，涵盖缺标记、低于下限、非零失败、重复V5标记、错误家族、引擎错误、非零退出、泄漏与真实超时。子进程明确替换为Python，不能计为Godot或玩法通过。

## GUARD-F1：真实拒绝与修复

初版creative检查新增120个有限inputs，遗漏`level_region_context`真实读取的上下文依赖。独立[正反例](guard-review/finite-counterexample-r2.json)在隔离副本以原10测试先exit0；仅删除未声明的`docs/quality/action_budget_spec.md`后原CLI exit1，旧有限input_digest完全不变。**该版REJECT**，不把全工作区10/0或先前availability ready签为完整依赖闭包。

实现者恢复原默认全源合同；同一删除现在改变原全源input_digest。修复后独立重跑原32+10全部通过，guard迁移范围复审ACCEPT。第一轮反证的正例因未复制隐式SKILL存在性依赖而失败，原件保留，未追签；实际成立的是r2正反例。

## 范围限制

本审查不重签root的native、GL或影片结果，不评72件完整行为／联动／平衡，不评画面和声音，不代签实体设备、玩家或G5。新native哨兵通过静态合同核对，未独立用Godot删除它们验证导入。原完整CI、真实正式消费者和功能独审仍分别以其原报告为准。
