# 阶段A宿主报告恢复稿

任务 `MAPGEN-HOST-04-ACCEPTANCE-01`。本稿只读d37源码、本次恢复后的原69原件、持久PR129交接及此前实际读回消息；未修改仓库、启动引擎/浏览器或重跑默认双fresh。**A收口仍待root填写本次新gears Web及最终精确head CI；B本轮不启动。**

## 来源与证据等级

本地受验源 `d37b37075144c7a7550ad0fe9d3bd7118d6dae1d`。远端传输提交 `c9416f16fcce53f64ce456f8eb33df42429627cd` 与其完整tree均为 `fecc23d4860a08ad5c3d49df7de503f13578c68c`；commit身份不同，不能称远端就是原d37。`transport-c941/transport-proof.json` 核根21项、68变化路径的blob/mode一致，只证明Git传输，不生成新测试结果。

| 结论 | 证据等级与边界 |
|---|---|
| 本次原gears native69/0、fresh、严格退出 | 当前原件可复核：report/log/nativeJSON/真实四件均在持久压缩包 |
| 原d37相关12fresh、181.474秒求和/197.859秒Harness墙钟 | 历史实际见证；原report/log已随临时环境丢失，不能冒作本次12报告 |
| 原默认双fresh自动209.255767/300秒与六图审查/strictjoin | 历史实际见证；PR129持久交接保留，原自动报告/PNG/PCK字节链本次不可重新核查，不重跑或补造 |
| 新gears Web、新精确head full178 | 待root实际证据；本稿未填PASS |

上述历史不是取消事实，也不是当前原件。JSON分别列 `current_raw_available` 与 `historical_witness_original_raw_lost`；旧路径只作来源说明，不创建同名虚构报告、截图或before向量。新的真实输出不得套旧f6期望。

SDK仍0.4.0、`mapgen/gdscript-candidate-0.4.0`、`stable-v3-reward-space`。release `6bf07ab5a655ea056461b935ae4354e15ef83482`，实际source `b21c889077ec97eb11a210d0ceab4fbddd862e48`，SDK ZIP `7aa3f0e573675c3bb41e2a2a5b23254c4005bb8eaef9756535e3a6480988d778`。模块仍1.1.0 / `5ad5a7871941b2c1ffa759b18f7b1e80f2fe7e571b72f95d1e0ef26031f08723`；18个原SDK GD逐SHA一致，未混0.4.1。现工作树clean，原source前后SHA相等。

## 本次可复核实测

恢复原worktree后正常editor准备导入56.489秒、exit0，首轮4条缺字体导入缓存ERROR单独保留，不能当check通过。原wrapper随后重新导入并执行原Harness：`--check runtime-map-m35-runtime --release --jobs 1`，check48.182秒、Harness墙钟51.775秒，69/0，exit0、0reuse。外check240秒和原wrapper导入90/运行240秒预算未改；运行log无ERROR/SCRIPT/leak行，原严格退出成功。

真实930007为PASS、43实例/55连接/43内容项，指纹 `deee1d69cc42840dfc5fae6648e8fc72f016dc2a450da53c94b787d30018f485`，出生 `[474,974]`。本次直接读回map内容身份 `c652943fe8e5e50c2b21242cc09530228a12d1a7fbfb08975977da5a4e835d97`、真实controller宿主身份 `6f1a6e262a765aa4025fafcedc683fd3f10161234d747f0d6675b16776f4cf3f`；这是新native原件，不是从旧f6抄填。完整runtime收据及四件真实result/provenance/protocol_payload/bindings均随包保全。

**execution均为同一主线程单调时钟elapsed，不是OS CPU。** SDK内部profile按advance入口phase归属；host、Provider、SDK项相互包含，不能当独立项再求和。wall还含帧让出/调用方工作；尚未测SDK独占CPU、完整Page/PCK/WASM boot边界、下载/解码/编译CPU分离、手机或硬帧延迟。

| 本次930007阶段 | 实际值 |
|---|---:|
| 暖库原ZIP工作 | 0 calls |
| 暖预载host执行 / wall | 0.656 / 0.679ms |
| 原生成单位 / checkpoint | 76,848 / 1,229,556 |
| generation host执行 / wall | 8704.345 / 8916.495ms |
| generation外层原advance累计 | 8378.711ms |
| SDK内部advance profile累计 | 8040.484ms |
| tick级generation进度采样累计 | 4.355ms |
| SDK profile捕获 / result一次深快照 | 12.883 / 5.602ms |
| Protocol fingerprint累计 / selection | 0.350 / 0.195ms |
| validation / Provider外层 | 68.563 / 68.129ms |
| Provider输入验证 / keycopy / identity摘要 | 18.298 / 6.903 / 40.377ms |
| 窄output_summary | 0.009ms |
| assembly执行 / 含物理交还wall | 47.734 / 49.448ms |
| 实际physics admission / commit / receiptcopy | 0.243 / 0.225 / 0.162ms |

此成功场景的暖库来自**同一原生进程先前负例装配之前完成的真实预载**；不是跨fresh浏览器、跨进程缓存。verified receipt记录657文件、首次只读冻结90.598ms，那是该进程最初发布成本，不能重复算作本次暖预载。本次没有为取冷库表另开原生。

生成原单位平均65.40次/tick，低于配置128；每advance1仍16检查点。SDK内部growth约3907.057ms、goal_aware_terminals约3582.671ms，合计93.15%执行。host外层advance与SDK内部profile差约338ms、host生成执行减外层单位约326ms，包含调用、原SDK返回progress分配、计时/接受guard、profile/快照及循环等，现有计时不能逐项完全拆开，不把残差全叫纯宿主CPU或idle。显式tick进度采样仅4.355ms，不是主热点。

## 历史见证：默认209秒、26/68秒及旧12

持久 `pr129-recovery-handoff.json` 记载：原d37/512c…PCK默认完整两fresh自动流程209.255767/原300秒完成，六图独立实际view和严格offline join通过；独立离线审查213.163965秒另计，不称整个人机审阅在300内。原报告保留AUTOMATED_COMPLETE_VISUAL_PENDING，最终认可另存，没有回写原报告。**现原自动报告、PNG、新PCK及当地12日志已丢失，只有当时实际工具见证和持久交接；本稿不重造其原件、不把摘要充作原command/screenshot。**

同一交接的历史default Web分项：冷预载wall26.048秒、SDKadvance执行11.098秒；生成wall68.498秒、SDKadvance执行30.538秒；进度采样约0.076秒、SDK结果快照0.0076秒、Provider0.119秒（摘要约0.058秒）、装配执行0.113秒/含物理交还wall0.369秒、冷只读冻结约0.119秒。它们是历史软件浏览器样本，不能与本次native直接相除宣称性能倍数。

历史DOMContentLoaded0.222秒**不是**完整PCK/游戏启动时间。当时observed-PID CPU采样包含SwiftShader GPU/renderer多线程、边界异步和PID覆盖缺口，不能视作SDK独占OS CPU；精确完整boot及PCK/WASM下载、解码、编译CPU分离仍未测。本稿不给这些缺项补零或补PASS。

原12历史求和181.474秒、Harness墙钟197.859秒，不能混写；Job1645/0包含真实930001仍存活时完整930007暖生成及前者完整result/provenance/Plan不变。此前作者已读回默认native冷预载wall3538.494ms、生成94678单位/执行9879.445ms/wall10244.246ms、validation79.930ms、digest44.903ms、assembly执行58.253ms/wall101.512ms。这些原12细项仅是历史见证，不是本次69测到了默认生成。原input_digest事后重建曾逐项匹配也不等于原before文件仍在；本稿不恢复虚构原向量。

旧f6实际两fresh300秒actual02/03失败保留，不能借新包历史成功或附加分项回签。此前实际读回的旧软件Web平均16.21预载/30.02生成单位/tick，低于128cap；SDK catalog/module JSON约90%预载执行、growth+term约94%生成执行。其精细原临时表已丢，仅保留当时读回和交接定位；旧4ms通用非PASS没有捕获SDK确切状态，不能追称必为预算耗尽。

## 架构、复制与生命周期

source私有缓存的Key为模块完整SHA/version与SDK implementation/algorithm/version/archiveSHA/releasehead/sourcecommit，避免跨SDK混用。只发布原PreloadJob完整PASS、实际archive身份一致并递归只读后的ModuleArchive DATA。内部JSON及文件字典只读，SDK已审写路径先duplicate后变换，PreparedLibrary自身不可共享。helper只有metadata复制和内部JOBfactory，没有返回可变archive的public getter；这是GDScript源内封装，不是对恶意脚本的安全沙箱。

每job保留独立LevelRequest/tuning实值、request/config、PreparedLibrary、Solver/RNG、WorkGate continuation、result、Plan与提交状态。owner WeakRef、独立opaque ticket、实际lifetime对象和run/stage/actor token共同守门；旧/重复/离图/替换后的结果不能take/commit。cancel/close/replace仅取消自身工作并释放访问，不清进程已验库，部分预载失败/取消不会发布。缓存不向UI暴露源JSON；驻留内存预算尚未测，不承诺长期多版本零增长。

原SDK.result已返回深快照，host移除随后第二份duplicate。Provider只读原入参并自行复制map/store/输出metadata，故host移除其前置完整actual/bindings/provenance冗余复制。入口只为计数和能力显示使用窄summary/abilities接口，公开actual_result/provenance诊断仍deepcopy。committed收据早于测试导出，未见full-result-copy计时不等于后续artifact writer免费。

默认8ms只是完成一个原单位后交还的软目标；配置cap仍1..4096、默认128，原算法90秒/候选预算/RNG不改，SDK18GD与原模块字节不改。本次单位max12.352ms、generation tick max31.295ms、validation68.563ms、assembly47.734ms已经说明不能签8/16ms硬保证。用户取消须等主线程得到调度；直接cancel调用elapsed不等于排队输入响应。

当前源码仍有真实budget1 BUDGET_EXHAUSTED及null-summary、部分预载取消不发布、全Key隔离、getter副本、opaque/旧lifetime/退出拒绝和PREDELETE严格断言。历史12曾通过这些完整测试；本次只跑原69，不宣称本次全套重验。两个job各advance1的交错只到prepare，所证是准备continuation/cancel隔离；完整930001→930007是顺序实生成，不是同时两个Solver/RNG压力或全部seed定理。

本次69另证初始实际定位、真实body/foot物理安全准入、不安全测试注入的provisionalPlan拒绝、actor epoch改变后无迟到提交、完整危带/saw/两ferry共享clock、自然walkoff按实际HP返回及fatal生命周期。固定景内一次接触重定位是显式fixture，不称初始进场或连续路线；saw cadence只证下一pulse调度，非连续两次实伤间隔。没有删除危险、添地板、grantgrapple、新钱包/Session/伤害权威，也不代签邻接、整图、设备或用户手感。

## 给map-gen的具体请求与后续

1. 保原Protocol/指纹、RNG次序、90秒/候选失败合同，提交growth与goal_aware_terminals的工作量、复制计数及长16-checkpoint单位栈；当前native约93%，历史Web约94%的SDK执行在此，不宜盲增宿主128cap。
2. 冷库重点catalog/module JSON parse与准备，提供可取消的小步和版本化已验不可变库复用合同；保留ZIP/成员SHA与来源，不跳哈希、不复制一套宿主solver。历史预载约90%执行为该类，当前暖复用仅免同进程重复I/O解析，不免每job准备/搜索。
3. 审每advance返回progress/result字典、终态profile排序、export和深快照成本，给可中断边界及峰值；不能为性能共享可变结果或改协议输出。SDK原样锁定，宿主本轮不直接改18GD。
4. 官方分别报告activeexecution、含帧让出的wall及明确失败状态，核实际Webhost节拍下deadline含义。宿主不能靠放宽90秒、候选预算或删交互/校验让流程绿。
5. Provider摘要/输入验证与Stage装配仍是宿主同步长段，已经单独记录，未来需独立范围审查分割；不能绕开身份或真实物理准入来追硬帧指标。完整boot/PCK边界、独占CPU、移动设备/FPS保未测。

新gears Web结果由root在此后追加原PCK、原300秒动作/截图/WAIT/guards与实际结论；本稿留空，不读运行中报告提前签结果。远端同tree不代签新CI，最终精确head原178及affected仍需root收口；相关12、父85或旧0.3 full178都不替代。**B本轮不启动、不混0.4.1、不合并/部署。** 未来B再独立处理真实used-port身体净空/落脚与safe_lesson完整机制，不能删封口/改geometry凑旧helper。

A整包回退提交 `46eb3960a592374b5fb99d7df588962a3680f86b`，保来源锁/旧失败/独立0.3基线，不只回退绑定造成混版本。持久主要证据 `gears-rescue-receipt.json`、`gears-native-actual-runtime-receipt.json`、`native-m35-runtime-01.json`、`gears-rescue-native-01.tar.gz`、`pr129-recovery-handoff.json`、`transport-c941/transport-proof.json`；精确SHA及当前/历史分层在同名JSON。路径仅纯文本，不含/tmp超链接。
