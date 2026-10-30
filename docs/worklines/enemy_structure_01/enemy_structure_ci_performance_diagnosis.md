# 原80森林路线 CI 超时：只读诊断

结论：当前有证据表明原 runner 在外层 serial lane 内仍启动4个独立 Godot，CI 与本地的可用 CPU 不同；没有证据把约66%的同路线耗时增加归因到新怪物 snapshot。已有 `--case-workers 2` 可在不删80案例、不改断言、不放宽600预算的条件下做一次有界验证，但不能预签它能解决超时。单纯减并发只能降低竞争，不能增加2 CPU的总算力。

本任务未运行 Godot，未修改共享仓库。对应机器可读计算为 `/tmp/enemy_structure_ci_performance_diagnosis.json`。

## 已取得的原始证据

| 运行 | 原80结果 | workers | check wall | route mean | 同 CI52条的 mean |
| --- | --- | --- | --- | --- | --- |
| d91 本地 | 80 passed、source stable | 4 | 540.378 / 600秒 | 26.277秒 | 26.484秒 |
| 4af 本地 | 80 passed、source stable | 4 | 547.301 / 600秒 | 26.612秒 | 26.717秒 |
| exact5b CI serial | 52条已完成均 passed；整体 timeout | 默认4 | 600.179 / 600秒 | 44.282秒（仅已完成52条） | 44.282秒 |

本地新旧完整80的 check wall 和 mean 均只增加约1.28%。同一52条，CI/4af 本地耗时比1.657；CI真实区间33.782–70.858秒，不能只用38–61秒代表全部路线。CI没有完整80终态，也没有原80 PASS。

出处：

- `build/verification/harness/20261029T051735.820131Z/report.json` 和其 corpus `build/forest_depth/region/harness-matrix/harness-8591b219997a49a48efa570403df2fb4/receipt.json`。
- `build/verification/harness/20261029T083648.345807Z/report.json` 和其 corpus `build/forest_depth/region/harness-matrix/harness-bc73fe2a5b814b349d8d89762fec036f/receipt.json`。
- `build/enemy_structure/ci-40844941490/serial-proof/report.json`、`forest-depth-region.log`。proof原包由root校验 SHA；本任务没有下载72 MB全lane包。
- GitHub job `123354759599`，run `40844941490`，head `5b083938ea9f2722fe6c44896914f9d2d198e87b`。本任务通过GitHub connector只读取过日志并另存 `/tmp/enemy_structure_ci_serial_40844941490.log`；上表使用原 proof日志复算。

## 工具实际怎样使用线程与进程

1. `tools/harness/profiles.json:1254` 仍是原 `--corpus`，600秒、原 completion regex、`serial:true`。`.github/workflows/production.yml:314` 的 `--jobs 1 --lane serial` 只约束 Harness check 层。
2. `tools/run_forest_depth_region.py:30` 固定10roots×2maps×4routes=80，原16 first；`--corpus` 禁止与routes/matrix等组合。
3. 该文件`:1571` 的 `ThreadPoolExecutor` 会启动独立 native进程；`:1612` 默认4，并明确已有1/2/4选项与低核机器用2的说明。外层engine.lock包住整个check，不能把其内部4个case序列化。
4. `:1544` 每个case真实启动 headless、fixed-fps60的原 `tests/forest_depth_region_runner.gd`。每case原240秒；import原90秒；独立user/config/cache目录。没有worker pool配置或进程affinity限制。
5. `:1553` 非movie只显式设置 `LP_NUM_THREADS=1`，这是Mesa/llvmpipe线程变量，不是Godot WorkerThreadPool限制。CI全局另有 `LIBGL_ALWAYS_SOFTWARE=1`。`tools/godot.sh`只选锁定Standard4.7.2后执行，没有额外CPU限制；project.godot也没有worker_pool配置。
6. exact Godot tag `4.7.2-stable` 源码 `main/main.cpp:2144` 从 `threading/worker_pool/max_threads`初始化游戏worker pool；`core/object/worker_thread_pool.cpp:817` 在负值时取OS默认；`core/os/os.h:358` 默认返回processor_count；`core/os/os.cpp:459` 是C++ hardware_concurrency。该信息证明LP1不能限制Godot池，**不证明全部worker持续工作**。不能用“线程数量很多”直接代替CPU利用率证据。
7. row.seconds包含进程启动/执行、JSON读入/解析、原validate、日志扫描和hash，不是纯Godot耗时。ThreadPoolExecutor中的Python验证仍受GIL影响；必须与native CPU区别。

原源码线上出处均为 `https://github.com/godotengine/godot/blob/4.7.2-stable/` 下上述文件；这里只读源码，没有探启动引擎。

## 环境证据和未证实部分

本地实际读到 `os.cpu_count=5`、affinity=`0-4`，但cgroup `cpu.max=400000 100000`，即有效4 CPU时间配额；memory.max=16 GiB。不能用5作为有效CPU预算。本地当前cpu.stat为累计量，不是该次check的节流证明。

CI已上传environment.log只记录Linux/x86_64、Python3.12.15、Godot4.7.2等，没有CPU拓扑、quota、进程线程数。job日志显示Azure hosted Ubuntu26.04.1/image ubuntu-26.04，未打印CPU数。CI2 CPU来自root提供的环境信息，此任务没有独立测到CI affinity/quota，需在下次运行附带采集。

在所述2 CPU上，4个有CPU工作的Godot主线程已至少2:1竞争；本地4 CPU上则约1:1。它能解释吞吐下降方向，但“4比2并发造成了多少额外浪费”仍需测量，不能仅凭配置量化。

root现有纯Python诊断 `build/enemy_structure/performance-diagnosis-01/validator.json` 对本地最重09-map2-growth：原row46.534秒，24.5 MB/3810frames，parse0.593秒，带profiler validate1.102秒且0 errors。`validator-top.txt`显示主要验证CPU为airborne resources扫描。该单条证明Python有成本，也说明它在这条本地row中不是大头；不能外推排除CI的GIL/IO竞争。

算力边界：CI已完成52条的row总和2302.672秒，除4为575.668秒，接近600秒预算，调度器已有持续in-flight工作。若只按同路线1.657倍外推完整80，新本地row总和2128.974×1.657/4≈882秒，再加import/guard。要在600内完成需约1.5倍吞吐改善；不能假设把workers4改2就自然得到它。2workers下平均row需约14.7秒才能留出import/guard余量，这显著低于当前本地workers4均值26.6秒，需要真实试验而非口头承诺。

## 不改输入和预算的有界2 CPU验证方案

第一轮仅验证现有调度选项，冻结同一source、engine、corpus、环境及source guard，不改production/test/runner：

1. 在CI同规格独占2 CPU宿主上记录 `lscpu`/`nproc`、Python affinity、cgroup cpu.max/cpuset、memory.max、Godot锁版本；记录每次check前后cpu.stat与IO/memory压力。只用taskset不等于2 CPU quota，必须同时记录实际quota。清理旧engine进程，保持原engine.lock。不要在该验证中同时做movie或其他引擎检查。
2. 复制**内存中的**原 `forest-depth-region` check定义，仅在argv追加现有 `--case-workers 2`，通过原 `tools/harness.py:124 run_check` 启动，保原600秒、success_pattern、token、process-group及tagged-descendant清理。fresh build输出。仍用原 `--corpus`，不得改seed/route/frame/native240/import90/source guard。该诊断本身不是原manifest CI的签收结果。
3. 不改runner，外部轻量每秒采样受管Godot和Python PID的/proc CPU累计量、RSS、Threads、线程CPU差值及context switch；保存JSON和原case receipt。这样可区分Godot主线程、Godot其他线程、Python校验、CPU节流/IO等待。线程数量要与CPU增量一起解释。
4. 每轮最多600秒执行+原Harness清理；不延长原timeout等待80完成。若与已存在CI4worker比较仍无法归因，可再做同硬件、同源的原4worker对照轮，各自独立600秒上限。没有必要先跑删减case的“替代验收”。
5. 通过必须是完整80/80、所有原validate与native错误/泄漏检查、source stable、原completion、原600预算同时成立；失败保持timeout和未完成清单，不能以完成52条或单独validate-only签整体通过。检查2worker与4worker的实际case状态/关键trace语义，线程调度差异不得掩盖新gap。

如果2worker得到80/600的真实证据，后续最小正式配置变更是原check argv明确 `--case-workers 2`，保其他条件，走原Harness选择/收据再执行；本任务未做该变更。如果仍超时，证据只能说明当前2 CPU环境/实现尚不能满足该预算；下一步应由CPU归属决定等价性能优化，或给该原check可用4 CPU执行资源。两者都保80与600，不应改成少case或提高timeout。本任务不提前推荐worker_pool override：它改变引擎运行配置，而且idle池不是已证实瓶颈，须先有CPU采样依据和同覆盖parity。
