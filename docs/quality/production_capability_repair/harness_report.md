# Harness 工程阶段：真实拒绝、有限生产闭环与成本边界

本报告只交付生产工具工程范围，不签全区商业美术、玩家或设备。原V3的44次请求、14次图生和失败归属来自[原件审计](../../evidence/production_capability_repair/harness/v3-evidence-audit.json)；本轮[机器摘要](../../evidence/production_capability_repair/harness/harness-summary.json)分别保留环境缺件、预检遗漏、实现缺陷、日志调用错误和真实资产失败。

本轮实际运行原production_loop：真实`/root`实施continuous校准，不同作者`/root/independent_review`审查，原controller收取后calls=2、工程G0 stage complete、content_complete=false。同源实际恢复没有新调用；注入外部源变化的隔离反例退出1，原state字节不变且calls仍2，随后恢复精确原源。完整请求/响应/检查点与可重建源覆盖保存在[原循环档案](../../evidence/production_capability_repair/harness/actual-family-loop-evidence.zip)。调度单测中的模拟worker只证明执行器合同，不计作额外自主生产。

实际第二张岩壁原图、原冻结规格未改：core `[64,64,1472,960]` 的alpha128覆盖`0.9845010336343344 < 0.995`，原CLI退出1，独审独立Pillow复核相同。[原失败报告](../../evidence/production_capability_repair/continuous_calibration/actual_failed_core/calibration.json)将完整冻结内核与声明的周边采样接口分栏；工具通过不追认岩壁家族、合缝或GPU品质。两轮岩壁方向停止，该失败岩壁最终消费者和三个export preset已排除；独审仅准入两RootBell空间的2树+1灌丛，不能追认原岩壁core。

工程修改均有实际失败依据：短专项失败保存前缀，停止本任务后续昂贵检查及审查，独立任务仍继续；任务`max_calls`限制单方向，失败/中断/重试不退款。实际route测试的知识缺件暴露既有预检遗漏，现在production-loop-tests和level-design-routing复用原lesson索引解析。完整full profile的真实依赖扫描物化旧原件后missing/import-risk/uncertain均为0，实际check_quality通过；没有改旧卡或略过检查。

独审先拒绝了初版缓存修复：默认jobs1仍归档空目录。最终版本归档真实生成物和原生log，校验输入摘要、归档SHA及默认工作区原件；改写/删除产物、源变化和链接都拒复用。额外声明`artifact_paths`保留隔离lane的art/ecology原件，并拒绝祖先目录symlink。原有检查保留，新增asset/正式植物/RootBell空间与行为专项接入原profiles；最终`--release`仍fresh。[测试变更说明](../../evidence/production_capability_repair/harness/test-change-justification.json)保留原断言与独审边界。

计时器是记录器。实际美术调用曾误将`--output`作为日志文件，缺日志记录保留，不能补造；现在`--log-file`保存真实合流stdout/stderr和SHA、拒覆盖旧文件。`--output/--artifact`只观察产物，exit0里的resource ERROR仍需专项拒绝。原标准入口实际23项harness/计时、87项production_loop、11项asset工具检查通过；独审另实跑缓存/计时反例。最终全游戏构建/发布由父交付记录提供，不由这些纯工具检查替代。

| 可见成本 | V3真实基线 | 本轮已观测范围 |
|---|---|---|
| 图生 | 14次，13次tool wall合计636.724秒；首次精确API时长不可见 | 当前3次tool wall 193.8秒，宿主包络217秒；其中一次78秒返工与图生重叠 |
| 模型 | 27/44个角色elapsed可见，包含工具与等待，不能称纯模型时间 | 一次真实实施和一次独审有原invocation区间；其他宿主工作及纯模型compute未测，不估算 |
| 完整交付 | deliver子步3461.096秒，gameplay/art2593.982秒 | 本报告截止未用工具专项冒充最终全游戏交付成本，父流程完成后刷新 |
| 冷checkout | 无可比完整网络分摊 | 实际逐blob恢复592.374秒后停止；剩147blob批取54.835秒、缓存restore0.459秒。对象集合/缓存状态不同，不报提速百分比 |

阶段[原始汇总快照](../../evidence/production_capability_repair/harness/phase-report-as-of-harness-handoff.json)包含实施、图生、实际集成、验证、审查、返工、网络和发布；区间求和/并集/重叠分开，旧seconds-only原件不伪造时间区间，token/价格not_exposed。这个快照只涵盖已记录事件，不是本轮全部墙钟。父流程结束后可按`build/production_repair/harness/report-command.json`原参数重采汇总，并加入最终fresh Harness和release事件；不能把不同工作范围的44与2次调用直接比较为效率提升。


最终闭窗：工程源码`fe84b4937347c8f8dd43f2c916f84689fa87cd8b`；[阶段原件](../../evidence/production_capability_repair/final_blocked_checkpoint/costs/phase-costs-as-of.json)为closed_blocked_observed_costs模式，已记录片段并集6267.743秒，非总工时。两次本地完整交付和A3/A4两个不同源CI失败全部计入，不同阶段/CI内层/返工标签不相加；返工专属排他时段未知，非0。旧as-of只作历史。原全地图terrain最终严格通过，但完整encounter仍20Obj7script资源阻断，未发第三CI/未发布；9ffe实际CI包三GUI通过不改签fe84。模型282.536秒与独审170.139秒仅覆盖实际连续校准两租约包络，其他宿主实施/审查、纯推理、token/价格未知。闭窗后的文档打包/最终静态复核另有原日志，不反复重算或冒完整项目总成本。
