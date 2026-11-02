# 模块调用边界与 CI 责任

基线 `8271d131331f961784bcd0b4dfe7ad28e8cf0f6f`。本批保留图声、物理、伤害、奖励、随机、存档及入口，只迁移实际调用与检查选择。

## 实际所有者

| 操作 | 改造后的调用 | 保留的协调职责 |
| --- | --- | --- |
| 森林地方表现及发现 Reader 装配 | App → `ThornForestRegionStage.configure_world_details` → 原 Actors／ambience／near scenery／Reader | App 传原玩家、生命、Lifetime、钱包和奖励窄依赖，负责暂停、输入、Manifest及流程错误 |
| 森林奖励解锁捷径 | cache hook 与 discovery acquired → 同一 `Stage.resolve_reward_shortcuts` → 原 Assembler | discovery 的 Manifest→捷径→音效→UI顺序保留 |
| 普通怪地方几何及恢复 | App → `EnemyActor.configure_region_placement` → 原 Behavior 配置／恢复接口 | App 保原伤害绑定、Actor绑定、错误输出／结束运行、表现同步和contact顺序 |

App 不再逐物种解码 shore、transfer、web、thread，也不装配森林内部节点。Actor 不接收 App／Director，不保存策略；攻击数量通过只在原成功点同步求值的窄 Callable 提供。六条原错误、缺失与空记录区别、短路和副作用顺序保持。Forest configure 沿用原一次性装配前置，不额外承诺幂等。

实际检查：Forest App95/0（含原真实按钮与暂停流程）、integration54/0、enemy-state61/0、run-session61/0、最终restore69/0且source_guard=true；18项所有权反例与13项依赖测试通过。首restore因并行CI配置变更被source guard拒绝，原件保留，冻结后完整重跑通过；不把原生marker代签该失败。见[源码及结果](../../evidence/module_boundaries_ci_01/boundary-source.json)。

## CI 如何选择

唯一责任配置仍是 `config/production_impact.json`，执行仍是原 `tools/production_plan.py` → Harness → Production impact 工作流。没有新增测试注册表；原218注册、full171＝92＋79、legacy手动30项及预算不变。

- 普通文档：docs／structure／quality三项纯Python共同门禁。
- 应用、玩家、战斗、装备、经济、奖励、成长、怪物、Boss、地图、表现、平台：共同门禁＋所属模块检查；Integration 再包含已列明的实际下游消费者。
- 内容权威、质量记录和世界设计文档：追加各自工具检查；原完整docs profile保留为显式入口。
- 已登记配置／资源：沿有限实际消费者映射；共享协议、玩家物理核心、存储格式、RNG、工具链、构建和未知路径继续full。
- 测试／工具入口：从原Harness argv反查所属检查；少量已核实测试族按责任模块处理。未知helper保守full，不把cache inputs当依赖图。
- 主线发布仍由原完整工作流验收。PR／开发按影响选择；选择器或共享workflow自身变更仍可触发full，不能用本次触发规则变更逃过其集成验证。

现有工作流在所选集合完全属于已验证的四项stdlib检查（共同三项＋harness-tests）时跳过媒体安装。其他情况保守安装；引擎、全量双通道和部署门槛保持。

实际选择示例（Integration计划，不表示这些检查已全部执行）：普通文档3项，普通怪24项，装备32项，奖励19项；玩家Motor、RunComposition或未知工具171项。完整检查名与理由见[计划样例](../../evidence/module_boundaries_ci_01/ci/selected-examples.json)，原33项去向见[责任清单](../../evidence/module_boundaries_ci_01/ci/original33-disposition.json)。新功能必须同步声明实际消费者，不能只依据文件夹名猜测下游。

选择器46项、Harness91项及原workflow专项通过；非作者独立验证19个计划控制、187个入口及4种环境条件。三项共同门禁也已在实际工作树fresh通过。以上是路由／限定功能证据，未代签远端新CI、完整171或公开发布。

## 回退与后续

调用迁移提交为 `4554687f`，回退基点为8271d131；CI路由作为其后继独立提交，回退基点为4554687f。按实际Git父提交逆序撤回。原内容权威的源码绑定与历史Bible30秒超时仍是独立已知阻断，本批没有以删检查、提高超时或刷新旧SHA隐藏它们。冻结最终源并闭合这些内容门槛后，再做完整集成／导出；本批未合main或发布。
