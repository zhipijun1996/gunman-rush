# ENEMY-STRUCTURE-01：CI超时后的性能修复守门（只读、方案前）

2026-10-29，/root/enemy_review。未运行Godot、未改生产／测试／预算。现行源5b；本文件提出可接受边界与需补的归因证据，**不接受尚未提出／实测的优化，不把失败改签通过。**

## 当前事实和推断边界

已直接读取5b runner、Harness、CI workflow与原80收据。原d91本地80为540.378秒，结构重构4af本地80为547.301秒，后者80/80完整通过且原600秒预算不变；约1.28%差异不足以证明新snapshot造成CI约60%的慢化，也不能严格证明两次性能等价（未控制全部环境）。

现已直接读serial-proof/report.json及forest-depth-region.log和serial-job.log。报告共18个check结果：17 passed＋该项timeout；原full166分区的serial清单实际75项，18结果为其精确前缀，故该通道其后57项未执行（report.requested_checks仍记录完整166，不应误读为本通道已跑166）。超时实际600.179秒，原argv／600预算不变；完成52条case row均passed。不能记“前18通过”或166全量通过。Parallel仍运行。

CI报告commit是5b，但git_status含预先物化的Foundry资源，不能称该CI工作树干净5b；其执行基线需按准备闭包与source_files before/after记录。原清单before/after相等。该准备态不等于本轮怪物生产源改动，也不能把差异隐藏。

将52条完成case按seed/map/route与本地80原收据配对，CI/本地总秒比中位1.649、范围1.507–1.801。近似全面慢化与环境吞吐降低相容，但同一生产热点也可能跨全部case存在；未读到CI捕获的逐帧/legs数据，尚不能确认工作量完全相同。现有environment/job日志未见实测CPU quota／affinity／processor数，不能仅由ubuntu-latest名称断言2核。

CI `.github/workflows/production.yml:222–314`的parallel／serial是两个独立ubuntu-latest job，每个Harness明确`--jobs 1`。不能仅因两个job同时运行就说它们必然争抢同一台2core runner。真正嵌套并发在`tools/run_forest_depth_region.py:1612/1646`：默认corpus `--case-workers=4`，同时启动4个独立Godot进程；各case240秒，外层Harness600秒。

`:1553`的LP_NUM_THREADS=1只约束软件GL线程，并没有为Godot全部WorkerThreadPool/物理/音频线程设总上界。若该CI执行环境有效CPU确为2，四进程过订阅是合理候选，但尚未证明它就是根因。

另`run_region_case.seconds`包含原生进程、capture读入/JSON解析和Python validate，不是纯游戏运行时长。ThreadPoolExecutor中的Python CPU校验受GIL影响。没有分段计时就不能把全部case秒归AI／mesh／snapshot。

## 不得改变的验收主体

- 原完整80个request、10根Seed、两map、四路线与原顺序／输出身份；不能只跑已完成52项或挑快Seed。
- 原Harness argv、outer600／import90／每case240预算；原60Hz、tick/edge预算、真实Router/AI/伤害／资源与音频释放、Manifest／轨迹／事件、原validator全部断言和拒绝例。
- 停首次失败、不再投新任务但观察已启动任务完成、源guard、独立用户／缓存目录、严格native ERROR／泄漏／退出码和原失败归档。
- 不改物理、闲置AI／激活语义、攻击周期、HP、资源、脚底／预警、尸体政策或正式采证内容。不得加headless／CI专属玩法或画面旁路，不以少录帧／省真实交互／放宽阈值救预算。

## 可以评估的层，以及接受它们前要看到什么

1. **有资源依据的调度。** 自动有效worker数可以少于请求上限4，但原80任务／参数／断言／预算不动，receipt同时记requested/effective workers与CPU依据。CPU判断至少区分os.cpu_count、affinity及cgroup quota；不能把host露出的核数当容器可用配额。现CLI本来允许1/2/4，不代表选2必然更快。须在同资源约束比较4与2的整体吞吐、单case耗时/CPU/RSS与相同轨迹，最终原CI600秒完整80通过才能关闭此失败。
2. **生产热点的等义消重。** 只针对profile确认的重复计算／分配／查找，保持读数据和时钟相位。若缓存快照，须能处理同physics/process帧内的accepted damage、initialize、位置／朝向／行为恢复和后续draw，不能靠相同frame号读回旧态。若省离屏mesh工作，仍保持所有世界／表现时钟与生命周期；屏内顶点／UV／cue不得漂移。不可笼统停_process或idle AI。
3. **runner／校验的等义消重。** 可在不变完整capture上预索引重复事件／帧扫描，但保顺序、重复事件检测、所有原正反例及相同拒绝原因；不能只验证summary、删原frames、跳末尾/保存/释放。离线validate-only可用于定位，不能代原80实际运行。

在根因未定前，先把process wall/user/system、parse/validate耗时、capture字节/frames/legs、各Godot线程数/峰值RSS、有效CPU及worker调度记录分开。固定同一seed/map/route/源/硬件配额比较，必要时冷／热import分列。先用已完成相同前缀与单route定位，再以完整原80和完整适用CI证明修复；不能只由局部速度改善签完成。

## 最终独审会核什么

具体diff出现后，逐项核原argv、80清单、断言／预算未降，CPU/热点证据支持修复层，线程／缓存／对象所有权和暂停epoch不出新问题。保原52/80超时与CI其余未跑；新源独立绑定，fresh原80和相关状态/GPU/生命周期回归，以及最终完整CI分别记。无论性能结果如何，旧怪物美术／动作质量拒绝与G5边界保持。

## 已读CI原件绑定

serial proof artifact12886948174，API声明2,311,315字节／SHA256 `71d7680563ddcedb9c8c83705d3c07bb008a20abea3b0f6247993f3945e6640a`由root已校；独审复用共享解包，未重复下载72MB lane包。

- `build/enemy_structure/ci-40844941490/serial-proof/report.json`：SHA256 `83b70921822f679e18128c18390e491014efda627c49145cab0eef64ba213a8e`。
- `build/enemy_structure/ci-40844941490/serial-proof/forest-depth-region.log`：SHA256 `5c267c4cf2e0a9550729655a928ebae27806551caff371e8b6edf49858dd35b6`。
- `build/enemy_structure/ci-40844941490/serial-proof/environment.log`：SHA256 `367ddefe2982245101fea3357679502f2a0080a572233e83fe32b0fbc604cca2`。
- `build/enemy_structure/ci-40844941490/serial-job.log`：SHA256 `0b2caae8d9f620770e8244037e7d6150e654bd4c1acd7f390de28c50615f1c73`。
