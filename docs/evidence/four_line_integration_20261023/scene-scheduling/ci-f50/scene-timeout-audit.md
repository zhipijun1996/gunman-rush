# f50 plains-redesign-scene：只读失败定位

CI39987409483 serial120535824686，source f50fe78630fd98339186349f4ea91d92540d6c5b。serial.zip SHA256 54bf3f1d994c3a7cdf5c7b3691c2fe6e1623c8aef3ddbdf5b81515ba2cb33bc6实核一致。只选run_i3y6e_ln小收据/日志；内嵌large-json.zip只在内存选读positive-shard-1.json，未整包解压、未运行native、未修改root。

## 直接原因

positive原180s共享聚合deadline耗尽。两个worker几乎同时启动：17:07:38.657UTC；shard0到17:10:38.757被timeout，180.100s，无最终JSON；shard1于17:10:16.948通过，158.291s。positive-partitions记录aggregate180.382693s、within_aggregate_deadline=false。外层plains-redesign-scene900s尚未耗尽：整体187.865s后因positive验证失败退出1。前项encounter已真实passed500.292s，不能把本失败归于encounter重现。

**没有发现SCENE FAIL、SCRIPT/Parse/SHADER ERROR或Godot诊断证明某条已完成case实际断言失败。** 收据中“missing eight-route / legacy UI / shared fork”等是shard0被杀无最终JSON后，合并仅剩4case产生的守门拒绝；不是已证新UI/地形功能回归。该拒绝正确，不能放宽。

## 本次实际分组及完成范围

实际f50源码是连续分组 `[0,1,2,3]` / `[4,5,6,7]`，并非odd/even。定位基于git show该ref及真实command/输出，不假定旧实现。

|index|正式原case|本次完成证据|
|---|---|---|
|0|map1 fast 默认|shard0 FORMAL ROUTE target_reached，4314ticks，随后audio teardown released|
|1|map2 growth|shard0 target_reached，3951ticks，audio teardown released|
|2|map2 return main_then_high|shard0 target_reached，4473ticks，audio teardown released|
|3|map2 fast outer_return|shard0开始map1→map2实际组装；超时前无FORMAL ROUTE结束、无最终case JSON；进度/结果未知|
|4|map2 fast outer_upper_alternative|shard1最终JSON finished/target_reached、issues=[]，6528ticks、1197visual samples|
|5|map1 fast extra_upward_recoil|shard1同上，822ticks、352visual samples|
|6|map1 fast touch_geometry|shard1同上，1315ticks、1315visual samples|
|7|map2 return main_then_high，seed baseline/01|shard1同上，3907ticks、719visual samples|

shard1原生marker48assertions0failures、indices[4,5,6,7]，四份sealed cleanup均ok、execution_done、audio_released、driver_released，observers均断开；10seed generation_corpus保留。其JSON SHA25672f2bb7ea0be5c5cfbc4798e55acc7e8d0834cea1e0a4e5be51aa49e450ab89c同时吻合partitions与large-json.index。内嵌archive SHA256d4ec1ee93c8a5789aea2f65aacb67b58511b2c0b60cec2112d74258037454017也吻合。

legacy_compatibility按原控制流在shard0先执行；该日志没有其断言失败，但shard0没有最终JSON，因此不能补造legacy_ui通过收据。shard1的legacy_ui={}符合“只在shard0执行一次”的设计，单凭它不代表遗失该consumer。整体8case cleanup/路由/legacy合并守门仍未通过。10项实际native mutation和后续Python corrupted-evidence反例尚未开始，本轮不能沿用旧本地通过结果改签。

## 最小有证据的优化方向

负载结构有确定偏斜：shard0仅前三条已完成轨迹即12738ticks，超过shard1全部四条12572ticks，且前者还欠outer_return。按四条数量对半不能保证计算工作对半；采样密度也不同（touch每tick观测），ticks不是真实性能计时。

最小可试候选是仅交换case1（growth3951ticks）与case5（elective822ticks），得到原顺序子序列 `[0,2,3,5]` / `[1,4,6,7]`；保8case原定义/参数、每组原索引顺序、合并回0..7、legacy/corpus各恰一次、所有断言、两worker上限及同一180s aggregate deadline。Python预期indices校验与GD实际选择必须同步，不能只改其中一层或只跳过慢case。任何新分组仍需真实验证，报告不能预先签180内。

这只是有限候选：本ZIP没有逐case wall时间，case3未结束，不能据ticks造性能提升数字；无法证明交换即可解决全部180s问题。允许的另一步是给现有case启动/封存点打印小型真实monotonic checkpoint以定位，不改变动作/采样/帧预算；无需新框架。若要考虑thread/Godot内部并发或serial与parallel同机争用，需实际环境/进程证据，本ZIP不足以归因。此次不建议放宽180预算、删legacy/corpus/反例、减少样本或假称局部完成就是整体PASS。

## 附件及边界

scene-selected-summary.json为精选小摘要，保两个Harness身份/时长、分片收据、shard1真实case/cleanup/corpus。scene-positive-partitions.json、scene-receipt.json、scene-positive-shard-0.log、scene-positive-shard-1.log均只从ZIP选出。原ZIP不变；未复制23MB大JSON到磁盘。整体当前仍failed，parallel仍由主线监控；本审计不取消或重启任何CI。
