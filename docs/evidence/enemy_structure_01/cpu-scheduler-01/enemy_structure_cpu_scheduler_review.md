# CPU调度／计时补丁限定独审

2026-10-29，/root/enemy_review。**ACCEPT，可应用；限源码与纯Python调度／计时守门。** 不签原80/600或完整CI已修复。未修改共享源、未运行Godot。

基线`3bc1759b17a0d06be94ef43f85f2116631437aef`。已审两份/tmp patch及实际应用字节。工具候选SHA256 `781469d74f1b51520da10d94aed822e6b2e78cc1dc645b69bd49abeda0581667`，基线SHA `da28fa29e68f18411c6354fe91e392223e3b48011ad95787d1f21c39ec2482e5`。

独立AST／源码比较：原函数只有main和run_region_case改变，新增cpu_capacity/select_case_workers；corpus_cases、schedule_cases、validate及其余原helper逐字保留。原80唯一请求、前16顺序、失败停止投新任务／观察已启动任务、源guard、独立env、ERROR／泄漏与cleanup不变；原Godot argv／60Hz／import90／每case240及Harness600预算不变，profiles.json未改。

显式workers1/2/4先返回，默认auto以可读os/affinity/可见cgroup正数最小值为上限，选合法1/2/4；小于1仍最少1，全部无读数回退原4，非corpus仍串行1。cgroup从当前membership映射实际可见mount，在mount根停止，拒绝relative '..'；支持v1组合controller、非根mount、v2祖先quota与namespace '/'。缺失／坏quota不制造CPU读数，隐藏祖先限制不作已知。容量是上限，不是跑分。

计时仅用monotonic新增native／JSON读解析／validate三个wall段；异常保已进入段、未到达段为null。原总seconds仍含其余工作，未冒充OS CPU时间。原subprocess参数、超时和拒绝路径保留。

原RegionSchedulerTests及FourProcessSchedulerTests两个class源体逐字保留（14项）；仅追加13项新边界／遥测测试。本代理实际执行`python3 /tmp/test_forest_region_scheduler_cpu_candidate.py -q`，退出0，**27/27，1.777秒**。该/tmp副本只把loader指向工具候选、ROOT指回原repo，不能原样替换仓库测试；实际应用测试patch不含loader改动。日志`/tmp/enemy_structure_cpu_scheduler_independent.log`。测试使用真实短Python子进程，不是Godot／真实路线替代。

未发现阻塞问题。此接受不重标原CI52/80超时，不声称调度选择已实际使原80在600秒内完成；须新精确源fresh原80与完整适用CI另证。物理、AI、采证、美术／动作拒绝及G5边界不变。
