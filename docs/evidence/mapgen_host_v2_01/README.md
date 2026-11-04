# MAPGEN-HOST-V2-01：真实装载证据

宿主基点 `30e36c9abe223f26e666ceaf796e3fe9cb58e10f`，工作分支 `feature/mapgen-host-v2-01`。测试针对该基点**加工作树候选**，不是基点原提交已经含本轮代码。[完整Harness报告](integration-harness/report.json)保留实际dirty/untracked摘要；[最终Harness](final-harness/report.json)覆盖目录归档修复；[证据回执](evidence-receipt.json)的24份非文档源SHA与最终测试时一致，9份原核心文件与main逐字相同。后续只写文档/质量证据，不更改该运行源。

## 输入来源

- map-gen main完整SHA `178c40164c2f7371ce1c8a56cde658e84a4f42c2`。官方 [request](upstream/request.json)、[config](upstream/config.json)、[library lock](upstream/library-lock.json)与[实际命令/API/source SHA](upstream/invocation.json)；[首次运行结果](upstream/run-receipt.json)为PASS，46实例/55连接/46 content，约3.98秒，仅为该开发机观测。
- module-pack1.1.0 ZIP原件、152个上游来源/结果/选择/完整内容文件在 [upstream-originals.zip](upstream-originals.zip)。包文件提交47aefebe与包内源提交02b5cb53分别保留；不是PR123/v1参考包。完整ZIP SHA、逐成员SHA/长度/CRC和逐字读回核验见回执。原始完整 map 同时在运行fixture，未裁写原文件。
- 实际游戏读取 [input-lock.json](../../../resources/levels/mapgen_host_v2_01/input-lock.json)，六成员包括完整map、三份完整content、selection及宿主bindings。选择M16/M18/M21，切割边和原11 Ports/20 routes均保留。范围及每项映射见[宿主报告](../../worklines/mapgen_host_v2_01/integration.md)。
- 开发生成脚本在ZIP内，仅作复现，不进入Godot运行时。复现先checkout锁定map-gen main，在新目录放原request/config/包，按 `mapgen.generate(GenerationRequest.from_dict(...), ModuleLibrary.from_zip(...,expected_sha256=...), GeneratorConfig.from_dict(...))` 执行；保留原run_generate.py的绝对输出路径与禁止覆盖首轮目录约束，若另机复现只改开发输出路径并另存来源。不要修改/覆写原首轮结果。

## 实际运行

固定已批准 Godot `4.7.2.stable.custom_build.gunman_sd1.ed1daf0bf`，Linux、headless、60Hz物理、Dummy音频。原Harness独占顺序fresh执行、0复用：

| check | 实际结果 | 用时/原预算 |
| --- | --- | --- |
| runtime-map-v2-host | 150断言/0失败，严格干净退出 | 5.825s / 180s |
| level-plan | 146断言/0失败，原正式两区消费者 | 22.025s / 180s |
| run-session | 61断言/0失败，原玩家与服务消费者 | 8.613s / 180s |
| architecture-tests | 13 tests/0失败 | 0.261s / 60s |
| cloud-production-planner-tests | 原48+新增1=49 tests/0失败 | 0.526s / 60s |

原日志和归档artifact在 [integration-harness](integration-harness/report.json)，逐帧实际 [native.json](native.json)：

- 实际20静态碰撞体 + 1 Animatable平台 + 唯一正式PlayerMotor/FrameDamagePolicy，逐矩形尺寸/世界坐标/oneway核验，无额外地面或第二套源场景。
- C027：连续输入20ticks，玩家x约−443.67→−361.33，始终grounded，跨原x=−384接缝。C030：−1211.67→−1129.33跨x=−1152，原M21/M18实例分别visited；不teleport、不重建服务。
- M16原椭圆：60ticks真实物理骑乘，>30个碰撞接触帧、移动>40px，与平台位移差<5px；实际首末坐标、接地和平台坐标全存trace。不是宿主逐帧写玩家位置。
- 两次同图reload：原时钟按稳定instance ID恢复，同一玩家位置/wallet/policy/HP，旧actor token失效。三次退出：原world audio drain释放，Stage弱引用清空、旧结果拒绝；原生无脚本错误或ObjectDB/resource泄漏。
- 实际拒绝：错schema、非精确seed、未物化mirror、源偏移误用、未知内容、敌人非空、新wallet服务、face错误、单向permission冒充开放接缝、缺失Port、断开子图；失败诊断包含连接/实例/字段。

C031只核源静态接缝，没有物理路线认证。所选内容无敌人/奖励/Boss/危险，不伪造覆盖；新机制交互由原椭圆骑乘满足。GUI/GPU、Web实际导出/PCK/浏览器、手机、完整46实例、随机算法运行时调度/取消和完整保存恢复均未验证。未发布，也未替换正常出发地图。

## 独立审查与原失败

非作者 `/root/death_event_audit` 的[源码审查](review/review.md)、[指纹](review/review.json)及[CI窄审](review/ci-review.md)签有限静态接入，无代跑Godot/全172/设备。原主线[host审计](host-audit.md)仍保持实施前时间点。Provider开发及初始seed问题见 [provider-development.zip](provider-development.zip)；CI候选、保留原219 check/171前缀与旧断言的证明，以及实际作者测试01/02失败与03通过见 [ci-registration.zip](ci-registration.zip)。

`development/` 保留真实parse/native原日志：初始WeakRef推断编译失败；旧build历史ShotEnergyDefinition class cache污染；native01 seed浮点文本拒绝、02 ellipse sign类型比较拒绝；03为反例未修改和StaticBody包含Animatable子类的3个测试失败（149/3，原trace单存）；04为150/0。这些日志不覆写成通过。退出echo/并发close提前返回的静态发现已修；missing-port缩进误报已由审查者撤回并保留。

另一次工具Harness检查在文档写入中触发全源冻结拒绝；原interrupted报告（启动检查前即拒绝，尚无子check日志）留在 `development/harness-source-drift/`。这是本轮执行次序错误，不是地图源缺陷或已通过检查，后续冻结文档再补跑。全部失败与最终通过按各自来源区分。


补充检查边界：当前为显式排除旧docs/evidence、docs/archive与preview的稀疏工作区，全局docs/quality/structure实际返回失败，原完整诊断见 `development/*-sparse-02.log`；原输入预检测得3777个待物化文件、已知约3.19GB，超过当前磁盘余量，未删除历史证据或放宽守门。新任务记录与本轮链接单独校验，PR按完整源CI继续验证。quality首次漏criterion dimension/reason、diff首次漏exact affected_paths均真实拒绝，修订仅本任务元数据、未修改quality工具/断言。

实际CI装配还发现artifact_paths声明单文件不会被原Harness目录递归采集；首轮专项PASS的artifact只有check.log，native.json已独立按原字节留存。后续将本check声明改为输出目录并真实补验归档；不把首轮空artifact追认完整。原候选与首轮独审保留，修复独审/最终Harness另存。


最终目录修复已通过[原Harness fresh补验](final-harness/report.json)：专项150/0（5.860s/180）、planner49/0（0.514s/60）、Harness91/0（18.635s/60）和Web资源合同测试（0.507s/60）。[实际归档核验](artifact-verification.json)确认native.json确实进入原artifact，且与首轮/live逐字相同，完整SHA为02ccb785c5fb8f6db73dd3b5e3e658657408abfb2b0e6868b121be0eb69b0dc9。仅新CI声明/对应断言改变，运行GD/scene/fixture不变；原LevelPlan/Session等证据按同字节依赖保留。独立[修复窄审](review/ci-review-artifact-fix.md)明确更正首轮漏审的collector语义。
