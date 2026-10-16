# 创作loop独立只读审查

范围：tools/production_loop.py、tools/region_creative_direction.py、tools/level_design.py及三个直接入口测试。审查未修改被审生产代码/测试；Skills为本代理此前实施范围，因此不自签Skills审查。本轮结论：REJECT（创作输入schema与来源闭包存在可复现绕过），不等于玩法/艺术品质评价。

## 实际验证

- `python3 tests/test_production_loop.py`：97 tests / 32.522s / OK，退出0。
- `python3 tests/test_region_creative_direction.py`：9 tests / 0.510s / OK，退出0。
- `python3 tests/test_level_design_routing.py`：16 tests / 0.514s / OK，退出0；包括route真实命令与预期REJECT报告。
- 另运行 `/workspace/scratch/creative-audit/creative_independent_probe.py`（临时目录+真实文件字节），结果保存在`creative-independent-probe.json`。这是独立新增反例，没有修改项目断言。

## P1：生产执行入口接受不满足区域总谱schema的JSON

`production_loop.py:91-114`只核JSON schema_version/region/version/selected/acceptance，而`region_creative_direction.py:13-50`要求的12类创作覆盖、2–3候选、专业推荐理由、来源、user_confirmed原始证据完全未复验。独立负例用仅五字段的JSON（schema_version/region_id/version/decision/acceptance=user_confirmed）与真实文件hash绑定：full validator明确20类错误，但loop creative_direction_input直接接受。因此手工mission可绕过route的完整校验，而且把没有用户证据的user_confirmed送进prompt。

`tests/test_production_loop.py:1547-1556`的最小direction fixture同样不符合完整总谱schema，现有绿测试固化了两种不同契约，不能证明执行器满足区域总谱门槛。应让执行器复用同一full loader/validator，并把fixture改为完整合法总谱；加入缺覆盖/缺候选/伪用户认可calls0负例。

## P1：路由后权威源变更没有使总谱失效

full `load_direction`检查authority_sources实际SHA（`region_creative_direction.py:65-74`），但loop每次仅复核总谱JSON本身SHA。独立反例先生成合法完整总谱，引用真实authority.txt；绑定后只改authority.txt。full loader拒绝Authority changed，而loop仍返回该总谱content。来源变更当然会改变全源码snapshot、影响旧loop恢复，但新建evidence执行同一旧mission仍会接受过期权威；这不满足“源变化须RETHINK并复验”。建议执行器调用统一full loader，预检失败calls0，恢复与每轮调用沿用该检查。

## 有效行为与范围

- RETHINK/DISCARD在`production_loop.py:1357-1363`停止该task、标preproduction_required/quarantine_required；依赖阻塞而无关task继续，原calls不退款，恢复不重跑已终止任务。对应新测试实际通过。
- REWORK沿原预算/原质量门槛，不允许实施者自accept。source变更不能直接收到accept，host lease保留creative source_inputs独立hash；新旧collector兼容测试实际通过。
- compact反馈保留最新result/findings、evidence与checkpoint路径，磁盘完整history不删，旧mission默认full。它没有汇总旧轮未解决finding；目前可按路径追读，不能声称自动提炼全部未解决问题或“连续两轮无实质画面进步”已有结构判定。
- DISCARD目前是控制面隔离标记和依赖阻断；stop_reason明确manual isolate。未自动改变Godot正式消费者或export清单，不应声称已完成候选资产物理隔离。此范围只可接受为停止投入决策，不可作为包体隔离证明。
- loader结构完整不证明2–3方案真的有实质创意差异；仍须专业/独立整体审查。当前测试不签用户、设备、市场或艺术品质。

## 复审要求

修复两项P1后重跑三个直接入口及独立负例；后者应两个loop_accepted=false，伪user_confirmed/missing覆盖须预检calls0，合法完整总谱仍能被路由和worker消费；旧无创作字段mission/collector的兼容保持原实跑结果。无须扩成大范围Godot物理回归，此变更不触玩法消费者。

## 修复后独立复审：ACCEPT（限定工程范围）

保留以上原REJECT及原`creative-independent-probe.json`，不改签旧源码。复审时仅只读被审源码，未修改生产实现/项目测试。修后源码逐文件完整SHA256保存`creative-rereview-source-sha256.json`，其中：

- production_loop.py `f08cd5653785df1cf4e0f52049217fe25e75c52f69c930bc86e37b8664a37801`
- region_creative_direction.py `bb9dfb52360c2ebd8d3177d09be05d648cf84b8247be6ed3bb14ec609531b696`
- level_design.py `9490494bb82238c40cf9e2b8e951c5912d0abe207052643aca4730f343c8a187`
- check_quality_diff.py `5690d5c3d57c7eb3a2d621a1ec146f4f3d9b75dcf1c55d439ee86426b4e6c949`

执行器现在每次调用统一完整loader，复核总谱所有schema、权威实际字节；严格JSON读取拒绝duplicate keys；user_confirmed须source/quote/scope。旧最小fixture已改完整合法总谱。独立probe保留相同实际缺项与authority篡改，但在scratch副本仅添加捕获预期ValueError以记录结果：`creative_independent_probe_fixed.py`输出`creative-independent-probe-fixed.json`，两项loop_accepted均false。合法完整总谱仍在对应测试通过，非法输入在calls0预检停止。

本次针对复验（未无意义重跑整套旧97）：

- `python3 tests/test_production_loop.py CreativeLoopTests`：11/11，2.689s，OK，退出0；覆盖full schema/authority/duplicate/user_evidence的calls0、RETHINK/DISCARD依赖闭包、REWORK、lease hash、紧凑反馈与重复finding判停。
- `python3 tests/test_production_loop.py CompletedReviewCollectionTests`：10/10，4.202s，OK，退出0；旧collector与新创作source终态恢复兼容。
- `python3 tests/test_region_creative_direction.py`：9/9，0.695s，OK，退出0。
- `python3 tests/test_level_design_routing.py`：16/16，0.478s，OK，退出0。
- `python3 tests/test_quality.py QualityTests.test_connected_root_constant_uses_existing_finite_family_adapter`：1/1，0.014s，OK，退出0。

新增的quality消费者适配没有扩大信任目录：`known_asset_consumers`先调用原`runtime_contract`核对connected的固定ROOT、literal read_family白名单、family JSON与raw纹理SHA，再仅对`relative == CONNECTED && value == 'res://' + CONNECTED_ROOT`这一目录常量跳过“必须是文件”误报。真实fixture保留family/raw消费者，改成unregistered_family仍按“calls changed”拒绝。原raw包哈希验证未改。因此限定适配可接受，不等于批准任意目录或新资产家族。

当前ACCEPT仅覆盖：版本总谱输入/来源闭包、原生产控制面语义/恢复兼容、该精确消费者常量适配。DISCARD仍是停止与隔离要求，真实撤出消费者/导出需另证；AI主题判断、用户最终认可、艺术品质、设备、商业表现与整区生产不在此验收范围。

## 新增native_import_preflight独立审查：ACCEPT（控制面/文件边界）

本次仅只读审查`tools/production_loop.py:1204-1289`、路由新mission flag与3项对应测试，未修改被审生产代码/测试。完整源码SHA256另存`native-import-review-source-sha256.json`。它针对真实host期间出现的新UID sidecar source drift做事前导入，不能改签原失败或使原旧租约恢复通过。

检查结论：仅mission显式boolean flag且目标目录尚无state.json时导入，使用原tools/godot.sh、版本前缀4.7.2 stable official与原strict harness.run_check。import前后真实snapshot比较只允许新增`.gd.uid/.gdshader.uid`，必须对应before已存在且after字节不变的普通非symlink源；UID载体同为普通非symlink且满足uid://格式。源变化、删除、已有UID变化、其他新文件与孤儿UID均记录rejected_changes并calls0 blocked，不做自动回滚、不消失失败。旧mission无flag时原路径不变；已创建state恢复时不再import，仍按原mission/source/worker/预算/phase校验，不能用预导入冲掉恢复来源漂移。

finally无论成功、引擎失败或异常都尝试after snapshot并写receipt；run_check实际异常时创建诊断log，保存原error、时长与log SHA。判定还额外拒绝通用ERROR/parse/script/shader行，不放宽原engine/lifecycle检查。receipt/state失败均不会分配worker调用预算。

实际针对验证：`python3 tests/test_production_loop.py NativeImportPreflightTests`，3 tests，0.103s，OK，退出0。测试使用真实临时Git/文件系统、明确SIMULATED importer，覆盖合法两类新UID与恢复只导入一次；源/未知/已有UID/孤儿四拒绝类calls0；引擎非零退出保留失败。另独立scratch探针使run_check抛OSError，实际得到blocked/calls0、log存在、receipt.error保持原异常、时长与log SHA均保存（`native-import-exception-probe.json`）。未运行Godot，此处只接受上述控制逻辑与文件边界；实际pinned Godot导入/退出与当前源消费者验证由主任务另留原生receipt，不把模拟当原生通过。
