# P10 guard V2：真实借用对象补齐（外部，待最终独审）

只改两Python候选：`tools/underworld_pipeline.py`、`tests/test_underworld_pipeline.py`。没有修改主树或运行Godot，没有整App模板/全函数hash白名单，没有改profiles、注册项或原180秒预算。

## 首版拒绝保留

首版174测试通过不能推翻非作者新反例。原独审拒绝及probe逐字保存在本目录：原guard可误放行pickup/chest行`.duplicate()`及正确cast后的`rs = PlainsRegionStage.new()`。它们让外观正确的owner调用作用于错误对象。首版外部目录与其全部日志/冻结保持原样。

V2新增有限约束：两实际提交函数内，真实depth1 `random_stage := stage as GeneratedDemoStage` / `rs := stage as PlainsRegionStage` 后，分别借用精确数组行 `pickup: Dictionary = random_stage.pickups[index]` / `chest: Dictionary = rs.chests[_region_chest]`，再到原claim。四个局部名在该真实函数内不准再次直接/复合赋值、重新声明或loop shadow。只剔除那一个经过唯一实际mask/span验证的初始化声明后检查其余代码；字符串里的assignment-shaped文字不算重绑定。

这是有限局部变量/调用合同，不是任意别名/动态数据流证明，也不锁无关App函数。原owner短body、coin成功分支、claim/audio/feedback/persist/Manifest顺序、私有hook调用次数、其余Plains claimed写禁令及所有原负例都保留。

`receiver-probe-v2.json`逐一使用独审相同App mutant SHA：旧guard三个True，V2三个False，完整生产正例True。生产输入App仍是冻结be61，不把root当前应用P10或native fixture修订误诊为guard回归。

## 新测试自身的一次失败与修正

首轮V2原入口执行177 tests /10 failures，140.416秒/180，已完整保留`full-v2.*`，未改签。原164和首版10组通过；新测试误用全App首次字符串替换，分别改到了更早的 `_physics_process`、`_update_actions`、`_load_stage`，而非受保护的实际提交函数。`first-v2-new-fixture-failure-analysis.json`列出真实行号/函数；guard拒绝任意无关函数变化反而会扩大任务范围。

修正只在新增测试中先用现有唯一函数提取器找到 `_commit_pickup` / `_claim_region_chest` 完整body，再在该body内变异，且先断言完整上下文正例。guard字节没变；原172方法AST与首版全部方法AST没变。新增三组定向3/0，3.124秒，见`new-three-scoped-02.*`；最终仍须完整原177/180验证，不能以定向结果代签。

## 输入与主树边界

原始C59 guard在精确P10源上只出现两个已知source-guard拒绝，旧原报告保留。V2使用1637个普通文件约98MB薄overlay，无symlink/hardlink，数据来自C59、精确P10四生产文件及这两Python候选。root已授权把四生产文件应用主树，另修新增native run-session夹具；**本Python suite不读取、未复制或绑定该native runner**，不冒签旧/新runner。四生产SHA在验证前后逐一保持；主树dirty属于root独立任务，本作者不改主树。

全套入口仍为`python3 tests/test_underworld_pipeline.py`，原180秒hard timeout，清除PYTHONPATH；没有引擎、跨检查缓存或忽略项。原164+首版10组+本次3组=177。最终结果、两文件/patch精确SHA和普通源闭包在后继freeze及receipt；原首次177/10和首版独审拒绝不可删除或覆盖。

最终完整复验：177/0，134.879秒/原180，清除PYTHONPATH，输入向量前后完全一致。原首次177/10保留，guard自该次以来字节未变，只纠正新增变异的函数目标；原164与首版十组方法AST全部保留。此为Python源码guard验收，不签生产native或root另修的run-session夹具。
