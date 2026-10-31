# plains-encounter-policy：attempt2超时定位（只读）

真实输入：CI39969481754 attempt2，source `8ca6b1373ea65c2cfcf897a1d3c30be680c44a6d`。serial.zip SHA256 `1e104f9fc94bb8ac99f76ff37056e6d34301ea8f917dbd2c35efaf10751aa5e8` 与提供值一致。只读ZIP中央目录、Harness报告、各invocation/receipt、小日志；不全量解包、不读capture大帧数据、不跑native/CI、不改root。

## 可证结论

**外层整个check的600秒总预算耗尽；停止时已进入最后bait capture。现有证据不能证明bait死锁、玩法逻辑错误或自身240秒timeout。** Harness `15:04:40.648` → `15:14:40.701` UTC，实际 `600.053`s，status timeout。最后bait invocation初始mtime15:14:14，距外层deadline约26.7秒；bait日志15:14:18已有真实平原assembled，无SCRIPT/Parse/SHADER/ERROR诊断，尚无完成capture。它没有获得capture_one默认240s的独立时间。

主stdout只见24 Python tests并不代表原生阶段未执行：该脚本在原生多阶段中不向主stdout打印progress，结果/日志写独立文件，最终成功marker和aggregate receipt仅在末尾。此次无最终marker、无run_elv06x16/receipt.json，因此整check必须仍记timeout，不能改签通过。

## 实际已完成范围

- 边界Python自测：24 tests / 3.130s / OK。
- cancellation：独立receipt status passed，exit0，完成mtime15:05:06。
- reward entry：14份实际进程receipt。11份正常exit0；3份是有意恢复不安全入口/回程的物理反例，exit1且expected_physical_failure为true或return，属于原设计负例，不是新CI失败。所有14份receipt只有经过cleanup、身份及capture validator后才写出；reward_validator_refusals.json还保留32项拒绝名称，完成mtime15:09:30。
- native：55 assertions / 0 failures / 14 cases，日志mtime15:09:34。
- recovery：17 / 0 / 1，mtime15:09:56；heart20 / 0 / 1，15:10:22；note17 / 0 / 1，15:10:44。脚本只有通过native validator才能进入后面formal阶段。
- 四个current formal capture：全部invocation accepted、errors空、exit0。随后after_report.json已产出（mtime15:13:34）。
- 独立same-source return replay：accepted、errors空、exit0；同源comparison.json实际产出（mtime15:14:08），manifest/action均未变化、统计delta0。comparison verdict REVIEW是比较报告正常语义，不是这次超时失败。脚本能够进入bait，说明中间policy/claim causal tamper函数没有抛异常，但这些列表尚未最终写入aggregate receipt，不能补造其收据。
- 最后bait：只有running invocation和assembled日志；无capture.json、无accepted/rejected最终invocation，未完成也未验证。

## 精确reward进程时间与参数

下表started/ended来自各receipt实际Unix wall clock，时区UTC；不是ZIP mtime倒算。共同命令：bash tools/godot.sh --headless --fixed-fps 60 --path . --script tests/plains_encounter_policy_runner.gd -- --reward-entry --output=res://build/verification/plains-encounter/run_elv06x16/<name>.json，以下为额外参数。

|case|start UTC|end UTC|秒|exit|额外参数|
|---|---|---|---:|---:|---|
|reward_bypass0|15:05:37.386|15:06:03.299|25.913|0|--entry-policy=bait_then_bypass_v1|
|reward_bypass100|15:05:38.620|15:06:05.561|26.941|0|--entry-policy=bait_then_bypass_v1 --entry-phase=100|
|reward_dead_low2|15:07:08.525|15:07:57.658|49.133|0|--entry-map=2 --entry-tier=region_top --entry-low|
|reward_high2|15:06:33.617|15:07:06.751|33.134|0|--entry-map=2|
|reward_kill0|15:05:08.364|15:05:37.015|28.651|0|默认|
|reward_kill100|15:05:08.363|15:05:38.247|29.884|0|--entry-phase=100|
|reward_low|15:06:03.673|15:06:33.246|29.573|0|--entry-low|
|reward_original_conflict_bypass|15:08:42.557|15:08:55.917|13.360|1|--restore-unsafe-entry --entry-policy=bait_then_bypass_v1|
|reward_original_conflict_kill|15:08:28.675|15:08:42.189|13.514|1|--restore-unsafe-entry|
|reward_original_return_conflict|15:08:56.539|15:09:20.348|23.810|1|--entry-seed=two-map-corpus/2 --restore-unsafe-return|
|reward_top1|15:06:05.936|15:07:08.156|62.220|0|--entry-tier=region_top|
|reward_top2|15:07:07.120|15:07:54.526|47.406|0|--entry-map=2 --entry-tier=region_top|
|reward_worst_return|15:07:55.089|15:08:28.309|33.220|0|--entry-seed=two-map-corpus/2|
|reward_worst_return_bypass|15:07:58.028|15:08:26.824|28.796|0|--entry-seed=two-map-corpus/2 --entry-policy=bait_then_bypass_v1|

## Formal invocation与最后超时边界

共同实际消费者是tools/level_formal_capture.gd，--headless --fixed-fps60；前四例与repeat max_ticks15000、policy kill_from_bank_v1。每个accepted invocation的wall_seconds是producer真实monotonic区间；JSON没有绝对start/end字段，下表不将mtime倒算冒充精确进程起点。ZIP mtime只有2秒精度，完成后source inventory/验证写盘可能另耗时。

|invocation|seed/map/strategy|producer秒|ZIP invocation mtime|status|
|---|---|---:|---|---|
|after/case_0/capture.invocation.json|level-design-v2-baseline / 1 / return|29.328744940999968|2026-10-23T15:11:14|accepted|
|after/case_1/capture.invocation.json|level-design-v2-baseline / 2 / fast|44.032317852999995|2026-10-23T15:12:00|accepted|
|after/case_2/capture.invocation.json|level-design-v2-baseline / 2 / growth|58.392941359999895|2026-10-23T15:12:58|accepted|
|after/case_3/capture.invocation.json|level-design-v2-baseline/01 / 1 / fast|32.15486888800001|2026-10-23T15:13:30|accepted|
|bait/capture.invocation.json|level-design-v2-baseline / 1 / fast|未完成|2026-10-23T15:14:14|running|
|current_repeat/capture.invocation.json|level-design-v2-baseline / 1 / return|31.609375850999868|2026-10-23T15:14:06|accepted|

最后bait具体参数：seed level-design-v2-baseline、map1、strategy fast、phase_wait_ticks0、max_ticks10000、policy bait_then_bypass_v1。tools/run_plains_encounter_policy_tests.py:900才启动它，之前大量工作均在同一原600s check内。level_formal.capture_one默认timeout240，先写running invocation，再启动Godot，只有自身finally正常执行才写最终status/耗时。此次外层强制timeout打断，留下running符合这一控制流；不把它当作单capture自身timeout证据。

## 直接原因、假设及未知

直接原因可证是**聚合预算与连续实际工作量相撞**：reward原始两worker矩阵从15:05:08.364开始，最后物理反例结束15:09:20.349，已占约252s；随后还有native/recovery、四个formal、独立repeat和完整验证。进入bait时原600s只剩约27s。四个正常formal producer各约29–58s、repeat约32s，所以单看当前证据，最后capture还未完成并不异常。

未知：bait最终会成功/拒绝、是否存在更晚路由问题；parallel lane同时运行带来的CPU/IO影响；本次机型和多次源snapshot扫描各占多少。ZIP未包含足够运行遥测证明这些，不能归因为引擎卡死、输入缺件或新增美术/BGM问题。本审计未跑native验证任何假设。

最小后续方向供总控选择：若重组验证，把独立原生阶段/完整矩阵拆为互相可追踪的Harness检查，保所有case/反例、同源身份与原单进程timeout，限制内部与外层并发；这是调度/可观测性问题，不是删断言、缩帧或把局部完成记全通过。不要仅凭本报告放宽原600预算，也不要重跑全CI来获取同样的无进度输出。是否需要实现拆分由主线决定，本审计不修改任何源。

可复核的精选摘要：plains-timeout-selected-evidence.json（含每个真实command/request/receipt身份、Harness时间和small-log marker）。原ZIP保持原样；未解包媒体、帧数据或历史内容。
